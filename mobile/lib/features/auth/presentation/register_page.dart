import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../data/auth_api.dart';
import 'auth_widgets.dart';
import 'password_rules.dart';

/// Đăng ký xong quay lại màn đăng nhập (trả về email); backend không cấp token ở đây.
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _fullName = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _submitting = false;
  String? _error;
  Map<String, String> _fieldErrors = const {};

  @override
  void dispose() {
    _email.dispose();
    _fullName.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  // Chỉ hỗ trợ trải nghiệm; backend vẫn kiểm tra đầy đủ (BR-A02).
  String? _validatePassword(String? v) {
    return passwordRuleError(v) ?? _fieldErrors['password'];
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _fieldErrors = const {});
    if (_submitting || !_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final email = _email.text.trim();
    try {
      await ref
          .read(authApiProvider)
          .register(
            email: email,
            password: _password.text,
            fullName: _fullName.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(email.toLowerCase());
    } on ApiException catch (e) {
      _fail(e.fieldErrors.isEmpty ? e.message : null, e.fieldErrors);
    } on NetworkException catch (e) {
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
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AuthGymHeader(
                compact: true,
                showBackButton: true,
                badgeText: 'GIA NHẬP VIEGYM',
                icon: Icons.bolt_rounded,
                title: 'Bắt đầu hành trình mới',
                subtitle:
                    'Thiết lập tài khoản để theo dõi lộ trình tập luyện & dinh dưỡng cá nhân.',
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                  child: AutofillGroup(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_error != null) ...[
                            AuthNoticeBanner(message: _error!),
                            const SizedBox(height: 16),
                          ],
                          TextFormField(
                            controller: _email,
                            enabled: !_submitting,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            decoration: authInputDecoration(
                              context,
                              labelText: 'Email',
                              hintText: 'you@example.com',
                              prefixIcon: Icons.email_outlined,
                            ),
                            validator: (v) {
                              final value = v?.trim() ?? '';
                              if (value.isEmpty) return 'Vui lòng nhập email';
                              if (!value.contains('@')) {
                                return 'Email không hợp lệ';
                              }
                              return _fieldErrors['email'];
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _fullName,
                            enabled: !_submitting,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.name],
                            decoration: authInputDecoration(
                              context,
                              labelText: 'Họ tên',
                              hintText: 'Nguyễn Văn A',
                              prefixIcon: Icons.person_outline_rounded,
                            ),
                            validator: (v) {
                              final value = v?.trim() ?? '';
                              if (value.isEmpty) return 'Vui lòng nhập họ tên';
                              if (value.length > 100) {
                                return 'Họ tên tối đa 100 ký tự';
                              }
                              return _fieldErrors['fullName'];
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _password,
                            enabled: !_submitting,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.newPassword],
                            decoration: authInputDecoration(
                              context,
                              labelText: 'Mật khẩu',
                              prefixIcon: Icons.lock_outline_rounded,
                              suffixIcon: PasswordVisibilityButton(
                                obscured: _obscurePassword,
                                onToggle: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                              ),
                            ),
                            validator: _validatePassword,
                          ),
                          PasswordChecklist(controller: _password),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _confirm,
                            enabled: !_submitting,
                            obscureText: _obscureConfirm,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.newPassword],
                            decoration: authInputDecoration(
                              context,
                              labelText: 'Nhập lại mật khẩu',
                              prefixIcon: Icons.verified_user_outlined,
                              suffixIcon: PasswordVisibilityButton(
                                obscured: _obscureConfirm,
                                onToggle: () => setState(
                                  () => _obscureConfirm = !_obscureConfirm,
                                ),
                              ),
                            ),
                            validator: (v) => v != _password.text
                                ? 'Mật khẩu nhập lại không khớp'
                                : null,
                            onFieldSubmitted: (_) => _submit(),
                          ),
                          const SizedBox(height: 24),
                          AuthPrimaryButton(
                            label: 'Đăng ký',
                            icon: Icons.rocket_launch_rounded,
                            busy: _submitting,
                            onPressed: _submit,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Đã có tài khoản?',
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              TextButton(
                                onPressed: _submitting
                                    ? null
                                    : () => Navigator.of(context).maybePop(),
                                style: TextButton.styleFrom(
                                  foregroundColor: AuthGymColors.vibrantGreen,
                                  textStyle: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                child: const Text('Đăng nhập'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
