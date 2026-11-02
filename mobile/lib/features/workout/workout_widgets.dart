import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';

/// Biểu tượng + thông điệp + nút tùy chọn, cho trạng thái rỗng/lỗi.
class StatusMessage extends StatelessWidget {
  const StatusMessage({
    super.key,
    required this.icon,
    required this.text,
    this.action,
  });

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64),
            const SizedBox(height: 8),
            Text(text, textAlign: TextAlign.center),
            ?action,
          ],
        ),
      ),
    );
  }
}

class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => StatusMessage(
    icon: Icons.error_outline,
    text: error.toString(),
    action: TextButton(onPressed: onRetry, child: const Text('Thử lại')),
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
  });

  final bool busy;
  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: busy ? null : onPressed,
    icon: busy
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(icon ?? Icons.check),
    label: Text(label),
  );
}
