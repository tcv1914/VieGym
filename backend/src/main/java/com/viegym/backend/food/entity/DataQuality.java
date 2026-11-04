package com.viegym.backend.food.entity;

/**
 * Mức tin cậy của số liệu (docs/20 §1). SOURCED: lấy nguyên từ nguồn truy xuất được;
 * ESTIMATED: tính/ước lượng (phải ghi cách tính); DEMO: dữ liệu minh họa, không dùng tư vấn.
 */
public enum DataQuality {
    SOURCED,
    ESTIMATED,
    DEMO
}
