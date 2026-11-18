import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../data/auth_api.dart';
import 'auth_widgets.dart';
import 'password_rules.dart';

/// UC11: hai bước trên cùng một màn — nhập email → nhập mã 6 số + mật khẩu mới. Thông báo
/// sau bước 1 luôn giống nhau, không cho biết email có đăng ký hay không (BR-A06).
/// Thành công thì pop về màn đăng nhập, trả về email để điền sẵn.
class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  static const sentMessage =
      'Nếu email đã đăng ký, mã gồm 6 chữ số đã được gửi tới hộp thư. '
      'Mã có hiệu lực 15 phút.';

  final _emailForm = GlobalKey<FormState>();
  final _resetForm = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _codeSent = false;
  bool _busy = false;
  String? _error;
  Map<String, String> _fieldErrors = const {};

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _fieldErrors = const {};
    });
    try {
      await action();
    } on ApiException catch (e) {
      _fieldErrors = e.fieldErrors;
      _error = e.code == 'VALIDATION_ERROR' && e.fieldErrors.isNotEmpty
          ? null
          : e.message;
      (_codeSent ? _resetForm : _emailForm).currentState?.validate();
    } on NetworkException catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() async {
    if (_busy || !_emailForm.currentState!.validate()) return;
    await _run(() async {
      await ref.read(authApiProvider).forgotPassword(_email.text.trim());
      _codeSent = true;
    });
  }

  Future<void> _reset() async {
    if (_busy || !_resetForm.currentState!.validate()) return;
    final email = _email.text.trim();
    await _run(() async {
      await ref
          .read(authApiProvider)
          .resetPassword(
            email: email,
            code: _code.text.trim(),
            newPassword: _password.text,
          );
      if (mounted) Navigator.of(context).pop(email);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_codeSent)
                const AuthGymHeader(
                  compact: true,
                  showBackButton: true,
                  badgeText: 'BƯỚC 1/2 • XÁC THỰC EMAIL',
                  icon: Icons.lock_reset_rounded,
                  title: 'Khôi phục mật khẩu',
                  subtitle:
                      'Nhập email tài khoản VieGym để nhận mã xác thực gồm 6 chữ số.',
                )
              else
                const _StepTwoCompactBar(),
              SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    _codeSent ? 16 : 24,
                    24,
                    24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Form(
                        key: _emailForm,
                        child: TextFormField(
                          key: const Key('forgot-email'),
                          controller: _email,
                          enabled: !_busy && !_codeSent,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.email],
                          decoration: authInputDecoration(
                            context,
                            labelText: 'Email đã đăng ký',
                            hintText: 'you@example.com',
                            prefixIcon: Icons.email_outlined,
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Vui lòng nhập email'
                              : _fieldErrors['email'],
                          onFieldSubmitted: (_) {
                            if (!_codeSent) _sendCode();
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (!_codeSent)
                        AuthPrimaryButton(
                          buttonKey: const Key('forgot-send'),
                          label: 'Gửi mã xác thực',
                          icon: Icons.send_rounded,
                          busy: _busy,
                          onPressed: _sendCode,
                        )
                      else
                        Form(
                          key: _resetForm,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const AuthNoticeBanner(
                                message: sentMessage,
                                isError: false,
                                textKey: Key('forgot-sent'),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                key: const Key('reset-code'),
                                controller: _code,
                                enabled: !_busy,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.next,
                                maxLength: 6,
                                autofillHints: const [
                                  AutofillHints.oneTimeCode,
                                ],
                                style: const TextStyle(
                                  letterSpacing: 3,
                                  fontWeight: FontWeight.w700,
                                ),
                                decoration: authInputDecoration(
                                  context,
                                  labelText: 'Mã 6 chữ số',
                                  hintText: '000000',
                                  prefixIcon: Icons.pin_outlined,
                                ).copyWith(counterText: ''),
                                validator: (v) =>
                                    RegExp(r'^\d{6}$').hasMatch(v?.trim() ?? '')
                                    ? _fieldErrors['code']
                                    : 'Mã gồm 6 chữ số',
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                key: const Key('reset-password'),
                                controller: _password,
                                enabled: !_busy,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [
                                  AutofillHints.newPassword,
                                ],
                                decoration: authInputDecoration(
                                  context,
                                  labelText: 'Mật khẩu mới',
                                  prefixIcon: Icons.lock_outline_rounded,
                                  suffixIcon: PasswordVisibilityButton(
                                    obscured: _obscurePassword,
                                    onToggle: () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                  ),
                                ),
                                validator: (v) =>
                                    passwordRuleError(v) ??
                                    _fieldErrors['newPassword'],
                              ),
                              PasswordChecklist(
                                controller: _password,
                                compact: true,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                key: const Key('reset-confirm'),
                                controller: _confirm,
                                enabled: !_busy,
                                obscureText: _obscureConfirm,
                                textInputAction: TextInputAction.done,
                                decoration: authInputDecoration(
                                  context,
                                  labelText: 'Nhập lại mật khẩu mới',
                                  prefixIcon: Icons.verified_user_outlined,
                                  suffixIcon: PasswordVisibilityButton(
                                    obscured: _obscureConfirm,
                                    onToggle: () => setState(
                                      () => _obscureConfirm = !_obscureConfirm,
                                    ),
                                  ),
                                ),
                                validator: (v) => v == _password.text
                                    ? null
                                    : 'Mật khẩu nhập lại không khớp',
                                onFieldSubmitted: (_) => _reset(),
                              ),
                              const SizedBox(height: 16),
                              AuthPrimaryButton(
                                buttonKey: const Key('reset-submit'),
                                label: 'Đặt lại mật khẩu',
                                icon: Icons.check_circle_outline_rounded,
                                busy: _busy,
                                onPressed: _reset,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  TextButton.icon(
                                    key: const Key('forgot-resend'),
                                    onPressed: _busy
                                        ? null
                                        : () => _run(() async {
                                            await ref
                                                .read(authApiProvider)
                                                .forgotPassword(
                                                  _email.text.trim(),
                                                );
                                            if (!context.mounted) return;
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Đã gửi yêu cầu mã mới. Mã cũ không còn dùng được.',
                                                ),
                                              ),
                                            );
                                          }),
                                    icon: const Icon(
                                      Icons.refresh_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('Gửi lại mã'),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    onPressed: _busy
                                        ? null
                                        : () => setState(() {
                                            _codeSent = false;
                                            _error = null;
                                          }),
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 18,
                                    ),
                                    label: const Text('Đổi email'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        AuthNoticeBanner(
                          message: _error!,
                          textKey: const Key('forgot-error'),
                        ),
                      ],
                    ],
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

class _StepTwoCompactBar extends StatelessWidget {
  const _StepTwoCompactBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AuthGymColors.heroDark, AuthGymColors.heroMid],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 20, 14),
          child: Row(
            children: [
              AuthHeaderActionButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Quay lại',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BƯỚC 2/2 • ĐẶT LẠI MẬT KHẨU',
                      style: TextStyle(
                        color: AuthGymColors.accentLime,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Nhập mã xác thực & mật khẩu mới',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
