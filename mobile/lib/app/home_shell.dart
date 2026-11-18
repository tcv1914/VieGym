import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/presentation/auth_widgets.dart';
import '../features/dashboard/application/dashboard_providers.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/exercise/presentation/exercise_list_page.dart';
import '../features/health/presentation/health_home_page.dart';
import '../features/nutrition/food/presentation/food_list_page.dart';
import '../features/nutrition/meal/presentation/meal_plan_page.dart';
import '../features/workout/program/presentation/program_list_page.dart';
import '../features/workout/schedule/presentation/schedule_week_page.dart';
import 'home_tab.dart';

/// Các tab sau đăng nhập. IndexedStack giữ trạng thái từng tab (từ khóa, bộ lọc, vị trí cuộn)
/// khi chuyển qua lại. Tab chỉ được dựng ở lần mở đầu tiên, tránh gọi API khi chưa xem.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  final _opened = {HomeTab.dashboard};

  static const _pages = <HomeTab, Widget>{
    HomeTab.dashboard: DashboardPage(),
    HomeTab.health: HealthHomePage(),
    HomeTab.exercises: ExerciseListPage(),
    HomeTab.programs: ProgramListPage(),
    HomeTab.schedule: ScheduleWeekPage(),
    HomeTab.mealPlan: MealPlanPage(),
    HomeTab.foods: FoodListPage(),
  };

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(homeTabProvider);
    _opened.add(current);
    return Scaffold(
      body: IndexedStack(
        index: current.index,
        children: [
          for (final tab in HomeTab.values)
            _opened.contains(tab) ? _pages[tab]! : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: current.index,
        indicatorColor: AuthGymColors.vibrantGreen.withValues(alpha: 0.16),
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        onDestinationSelected: (i) {
          final tab = HomeTab.values[i];
          // Quay lại Tổng quan luôn tải lại: lưới an toàn nếu một màn ghi nào đó quên báo.
          if (tab == HomeTab.dashboard && current != HomeTab.dashboard) {
            ref.invalidate(dashboardProvider);
          }
          ref.read(homeTabProvider.notifier).select(tab);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(
              Icons.home_rounded,
              color: AuthGymColors.heroMid,
            ),
            label: 'Tổng quan',
          ),
          NavigationDestination(
            icon: Icon(Icons.monitor_heart_outlined),
            selectedIcon: Icon(
              Icons.monitor_heart_rounded,
              color: AuthGymColors.heroMid,
            ),
            label: 'Sức khỏe',
          ),
          NavigationDestination(
            icon: Icon(Icons.fitness_center_outlined),
            selectedIcon: Icon(
              Icons.fitness_center_rounded,
              color: AuthGymColors.heroMid,
            ),
            label: 'Bài tập',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(
              Icons.event_note_rounded,
              color: AuthGymColors.heroMid,
            ),
            label: 'Giáo án',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(
              Icons.calendar_month_rounded,
              color: AuthGymColors.heroMid,
            ),
            label: 'Lịch tập',
          ),
          NavigationDestination(
            icon: Icon(Icons.dinner_dining_outlined),
            selectedIcon: Icon(
              Icons.dinner_dining_rounded,
              color: AuthGymColors.heroMid,
            ),
            label: 'Thực đơn',
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_menu_outlined),
            selectedIcon: Icon(
              Icons.restaurant_menu_rounded,
              color: AuthGymColors.heroMid,
            ),
            label: 'Món ăn',
          ),
        ],
      ),
    );
  }
}
