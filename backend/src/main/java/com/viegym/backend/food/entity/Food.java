package com.viegym.backend.food.entity;

import com.viegym.backend.exercise.SearchText;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * Một món với dinh dưỡng của đúng một khẩu phần chuẩn (BR-N01). Chỉ đọc ở ngày 9; admin sửa ở
 * ngày 14 (docs/31). {@code servingSize} null khi nguồn không công bố khối lượng phần (docs/20 §2).
 */
@Entity
@Table(name = "foods")
public class Food {
    @Id
    private UUID id;

    @Column(nullable = false, updatable = false, length = 30)
    private String code;

    @Column(nullable = false, length = 150)
    private String name;

    @Column(name = "name_en", length = 200)
    private String nameEn;

    @Column(name = "name_search", nullable = false, length = 150)
    private String nameSearch;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "category_id", nullable = false)
    private FoodCategory category;

    @Enumerated(EnumType.STRING)
    @Column(length = 3)
    private FoodRegion region;

    @Column(name = "serving_size", precision = 7, scale = 2)
    private BigDecimal servingSize;

    @Column(name = "serving_unit", length = 20)
    private String servingUnit;

    @Column(name = "serving_description", nullable = false, length = 100)
    private String servingDescription;

    @Column(name = "kcal_per_serving", nullable = false, precision = 7, scale = 2)
    private BigDecimal kcalPerServing;

    @Column(name = "protein_per_serving", nullable = false, precision = 6, scale = 2)
    private BigDecimal proteinPerServing;

    @Column(name = "carbs_per_serving", nullable = false, precision = 6, scale = 2)
    private BigDecimal carbsPerServing;

    @Column(name = "fat_per_serving", nullable = false, precision = 6, scale = 2)
    private BigDecimal fatPerServing;

    @Enumerated(EnumType.STRING)
    @Column(name = "data_quality", nullable = false, length = 10)
    private DataQuality dataQuality;

    @Column(nullable = false, length = 200)
    private String source;

    @Column(name = "source_url", length = 500)
    private String sourceUrl;

    @Column(name = "image_url", length = 500)
    private String imageUrl;

    @Column(name = "review_note", length = 300)
    private String reviewNote;

    @Column(name = "is_active", nullable = false)
    private boolean active;

    @Column(nullable = false)
    private int revision;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected Food() {
    }

    /** Món admin tạo; {@code code} cố định từ lúc tạo (docs/31 §3). */
    public Food(String code, FoodValues values, Instant now) {
        this.id = UUID.randomUUID();
        this.code = code;
        this.revision = 1;
        this.updatedAt = now;
        assign(values);
    }

    /** Ghi đè toàn bộ trường sửa được và tăng revision; snapshot thực đơn cũ không bị đụng (NUT-BR05). */
    public void update(FoodValues values, Instant now) {
        assign(values);
        this.revision++;
        this.updatedAt = now;
    }

    public FoodValues values() {
        return new FoodValues(name, nameEn, category, region, servingSize, servingUnit, servingDescription,
            kcalPerServing, proteinPerServing, carbsPerServing, fatPerServing, dataQuality, source, sourceUrl,
            imageUrl, reviewNote, active);
    }

    private void assign(FoodValues v) {
        this.name = v.name();
        this.nameEn = v.nameEn();
        this.nameSearch = SearchText.normalize(v.name());
        this.category = v.category();
        this.region = v.region();
        this.servingSize = v.servingSize();
        this.servingUnit = v.servingUnit();
        this.servingDescription = v.servingDescription();
        this.kcalPerServing = v.kcalPerServing();
        this.proteinPerServing = v.proteinPerServing();
        this.carbsPerServing = v.carbsPerServing();
        this.fatPerServing = v.fatPerServing();
        this.dataQuality = v.dataQuality();
        this.source = v.source();
        this.sourceUrl = v.sourceUrl();
        this.imageUrl = v.imageUrl();
        this.reviewNote = v.reviewNote();
        this.active = v.active();
    }

    public UUID getId() {
        return id;
    }

    public String getCode() {
        return code;
    }

    public String getName() {
        return name;
    }

    public String getNameEn() {
        return nameEn;
    }

    public FoodCategory getCategory() {
        return category;
    }

    public FoodRegion getRegion() {
        return region;
    }

    public BigDecimal getServingSize() {
        return servingSize;
    }

    public String getServingUnit() {
        return servingUnit;
    }

    public String getServingDescription() {
        return servingDescription;
    }

    public BigDecimal getKcalPerServing() {
        return kcalPerServing;
    }

    public BigDecimal getProteinPerServing() {
        return proteinPerServing;
    }

    public BigDecimal getCarbsPerServing() {
        return carbsPerServing;
    }

    public BigDecimal getFatPerServing() {
        return fatPerServing;
    }

    public DataQuality getDataQuality() {
        return dataQuality;
    }

    public String getSource() {
        return source;
    }

    public String getSourceUrl() {
        return sourceUrl;
    }

    public String getImageUrl() {
        return imageUrl;
    }

    public String getReviewNote() {
        return reviewNote;
    }

    public boolean isActive() {
        return active;
    }

    public int getRevision() {
        return revision;
    }
}
