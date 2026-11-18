import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/date_format.dart';
import '../../../core/format/number_format.dart';
import '../../../core/network/api_client.dart';
import '../../../core/ui/gym_ui.dart';
import '../../auth/presentation/auth_widgets.dart';
import '../data/weight_api.dart';
import '../data/weight_models.dart';

/// Ghi/sửa một lần cân. Sửa giữ nguyên ngày (đổi ngày = một lần cân khác). Chọn ngày đã có bản ghi
/// thì báo trước là sẽ ghi đè (BR-WL01). Trả về bản ghi đã lưu qua Navigator.pop.
class WeightFormSheet extends ConsumerStatefulWidget {
  const WeightFormSheet({
    super.key,
    this.existing,
    this.existingLogs = const [],
  });

  final WeightLog? existing;
  final List<WeightLog> existingLogs;

  @override
  ConsumerState<WeightFormSheet> createState() => _WeightFormSheetState();
}

class _WeightFormSheetState extends ConsumerState<WeightFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _weight = TextEditingController(
    text: widget.existing == null
        ? ''
        : formatViCompact(widget.existing!.weightKg, maxDecimals: 1),
  );
  late final _note = TextEditingController(text: widget.existing?.note ?? '');
  late DateTime _date = widget.existing?.logDate ?? today();
  bool _saving = false;
  String? _error;
  Map<String, String> _fieldErrors = const {};

  @override
  void dispose() {
    _weight.dispose();
    _note.dispose();
    super.dispose();
  }

  WeightLog? get _sameDay => widget.existing != null
      ? null
      : widget.existingLogs.where((l) => l.logDate == _date).firstOrNull;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: today(),
    );
    if (picked != null) setState(() => _date = dateOnly(picked));
  }

  String? _validateWeight(String? v) {
    final kg = parseViDecimal(v ?? '');
    if (kg == null) return 'Nhập số, tối đa 1 chữ số lẻ (vd. 65,5)';
    if (kg < 30 || kg > 300) return 'Cân nặng từ 30 đến 300 kg';
    return _fieldErrors['weightKg'];
  }

  Future<void> _submit() async {
    setState(() => _fieldErrors = const {});
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await ref
          .read(weightApiProvider)
          .save(
            logDate: _date,
            weightKg: parseViDecimal(_weight.text)!,
            note: _note.text,
          );
      if (mounted) Navigator.of(context).pop(saved);
    } on ApiException catch (e) {
      setState(() {
        _saving = false;
        _fieldErrors = e.fieldErrors;
        _error =
            e.fieldErrors['logDate'] ?? e.fieldErrors['note'] ?? e.message;
      });
      _formKey.currentState!.validate();
    } on NetworkException catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sameDay = _sameDay;
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          18,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GymSectionHeader(
                icon: Icons.monitor_weight_outlined,
                title: widget.existing == null ? 'Ghi cân nặng' : 'Sửa lần cân',
                accent: GymColors.bodyBlue,
              ),
              const SizedBox(height: 14),
              Material(
                color: scheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(14),
                child: ListTile(
                  key: const Key('weight-date'),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: scheme.outlineVariant),
                  ),
                  leading: const Icon(
                    Icons.event_rounded,
                    color: GymColors.vibrantGreen,
                  ),
                  title: Text(
                    '${viWeekday(_date)}, ${viDate(_date)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: sameDay == null
                      ? null
                      : Text(
                          'Ngày này đã có ${formatViCompact(sameDay.weightKg, maxDecimals: 1)} kg — lưu sẽ ghi đè.',
                          key: const Key('weight-overwrite-hint'),
                          style: TextStyle(color: Colors.amber.shade800),
                        ),
                  trailing: widget.existing == null
                      ? const Icon(Icons.edit_calendar_rounded)
                      : null,
                  onTap:
                      widget.existing == null && !_saving ? _pickDate : null,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('weight-kg'),
                controller: _weight,
                enabled: !_saving,
                autofocus: widget.existing == null,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: gymInputDecoration(
                  context,
                  labelText: 'Cân nặng',
                  suffixText: 'kg',
                  prefixIcon: Icons.scale_outlined,
                ),
                validator: _validateWeight,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('weight-note'),
                controller: _note,
                enabled: !_saving,
                maxLength: 500,
                decoration: gymInputDecoration(
                  context,
                  labelText: 'Ghi chú (không bắt buộc)',
                  hintText: 'Vd. sau khi ngủ dậy',
                  prefixIcon: Icons.notes_rounded,
                ),
              ),
              if (_error != null) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AuthNoticeBanner(message: _error!),
                ),
              ],
              AuthPrimaryButton(
                buttonKey: const Key('weight-save'),
                label: 'Lưu',
                icon: Icons.check_rounded,
                busy: _saving,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
