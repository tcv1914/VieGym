package com.viegym.backend.health;

import com.viegym.backend.auth.entity.User;
import com.viegym.backend.auth.repository.UserRepository;
import com.viegym.backend.common.exception.ApiException;
import com.viegym.backend.health.dto.HealthProfileRequest;
import com.viegym.backend.health.dto.HealthProfileResponse;
import com.viegym.backend.health.entity.HealthProfile;
import com.viegym.backend.health.entity.NutritionTarget;
import com.viegym.backend.health.repository.HealthProfileRepository;
import com.viegym.backend.health.repository.NutritionTargetRepository;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class HealthProfileService {
    private final UserRepository userRepository;
    private final HealthProfileRepository profileRepository;
    private final NutritionTargetRepository targetRepository;
    private final Clock clock;

    public HealthProfileService(UserRepository userRepository, HealthProfileRepository profileRepository,
                                NutritionTargetRepository targetRepository, Clock clock) {
        this.userRepository = userRepository;
        this.profileRepository = profileRepository;
        this.targetRepository = targetRepository;
        this.clock = clock;
    }

    /** Chỉ đọc; không tính lại mục tiêu dù tuổi đã đổi (BR-H04). */
    @Transactional(readOnly = true)
    public HealthProfileResponse get(UUID userId) {
        User user = userRepository.findById(userId).orElseThrow(HealthProfileService::userNotFound);
        HealthProfile profile = profileRepository.findByUserId(userId)
            .orElseThrow(HealthProfileService::profileRequired);
        NutritionTarget target = targetRepository.findByUserId(userId)
            .orElseThrow(() -> new IllegalStateException("Hồ sơ có nhưng thiếu mục tiêu: user " + userId));
        int age = HealthCalculator.ageOn(profile.getDateOfBirth(), today(user));
        return HealthProfileResponse.of(profile, target, age);
    }

    /** BR-H01: hồ sơ và mục tiêu ghi cùng giao dịch; lỗi ở bất kỳ bước nào thì không lưu gì. */
    @Transactional
    public HealthProfileResponse put(UUID userId, HealthProfileRequest request) {
        // Khóa hàng users: hai PUT đầu tiên đồng thời không cùng INSERT hồ sơ rồi vấp UNIQUE.
        User user = userRepository.findForUpdate(userId).orElseThrow(HealthProfileService::userNotFound);
        // Cột TIMESTAMPTZ giữ tới micro giây; cắt trước để response PUT và GET sau đó khớp nhau.
        Instant now = clock.instant().truncatedTo(ChronoUnit.MICROS);
        int age = validAge(request.dateOfBirth(), today(user));

        HealthCalculator.Result result = HealthCalculator.calculate(new HealthCalculator.Input(
            request.sex(), age, request.heightCm(), request.weightKg(), request.activityLevel(), request.goal()));

        HealthProfile profile = profileRepository.findByUserId(userId)
            .orElseGet(() -> new HealthProfile(userId, now));
        profile.replace(request.sex(), request.dateOfBirth(), request.heightCm(), request.weightKg(),
            request.activityLevel(), request.goal(), now);
        profileRepository.save(profile);

        NutritionTarget target = targetRepository.findByUserId(userId)
            .orElseGet(() -> new NutritionTarget(userId, now));
        target.apply(result, now);
        targetRepository.save(target);

        return HealthProfileResponse.of(profile, target, age);
    }

    /** "Hôm nay" theo múi giờ của user (BR-G04), không theo múi giờ máy chủ. */
    private LocalDate today(User user) {
        return LocalDate.now(clock.withZone(ZoneId.of(user.getTimezone())));
    }

    private static int validAge(LocalDate dateOfBirth, LocalDate today) {
        if (dateOfBirth.isAfter(today)) {
            throw ApiException.validation("dateOfBirth", "Ngày sinh không được ở tương lai");
        }
        int age = HealthCalculator.ageOn(dateOfBirth, today);
        if (age < HealthCalculator.MIN_AGE || age > HealthCalculator.MAX_AGE) {
            throw ApiException.validation("dateOfBirth", "Ứng dụng hỗ trợ người từ %d đến %d tuổi"
                .formatted(HealthCalculator.MIN_AGE, HealthCalculator.MAX_AGE));
        }
        return age;
    }

    private static ApiException profileRequired() {
        return new ApiException(HttpStatus.NOT_FOUND, "HEALTH_PROFILE_REQUIRED", "Bạn chưa có hồ sơ sức khỏe");
    }

    private static ApiException userNotFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "NOT_FOUND", "Không tìm thấy tài khoản");
    }
}
