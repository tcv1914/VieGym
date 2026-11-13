import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../data/auth_api.dart';
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
    setState(() => _fieldErrors = const {});
    if (_submitting || !_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final email = _email.text.trim();
    try {
      await ref.read(authApiProvider).register(
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
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng ký')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              TextFormField(
                controller: _email,
                enabled: !_submitting,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return 'Vui lòng nhập email';
                  if (!value.contains('@')) return 'Email không hợp lệ';
                  return _fieldErrors['email'];
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _fullName,
                enabled: !_submitting,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Họ tên'),
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return 'Vui lòng nhập họ tên';
                  if (value.length > 100) return 'Họ tên tối đa 100 ký tự';
                  return _fieldErrors['fullName'];
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                enabled: !_submitting,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Mật khẩu',
                  helperText: '8–72 ký tự, có chữ cái và chữ số',
                ),
                validator: _validatePassword,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirm,
                enabled: !_submitting,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Nhập lại mật khẩu'),
                validator: (v) =>
                    v != _password.text ? 'Mật khẩu nhập lại không khớp' : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Đăng ký'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
