import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/ui/gym_ui.dart';

/// Biểu tượng + thông điệp + nút tùy chọn, cho trạng thái rỗng/lỗi.
class StatusMessage extends StatelessWidget {
  const StatusMessage({
    super.key,
    required this.icon,
    required this.text,
    this.action,
    this.accent = GymColors.vibrantGreen,
  });

  final IconData icon;
  final String text;
  final Widget? action;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return GymStateView(
      icon: icon,
      message: text,
      accent: accent,
      action: action,
    );
  }
}

class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => StatusMessage(
    icon: Icons.error_outline_rounded,
    accent: Theme.of(context).colorScheme.error,
    text: error.toString(),
    action: FilledButton.tonalIcon(
      onPressed: onRetry,
      icon: const Icon(Icons.refresh_rounded, size: 18),
      label: const Text('Thử lại'),
    ),
  );
}

/// Lỗi của thao tác tạo mới. Mất mạng giữa chừng thì server có thể đã ghi: không tự gửi lại,
/// nhắc người dùng tải lại để kiểm tra (chưa có Idempotency-Key, docs/16 §6).
String createErrorText(Object error) => error is NetworkException
    ? 'Không rõ yêu cầu đã tới máy chủ chưa. Hãy tải lại danh sách để kiểm tra trước khi gửi lại.'
    : error.toString();

void showSnack(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// "3 hiệp × 10 lần · nghỉ 90 giây"
String planText(int sets, int reps, int restSeconds) =>
    '$sets hiệp × $reps lần · nghỉ $restSeconds giây';

/// Nút có vòng tải khi đang gửi; [onPressed] null khi bận để không gửi lặp.
class BusyButton extends StatelessWidget {
  const BusyButton({
    super.key,
    required this.busy,
    required this.onPressed,
    required this.label,
    this.icon,
    this.compact = false,
  });

  final bool busy;
  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    style: FilledButton.styleFrom(
      backgroundColor: compact ? GymColors.accentLime : GymColors.vibrantGreen,
      foregroundColor: compact ? GymColors.heroDark : Colors.white,
      minimumSize: compact ? const Size(0, 38) : const Size.fromHeight(50),
      padding: compact ? const EdgeInsets.symmetric(horizontal: 14) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(compact ? 12 : 14),
      ),
      textStyle: TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: compact ? 13.5 : 15.5,
      ),
    ),
    onPressed: busy ? null : onPressed,
    icon: busy
        ? SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: compact ? GymColors.heroDark : Colors.white,
            ),
          )
        : Icon(icon ?? Icons.check_rounded, size: compact ? 18 : 20),
    label: Text(label),
  );
}
