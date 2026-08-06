package com.hjson.tenk.admin;

import com.hjson.tenk.domain.inquiry.Inquiry;
import java.time.format.DateTimeFormatter;
import java.util.stream.Collectors;

/**
 * 패널의 '메일로 답장' 버튼에 미리 채워 넣을 답장 초안 (받는 사람 · 제목 · 원문 인용).
 *
 * <p><b>알림에서 본문을 뺀 대가로 생긴 장치다.</b> 예전에는 알림 메일에 문의 본문이 통째로 들어가
 * '답장' 한 번이면 원문이 자동 인용됐는데, 알림이 신호만 전하게 되면서 그 경로가 사라졌다. 여기서
 * 원문을 인용해 두지 않으면 운영자가 패널과 메일 사이를 손으로 복붙해야 하고, <b>답장 스레드가
 * 아카이브</b>라는 전제({@code Inquiry.handlerNote} 에 답변 전문을 적지 않기로 한 근거)도 함께 무너진다.
 *
 * <p>⚠️ <b>{@code mailto:} 가 아니라 Gmail 작성 링크에 실을 값이다.</b> 한글은 URL 인코딩하면 1자가
 * 9자(<code>%EC%9E%90</code>)가 돼 본문 1000자짜리 문의는 9,000자 URL 이 되는데, OS 로 넘기는
 * {@code mailto:} 는 2KB 안팎에서 잘린다. 브라우저가 여는 링크에는 그 제한이 없다.
 *
 * <p>⚠️ <b>여기서 만든 문자열을 DB 나 로그에 저장하지 말 것</b> — 원문 사본이라 저장하는 순간
 * 보관 대상 개인정보가 하나 늘어난다. 화면에서 메일 클라이언트로 건네주고 끝나는 값이다.
 */
public record InquiryReplyDraft(String to, String subject, String body) {

    private static final DateTimeFormatter STAMP = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm");

    public static InquiryReplyDraft of(Inquiry inquiry) {
        return new InquiryReplyDraft(
                inquiry.getReplyEmail(),
                // 제목에 문의 번호를 넣어 스레드를 대조한다.
                "[TenK] 문의 #%d 답변".formatted(inquiry.getId()),
                """
                안녕하세요, TenK 입니다.


                ------------------------------
                %s에 접수된 문의입니다.

                %s
                """.formatted(
                        inquiry.getCreatedDt().format(STAMP),
                        quote(inquiry.getContent())));
    }

    /** 원문을 인용 부호로 감싼다 — 답변만 위에 쓰면 되도록. */
    private static String quote(String content) {
        return content.lines()
                .map(line -> "> " + line)
                .collect(Collectors.joining("\n"));
    }
}
