import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../system/connection_page.dart';
import '../application/auth_controller.dart';
import 'auth_widgets.dart';
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
  bool _obscurePassword = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
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
    final email = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const RegisterPage()));
    if (email == null || !mounted) return;
    _email.text = email;
    _password.clear();
    setState(() => _error = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đăng ký thành công. Hãy đăng nhập.')),
    );
  }

  Future<void> _openForgot() async {
    final email = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ForgotPasswordPage(initialEmail: _email.text.trim()),
      ),
    );
    if (email == null || !mounted) return;
    _email.text = email;
    _password.clear();
    setState(() => _error = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã đặt lại mật khẩu. Hãy đăng nhập bằng mật khẩu mới.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasSessionNotice = _error == null && widget.message != null;

    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthGymHeader(
                title: 'Sẵn sàng tập luyện!',
                subtitle:
                    'Đăng nhập để tiếp tục lịch tập, thực đơn & AI Coach của bạn.',
                showFeaturePills: true,
                trailing: AuthHeaderActionButton(
                  tooltip: 'Kiểm tra kết nối',
                  icon: Icons.wifi_tethering_rounded,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ConnectionPage()),
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  child: AutofillGroup(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Đăng nhập tài khoản',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Nhập thông tin của bạn để vào phòng tập số VieGym',
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 13.5,
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (hasSessionNotice) ...[
                            AuthNoticeBanner(
                              message: widget.message!,
                              isError: false,
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (_error != null) ...[
                            AuthNoticeBanner(message: _error!),
                            const SizedBox(height: 16),
                          ],
                          TextFormField(
                            key: const Key('login-email'),
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
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Vui lòng nhập email'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            key: const Key('login-password'),
                            controller: _password,
                            enabled: !_submitting,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
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
                            validator: (v) => (v == null || v.isEmpty)
                                ? 'Vui lòng nhập mật khẩu'
                                : null,
                            onFieldSubmitted: (_) => _submit(),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              key: const Key('login-forgot'),
                              onPressed: _submitting ? null : _openForgot,
                              style: TextButton.styleFrom(
                                foregroundColor: AuthGymColors.vibrantGreen,
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              child: const Text('Quên mật khẩu?'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          AuthPrimaryButton(
                            buttonKey: const Key('login-submit'),
                            label: 'Đăng nhập',
                            busy: _submitting,
                            onPressed: _submit,
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: Divider(color: scheme.outlineVariant),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Text(
                                  'MỚI THAM GIA?',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(color: scheme.outlineVariant),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: _submitting ? null : _openRegister,
                            icon: const Icon(
                              Icons.person_add_alt_1_rounded,
                              size: 20,
                            ),
                            label: const Text('Tạo tài khoản tập luyện mới'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AuthGymColors.heroMid,
                              minimumSize: const Size.fromHeight(50),
                              side: BorderSide(
                                color: AuthGymColors.vibrantGreen.withValues(
                                  alpha: 0.55,
                                ),
                                width: 1.4,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
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
