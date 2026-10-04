import 'dart:async';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:polaris_mobile_app/controllers/auth_controller.dart';
import 'package:polaris_mobile_app/services/theme_service.dart';
import 'register_page.dart';

final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  Color get cream => context.pc.background;
  Color get navy => context.pc.ink;
  Color get gold => context.pc.star;
  Color get mutedColor => context.pc.muted;

  static const int _resendCooldownSeconds = 60;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool obscurePassword = true;

  Timer? _cooldownTimer;
  int _resendCooldown = 0;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    final auth = context.read<AuthController>();
    if (auth.isLoading) return;
    FocusScope.of(context).unfocus();

    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      showMessage('Please enter your email and password.');
      return;
    }

    final success = await auth.login(email: email, password: password);

    if (!mounted) return;

    if (!success) {
      showMessage(auth.errorMessage ?? 'Login failed.');
    }
  }

  Future<void> googleLogin() async {
    final auth = context.read<AuthController>();
    if (auth.isLoading) return;
    FocusScope.of(context).unfocus();

    final success = await auth.signInWithGoogle();

    if (!mounted) return;

    if (!success && auth.errorMessage != null) {
      showMessage(auth.errorMessage!);
    }
  }

  Future<void> forgotPassword() async {
    final auth = context.read<AuthController>();
    if (auth.isLoading) return;

    final email = await showDialog<String>(
      context: context,
      builder: (_) => _ForgotPasswordDialog(
        initialEmail: emailController.text.trim(), 
      ),
    );

    if (email == null || !mounted) return;

    final success = await auth.resetPassword(email);

    if (!mounted) return;

    if (success) {
      showMessage(
        auth.infoMessage ?? 'Password reset link sent.',
        isError: false,
      );
    } else {
      showMessage(auth.errorMessage ?? 'Could not send reset email.');
    }
  }

  Future<void> resendVerification() async {
    final auth = context.read<AuthController>();
    if (auth.isLoading || _resendCooldown > 0) return;
    FocusScope.of(context).unfocus();

    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      showMessage(
        'Enter your email and password above, then tap "Resend verification email".',
      );
      return;
    }
    if (!_emailRegex.hasMatch(email)) {
      showMessage('Please enter a valid email address.');
      return;
    }

    final success = await auth.resendVerificationEmail(
      email: email,
      password: password,
    );

    if (!mounted) return;

    if (success) {
      showMessage(
        auth.infoMessage ?? 'Verification email sent.',
        isError: false,
      );
      _startCooldown();
    } else {
      showMessage(auth.errorMessage ?? 'Could not send the email.');
    }
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _resendCooldown = _resendCooldownSeconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCooldown <= 1) {
        timer.cancel();
        setState(() => _resendCooldown = 0);
      } else {
        setState(() => _resendCooldown--);
      }
    });
  }

  void showMessage(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? const Color(0xFFC0252B) : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final resendDisabled = auth.isLoading || _resendCooldown > 0;

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
                      color: navy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to continue',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: mutedColor),
                  ),
                  const SizedBox(height: 36),

                  // EMAIL
                  TextField(
                    controller: emailController,
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
                    controller: passwordController,
                    obscureText: obscurePassword,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => login(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                          () => obscurePassword = !obscurePassword,
                        ),
                        icon: Icon(
                          obscurePassword
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
                      onPressed: auth.isLoading ? null : forgotPassword,
                      child: Text(
                        'Forgot Password?',
                        style: TextStyle(
                          color: navy,
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
                      onPressed: auth.isLoading ? null : login,
                      child: auth.isLoading
                          ? SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: cream,
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
                      onPressed: resendDisabled ? null : resendVerification,
                      child: Text(
                        _resendCooldown > 0
                            ? 'Resend verification email (${_resendCooldown}s)'
                            : 'Resend verification email',
                        style: TextStyle(
                          color: resendDisabled ? mutedColor : navy,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // OR DIVIDER
                  Row(
                    children: [
                      Expanded(child: Divider(color: context.pc.line)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('OR', style: TextStyle(color: mutedColor)),
                      ),
                      Expanded(child: Divider(color: context.pc.line)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // GOOGLE
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: auth.isLoading ? null : googleLogin,
                      icon: const FaIcon(FontAwesomeIcons.google, size: 20),
                      label: const Text(
                        'Continue with Google',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.pc.field,
                        foregroundColor: context.pc.ink,
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
                        style: TextStyle(color: mutedColor),
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
                            color: navy,
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

// -----------------------------------------------------------------------------
// FORGOT PASSWORD DIALOG
// Owns its own TextEditingController so it is disposed safely with the dialog.
// -----------------------------------------------------------------------------
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
    if (!_emailRegex.hasMatch(email)) {
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