package com.hjson.tenk.admin;

import com.hjson.tenk.domain.inquiry.Inquiry;
import com.hjson.tenk.domain.inquiry.InquiryStatus;
import com.hjson.tenk.domain.user.UserRole;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

/**
 * 관리자 패널 화면. <b>컨트롤러는 얇게</b> — 조회·변경은 전부 {@link AdminService} 가 한다.
 *
 * <p>이 패널이 대체하는 것: SSH → {@code docker compose exec db mariadb} → {@code SELECT}/
 * {@code UPDATE} 의례 네 가지(문의 처리 · 의견 열람 · TESTER 승격 · 앱 버전 정책).
 *
 * <p>⚠️ <b>여기에 이용자 데이터를 편집·삭제하는 화면을 늘리지 말 것.</b> 삭제의 진실의 원천은
 * 앱의 탈퇴 흐름과 파기 배치이고, 패널이 우회로가 되면 그 계약이 무너진다. 이 패널은
 * <b>운영에 필요한 최소한</b>만 한다 (범위는 decisions.md "관리자 패널" 참고).
 *
 * <p>패널이 꺼져 있으면({@code tenk.admin.enabled=false}) 이 빈 자체가 등록되지 않는다.
 */
@Controller
@RequestMapping("/admin")
@RequiredArgsConstructor
@ConditionalOnProperty(prefix = "tenk.admin", name = "enabled", havingValue = "true")
public class AdminController {

    private final AdminService adminService;
    /**
     * <b>열람도 접속기록 대상이다</b> — 고시의 '수행업무'에 조회가 포함되고, 실제로 유출은 변경이
     * 아니라 열람에서 일어난다. 개인정보가 <b>화면에 실제로 보이는</b> 곳에만 건다 — 대시보드(집계 숫자)와
     * 앱 버전(정책 값)은 개인정보가 아니라 제외했다. 변경 기록은 {@link AdminService} 가 담당한다.
     */
    private final AdminAudit audit;

    /** 로그인 화면. 인증 전 유일하게 열린 경로라 모델에 아무것도 담지 않는다. */
    @GetMapping("/login")
    public String login() {
        return "admin/login";
    }

    @GetMapping
    public String dashboard(Model model) {
        model.addAttribute("summary", adminService.dashboard());
        model.addAttribute("menu", "dashboard");
        return "admin/dashboard";
    }

    // ── 문의 ────────────────────────────────────────────────────

    /**
     * @param status {@code PENDING}/{@code DONE}, 비우면 전체.
     *               <b>기본값이 PENDING 인 게 의도다</b> — 이 패널을 여는 이유의 대부분이 미처리 확인이다.
     */
    @GetMapping("/inquiries")
    public String inquiries(
            @RequestParam(required = false, defaultValue = "PENDING") String status,
            @PageableDefault(size = 20, sort = "createdDt", direction = Sort.Direction.DESC) Pageable pageable,
            Model model) {
        InquiryStatus filter = "ALL".equals(status) ? null : InquiryStatus.valueOf(status);
        audit.record("INQUIRY_LIST_VIEW", "inquiry", "status=" + status + " page=" + pageable.getPageNumber());
        model.addAttribute("page", adminService.inquiries(filter, pageable));
        model.addAttribute("status", status);
        model.addAttribute("menu", "inquiries");
        return "admin/inquiries";
    }

    @GetMapping("/inquiries/{id}")
    public String inquiry(@PathVariable Long id, Model model) {
        // 본문·회신 이메일·계정이 한 화면에 다 나오는 곳이라 열람 기록이 가장 필요한 지점이다.
        audit.record("INQUIRY_VIEW", "inquiry#" + id, "-");
        Inquiry inquiry = adminService.inquiry(id);
        model.addAttribute("inquiry", inquiry);
        // 알림이 본문을 싣지 않으므로, 답장에 원문을 넣는 건 이 초안이 맡는다.
        model.addAttribute("draft", InquiryReplyDraft.of(inquiry));
        model.addAttribute("menu", "inquiries");
        return "admin/inquiry-detail";
    }

