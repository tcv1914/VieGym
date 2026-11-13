package com.viegym.backend.admin;

import com.viegym.backend.admin.AdminDtos.AdminExerciseDetail;
import com.viegym.backend.admin.AdminDtos.AdminExerciseItem;
import com.viegym.backend.admin.AdminDtos.AdminFoodDetail;
import com.viegym.backend.admin.AdminDtos.AdminFoodItem;
import com.viegym.backend.admin.AdminDtos.AdminFoodOptions;
import com.viegym.backend.admin.AdminDtos.AdminUserItem;
import com.viegym.backend.admin.AdminDtos.ExerciseRequest;
import com.viegym.backend.admin.AdminDtos.FoodRequest;
import com.viegym.backend.admin.AdminDtos.UserStatusRequest;
import com.viegym.backend.auth.entity.UserStatus;
import com.viegym.backend.common.security.AuthenticatedUser;
import com.viegym.backend.common.web.PageResponse;
import com.viegym.backend.exercise.entity.MuscleGroup;
import jakarta.validation.Valid;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * docs/05 §13, docs/31. Quyền ADMIN kiểm tra ở SecurityConfig cho cả {@code /api/v1/admin/**}
 * (USER → 403, chưa đăng nhập → 401), không dựa vào menu của frontend. Không có DELETE.
 */
@RestController
@RequestMapping("/api/v1/admin")
public class AdminController {
    private final AdminFoodService foods;
    private final AdminExerciseService exercises;
    private final AdminUserService users;

    public AdminController(AdminFoodService foods, AdminExerciseService exercises, AdminUserService users) {
        this.foods = foods;
        this.exercises = exercises;
        this.users = users;
    }

    // ----- Món ăn -----

    @GetMapping("/foods")
    public PageResponse<AdminFoodItem> foods(@RequestParam(required = false) String keyword,
                                             @RequestParam(required = false) String category,
                                             @RequestParam(required = false) Boolean active,
                                             @RequestParam(defaultValue = "0") int page,
                                             @RequestParam(defaultValue = "20") int size) {
        return foods.search(keyword, category, active, page, size);
    }

    @GetMapping("/food-options")
    public AdminFoodOptions foodOptions() {
        return foods.options();
    }

    @GetMapping("/foods/{id}")
    public AdminFoodDetail food(@PathVariable UUID id) {
        return foods.get(id);
    }

    @PostMapping("/foods")
    @ResponseStatus(HttpStatus.CREATED)
    public AdminFoodDetail createFood(@AuthenticationPrincipal AuthenticatedUser admin,
                                      @Valid @RequestBody FoodRequest request) {
        return foods.create(admin.userId(), request);
    }

    @PutMapping("/foods/{id}")
    public AdminFoodDetail updateFood(@AuthenticationPrincipal AuthenticatedUser admin, @PathVariable UUID id,
                                      @Valid @RequestBody FoodRequest request) {
        return foods.update(admin.userId(), id, request);
    }

    // ----- Bài tập -----

    @GetMapping("/exercises")
    public PageResponse<AdminExerciseItem> exercises(@RequestParam(required = false) String keyword,
                                                     @RequestParam(required = false) MuscleGroup muscleGroup,
                                                     @RequestParam(required = false) Boolean active,
                                                     @RequestParam(defaultValue = "0") int page,
                                                     @RequestParam(defaultValue = "20") int size) {
        return exercises.search(keyword, muscleGroup, active, page, size);
    }

    @GetMapping("/exercises/{id}")
    public AdminExerciseDetail exercise(@PathVariable UUID id) {
        return exercises.get(id);
    }

    @PostMapping("/exercises")
    @ResponseStatus(HttpStatus.CREATED)
    public AdminExerciseDetail createExercise(@AuthenticationPrincipal AuthenticatedUser admin,
                                              @Valid @RequestBody ExerciseRequest request) {
        return exercises.create(admin.userId(), request);
    }

    @PutMapping("/exercises/{id}")
    public AdminExerciseDetail updateExercise(@AuthenticationPrincipal AuthenticatedUser admin,
                                              @PathVariable UUID id, @Valid @RequestBody ExerciseRequest request) {
        return exercises.update(admin.userId(), id, request);
    }

    // ----- Tài khoản -----

    @GetMapping("/users")
    public PageResponse<AdminUserItem> users(@RequestParam(required = false) String keyword,
                                             @RequestParam(required = false) UserStatus status,
                                             @RequestParam(defaultValue = "0") int page,
                                             @RequestParam(defaultValue = "20") int size) {
        return users.search(keyword, status, page, size);
    }

    @PutMapping("/users/{id}/status")
    public AdminUserItem setUserStatus(@AuthenticationPrincipal AuthenticatedUser admin, @PathVariable UUID id,
                                       @Valid @RequestBody UserStatusRequest request) {
        return users.setStatus(admin.userId(), id, request);
    }
}
