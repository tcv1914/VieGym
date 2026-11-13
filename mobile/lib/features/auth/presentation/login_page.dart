import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../system/connection_page.dart';
import '../application/auth_controller.dart';
import 'forgot_password_page.dart';
import 'register_page.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key, this.message});

  /// Thông báo khi bị đưa về màn này (phiên hết hạn, logout chưa xác nhận...).
  final String? message;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .login(_email.text, _password.text);
      // Thành công: AuthGate chuyển màn, widget này bị gỡ.
    } on ApiException catch (e) {
      _setError(e.message);
    } on NetworkException catch (e) {
      _setError(e.toString());
    } catch (_) {
      _setError('Không lưu được phiên đăng nhập trên máy, vui lòng thử lại.');
    }
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _error = message;
    });
  }

  Future<void> _openRegister() async {
    final email = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const RegisterPage()),
    );
    if (email == null || !mounted) return;
    _email.text = email;
    _password.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đăng ký thành công. Hãy đăng nhập.')),
    );
  }

  Future<void> _openForgot() async {
    final email = await Navigator.of(context).push<String>(
      MaterialPageRoute(
          builder: (_) => ForgotPasswordPage(initialEmail: _email.text.trim())),
    );
    if (email == null || !mounted) return;
    _email.text = email;
    _password.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Đã đặt lại mật khẩu. Hãy đăng nhập bằng mật khẩu mới.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notice = _error ?? widget.message;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đăng nhập VieGym'),
        actions: [
          IconButton(
            tooltip: 'Kiểm tra kết nối',
            icon: const Icon(Icons.wifi_tethering),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ConnectionPage()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              TextFormField(
                key: const Key('login-email'),
                controller: _email,
                enabled: !_submitting,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Vui lòng nhập email' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('login-password'),
                controller: _password,
                enabled: !_submitting,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                decoration: const InputDecoration(labelText: 'Mật khẩu'),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Vui lòng nhập mật khẩu' : null,
                onFieldSubmitted: (_) => _submit(),
              ),
              if (notice != null) ...[
                const SizedBox(height: 16),
                Text(notice,
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('login-submit'),
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Đăng nhập'),
              ),
              TextButton(
                key: const Key('login-forgot'),
                onPressed: _submitting ? null : _openForgot,
                child: const Text('Quên mật khẩu?'),
              ),
              TextButton(
                onPressed: _submitting ? null : _openRegister,
                child: const Text('Chưa có tài khoản? Đăng ký'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
