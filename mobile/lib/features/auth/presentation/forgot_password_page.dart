import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../data/auth_api.dart';
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
      await ref.read(authApiProvider).resetPassword(
            email: email,
            code: _code.text.trim(),
            newPassword: _password.text,
          );
      if (mounted) Navigator.of(context).pop(email);
    });
  }

  @override
  Widget build(BuildContext context) {
    final errorStyle = TextStyle(color: Theme.of(context).colorScheme.error);
    return Scaffold(
      appBar: AppBar(title: const Text('Quên mật khẩu')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Form(
              key: _emailForm,
              child: TextFormField(
                key: const Key('forgot-email'),
                controller: _email,
                enabled: !_busy && !_codeSent,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'Email đã đăng ký'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Vui lòng nhập email'
                    : _fieldErrors['email'],
              ),
            ),
            const SizedBox(height: 16),
            if (!_codeSent)
              FilledButton(
                key: const Key('forgot-send'),
                onPressed: _busy ? null : _sendCode,
                child: const Text('Gửi mã'),
              )
            else
              Form(
                key: _resetForm,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(sentMessage, key: Key('forgot-sent')),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('reset-code'),
                      controller: _code,
                      enabled: !_busy,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      decoration: const InputDecoration(labelText: 'Mã 6 chữ số'),
                      validator: (v) =>
                          RegExp(r'^\d{6}$').hasMatch(v?.trim() ?? '')
                              ? _fieldErrors['code']
                              : 'Mã gồm 6 chữ số',
                    ),
                    TextFormField(
                      key: const Key('reset-password'),
                      controller: _password,
                      enabled: !_busy,
                      obscureText: true,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: const InputDecoration(labelText: 'Mật khẩu mới'),
                      validator: (v) =>
                          passwordRuleError(v) ?? _fieldErrors['newPassword'],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('reset-confirm'),
                      controller: _confirm,
                      enabled: !_busy,
                      obscureText: true,
                      decoration:
                          const InputDecoration(labelText: 'Nhập lại mật khẩu mới'),
                      validator: (v) =>
                          v == _password.text ? null : 'Mật khẩu nhập lại không khớp',
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      key: const Key('reset-submit'),
                      onPressed: _busy ? null : _reset,
                      child: const Text('Đặt lại mật khẩu'),
                    ),
                    TextButton(
                      key: const Key('forgot-resend'),
                      onPressed: _busy
                          ? null
                          : () => _run(() async {
                                await ref
                                    .read(authApiProvider)
                                    .forgotPassword(_email.text.trim());
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Đã gửi yêu cầu mã mới. Mã cũ không còn dùng được.')),
                                );
                              }),
                      child: const Text('Gửi lại mã'),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                _codeSent = false;
                                _error = null;
                              }),
                      child: const Text('Đổi email'),
                    ),
                  ],
                ),
              ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(_error!, key: const Key('forgot-error'), style: errorStyle),
              ),
          ],
        ),
      ),
    );
  }
}
