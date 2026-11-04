package com.viegym.backend.food.entity;

/** Vùng đo của nguồn Viện Dinh dưỡng; cùng tên món ở vùng khác là một phần ăn khác. */
public enum FoodRegion {
    VPF("Toàn quốc"),
    HAN("Hà Nội"),
    HAP("Hải Phòng"),
    SFF("Miền Bắc");

    private final String label;

    FoodRegion(String label) {
        this.label = label;
    }

    public String label() {
        return label;
    }
}
