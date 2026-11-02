import 'package:flutter/material.dart';

import '../features/exercise/presentation/exercise_list_page.dart';
import '../features/health/presentation/health_home_page.dart';
import '../features/workout/program/presentation/program_list_page.dart';
import '../features/workout/schedule/presentation/schedule_week_page.dart';

/// Các tab sau đăng nhập. IndexedStack giữ trạng thái từng tab (từ khóa, bộ lọc, vị trí cuộn)
/// khi chuyển qua lại. Tab chỉ được dựng ở lần mở đầu tiên, tránh gọi API khi chưa xem.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final _opened = {0};

  static const _tabs = <Widget>[
    HealthHomePage(),
    ExerciseListPage(),
    ProgramListPage(),
    ScheduleWeekPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          for (var i = 0; i < _tabs.length; i++)
            _opened.contains(i) ? _tabs[i] : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() {
          _index = i;
          _opened.add(i);
        }),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.monitor_heart_outlined),
            label: 'Sức khỏe',
          ),
          NavigationDestination(
            icon: Icon(Icons.fitness_center),
            label: 'Bài tập',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            label: 'Giáo án',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month),
            label: 'Lịch tập',
          ),
        ],
      ),
    );
  }
}
