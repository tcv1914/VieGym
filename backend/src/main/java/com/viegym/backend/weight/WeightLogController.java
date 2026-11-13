package com.viegym.backend.weight;

import com.viegym.backend.common.security.AuthenticatedUser;
import com.viegym.backend.weight.WeightLogDtos.SaveResult;
import com.viegym.backend.weight.WeightLogDtos.SaveWeightLogRequest;
import com.viegym.backend.weight.WeightLogDtos.WeightLogItem;
import com.viegym.backend.weight.WeightLogDtos.WeightLogList;
import jakarta.validation.Valid;
import java.time.LocalDate;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** docs/05 §4. Sửa = POST lại cùng ngày (BR-WL01); DELETE thêm ở ngày 13 (docs/29 §1). */
@RestController
@RequestMapping("/api/v1/weight-logs")
public class WeightLogController {
    private final WeightLogService service;

    public WeightLogController(WeightLogService service) {
        this.service = service;
    }

    @GetMapping
    public WeightLogList list(@AuthenticationPrincipal AuthenticatedUser currentUser,
                              @RequestParam(required = false) LocalDate from,
                              @RequestParam(required = false) LocalDate to) {
        return service.list(currentUser.userId(), from, to);
    }

    @PostMapping
    public ResponseEntity<WeightLogItem> save(@AuthenticationPrincipal AuthenticatedUser currentUser,
                                              @Valid @RequestBody SaveWeightLogRequest request) {
        SaveResult result = service.save(currentUser.userId(), request);
        return ResponseEntity.status(result.created() ? HttpStatus.CREATED : HttpStatus.OK).body(result.item());
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@AuthenticationPrincipal AuthenticatedUser currentUser, @PathVariable UUID id) {
        service.delete(currentUser.userId(), id);
    }
}
