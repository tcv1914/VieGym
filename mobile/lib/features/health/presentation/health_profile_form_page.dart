import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/number_format.dart';
import '../../../core/network/api_client.dart';
import '../../../core/ui/gym_ui.dart';
import '../../auth/presentation/auth_widgets.dart';
import '../../auth/presentation/logout_button.dart';
import '../../dashboard/application/dashboard_providers.dart';
import '../application/health_profile_controller.dart';
import '../data/health_api.dart';
import '../data/health_models.dart';

/// Tạo mới ([initial] null, là màn chính khi chưa có hồ sơ) hoặc sửa (mở từ màn tổng quan,
/// lưu xong trả về true). Kiểm tra ở đây chỉ hỗ trợ nhập; backend kiểm tra lại đầy đủ.
class HealthProfileFormPage extends ConsumerStatefulWidget {
  const HealthProfileFormPage({super.key, this.initial});

  final HealthProfileInput? initial;

  @override
  ConsumerState<HealthProfileFormPage> createState() =>
      _HealthProfileFormPageState();
}

class _HealthProfileFormPageState extends ConsumerState<HealthProfileFormPage> {
  // docs/04-business-rules.md §3.1.
  static const _minAge = 18;
  static const _maxAge = 80;

  final _formKey = GlobalKey<FormState>();
  final _dateOfBirth = TextEditingController();
  final _height = TextEditingController();
  final _weight = TextEditingController();
  Sex? _sex;
  DateTime? _dob;
  ActivityLevel? _activity;
  Goal? _goal;
  bool _submitting = false;
  String? _error;
  Map<String, String> _fieldErrors = const {};

