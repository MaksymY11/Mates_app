import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/auth_service.dart';
import 'login_page.dart';

/// Three-step password recovery flow: (1) enter email to request a reset code, (2) enter the 6-digit code, (3) set and confirm a new password.
/// All state lives in a single widget so users can navigate back through steps without losing values.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  int _step = 1;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  String _email = '';
  String _code = '';
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  /// Requests a reset code for the entered email and advances to the code-entry step. Backend always returns 200 for anti-enumeration,
  /// so this effectively never user-errors, network failures surface via snackbar.
  Future<void> _handleSendCode() async {
    if (_loading) return;

    setState(() => _loading = true);
    try {
      await AuthService.forgotPassword(_emailController.text);
      _email = _emailController.text;
      setState(() => _step = 2);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  /// Stores the entered code locally and advances to the password step. Code validity is checked server-side at the final step
  /// (fewer round trips, fewer failure points).
  void _handleCodeContinue() {
    if (_codeController.text.length != 6) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter the 6-digit code')));
      return;
    }
    _code = _codeController.text;
    setState(() => _step = 3);
  }

  /// Submits the email + code + new password to the backend. On success shows a confirmation snackbar and navigates to LoginPage (clearing the stack).
  /// On failure (bad code, expired code, weak password) surfaces the server message via snackbar so the user can go back and retry.
  Future<void> _handleResetPassword() async {
    if (_loading) return;
    if (_passwordController.text != _confirmController.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }

    setState(() => _loading = true);
    try {
      await AuthService.resetPassword(_email, _code, _passwordController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset successfully')),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  /// Shared decoration for the three brand-green rounded inputs used across steps.
  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFF7CFF7C),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide.none,
      ),
    );
  }

  /// Shared right-aligned brand button matching login_page's Continue style. Shows a spinner while [loading] is true.
  Widget _primaryButton({
    required String label,
    required VoidCallback? onPressed,
    required bool loading,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          width: 120,
          child: ElevatedButton(
            onPressed: loading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7CFF7C),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
            ),
            child:
                loading
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : Text(
                      label,
                      style: const TextStyle(color: Colors.black, fontSize: 16),
                    ),
          ),
        ),
      ],
    );
  }

  /// Step 1: email entry. Submits to /forgotPassword and advances to the code step.
  Widget _buildEmailStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Forgot password',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter the email associated with your account',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: _fieldDecoration('Email'),
        ),
        const SizedBox(height: 20),
        _primaryButton(
          label: 'Send code',
          onPressed: _handleSendCode,
          loading: _loading,
        ),
      ],
    );
  }

  /// Step 2: code entry. Digits-only 6-digit field; advances without hitting the server (code is validated at step 3).
  Widget _buildCodeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Enter the code',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'We sent a code to $_email',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _codeController,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
            fontSize: 24,
            letterSpacing: 8,
            fontWeight: FontWeight.bold,
          ),
          decoration: _fieldDecoration('6-digit code').copyWith(
            counterText: '',
            hintStyle: const TextStyle(
              fontSize: 16,
              letterSpacing: 0,
              fontWeight: FontWeight.normal,
            ),
          ),
          onChanged: (v) {
            if (v.length == 6) _handleCodeContinue();
          },
          onSubmitted: (_) => _handleCodeContinue(),
        ),
        const SizedBox(height: 20),
        _primaryButton(
          label: 'Continue',
          onPressed: _handleCodeContinue,
          loading: false,
        ),
      ],
    );
  }

  /// Step 3: new password entry with match confirmation. Submits the full reset on success.
  Widget _buildPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Set a new password',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: _fieldDecoration('New password').copyWith(
            helperText:
                'Use 8+ characters, mix letters and numbers, avoid your name or email',
            helperMaxLines: 2,
            helperStyle: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _confirmController,
          obscureText: true,
          decoration: _fieldDecoration('Confirm password'),
        ),
        const SizedBox(height: 20),
        _primaryButton(
          label: 'Reset',
          onPressed: _handleResetPassword,
          loading: _loading,
        ),
      ],
    );
  }

  /// Dispatches to the correct step builder based on [_step].
  Widget _buildCurrentStep() {
    switch (_step) {
      case 1:
        return _buildEmailStep();
      case 2:
        return _buildCodeStep();
      case 3:
        return _buildPasswordStep();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 1,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) setState(() => _step--);
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.black,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (_step == 1) {
                Navigator.pop(context);
              } else {
                setState(() => _step--);
              }
            },
          ),
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: 0,
                right: 0,
                child: Image.asset('assets/leaves1.png', width: 150),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Image.asset('assets/logo.png', width: 120, height: 120),
                      const SizedBox(height: 35),
                      _buildCurrentStep(),
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
