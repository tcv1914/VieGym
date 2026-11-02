package com.viegym.backend.workout.repository;

import com.viegym.backend.workout.entity.ScheduleStatus;
import com.viegym.backend.workout.entity.WorkoutSchedule;
import jakarta.persistence.LockModeType;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;

public interface WorkoutScheduleRepository extends JpaRepository<WorkoutSchedule, UUID> {
    String RANGE = """
        select s from WorkoutSchedule s join fetch s.workoutDay d join fetch d.program
        where s.userId = :userId and s.scheduledDate between :from and :to
        """;
    String ORDER = " order by s.scheduledDate, s.startTime nulls last, s.createdAt, s.id";

    @Query(RANGE + ORDER)
    List<WorkoutSchedule> findInRange(UUID userId, LocalDate from, LocalDate to);

    @Query(RANGE + " and s.status = :status" + ORDER)
    List<WorkoutSchedule> findInRange(UUID userId, LocalDate from, LocalDate to, ScheduleStatus status);

    @Query("select s from WorkoutSchedule s join fetch s.workoutDay d join fetch d.program "
        + "where s.id = :id and s.userId = :userId")
    Optional<WorkoutSchedule> findOwned(UUID id, UUID userId);

    /**
     * SELECT ... FOR UPDATE chỉ trên dòng lịch (không join, để không khóa lan sang giáo án).
     * Ngày 8 hoàn thành buổi cũng khóa dòng này, nên hủy và hoàn thành không ghi đè nhau.
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select s from WorkoutSchedule s where s.id = :id and s.userId = :userId")
    Optional<WorkoutSchedule> findOwnedForUpdate(UUID id, UUID userId);

    boolean existsByWorkoutDayId(UUID workoutDayId);

    long countByUserIdAndScheduledDateAndStatusNot(UUID userId, LocalDate date, ScheduleStatus status);
}
