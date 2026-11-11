import 'package:flutter/material.dart';
import '../application/app_controller.dart';
import '../core/theme.dart';
import '../domain/models.dart';
import '../domain/registration.dart';
import 'widgets.dart';
import 'location_fields.dart';
import '../domain/location.dart';

void _reveal(BuildContext context) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (context.mounted) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 200),
        alignment: .1,
      );
    }
  });
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool registering = false;
  @override
  Widget build(BuildContext context) => registering
      ? RegisterScreen(onLogin: () => setState(() => registering = false))
      : LoginScreen(onRegister: () => setState(() => registering = true));
}

class _AuthFrame extends StatelessWidget {
  final String title, subtitle;
  final Widget child;
  const _AuthFrame({
    required this.title,
    required this.subtitle,
    required this.child,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Row(
        children: [BrandMark(size: 30), SizedBox(width: 9), Text('EasyScrap')],
      ),
    ),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(
                  child: CircleAvatar(
                    radius: 32,
                    backgroundColor: AppColors.mint,
                    child: Icon(
                      Icons.eco_rounded,
                      size: 36,
                      color: AppColors.green,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.darkGreen,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                child,
                const SizedBox(height: 24),
                const Text(
                  'Recycle locally. Make a difference.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Text(
                  AppScope.of(context).connected
                      ? 'Your account and activity are saved.'
                      : 'Static demo · Accounts reset when the app restarts.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _AuthError extends StatelessWidget {
  final String? message;
  const _AuthError(this.message, {super.key});
  @override
  Widget build(BuildContext context) => message == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEEEE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 18,
                  color: Color(0xFFB42318),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message!,
                    style: const TextStyle(
                      color: Color(0xFFB42318),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
}

class _PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?) validator;
  final bool newPassword;
  final VoidCallback? onSubmit;
  const _PasswordField({
    required super.key,
    required this.controller,
    this.label = 'Password',
    required this.validator,
    this.newPassword = false,
    this.onSubmit,
  });
  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool hidden = true;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.controller,
    obscureText: hidden,
    autocorrect: false,
    enableSuggestions: false,
    autofillHints: [
      widget.newPassword ? AutofillHints.newPassword : AutofillHints.password,
    ],
    validator: widget.validator,
    onFieldSubmitted: (_) => widget.onSubmit?.call(),
    decoration: InputDecoration(
      labelText: widget.label,
      prefixIcon: const Icon(Icons.lock_outline),
      suffixIcon: IconButton(
        tooltip: hidden
            ? 'Show ${widget.label.toLowerCase()}'
            : 'Hide ${widget.label.toLowerCase()}',
        onPressed: () => setState(() => hidden = !hidden),
        icon: Icon(
          hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          size: 20,
        ),
      ),
    ),
  );
}

class LoginScreen extends StatefulWidget {
  final VoidCallback onRegister;
  const LoginScreen({super.key, required this.onRegister});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final form = GlobalKey<FormState>();
  final identifier = TextEditingController(),
      password = TextEditingController();
  String? error;
  @override
  void dispose() {
    identifier.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final app = AppScope.of(context);
    if (app.authBusy || !form.currentState!.validate()) return;
    setState(() => error = null);
    try {
      await app.signIn(identifier.text, password.text);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is StateError
              ? e.message.toString()
              : 'Could not log in. Please try again.',
        );
      }
    }
  }

  void fillDemo(String username) {
    identifier.text = username;
    password.text = 'EasyScrap123!';
    setState(() => error = null);
  }

  @override
  Widget build(BuildContext context) {
    final busy = AppScope.of(context).authBusy;
    return _AuthFrame(
      title: 'Welcome back!',
      subtitle: 'Log in and turn your scrap into something valuable.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Surface(
            child: AutofillGroup(
              child: Form(
                key: form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Log in to EasyScrap',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _AuthError(error),
                    TextFormField(
                      key: const Key('login-identifier'),
                      controller: identifier,
                      autofillHints: const [AutofillHints.username],
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      validator: AccountValidation.requiredName,
                      decoration: const InputDecoration(
                        labelText: 'Email or username',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _PasswordField(
                      key: const Key('login-password'),
                      controller: password,
                      validator: AccountValidation.requiredName,
                      onSubmit: submit,
                    ),
                    const SizedBox(height: 22),
                    FilledButton(
                      key: const Key('login-submit'),
                      onPressed: busy ? null : submit,
                      child: busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Log in'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: busy ? null : widget.onRegister,
                      child: const Text('New here? Create an account'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (!AppScope.of(context).connected)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.mint,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Try a demo account',
                    style: TextStyle(
                      color: AppColors.darkGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Choose an account to fill the form, then log in.',
                    style: TextStyle(color: AppColors.muted, fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: busy ? null : () => fillDemo('household'),
                        icon: const Icon(Icons.cottage_outlined, size: 18),
                        label: const Text('Household'),
                      ),
                      OutlinedButton.icon(
                        onPressed: busy ? null : () => fillDemo('buyer'),
                        icon: const Icon(
                          Icons.local_shipping_outlined,
                          size: 18,
                        ),
                        label: const Text('Scrap Buyer'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Demo password: EasyScrap123!',
                    style: TextStyle(color: AppColors.darkGreen, fontSize: 11),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  final VoidCallback onLogin;
  const RegisterScreen({super.key, required this.onLogin});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final form = GlobalKey<FormState>();
  final errorKey = GlobalKey();
  final first = TextEditingController(),
      middle = TextEditingController(),
      last = TextEditingController(),
      suffix = TextEditingController(),
      contact = TextEditingController(),
      username = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController(),
      confirmation = TextEditingController(),
      street = TextEditingController();
  UserRole role = UserRole.household;
  LocationSelection? address;
  String? error;
  @override
  void dispose() {
    for (final controller in [
      first,
      middle,
      last,
      suffix,
      contact,
      username,
      email,
      password,
      confirmation,
      street,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    final app = AppScope.of(context);
    if (app.authBusy) return;
    final invalid = form.currentState!.validateGranularly();
    if (invalid.isNotEmpty) {
      _reveal(invalid.first.context);
      return;
    }
    if (address == null) {
      setState(
        () => error = 'Please select your city / municipality and barangay.',
      );
      _reveal(errorKey.currentContext!);
      return;
    }
    setState(() => error = null);
    try {
      await app.register(
        Registration(
          firstname: first.text,
          middlename: middle.text,
          lastname: last.text,
          suffix: suffix.text,
          contact: contact.text,
          username: username.text,
          email: email.text,
          password: password.text,
          barangay: address!.barangay.name,
          cityMunicipalityCode: address!.city.code,
          barangayCode: address!.barangay.code,
          streetPurok: street.text,
          role: role,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is StateError
              ? e.message.toString()
              : 'Could not create your account. Please try again.',
        );
        _reveal(errorKey.currentContext!);
      }
    }
  }

  Widget field(
    String id,
    String label,
    TextEditingController controller, {
    String? Function(String?)? validator,
    TextInputType? keyboard,
    bool optional = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      key: Key(id),
      controller: controller,
      keyboardType: keyboard,
      textInputAction: TextInputAction.next,
      validator: optional ? null : validator ?? AccountValidation.requiredName,
      decoration: InputDecoration(labelText: label),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final busy = AppScope.of(context).authBusy;
    return _AuthFrame(
      title: 'Join the green community',
      subtitle: 'Create your account and start recycling with EasyScrap.',
      child: Surface(
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Create an account',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              _AuthError(error, key: errorKey),
              const Text(
                'I am a',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              ...UserRole.values.map(
                (value) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: busy ? null : () => setState(() => role = value),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: role == value ? AppColors.mint : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: role == value
                              ? AppColors.green
                              : AppColors.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            value == UserRole.household
                                ? Icons.cottage_outlined
                                : Icons.local_shipping_outlined,
                            color: AppColors.green,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  value.label,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  value == UserRole.household
                                      ? 'Post scrap and book a pickup'
                                      : 'Find scrap and collect recyclables',
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            role == value
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            color: AppColors.green,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (role == UserRole.buyer)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Submit your buyer documents from Profile. An LGU admin must approve your application before you can send offers.',
                    style: TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                ),
              const SectionTitle('Personal information'),
              field('register-first', 'First name', first),
              field(
                'register-middle',
                'Middle name (optional)',
                middle,
                optional: true,
              ),
              field('register-last', 'Last name', last),
              field(
                'register-suffix',
                'Suffix (optional)',
                suffix,
                optional: true,
              ),
              field(
                'register-contact',
                'Contact number',
                contact,
                keyboard: TextInputType.phone,
                validator: AccountValidation.contact,
              ),
              const SectionTitle('Your location'),
              const Surface(
                padding: EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      color: AppColors.green,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Central Visayas (Region VII) · Bohol',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.darkGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              BoholLocationFields(onChanged: (value) => address = value),
              const SizedBox(height: 16),
              field('register-street', 'Street / Purok', street),
              const SectionTitle('Account details'),
              field(
                'register-username',
                'Username',
                username,
                validator: AccountValidation.username,
              ),
              field(
                'register-email',
                'Email address',
                email,
                keyboard: TextInputType.emailAddress,
                validator: AccountValidation.email,
              ),
              _PasswordField(
                key: const Key('register-password'),
                controller: password,
                newPassword: true,
                validator: AccountValidation.password,
              ),
              const SizedBox(height: 16),
              _PasswordField(
                key: const Key('register-confirmation'),
                label: 'Confirm password',
                controller: confirmation,
                newPassword: true,
                validator: (value) => value == null || value.isEmpty
                    ? 'Confirm your password.'
                    : value != password.text
                    ? 'Passwords do not match.'
                    : null,
                onSubmit: submit,
              ),
              const SizedBox(height: 22),
              FilledButton(
                key: const Key('register-submit'),
                onPressed: busy ? null : submit,
                child: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Create account'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: busy ? null : widget.onLogin,
                child: const Text('Already have an account? Log in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
