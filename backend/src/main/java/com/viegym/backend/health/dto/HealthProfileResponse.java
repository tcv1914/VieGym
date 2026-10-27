package com.viegym.backend.health.dto;

import com.viegym.backend.health.entity.ActivityLevel;
import com.viegym.backend.health.entity.Goal;
import com.viegym.backend.health.entity.HealthProfile;
import com.viegym.backend.health.entity.NutritionTarget;
import com.viegym.backend.health.entity.Sex;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;

/** docs/05-api-contract.md §3. */
public record HealthProfileResponse(Profile profile, Targets targets) {
    /** {@code age} tính tại hôm nay; có thể lớn hơn tuổi lúc tính mục tiêu (BR-H04). */
    public record Profile(Sex sex, LocalDate dateOfBirth, int age, BigDecimal heightCm, BigDecimal weightKg,
                          ActivityLevel activityLevel, Goal goal, Instant updatedAt) {
    }

    public record Targets(BigDecimal bmi, BigDecimal bmrKcal, BigDecimal tdeeKcal, BigDecimal targetKcal,
                          BigDecimal proteinG, BigDecimal carbsG, BigDecimal fatG, boolean kcalFloorApplied,
                          String formulaVersion, Instant calculatedAt) {
    }

    public static HealthProfileResponse of(HealthProfile p, NutritionTarget t, int age) {
        return new HealthProfileResponse(
            new Profile(p.getSex(), p.getDateOfBirth(), age, p.getHeightCm(), p.getWeightKg(),
                p.getActivityLevel(), p.getGoal(), p.getUpdatedAt()),
            new Targets(t.getBmi(), t.getBmrKcal(), t.getTdeeKcal(), t.getTargetKcal(), t.getProteinG(),
                t.getCarbsG(), t.getFatG(), t.isKcalFloorApplied(), t.getFormulaVersion(), t.getCalculatedAt()));
    }
}
