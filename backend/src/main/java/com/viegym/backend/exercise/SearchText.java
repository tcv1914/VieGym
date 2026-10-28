package com.viegym.backend.exercise;

import java.text.Normalizer;
import java.util.Locale;
import java.util.regex.Pattern;

/** Chuẩn hóa tên để tìm không dấu; seed SQL (V5) được sinh bằng đúng quy tắc này. */
public final class SearchText {
    public static final char LIKE_ESCAPE = '\\';

    private static final Pattern MARKS = Pattern.compile("\\p{M}+");
    private static final Pattern SPACES = Pattern.compile("\\s+", Pattern.UNICODE_CHARACTER_CLASS);

    private SearchText() {
    }

    /** Bỏ dấu, đ → d, chữ thường, gộp khoảng trắng: "  Đẩy   NGỰC " → "day nguc". */
    public static String normalize(String value) {
        if (value == null) {
            return "";
        }
        String stripped = MARKS.matcher(Normalizer.normalize(value, Normalizer.Form.NFD)).replaceAll("");
        String lower = stripped.replace('đ', 'd').replace('Đ', 'D').toLowerCase(Locale.ROOT);
        return SPACES.matcher(lower).replaceAll(" ").strip();
    }

    /** Để %, _ và ký tự escape trong keyword được so khớp như chữ thường, không phải wildcard. */
    public static String escapeLike(String value) {
        StringBuilder out = new StringBuilder(value.length());
        for (char ch : value.toCharArray()) {
            if (ch == LIKE_ESCAPE || ch == '%' || ch == '_') {
                out.append(LIKE_ESCAPE);
            }
            out.append(ch);
        }
        return out.toString();
    }
}
