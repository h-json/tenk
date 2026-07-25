package com.hjson.tenk.domain.app;

/**
 * "1.0.0" 형태의 버전 비교. 빌드/프리릴리스 접미사(+3, -beta)는 무시하고 숫자 부분만 비교한다.
 * 파싱 불가한 입력은 {@link IllegalArgumentException} 을 던지므로, 클라 버전처럼 신뢰할 수 없는 값은
 * 호출부가 예외를 잡아 fail-open(게이트 미적용) 처리할 것.
 */
public final class SemanticVersion implements Comparable<SemanticVersion> {

    private final int[] parts;

    private SemanticVersion(int[] parts) {
        this.parts = parts;
    }

    public static SemanticVersion parse(String raw) {
        if (raw == null) {
            throw new IllegalArgumentException("version is null");
        }
        // "1.0.0+3" / "1.0.0-beta" → "1.0.0"
        String core = raw.trim().split("[+-]", 2)[0];
        if (core.isEmpty()) {
            throw new IllegalArgumentException("version is blank: " + raw);
        }
        String[] tokens = core.split("\\.");
        int[] p = new int[tokens.length];
        for (int i = 0; i < tokens.length; i++) {
            try {
                p[i] = Integer.parseInt(tokens[i].trim());
            } catch (NumberFormatException e) {
                throw new IllegalArgumentException("invalid version segment: " + raw, e);
            }
        }
        return new SemanticVersion(p);
    }

    @Override
    public int compareTo(SemanticVersion o) {
        int len = Math.max(parts.length, o.parts.length);
        for (int i = 0; i < len; i++) {
            int a = i < parts.length ? parts[i] : 0;
            int b = i < o.parts.length ? o.parts[i] : 0;
            if (a != b) {
                return Integer.compare(a, b);
            }
        }
        return 0;
    }
}
