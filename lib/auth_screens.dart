import 'package:flutter/material.dart';

import 'auth.dart';
import 'design_system.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.controller,
    required this.homeBuilder,
  });

  final AuthController controller;
  final Widget Function() homeBuilder;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  AuthPage _page = AuthPage.splash;
  bool _guestMode = false;
  AuthStatus? _previousStatus;

  @override
  void initState() {
    super.initState();
    _previousStatus = widget.controller.status;
    widget.controller.addListener(_onAuthControllerChanged);
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (mounted && !widget.controller.isSignedIn) {
        setState(() => _page = AuthPage.welcome);
      }
    });
  }

  void _onAuthControllerChanged() {
    final currentStatus = widget.controller.status;
    if (_previousStatus == AuthStatus.signedIn &&
        currentStatus == AuthStatus.signedOut) {
      if (mounted) {
        setState(() {
          _guestMode = false;
          _page = AuthPage.welcome;
        });
      }
    }
    _previousStatus = currentStatus;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onAuthControllerChanged);
    super.dispose();
  }

  void _show(AuthPage page) {
    widget.controller.clearError();
    setState(() => _page = page);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        if (widget.controller.isSignedIn || _guestMode) {
          return widget.homeBuilder();
        }
        if (_page == AuthPage.splash) return const _SplashScreen();
        return switch (_page) {
          AuthPage.welcome => _WelcomeScreen(
            onLogin: () => _show(AuthPage.login),
            onSignUp: () => _show(AuthPage.signUp),
            onGuest: () => setState(() => _guestMode = true),
          ),
          AuthPage.login => _LoginScreen(
            controller: widget.controller,
            onBack: () => _show(AuthPage.welcome),
            onSignUp: () => _show(AuthPage.signUp),
            onForgotPassword: () => _show(AuthPage.forgotPassword),
          ),
          AuthPage.signUp => _SignUpScreen(
            controller: widget.controller,
            onBack: () => _show(AuthPage.welcome),
            onLogin: () => _show(AuthPage.login),
            onVerified: () => _show(AuthPage.login),
          ),
          AuthPage.forgotPassword => _ForgotPasswordScreen(
            controller: widget.controller,
            onBack: () => _show(AuthPage.login),
          ),
          AuthPage.splash => const _SplashScreen(),
        };
      },
    );
  }
}

enum AuthPage { splash, welcome, login, signUp, forgotPassword }

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: _BrandLockup(showTagline: true)));
}

class _WelcomeScreen extends StatelessWidget {
  const _WelcomeScreen({
    required this.onLogin,
    required this.onSignUp,
    required this.onGuest,
  });

  final VoidCallback onLogin;
  final VoidCallback onSignUp;
  final VoidCallback onGuest;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 46),
            child: Column(
              children: [
                const SizedBox(height: 26),
                const _BrandLockup(showTagline: true, prominent: true),
                const SizedBox(height: 30),
                SizedBox(
                  height: ((constraints.maxWidth - 48) / 1.506)
                      .clamp(0.0, constraints.maxHeight * .32)
                      .clamp(180.0, 760.0),
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: Image.asset(
                      'assets/welcome_road.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'A safer journey\nwith every user.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontSize: 36,
                    height: 1.12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 20),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Text(
                    'RoadSense maps road conditions using real-world data from people like you.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: RoadSenseColors.muted,
                      fontSize: 21,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 34),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 64),
                      shape: const StadiumBorder(),
                      backgroundColor: const Color(0xFF07988C),
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onPressed: onSignUp,
                    child: const Text('Create account'),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 64),
                      shape: const StadiumBorder(),
                      side: const BorderSide(
                        color: Color(0xFF07988C),
                        width: 2,
                      ),
                      foregroundColor: const Color(0xFF078E83),
                      textStyle: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onPressed: onLogin,
                    child: const Text('Log in'),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: onGuest,
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.arrow_forward, size: 25),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF078E83),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  label: const Text('Continue as guest'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _LoginScreen extends StatefulWidget {
  const _LoginScreen({
    required this.controller,
    required this.onBack,
    required this.onSignUp,
    required this.onForgotPassword,
  });

  final AuthController controller;
  final VoidCallback onBack;
  final VoidCallback onSignUp;
  final VoidCallback onForgotPassword;

  @override
  State<_LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<_LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await widget.controller.signIn(
      email: _email.text,
      password: _password.text,
    );
  }

  @override
  Widget build(BuildContext context) => _AuthLayout(
    title: 'Welcome back',
    onBack: widget.onBack,
    child: Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Log in to continue your journey.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: RoadSenseSpacing.lg),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
            validator: _emailValidator,
          ),
          const SizedBox(height: RoadSenseSpacing.md),
          TextFormField(
            controller: _password,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Password',
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                tooltip: _obscure ? 'Show password' : 'Hide password',
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: (value) => _required(value, 'Enter your password'),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: widget.onForgotPassword,
              child: const Text('Forgot password?'),
            ),
          ),
          _AuthError(controller: widget.controller),
          const SizedBox(height: RoadSenseSpacing.sm),
          _AuthButton(
            label: 'Log in',
            busy: widget.controller.status == AuthStatus.signingIn,
            onPressed: _submit,
          ),
          const SizedBox(height: RoadSenseSpacing.md),
          OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.account_circle_outlined),
            label: const Text('Continue with Google (coming soon)'),
          ),
          const SizedBox(height: RoadSenseSpacing.lg),
          TextButton(
            onPressed: widget.onSignUp,
            child: const Text('Create an account'),
          ),
        ],
      ),
    ),
  );
}

