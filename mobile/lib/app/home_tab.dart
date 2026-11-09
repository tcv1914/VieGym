import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Thứ tự tab trong [HomeShell]. Tổng quan dẫn tới các tab khác qua [homeTabProvider].
enum HomeTab { dashboard, health, exercises, programs, schedule, mealPlan, foods }

class HomeTabController extends Notifier<HomeTab> {
  @override
  HomeTab build() => HomeTab.dashboard;

  void select(HomeTab tab) => state = tab;
}

/// autoDispose: đăng xuất (HomeShell bị gỡ) → lần đăng nhập sau bắt đầu ở Tổng quan.
final homeTabProvider =
    NotifierProvider.autoDispose<HomeTabController, HomeTab>(
      HomeTabController.new,
    );
