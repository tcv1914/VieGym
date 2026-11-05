import 'package:flutter/material.dart';

import '../../../../core/format/number_format.dart';
import '../../../../core/network/api_client.dart';
import '../../food/presentation/food_widgets.dart';
import '../data/meal_models.dart';

/// Kết quả gửi của form: null = thành công (đóng sheet); khác null = thông báo lỗi, giữ form.
typedef EntrySubmit = Future<String?> Function(
  MealType mealType,
  double servings,
);

/// Form số khẩu phần + bữa, dùng cho thêm món (A1–A4) và sửa mục (A5/A6).
/// Kcal hiển thị là bản xem trước; số chính thức là của server sau khi lưu.
Future<void> showMealEntrySheet(
  BuildContext context, {
  required String title,
  required String foodName,
  required String servingLabel,
  required Nutrients perServing,
  required MealType mealType,
  double servings = 1,
  required String submitLabel,
  required EntrySubmit onSubmit,
  Future<String?> Function()? onDelete,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (context) => MealEntrySheet(
    title: title,
    foodName: foodName,
    servingLabel: servingLabel,
    perServing: perServing,
    mealType: mealType,
    servings: servings,
    submitLabel: submitLabel,
    onSubmit: onSubmit,
    onDelete: onDelete,
  ),
);

class MealEntrySheet extends StatefulWidget {
  const MealEntrySheet({
    super.key,
    required this.title,
    required this.foodName,
    required this.servingLabel,
    required this.perServing,
    required this.mealType,
    required this.servings,
    required this.submitLabel,
    required this.onSubmit,
    this.onDelete,
  });

  final String title;
  final String foodName;
  final String servingLabel;
  final Nutrients perServing;
  final MealType mealType;
  final double servings;
  final String submitLabel;
  final EntrySubmit onSubmit;
  final Future<String?> Function()? onDelete;

  @override
  State<MealEntrySheet> createState() => _MealEntrySheetState();
}

class _MealEntrySheetState extends State<MealEntrySheet> {
  late final _servings = TextEditingController(
    text: formatViCompact(widget.servings),
  );
  late MealType _mealType = widget.mealType;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _servings.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String?> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await action();
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  void _submit() {
    final servings = parseServings(_servings.text);
    if (servings == null) {
      setState(() => _error = null);
      return;
    }
    _run(() => widget.onSubmit(_mealType, servings));
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa món khỏi thực đơn?'),
        content: Text(widget.foodName),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Không'),
          ),
          FilledButton(
            key: const Key('meal-delete-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) _run(widget.onDelete!);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: ListenableBuilder(
        listenable: _servings,
        builder: (context, _) {
          final servings = parseServings(_servings.text);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(widget.foodName, style: theme.textTheme.titleMedium),
              Text(
                '1 khẩu phần = ${widget.servingLabel}: '
                '${kcalText(widget.perServing.kcal)} · '
                'Đạm ${gramText(widget.perServing.protein)} · '
                'Bột đường ${gramText(widget.perServing.carbs)} · '
                'Béo ${gramText(widget.perServing.fat)}',
                key: const Key('meal-per-serving'),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('meal-servings'),
                controller: _servings,
                enabled: !_busy,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Số khẩu phần',
                  helperText: 'Ví dụ 0,5 hoặc 1,5 (tối đa 20)',
                  errorText: servings == null && _servings.text.isNotEmpty
                      ? 'Nhập số lớn hơn 0, tối đa 20, tối đa 2 chữ số lẻ'
                      : null,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<MealType>(
                key: const Key('meal-type'),
                initialValue: _mealType,
                decoration: const InputDecoration(
                  labelText: 'Bữa',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final t in MealType.values)
                    DropdownMenuItem(value: t, child: Text(t.label)),
                ],
                onChanged: _busy
                    ? null
                    : (t) => setState(() => _mealType = t ?? _mealType),
              ),
              const SizedBox(height: 12),
              Text(
                servings == null
                    ? 'Xem trước: —'
                    : 'Xem trước: '
                          '${kcalText(previewKcal(servings, widget.perServing.kcal))}',
                key: const Key('meal-preview'),
                style: theme.textTheme.titleSmall,
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  key: const Key('meal-entry-error'),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  if (widget.onDelete != null)
                    TextButton.icon(
                      key: const Key('meal-delete'),
                      onPressed: _busy ? null : _delete,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Xóa'),
                    ),
                  const Spacer(),
                  FilledButton.icon(
                    key: const Key('meal-submit'),
                    onPressed: _busy || servings == null ? null : _submit,
                    icon: _busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: Text(widget.submitLabel),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Thông điệp lỗi cho form thực đơn. Mất mạng khi đang ghi: server có thể đã lưu → nhắc
/// kiểm tra thực đơn (vừa tự tải lại) trước khi gửi lại, tránh thêm trùng (NUT-BR08).
String mealErrorText(Object error) {
  if (error is NetworkException) {
    return 'Không rõ yêu cầu đã tới máy chủ chưa. Thực đơn đã được tải lại — '
        'hãy kiểm tra trước khi gửi lại.';
  }
  if (error is ApiException) {
    return switch (error.code) {
      'FOOD_INACTIVE' => 'Món này không còn sử dụng được, hãy chọn món khác.',
      'NOT_FOUND' => 'Món này không còn trong thực đơn (có thể đã bị xóa).',
      'VALIDATION_ERROR' =>
        error.fieldErrors.values.firstOrNull ?? error.message,
      _ => error.message,
    };
  }
  return error.toString();
}
