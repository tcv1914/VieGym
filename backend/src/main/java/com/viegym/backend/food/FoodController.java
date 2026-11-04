package com.viegym.backend.food;

import com.viegym.backend.common.web.PageResponse;
import com.viegym.backend.food.dto.FoodDtos.FoodDetail;
import com.viegym.backend.food.dto.FoodDtos.FoodFilters;
import com.viegym.backend.food.dto.FoodDtos.FoodSummary;
import com.viegym.backend.food.entity.FoodRegion;
import java.util.UUID;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** docs/05 §9. Cần đăng nhập (mặc định của SecurityConfig). Vùng lạ / page sai kiểu → 400. */
@RestController
@RequestMapping("/api/v1")
public class FoodController {
    private final FoodService service;

    public FoodController(FoodService service) {
        this.service = service;
    }

    @GetMapping("/foods")
    public PageResponse<FoodSummary> list(@RequestParam(required = false) String keyword,
                                          @RequestParam(required = false) String category,
                                          @RequestParam(required = false) FoodRegion region,
                                          @RequestParam(defaultValue = "0") int page,
                                          @RequestParam(defaultValue = "20") int size) {
        return service.search(keyword, category, region, page, size);
    }

    @GetMapping("/foods/{id}")
    public FoodDetail get(@PathVariable UUID id) {
        return service.get(id);
    }

    @GetMapping("/food-filters")
    public FoodFilters filters() {
        return service.filters();
    }
}
