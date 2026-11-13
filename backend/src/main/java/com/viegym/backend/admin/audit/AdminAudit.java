package com.viegym.backend.admin.audit;

import com.viegym.backend.admin.audit.AuditLog.Action;
import com.viegym.backend.admin.audit.AuditLog.EntityType;
import java.lang.reflect.RecordComponent;
import java.math.BigDecimal;
import java.time.Clock;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;
import java.util.UUID;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/** Ghi audit trong giao dịch của thao tác (MANDATORY): không có thay đổi nào thiếu dấu vết. */
@Component
public class AdminAudit {
    private final AuditLogRepository repository;
    private final Clock clock;

    public AdminAudit(AuditLogRepository repository, Clock clock) {
        this.repository = repository;
        this.clock = clock;
    }

    @Transactional(propagation = Propagation.MANDATORY)
    public void record(UUID actorId, Action action, EntityType type, UUID entityId, String reason,
                       List<String> changedFields) {
        String fields = changedFields == null || changedFields.isEmpty() ? null : String.join(",", changedFields);
        repository.save(new AuditLog(actorId, action, type, entityId, reason, fields, clock.instant()));
    }

    /** Tên các thành phần record khác nhau; số so bằng compareTo (70.0 = 70.00). */
    public static List<String> diff(Record before, Record after) {
        List<String> changed = new ArrayList<>();
        for (RecordComponent component : before.getClass().getRecordComponents()) {
            try {
                Object a = component.getAccessor().invoke(before);
                Object b = component.getAccessor().invoke(after);
                if (!same(a, b)) {
                    changed.add(component.getName());
                }
            } catch (ReflectiveOperationException ex) {
                throw new IllegalStateException(ex);
            }
        }
        return changed;
    }

    private static boolean same(Object a, Object b) {
        if (a instanceof BigDecimal x && b instanceof BigDecimal y) {
            return x.compareTo(y) == 0;
        }
        return Objects.equals(a, b);
    }
}
