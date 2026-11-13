package com.viegym.backend.admin;

import com.viegym.backend.auth.entity.UserRole;
import com.viegym.backend.auth.entity.UserStatus;
import com.viegym.backend.exercise.entity.Difficulty;
import com.viegym.backend.exercise.entity.Equipment;
import com.viegym.backend.exercise.entity.MediaType;
import com.viegym.backend.exercise.entity.MuscleGroup;
import com.viegym.backend.food.dto.FoodDtos.Option;
import com.viegym.backend.food.entity.DataQuality;
import com.viegym.backend.food.entity.FoodRegion;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

/** API admin (docs/05 §13, docs/31). Không trả entity, không trả password_hash/token. */
public final class AdminDtos {
    private AdminDtos() {
    }

    // URL tuyệt đối http(s); chặn javascript:, data:… dù frontend không chèn HTML.
    static final String HTTP_URL = "^https?://[^\\s<>\"]+$";

    private static String trimToNull(String value) {
        return value == null || value.isBlank() ? null : value.strip();
    }

    private static String trim(String value) {
        return value == null ? null : value.strip();
    }

    // ---------- Món ăn ----------

    /**
     * POST không gửi {@code revision}; PUT bắt buộc gửi revision đang sửa (409 nếu đã đổi).
     * Mọi số dinh dưỡng là của một khẩu phần {@code servingDescription} (BR-N01).
     */
    public record FoodRequest(
        @NotBlank(message = "Vui lòng nhập tên món")
        @Size(max = 150, message = "Tên món tối đa 150 ký tự")
        String name,

        @Size(max = 200, message = "Tên tiếng Anh tối đa 200 ký tự")
        String nameEn,

        @NotBlank(message = "Vui lòng chọn danh mục")
        String categoryCode,

        FoodRegion region,

        @NotBlank(message = "Vui lòng nhập nhãn khẩu phần")
        @Size(max = 100, message = "Nhãn khẩu phần tối đa 100 ký tự")
        String servingDescription,

        @DecimalMin(value = "0", inclusive = false, message = "Khối lượng phần phải lớn hơn 0")
        @Digits(integer = 5, fraction = 2, message = "Khối lượng phần tối đa 99999,99, 2 chữ số lẻ")
        BigDecimal servingSize,

        @Pattern(regexp = "^(g|ml)$", message = "Đơn vị là g hoặc ml")
        String servingUnit,

        @NotNull(message = "Vui lòng nhập kcal")
        @DecimalMin(value = "0", message = "Không được âm")
        @Digits(integer = 5, fraction = 2, message = "Tối đa 99999,99, 2 chữ số lẻ")
        BigDecimal kcalPerServing,

        @NotNull(message = "Vui lòng nhập đạm")
        @DecimalMin(value = "0", message = "Không được âm")
        @Digits(integer = 4, fraction = 2, message = "Tối đa 9999,99, 2 chữ số lẻ")
        BigDecimal proteinPerServing,

        @NotNull(message = "Vui lòng nhập bột đường")
        @DecimalMin(value = "0", message = "Không được âm")
        @Digits(integer = 4, fraction = 2, message = "Tối đa 9999,99, 2 chữ số lẻ")
        BigDecimal carbsPerServing,

        @NotNull(message = "Vui lòng nhập chất béo")
        @DecimalMin(value = "0", message = "Không được âm")
        @Digits(integer = 4, fraction = 2, message = "Tối đa 9999,99, 2 chữ số lẻ")
        BigDecimal fatPerServing,

        @NotNull(message = "Vui lòng chọn mức tin cậy")
        DataQuality dataQuality,

        @NotBlank(message = "Vui lòng nhập nguồn số liệu")
        @Size(max = 200, message = "Nguồn tối đa 200 ký tự")
        String source,

        @Size(max = 500, message = "URL tối đa 500 ký tự")
        @Pattern(regexp = HTTP_URL, message = "URL phải bắt đầu bằng http:// hoặc https://")
        String sourceUrl,

        @Size(max = 500, message = "URL tối đa 500 ký tự")
        @Pattern(regexp = HTTP_URL, message = "URL phải bắt đầu bằng http:// hoặc https://")
        String imageUrl,

        @Size(max = 300, message = "Ghi chú rà soát tối đa 300 ký tự")
        String reviewNote,

        @NotNull(message = "Vui lòng chọn trạng thái hiển thị")
        Boolean active,

        Integer revision
    ) {
        public FoodRequest {
            name = trim(name);
            nameEn = trimToNull(nameEn);
            categoryCode = trim(categoryCode);
            servingDescription = trim(servingDescription);
            servingUnit = trimToNull(servingUnit);
            source = trim(source);
            sourceUrl = trimToNull(sourceUrl);
            imageUrl = trimToNull(imageUrl);
            reviewNote = trimToNull(reviewNote);
        }
    }

