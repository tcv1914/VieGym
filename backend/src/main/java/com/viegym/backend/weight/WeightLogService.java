package com.viegym.backend.weight;

import com.viegym.backend.auth.repository.UserRepository;
import com.viegym.backend.common.exception.ApiException;
import com.viegym.backend.weight.WeightLogDtos.SaveResult;
import com.viegym.backend.weight.WeightLogDtos.SaveWeightLogRequest;
import com.viegym.backend.weight.WeightLogDtos.WeightLogItem;
import com.viegym.backend.weight.WeightLogDtos.WeightLogList;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Clock;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Nhật ký cân nặng (docs/29 §1). Ghi cân nặng KHÔNG đổi hồ sơ hay mục tiêu (BR-H02): app hỏi user rồi
 * tự gọi PUT /health-profile/me. Bảng nhỏ, truy vấn đơn giản nên dùng JDBC thẳng; upsert bằng
 * ON CONFLICT để hai request cùng ngày không đụng UNIQUE.
 */
@Service
public class WeightLogService {
    static final int DEFAULT_RANGE_DAYS = 90;
    static final int MAX_RANGE_DAYS = 366;

    private final JdbcTemplate jdbc;
    private final UserRepository userRepository;
    private final Clock clock;

    public WeightLogService(JdbcTemplate jdbc, UserRepository userRepository, Clock clock) {
        this.jdbc = jdbc;
        this.userRepository = userRepository;
        this.clock = clock;
    }

    /** Mặc định 90 ngày gần nhất (tính cả hôm nay); khoảng tối đa 366 ngày, tăng dần theo ngày. */
    @Transactional(readOnly = true)
    public WeightLogList list(UUID userId, LocalDate from, LocalDate to) {
        LocalDate end = to != null ? to : (from != null ? from.plusDays(DEFAULT_RANGE_DAYS - 1) : today(userId));
        LocalDate start = from != null ? from : end.minusDays(DEFAULT_RANGE_DAYS - 1);
        if (start.isAfter(end)) {
            throw ApiException.validation("from", "Ngày bắt đầu phải trước hoặc bằng ngày kết thúc");
        }
        if (ChronoUnit.DAYS.between(start, end) + 1 > MAX_RANGE_DAYS) {
            throw ApiException.validation("to", "Khoảng ngày tối đa " + MAX_RANGE_DAYS + " ngày");
        }
        return new WeightLogList(jdbc.query("""
            SELECT id, log_date, weight_kg, note FROM weight_logs
            WHERE user_id = ? AND log_date BETWEEN ? AND ?
            ORDER BY log_date
            """, WeightLogService::item, userId, start, end));
    }

    @Transactional
    public SaveResult save(UUID userId, SaveWeightLogRequest request) {
        if (request.logDate().isAfter(today(userId))) {
            throw ApiException.validation("logDate", "Không ghi cân nặng cho ngày trong tương lai");
        }
        // xmax = 0 chỉ đúng với dòng vừa INSERT; dòng đi qua DO UPDATE có xmax khác 0.
        Map<String, Object> row = jdbc.queryForMap("""
            INSERT INTO weight_logs (user_id, log_date, weight_kg, note) VALUES (?, ?, ?, ?)
            ON CONFLICT (user_id, log_date)
            DO UPDATE SET weight_kg = EXCLUDED.weight_kg, note = EXCLUDED.note, updated_at = now()
            RETURNING id, (xmax = 0) AS inserted
            """, userId, request.logDate(), request.weightKg(), request.note());
        var item = new WeightLogItem((UUID) row.get("id"), request.logDate(),
            request.weightKg().setScale(1), request.note());
        return new SaveResult(item, (Boolean) row.get("inserted"));
    }

    /** Bản ghi của user khác cũng là 404, không phân biệt với id không tồn tại. */
    @Transactional
    public void delete(UUID userId, UUID id) {
        if (jdbc.update("DELETE FROM weight_logs WHERE id = ? AND user_id = ?", id, userId) == 0) {
            throw new ApiException(HttpStatus.NOT_FOUND, "NOT_FOUND", "Không tìm thấy bản ghi cân nặng");
        }
    }

    /** Bản ghi có ngày đo mới nhất; dùng cho dashboard. */
    @Transactional(readOnly = true)
    public Optional<WeightLogItem> latest(UUID userId) {
        return jdbc.query("""
            SELECT id, log_date, weight_kg, note FROM weight_logs
            WHERE user_id = ? ORDER BY log_date DESC LIMIT 1
            """, WeightLogService::item, userId).stream().findFirst();
    }

    private LocalDate today(UUID userId) {
        String timezone = userRepository.findById(userId)
            .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "NOT_FOUND", "Không tìm thấy tài khoản"))
            .getTimezone();
        return LocalDate.now(clock.withZone(ZoneId.of(timezone)));
    }

    private static WeightLogItem item(ResultSet rs, int rowNum) throws SQLException {
        return new WeightLogItem(rs.getObject("id", UUID.class), rs.getObject("log_date", LocalDate.class),
            rs.getBigDecimal("weight_kg"), rs.getString("note"));
    }
}
