import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:indirimgo_mobile/core/localization/generated/app_localizations.dart';
import 'package:indirimgo_mobile/core/localization/locale_controller.dart';
import 'package:indirimgo_mobile/core/theme/app_theme.dart';
import 'package:indirimgo_mobile/core/widgets/api_error_message.dart';
import 'package:indirimgo_mobile/features/auth/presentation/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    await ref.read(authControllerProvider.notifier).login(
      username: _usernameController.text,
      password: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = ref.watch(authControllerProvider);
    final isLoading = auth.phase == AuthPhase.submittingLogin;
    final usernameServerError = auth.fieldErrors['username']?.firstOrNull;
    final passwordServerError = auth.fieldErrors['password']?.firstOrNull;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - AppSpacing.md * 2,
                ),
                child: Center(
                  child: SizedBox(
                    width: 480,
                    child: AutofillGroup(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                const _BrandMark(),
                                const Spacer(),
                                TextButton.icon(
                                  key: const Key('language-toggle'),
                                  onPressed: isLoading
                                      ? null
                                      : ref
                                            .read(localeControllerProvider.notifier)
                                            .toggle,
                                  icon: const Icon(Icons.language, size: 19),
                                  label: Text(l10n.languageAction),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            Text(
                              l10n.loginEyebrow,
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: BrandColors.warning,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.4,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              l10n.loginTitle,
                              style: Theme.of(context).textTheme.displaySmall,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              l10n.loginSubtitle,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            if (auth.error != null)
                              _ErrorBanner(
                                message: localizedApiError(l10n, auth.error),
                              ),
                            TextFormField(
                              key: const Key('username-field'),
                              controller: _usernameController,
                              enabled: !isLoading,
                              autofillHints: const [AutofillHints.username],
                              textInputAction: TextInputAction.next,
                              keyboardType: TextInputType.text,
                              decoration: InputDecoration(
                                labelText: l10n.usernameLabel,
                                hintText: l10n.usernameHint,
                                prefixIcon: const Icon(Icons.person_outline),
                                errorText: usernameServerError,
                              ),
                              validator: (value) =>
                                  (value == null || value.trim().isEmpty)
                                  ? l10n.usernameRequired
                                  : null,
                              onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TextFormField(
                              key: const Key('password-field'),
                              controller: _passwordController,
                              focusNode: _passwordFocus,
                              enabled: !isLoading,
                              obscureText: _obscurePassword,
                              autofillHints: const [AutofillHints.password],
                              textInputAction: TextInputAction.done,
                              decoration: InputDecoration(
                                labelText: l10n.passwordLabel,
                                hintText: l10n.passwordHint,
                                prefixIcon: const Icon(Icons.lock_outline),
                                errorText: passwordServerError,
                                suffixIcon: Semantics(
                                  button: true,
                                  label: _obscurePassword
                                      ? l10n.showPassword
                                      : l10n.hidePassword,
                                  child: IconButton(
                                    key: const Key('password-visibility'),
                                    tooltip: _obscurePassword
                                        ? l10n.showPassword
                                        : l10n.hidePassword,
                                    onPressed: isLoading
                                        ? null
                                        : () => setState(
                                            () => _obscurePassword =
                                                !_obscurePassword,
                                          ),
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                              ),
                              validator: (value) => (value == null || value.isEmpty)
                                  ? l10n.passwordRequired
                                  : null,
                              onFieldSubmitted: (_) => isLoading ? null : _submit(),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            Semantics(
                              button: true,
                              label: isLoading ? l10n.loggingIn : l10n.loginAction,
                              child: FilledButton(
                                key: const Key('login-button'),
                                onPressed: isLoading ? null : _submit,
                                child: isLoading
                                    ? const SizedBox.square(
                                        dimension: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: BrandColors.ink,
                                        ),
                                      )
                                    : Text(l10n.loginAction),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.shield_outlined, size: 18),
                                const SizedBox(width: AppSpacing.xs),
                                Flexible(
                                  child: Text(
                                    l10n.secureLoginNote,
                                    style: Theme.of(context).textTheme.bodySmall,
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
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      header: true,
      label: l10n.appName,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          color: BrandColors.yellow,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(color: BrandColors.ink, width: 2),
          boxShadow: const [
            BoxShadow(color: BrandColors.ink, offset: Offset(3, 3)),
          ],
        ),
        child: Text(
          l10n.brandLatin,
          textDirection: TextDirection.ltr,
          style: const TextStyle(
            color: BrandColors.ink,
            fontWeight: FontWeight.w900,
            fontSize: 17,
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        key: const Key('error-banner'),
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(AppRadii.input),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