class _SignUpScreen extends StatefulWidget {
  const _SignUpScreen({
    required this.controller,
    required this.onBack,
    required this.onLogin,
    required this.onVerified,
  });

  final AuthController controller;
  final VoidCallback onBack;
  final VoidCallback onLogin;
  final VoidCallback onVerified;

  @override
  State<_SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<_SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await widget.controller.signUp(
      name: _name.text,
      email: _email.text,
      password: _password.text,
    );
    if (mounted && widget.controller.isSignedIn) {
      FocusManager.instance.primaryFocus?.unfocus();
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => Dialog(
          child: Padding(
            padding: const EdgeInsets.all(RoadSenseSpacing.md),
            child: _VerificationContent(
              onContinue: () {
                Navigator.of(dialogContext).pop();
                widget.onVerified();
              },
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => _AuthLayout(
    title: 'Create your account',
    onBack: widget.onBack,
    child: Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Set up RoadSense for your next journey.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: RoadSenseSpacing.lg),
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Name'),
            validator: (value) => _required(value, 'Enter your name'),
          ),
          const SizedBox(height: RoadSenseSpacing.md),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
            validator: _emailValidator,
          ),
          const SizedBox(height: RoadSenseSpacing.md),
          TextFormField(
            controller: _password,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Password',
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                tooltip: 'Show or hide password',
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: _passwordValidator,
          ),
          const SizedBox(height: RoadSenseSpacing.md),
          TextFormField(
            controller: _confirmPassword,
            obscureText: _obscure,
            decoration: const InputDecoration(labelText: 'Confirm password'),
            validator: (value) =>
                value != _password.text ? 'Passwords do not match' : null,
          ),
          _AuthError(controller: widget.controller),
          const SizedBox(height: RoadSenseSpacing.md),
          _AuthButton(
            label: 'Create account',
            busy: widget.controller.status == AuthStatus.signingUp,
            onPressed: _submit,
          ),
          const SizedBox(height: RoadSenseSpacing.md),
          TextButton(
            onPressed: widget.onLogin,
            child: const Text('Already have an account? Log in'),
          ),
        ],
      ),
    ),
  );
}

class _ForgotPasswordScreen extends StatefulWidget {
  const _ForgotPasswordScreen({required this.controller, required this.onBack});

  final AuthController controller;
  final VoidCallback onBack;

  @override
  State<_ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<_ForgotPasswordScreen> {
  final _email = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await widget.controller.sendPasswordReset(_email.text);
    if (mounted && widget.controller.errorMessage == null) {
      setState(() => _sent = true);
    }
  }