  bool get _editing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _sex = initial.sex;
      _setDob(initial.dateOfBirth);
      _height.text = formatVi(initial.heightCm);
      _weight.text = formatVi(initial.weightKg);
      _activity = initial.activityLevel;
      _goal = initial.goal;
    }
  }

  @override
  void dispose() {
    _dateOfBirth.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  void _setDob(DateTime date) {
    _dob = DateTime(date.year, date.month, date.day);
    _dateOfBirth.text =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final first = DateTime(
      today.year - _maxAge - 1,
      today.month,
      today.day + 1,
    );
    final last = DateTime(today.year - _minAge, today.month, today.day);
    var initial = _dob ?? DateTime(today.year - 25, today.month, today.day);
    // Hồ sơ cũ có thể đã quá 80 tuổi (tuổi tăng theo thời gian); picker không nhận ngày ngoài khoảng.
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: 'Chọn ngày sinh',
    );
    if (picked != null) setState(() => _setDob(picked));
  }

  // Cùng cách tính với backend: năm tròn tại ngày hôm nay.
  static int _ageOn(DateTime dob, DateTime today) {
    var age = today.year - dob.year;
    if (today.month < dob.month ||
        (today.month == dob.month && today.day < dob.day)) {
      age--;
    }
    return age;
  }

  String? _validateDob(String? _) {
    final dob = _dob;
    if (dob == null) return 'Vui lòng chọn ngày sinh';
    final age = _ageOn(dob, DateTime.now());
    if (age < _minAge || age > _maxAge) {
      return 'Ứng dụng hỗ trợ người từ $_minAge đến $_maxAge tuổi';
    }
    return _fieldErrors['dateOfBirth'];
  }

  String? Function(String?) _numberValidator({
    required String field,
    required String label,
    required double min,
    required double max,
    required String unit,
  }) => (text) {
    if (text == null || text.trim().isEmpty) return 'Vui lòng nhập $label';
    final value = parseViDecimal(text);
    if (value == null) return 'Nhập số, tối đa 1 chữ số thập phân';
    if (value < min || value > max) {
      return '${label[0].toUpperCase()}${label.substring(1)} từ '
          '${formatVi(min, decimals: 0)} đến ${formatVi(max, decimals: 0)} $unit';
    }
    return _fieldErrors[field];
  };

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _fieldErrors = const {});
    if (_submitting || !_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final input = HealthProfileInput(
      sex: _sex!,
      dateOfBirth: _dob!,
      heightCm: parseViDecimal(_height.text)!,
      weightKg: parseViDecimal(_weight.text)!,
      activityLevel: _activity!,
      goal: _goal!,
    );
    try {
      await ref.read(healthApiProvider).save(input);
      // Đọc lại từ máy chủ thay vì tự ghép kết quả: màn tổng quan luôn là dữ liệu đã lưu.
      ref.invalidate(healthProfileProvider);
      ref.invalidate(dashboardProvider);
      if (_editing && mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      _fail(e.fieldErrors.isEmpty ? e.message : null, e.fieldErrors);
    } on NetworkException {
      // Có thể request đã tới máy chủ; PUT ghi đè toàn bộ nên gửi lại an toàn.
      _fail(
        'Không kết nối được máy chủ, hồ sơ có thể chưa được lưu. '
        'Kiểm tra mạng rồi bấm Lưu lại.',
        const {},
      );
    } catch (e) {
      _fail(e.toString(), const {});
    }
  }

  void _fail(String? message, Map<String, String> fieldErrors) {
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _error = message;
      _fieldErrors = fieldErrors;
    });
    _formKey.currentState!.validate();
  }

  @override
  Widget build(BuildContext context) {
    return GymScaffold(
      appBar: GymAppBar(
        eyebrow: 'THIẾT LẬP CƠ THỂ',
        title: _editing ? 'Sửa hồ sơ sức khỏe' : 'Tạo hồ sơ sức khỏe',
        actions: [
          if (!_editing) const GymGlassAction(child: LogoutButton()),
        ],
      ),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                AuthNoticeBanner(
                  isError: false,
                  message: _editing
                      ? 'Lưu thay đổi sẽ tính lại BMI và mục tiêu dinh dưỡng.'
                      : 'Nhập thông tin để tính BMI và mục tiêu dinh dưỡng mỗi ngày.',
                ),
                const SizedBox(height: 16),
                GymCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const GymSectionHeader(
                        icon: Icons.badge_outlined,
                        title: 'Thông số cơ bản',
                        accent: GymColors.bodyBlue,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<Sex>(
                        key: const Key('health-sex'),
                        initialValue: _sex,
                        decoration: gymInputDecoration(
                          context,
                          labelText: 'Giới tính (dùng trong công thức)',
                          prefixIcon: Icons.wc_rounded,
                        ),
                        items: [
                          for (final v in Sex.values)
                            DropdownMenuItem(value: v, child: Text(v.label)),
                        ],
                        onChanged: _submitting
                            ? null
                            : (v) => setState(() => _sex = v),
                        validator: (v) => v == null
                            ? 'Vui lòng chọn giới tính'
                            : _fieldErrors['sex'],
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        key: const Key('health-dob'),
                        controller: _dateOfBirth,
                        readOnly: true,
                        enabled: !_submitting,
                        decoration: gymInputDecoration(
                          context,
                          labelText: 'Ngày sinh',
                          prefixIcon: Icons.cake_outlined,
                          suffixIcon: const Icon(
                            Icons.calendar_today_rounded,
                            size: 19,
                          ),
                        ),
                        onTap: _pickDob,
                        validator: _validateDob,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        key: const Key('health-height'),
                        controller: _height,
                        enabled: !_submitting,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: gymInputDecoration(
                          context,
                          labelText: 'Chiều cao',
                          suffixText: 'cm',
                          prefixIcon: Icons.height_rounded,
                        ),
                        validator: _numberValidator(
                          field: 'heightCm',
                          label: 'chiều cao',
                          min: 100,
                          max: 250,
                          unit: 'cm',
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        key: const Key('health-weight'),
                        controller: _weight,
                        enabled: !_submitting,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: gymInputDecoration(
                          context,
                          labelText: 'Cân nặng',
                          suffixText: 'kg',
                          prefixIcon: Icons.monitor_weight_outlined,
                        ),
                        validator: _numberValidator(
                          field: 'weightKg',
                          label: 'cân nặng',
                          min: 30,
                          max: 300,
                          unit: 'kg',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                GymCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const GymSectionHeader(
                        icon: Icons.flag_rounded,
                        title: 'Lối sống & Mục tiêu',
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<ActivityLevel>(
                        key: const Key('health-activity'),
                        initialValue: _activity,
                        isExpanded: true,
                        decoration: gymInputDecoration(
                          context,
                          labelText: 'Mức vận động',
                          prefixIcon: Icons.directions_run_rounded,
                        ),
                        items: [
                          for (final v in ActivityLevel.values)
                            DropdownMenuItem(
                              value: v,
                              child: Text(
                                v.label,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: _submitting
                            ? null
                            : (v) => setState(() => _activity = v),
                        validator: (v) => v == null
                            ? 'Vui lòng chọn mức vận động'
                            : _fieldErrors['activityLevel'],
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<Goal>(
                        key: const Key('health-goal'),
                        initialValue: _goal,
                        decoration: gymInputDecoration(
                          context,
                          labelText: 'Mục tiêu',
                          prefixIcon: Icons.track_changes_rounded,
                        ),
                        items: [
                          for (final v in Goal.values)
                            DropdownMenuItem(value: v, child: Text(v.label)),
                        ],
                        onChanged: _submitting
                            ? null
                            : (v) => setState(() => _goal = v),
                        validator: (v) => v == null
                            ? 'Vui lòng chọn mục tiêu'
                            : _fieldErrors['goal'],
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  AuthNoticeBanner(message: _error!),
                ],
                const SizedBox(height: 20),
                AuthPrimaryButton(
                  buttonKey: const Key('health-submit'),
                  label: 'Lưu hồ sơ',
                  icon: Icons.check_circle_outline_rounded,
                  busy: _submitting,
                  onPressed: _submit,
                ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
