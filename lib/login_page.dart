import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:polaris_mobile_app/controllers/auth_controller.dart';
import 'package:polaris_mobile_app/services/theme_service.dart';
import 'register_page.dart';

/// Login screen. It only collects input and shows messages;
/// validation and the resend cooldown live in AuthController.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showMessage(String? message, {bool isError = true}) {
    if (!mounted || message == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? context.pc.danger : null,
        ),
      );
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    final auth = context.read<AuthController>();

    final success = await auth.login(
      email: _emailController.text,
      password: _passwordController.text,
    );

    if (!success) _showMessage(auth.errorMessage);
  }

  Future<void> _googleLogin() async {
    FocusScope.of(context).unfocus();
    final auth = context.read<AuthController>();

    final success = await auth.signInWithGoogle();

    if (!success) _showMessage(auth.errorMessage);
  }

  Future<void> _forgotPassword() async {
    final auth = context.read<AuthController>();

    final email = await showDialog<String>(
      context: context,
      builder: (_) => _ForgotPasswordDialog(
        initialEmail: _emailController.text.trim(),
      ),
    );

    if (email == null || !mounted) return;

    final success = await auth.resetPassword(email);

    _showMessage(
      success ? auth.infoMessage : auth.errorMessage,
      isError: !success,
    );
  }

  Future<void> _resendVerification() async {
    FocusScope.of(context).unfocus();
    final auth = context.read<AuthController>();

    final success = await auth.resendVerificationEmail(
      email: _emailController.text,
      password: _passwordController.text,
    );

    _showMessage(
      success ? auth.infoMessage : auth.errorMessage,
      isError: !success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final pc = context.pc;
    final resendDisabled = auth.isLoading || auth.resendCooldown > 0;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'POLARIS',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.lora(
                      fontSize: 35,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: pc.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to continue',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: pc.muted),
                  ),
                  const SizedBox(height: 36),

                  // EMAIL
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // PASSWORD
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _login(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // FORGOT PASSWORD
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: auth.isLoading ? null : _forgotPassword,
                      child: Text(
                        'Forgot Password?',
                        style: TextStyle(
                          color: pc.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // LOGIN BUTTON
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: auth.isLoading ? null : _login,
                      child: auth.isLoading
                          ? SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: pc.background,
                              ),
                            )
                          : const Text(
                              'Login',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // RESEND VERIFICATION
                  Center(
                    child: TextButton(
                      onPressed: resendDisabled ? null : _resendVerification,
                      child: Text(
                        auth.resendCooldown > 0
                            ? 'Resend verification email (${auth.resendCooldown}s)'
                            : 'Resend verification email',
                        style: TextStyle(
                          color: resendDisabled ? pc.muted : pc.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // OR DIVIDER
                  Row(
                    children: [
                      Expanded(child: Divider(color: pc.line)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('OR', style: TextStyle(color: pc.muted)),
                      ),
                      Expanded(child: Divider(color: pc.line)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // GOOGLE
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: auth.isLoading ? null : _googleLogin,
                      icon: const FaIcon(FontAwesomeIcons.google, size: 20),
                      label: const Text(
                        'Continue with Google',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: pc.field,
                        foregroundColor: pc.ink,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // REGISTER LINK
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: TextStyle(color: pc.muted),
                      ),
                      TextButton(
                        onPressed: auth.isLoading
                            ? null
                            : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const RegisterPage(),
                                  ),
                                ),
                        child: Text(
                          'Register',
                          style: TextStyle(
                            color: pc.ink,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
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

/// Asks for an email address. Owns its own controller so it is disposed
/// together with the dialog.
class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog({required this.initialEmail});

  final String initialEmail;

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _controller.text.trim();
    if (!AuthController.isValidEmail(email)) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    Navigator.pop(context, email);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reset Password'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        decoration: InputDecoration(
          labelText: 'Email',
          hintText: 'Enter your email',
          errorText: _error,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Send'),
        ),
      ],
    );
  }
}