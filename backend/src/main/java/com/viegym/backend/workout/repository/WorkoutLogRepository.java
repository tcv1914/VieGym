package com.viegym.backend.workout.repository;

import com.viegym.backend.workout.entity.WorkoutLog;
import java.time.LocalDate;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface WorkoutLogRepository extends JpaRepository<WorkoutLog, UUID> {
    Optional<WorkoutLog> findByScheduleId(UUID scheduleId);

    /** Luôn kèm user: log của người khác trả rỗng như không tồn tại. */
    @Query("select distinct l from WorkoutLog l left join fetch l.exercises where l.id = :id and l.userId = :userId")
    Optional<WorkoutLog> findOwned(UUID id, UUID userId);

    /** Khoảng đóng [from, to] theo {@code workout_date}; thứ tự ổn định cho phân trang. */
    @Query(value = """
        select l from WorkoutLog l where l.userId = :userId and l.workoutDate between :from and :to
        order by l.workoutDate desc, l.createdAt desc, l.id desc
        """, countQuery = """
        select count(l) from WorkoutLog l where l.userId = :userId and l.workoutDate between :from and :to
        """)
    Page<WorkoutLog> findPage(UUID userId, LocalDate from, LocalDate to, Pageable pageable);

    /**
     * Tổng cho một trang trong một truy vấn (không tải từng set của từng log):
     * [logId, số bài, số hiệp, tổng reps, tổng volume tạ ngoài].
     */
    @Query("""
        select e.log.id, count(distinct e.id), count(s.id), coalesce(sum(s.reps), 0),
               coalesce(sum(s.reps * s.weightKg), 0)
        from WorkoutLogExercise e join e.sets s
        where e.log.id in :logIds
        group by e.log.id
        """)
    List<Object[]> totals(Collection<UUID> logIds);

    /** [scheduleId, logId] để lịch biết buổi nào đã có log. */
    @Query("select l.scheduleId, l.id from WorkoutLog l where l.scheduleId in :scheduleIds")
    List<Object[]> logIdsBySchedule(Collection<UUID> scheduleIds);
}
