package com.hjson.tenk.admin;

import com.hjson.tenk.common.exception.BusinessException;
import com.hjson.tenk.common.exception.ErrorCode;
import com.hjson.tenk.domain.app.AppConfig;
import com.hjson.tenk.domain.app.AppConfigRepository;
import com.hjson.tenk.domain.feedback.Feedback;
import com.hjson.tenk.domain.feedback.FeedbackRepository;
import com.hjson.tenk.domain.inquiry.Inquiry;
import com.hjson.tenk.domain.inquiry.InquiryRepository;
import com.hjson.tenk.domain.inquiry.InquiryStatus;
import com.hjson.tenk.domain.user.User;
import com.hjson.tenk.domain.user.UserRepository;
import com.hjson.tenk.domain.user.UserRole;
import java.time.LocalDateTime;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 관리자 패널의 조회·변경. <b>이용자용 서비스와 일부러 분리했다</b> — 앱이 쓰는
 * {@code InquiryService}/{@code UserService} 에 운영 기능을 섞으면 두 종류의 호출자가 한 클래스를
 * 공유하게 되고, "이 메서드는 누가 부르나"가 흐려진다. 도메인 불변식은 여전히 엔티티에 있다
 * ({@code Inquiry.markHandled}, {@code User.changeRole}).
 *
 * <p>모든 변경은 {@link AdminAudit} 에 기록한다 — 패널이 SQL 직접 접근을 대체하면서 생긴 이점이라
 * <b>기록 없이 바꾸는 경로를 만들지 말 것</b>.
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class AdminService {

    private final InquiryRepository inquiryRepository;
    private final FeedbackRepository feedbackRepository;
    private final UserRepository userRepository;
    private final AppConfigRepository appConfigRepository;
    private final AdminAudit audit;

    // ── 대시보드 ────────────────────────────────────────────────

    /** 첫 화면에 띄우는 숫자. 미처리 문의가 0인지 아닌지가 이 패널의 유일한 "할 일" 신호다. */
    public DashboardSummary dashboard() {
        return new DashboardSummary(
                inquiryRepository.countByStatus(InquiryStatus.PENDING),
                inquiryRepository.count(),
                feedbackRepository.count());
    }

    public record DashboardSummary(long pendingInquiries, long totalInquiries, long totalFeedbacks) {
    }

    // ── 문의 ────────────────────────────────────────────────────

    /** @param status null 이면 전체, 아니면 그 상태만 */
    public Page<Inquiry> inquiries(InquiryStatus status, Pageable pageable) {
        return status == null
                ? inquiryRepository.findAllForAdmin(pageable)
                : inquiryRepository.findAllForAdminByStatus(status, pageable);
    }

    public Inquiry inquiry(Long id) {
        return inquiryRepository.findByIdForAdmin(id)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND));
    }

    /** 처리 완료로 표시 → 매일 09:00 리마인드에서 빠진다. 메모는 비워도 된다. */
    @Transactional
    public void handleInquiry(Long id, String note) {
        Inquiry inquiry = inquiry(id);
        inquiry.markHandled(note, LocalDateTime.now());
        audit.record("INQUIRY_HANDLE", "inquiry#" + id, "status=DONE noteLength=" + length(note));
    }

    /** 처리 표시를 되돌린다 — 다시 리마인드 대상이 된다. */
    @Transactional
    public void reopenInquiry(Long id) {
        inquiry(id).markPending();
        audit.record("INQUIRY_REOPEN", "inquiry#" + id, "status=PENDING");
    }

    // ── 의견 ────────────────────────────────────────────────────

    public Page<Feedback> feedbacks(Pageable pageable) {
        return feedbackRepository.findAll(pageable);
    }

    /** 의견에는 처리 상태가 없다 — 남길 수 있는 건 메모뿐이고 그게 "봤다"의 표시다. */
    @Transactional
    public void writeFeedbackNote(Long id, String note) {
        Feedback feedback = feedbackRepository.findById(id)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND));
        feedback.writeHandlerNote(note);
        audit.record("FEEDBACK_NOTE", "feedback#" + id, "noteLength=" + length(note));
    }

    // ── 사용자 ──────────────────────────────────────────────────

    /** @param keyword 닉네임 부분 일치 또는 공급자 회원번호 정확 일치. 비면 전체. */
    public Page<User> searchUsers(String keyword, Pageable pageable) {
        String normalized = (keyword == null || keyword.isBlank()) ? null : keyword.trim();
        return userRepository.searchForAdmin(normalized, pageable);
    }

    /**
     * 권한 변경. ⚠️ {@code TESTER} 는 <b>시딩 권한</b>이고 시딩은 그 계정의 데이터를 통째로 지운다 —
     * 소모용 계정에만 줄 것 (심사자 데모 계정 승격 금지).
     *
     * <p><b>{@code ADMIN} 으로는 올릴 수 없다.</b> 그 상수는 이용자 계정에 관리 권한을 줄 때의 자리이고
     * 패널 로그인은 {@code admin_user} 가 담당한다 — 두 축을 섞으면 권한 상승 경로가 생긴다.
     */
    @Transactional
    public void changeUserRole(Long userId, UserRole role) {
        if (role == UserRole.ADMIN) {
            throw new BusinessException(ErrorCode.INVALID_INPUT);
        }
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new BusinessException(ErrorCode.USER_NOT_FOUND));
        UserRole before = user.getRole();
        user.changeRole(role);
        audit.record("USER_ROLE_CHANGE", "user#" + userId, before + "->" + role);
    }

    // ── 앱 버전 정책 ────────────────────────────────────────────

    public Optional<AppConfig> appConfig() {
        return appConfigRepository.findById(AppConfig.SINGLETON_ID);
    }

    /**
     * 앱 버전 정책 갱신. 예전의 {@code UPDATE app_config ...} 을 대체한다.
     *
     * <p>⚠️ <b>{@code minSupportedVersion} 을 올릴 땐 스토어 게시 반영을 먼저 확인할 것</b> —
     * 스토어에 그 버전이 아직 없으면 사용자가 강제 업데이트 화면에서 나갈 길이 없다.
     */
    @Transactional
    public void updateAppConfig(String minSupportedVersion, String latestVersion,
                                String androidStoreUrl, String iosStoreUrl) {
        AppConfig config = appConfig()
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND));
        String before = config.getMinSupportedVersion() + "/" + config.getLatestVersion();
        config.updatePolicy(minSupportedVersion, latestVersion, androidStoreUrl, iosStoreUrl);
        audit.record("APP_CONFIG_UPDATE", "app_config#" + AppConfig.SINGLETON_ID,
                "min/latest " + before + " -> " + minSupportedVersion + "/" + latestVersion);
    }

    private static int length(String value) {
        return value == null ? 0 : value.trim().length();
    }
}