    public record AdminFoodItem(UUID id, String code, String name, Option category, String servingDescription,
                                BigDecimal kcalPerServing, DataQuality dataQuality, boolean active,
                                int revision) {
    }

    public record AdminFoodDetail(UUID id, String code, String name, String nameEn, Option category,
                                  Option region, String servingDescription, BigDecimal servingSize,
                                  String servingUnit, BigDecimal kcalPerServing, BigDecimal proteinPerServing,
                                  BigDecimal carbsPerServing, BigDecimal fatPerServing, DataQuality dataQuality,
                                  String source, String sourceUrl, String imageUrl, String reviewNote,
                                  boolean active, int revision) {
    }

    public record AdminFoodOptions(List<Option> categories, List<Option> regions,
                                   List<DataQuality> dataQualities, List<String> servingUnits) {
    }

    // ---------- Bài tập ----------

    /** Media: URL http(s) hoặc key tĩnh {@code exercises/<tệp>} đã có; bỏ trống → app dùng ảnh mặc định. */
    public record ExerciseRequest(
        @NotBlank(message = "Vui lòng nhập tên bài")
        @Size(max = 150, message = "Tên bài tối đa 150 ký tự")
        String name,

        @NotNull(message = "Vui lòng chọn nhóm cơ")
        MuscleGroup muscleGroup,

        @NotNull(message = "Vui lòng chọn thiết bị")
        Equipment equipment,

        @NotNull(message = "Vui lòng chọn độ khó")
        Difficulty difficulty,

        @NotBlank(message = "Vui lòng nhập hướng dẫn")
        @Size(max = 4000, message = "Hướng dẫn tối đa 4000 ký tự")
        String instructions,

        @NotBlank(message = "Vui lòng nhập lỗi thường gặp")
        @Size(max = 4000, message = "Lỗi thường gặp tối đa 4000 ký tự")
        String commonMistakes,

        @Size(max = 500, message = "URL tối đa 500 ký tự")
        String thumbnailUrl,

        MediaType mediaType,

        @Size(max = 500, message = "URL tối đa 500 ký tự")
        String mediaUrl,

        @Size(max = 500, message = "Nguồn nội dung tối đa 500 ký tự")
        String contentSource,

        @Size(max = 500, message = "Giấy phép media tối đa 500 ký tự")
        String mediaLicense,

        @NotNull(message = "Vui lòng chọn trạng thái hiển thị")
        Boolean active,

        Integer revision
    ) {
        public ExerciseRequest {
            name = trim(name);
            instructions = trim(instructions);
            commonMistakes = trim(commonMistakes);
            thumbnailUrl = trimToNull(thumbnailUrl);
            mediaUrl = trimToNull(mediaUrl);
            contentSource = trimToNull(contentSource);
            mediaLicense = trimToNull(mediaLicense);
        }
    }

    public record AdminExerciseItem(UUID id, String code, String name, MuscleGroup muscleGroup,
                                    Equipment equipment, Difficulty difficulty, String thumbnailPreviewUrl,
                                    boolean active, int revision) {
    }

    /** {@code thumbnailUrl}/{@code mediaUrl} là giá trị lưu (để sửa); {@code *PreviewUrl} để hiển thị. */
    public record AdminExerciseDetail(UUID id, String code, String name, MuscleGroup muscleGroup,
                                      Equipment equipment, Difficulty difficulty, String instructions,
                                      String commonMistakes, String thumbnailUrl, String thumbnailPreviewUrl,
                                      MediaType mediaType, String mediaUrl, String mediaPreviewUrl,
                                      String contentSource, String mediaLicense, boolean active, int revision) {
    }

    // ---------- Người dùng ----------

    public record AdminUserItem(UUID id, String email, String fullName, UserRole role, UserStatus status,
                                Instant createdAt) {
    }

    public record UserStatusRequest(
        @NotNull(message = "Vui lòng chọn trạng thái")
        UserStatus status,

        @Size(max = 300, message = "Lý do tối đa 300 ký tự")
        String reason
    ) {
        public UserStatusRequest {
            reason = trimToNull(reason);
        }
    }
}
