package com.viegym.backend.exercise.entity;

/** Enum có nhãn tiếng Việt; app lấy nhãn từ backend để không giữ bộ danh mục thứ hai. */
public interface Labeled {
    String name();

    String label();
}