    @PostMapping("/inquiries/{id}/handle")
    public String handleInquiry(@PathVariable Long id,
                                @RequestParam(required = false) String note,
                                RedirectAttributes redirect) {
        adminService.handleInquiry(id, note);
        redirect.addFlashAttribute("flash", "처리 완료로 표시했어요. 리마인드에서 빠집니다.");
        return "redirect:/admin/inquiries/" + id;
    }

    @PostMapping("/inquiries/{id}/reopen")
    public String reopenInquiry(@PathVariable Long id, RedirectAttributes redirect) {
        adminService.reopenInquiry(id);
        redirect.addFlashAttribute("flash", "미처리로 되돌렸어요. 매일 18시 리마인드 대상이 됩니다.");
        return "redirect:/admin/inquiries/" + id;
    }

    // ── 의견 ────────────────────────────────────────────────────

    @GetMapping("/feedbacks")
    public String feedbacks(
            @PageableDefault(size = 20, sort = "createdDt", direction = Sort.Direction.DESC) Pageable pageable,
            Model model) {
        // 의견은 익명이지만 회신 이메일이 보이므로 열람 기록 대상이다.
        audit.record("FEEDBACK_LIST_VIEW", "feedback", "page=" + pageable.getPageNumber());
        model.addAttribute("page", adminService.feedbacks(pageable));
        model.addAttribute("menu", "feedbacks");
        return "admin/feedbacks";
    }

    @PostMapping("/feedbacks/{id}/note")
    public String writeFeedbackNote(@PathVariable Long id,
                                    @RequestParam(required = false) String note,
                                    @RequestParam(required = false) Integer page,
                                    RedirectAttributes redirect) {
        adminService.writeFeedbackNote(id, note);
        redirect.addFlashAttribute("flash", "메모를 저장했어요.");
        return "redirect:/admin/feedbacks" + (page == null ? "" : "?page=" + page);
    }

    // ── 사용자 ──────────────────────────────────────────────────

    @GetMapping("/users")
    public String users(@RequestParam(required = false) String keyword,
                        @PageableDefault(size = 20, sort = "createdDt", direction = Sort.Direction.DESC) Pageable pageable,
                        Model model) {
        // ⚠️ 검색어 자체를 기록하지 않는다 — 닉네임으로 검색하면 그게 곧 개인정보다.
        //    "누가 언제 사용자 목록을 봤나"만 남기면 접속기록의 목적은 충족된다.
        audit.record("USER_LIST_VIEW", "user",
                "keyword=" + (keyword == null || keyword.isBlank() ? "none" : "given")
                        + " page=" + pageable.getPageNumber());
        model.addAttribute("page", adminService.searchUsers(keyword, pageable));
        model.addAttribute("keyword", keyword);
        model.addAttribute("menu", "users");
        return "admin/users";
    }

    @PostMapping("/users/{id}/role")
    public String changeUserRole(@PathVariable Long id,
                                 @RequestParam UserRole role,
                                 @RequestParam(required = false) String keyword,
                                 RedirectAttributes redirect) {
        adminService.changeUserRole(id, role);
        redirect.addFlashAttribute("flash", "권한을 " + role + " 로 바꿨어요.");
        return "redirect:/admin/users" + (keyword == null || keyword.isBlank() ? "" : "?keyword=" + keyword);
    }

    // ── 앱 버전 정책 ────────────────────────────────────────────

    @GetMapping("/app-config")
    public String appConfig(Model model) {
        model.addAttribute("config", adminService.appConfig().orElse(null));
        model.addAttribute("menu", "app-config");
        return "admin/app-config";
    }

    @PostMapping("/app-config")
    public String updateAppConfig(@RequestParam String minSupportedVersion,
                                  @RequestParam String latestVersion,
                                  @RequestParam(required = false) String androidStoreUrl,
                                  @RequestParam(required = false) String iosStoreUrl,
                                  RedirectAttributes redirect) {
        adminService.updateAppConfig(minSupportedVersion, latestVersion, androidStoreUrl, iosStoreUrl);
        redirect.addFlashAttribute("flash", "앱 버전 정책을 저장했어요. 재배포 없이 즉시 반영됩니다.");
        return "redirect:/admin/app-config";
    }
}