  @override
  Widget build(BuildContext context) => _AuthLayout(
    title: 'Reset your password',
    onBack: widget.onBack,
    child: _sent
        ? Column(
            children: [
              const Icon(
                Icons.mark_email_read_outlined,
                size: 48,
                color: RoadSenseColors.teal,
              ),
              const SizedBox(height: RoadSenseSpacing.md),
              Text(
                'Check your inbox',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: RoadSenseSpacing.sm),
              Text(
                'We sent password reset instructions to ${_email.text}.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          )
        : Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Enter your account email and we will send reset instructions.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: RoadSenseSpacing.lg),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: _emailValidator,
                ),
                _AuthError(controller: widget.controller),
                const SizedBox(height: RoadSenseSpacing.md),
                _AuthButton(
                  label: 'Send reset link',
                  busy: widget.controller.status == AuthStatus.sendingReset,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
  );
}

class _VerificationContent extends StatelessWidget {
  const _VerificationContent({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const RoadSenseLoadingState(label: 'Preparing your account'),
      const SizedBox(height: RoadSenseSpacing.md),
      Text(
        'Your email is ready to be verified when connected to a backend.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: RoadSenseSpacing.md),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onContinue,
          child: const Text('Continue to RoadSense'),
        ),
      ),
    ],
  );
}

class _AuthLayout extends StatelessWidget {
  const _AuthLayout({required this.child, this.title, this.onBack});

  final Widget child;
  final String? title;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.all(RoadSenseSpacing.md),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (onBack != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: onBack,
                      tooltip: 'Back',
                      icon: const Icon(Icons.arrow_back),
                    ),
                  ),
                if (title != null) ...[
                  const SizedBox(height: RoadSenseSpacing.lg),
                  Text(
                    title!,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: RoadSenseSpacing.lg),
                ],
                child,
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _BrandLockup extends StatelessWidget {
  const _BrandLockup({required this.showTagline, this.prominent = false});

  final bool showTagline;
  final bool prominent;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        width: prominent ? 66 : 48,
        height: prominent ? 70 : 48,
        child: CustomPaint(painter: _BrandMarkPainter()),
      ),
      SizedBox(height: prominent ? 12 : RoadSenseSpacing.sm),
      Text(
        'RoadSense',
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontSize: prominent ? 40 : null,
          fontWeight: FontWeight.w700,
        ),
      ),
      if (showTagline) ...[
        const SizedBox(height: RoadSenseSpacing.xs),
        Text(
          'Know the road around you.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(fontSize: prominent ? 18 : null),
        ),
      ],
    ],
  );
}

class _BrandMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final mark = Path()
      ..moveTo(size.width * .5, size.height * .04)
      ..lineTo(size.width * .98, size.height * .97)
      ..lineTo(size.width * .5, size.height * .73)
      ..lineTo(size.width * .02, size.height * .97)
      ..close();
    canvas.drawPath(mark, Paint()..color = const Color(0xFF07988C));
    final cutout = Path()
      ..moveTo(size.width * .5, size.height * .31)
      ..lineTo(size.width * .68, size.height * .72)
      ..lineTo(size.width * .5, size.height * .63)
      ..lineTo(size.width * .32, size.height * .72)
      ..close();
    canvas.drawPath(cutout, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AuthButton extends StatelessWidget {
  const _AuthButton({
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => ElevatedButton(
    onPressed: busy ? null : onPressed,
    child: busy
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(label),
  );
}

class _AuthError extends StatelessWidget {
  const _AuthError({required this.controller});

  final AuthController controller;

  @override
  Widget build(BuildContext context) => controller.errorMessage == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: RoadSenseSpacing.md),
          child: Text(
            controller.errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: RoadSenseColors.red,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
}

String? _required(String? value, String message) =>
    value == null || value.trim().isEmpty ? message : null;

String? _emailValidator(String? value) {
  if (value == null || value.trim().isEmpty) return 'Enter your email';
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())
      ? null
      : 'Enter a valid email';
}

String? _passwordValidator(String? value) {
  if (value == null || value.isEmpty) return 'Enter a password';
  return value.length < 8 ? 'Use at least 8 characters' : null;
}
