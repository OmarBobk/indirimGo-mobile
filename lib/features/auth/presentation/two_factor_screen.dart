import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:indirimgo_mobile/core/localization/generated/app_localizations.dart';
import 'package:indirimgo_mobile/core/theme/app_theme.dart';
import 'package:indirimgo_mobile/core/widgets/api_error_message.dart';
import 'package:indirimgo_mobile/features/auth/presentation/auth_controller.dart';

enum _TwoFactorMode { authenticator, recovery }

class TwoFactorScreen extends ConsumerStatefulWidget {
  const TwoFactorScreen({super.key});

  @override
  ConsumerState<TwoFactorScreen> createState() => _TwoFactorScreenState();
}

class _TwoFactorScreenState extends ConsumerState<TwoFactorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  _TwoFactorMode _mode = _TwoFactorMode.authenticator;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _switchMode(_TwoFactorMode mode) {
    if (_mode == mode) {
      return;
    }
    setState(() {
      _mode = mode;
      _controller.clear();
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    final notifier = ref.read(authControllerProvider.notifier);
    if (_mode == _TwoFactorMode.authenticator) {
      await notifier.completeTwoFactorWithAuthenticator(_controller.text);
    } else {
      await notifier.completeTwoFactorWithRecoveryCode(_controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = ref.watch(authControllerProvider);
    final isLoading =
        auth.phase == AuthPhase.submittingLogin && auth.challenge != null;
    final expired =
        auth.challengeExpired || (auth.challenge?.isExpired ?? true);
    final field = _mode == _TwoFactorMode.authenticator
        ? 'code'
        : 'recovery_code';
    final serverError = auth.fieldErrors[field]?.firstOrNull;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l10n.backToLogin,
          onPressed: isLoading
              ? null
              : ref.read(authControllerProvider.notifier).returnToLogin,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: SizedBox(
              width: 480,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: BrandColors.yellow,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.phonelink_lock_outlined,
                        color: BrandColors.ink,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      l10n.twoFactorTitle,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.twoFactorSubtitle,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SegmentedButton<_TwoFactorMode>(
                      key: const Key('two-factor-mode'),
                      segments: [
                        ButtonSegment(
                          value: _TwoFactorMode.authenticator,
                          icon: const Icon(Icons.password_outlined),
                          label: Text(l10n.authenticatorMode),
                        ),
                        ButtonSegment(
                          value: _TwoFactorMode.recovery,
                          icon: const Icon(Icons.key_outlined),
                          label: Text(l10n.recoveryMode),
                        ),
                      ],
                      selected: {_mode},
                      onSelectionChanged: isLoading || expired
                          ? null
                          : (selection) => _switchMode(selection.single),
                      showSelectedIcon: false,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (expired)
                      _TwoFactorNotice(
                        key: const Key('challenge-expired'),
                        message: l10n.challengeExpired,
                      )
                    else if (auth.error != null)
                      _TwoFactorNotice(
                        message: localizedApiError(l10n, auth.error),
                      ),
                    TextFormField(
                      key: ValueKey('${_mode.name}-field'),
                      controller: _controller,
                      enabled: !isLoading && !expired,
                      autofocus: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.done,
                      keyboardType: _mode == _TwoFactorMode.authenticator
                          ? TextInputType.number
                          : TextInputType.text,
                      inputFormatters: _mode == _TwoFactorMode.authenticator
                          ? [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ]
                          : [LengthLimitingTextInputFormatter(255)],
                      decoration: InputDecoration(
                        labelText: _mode == _TwoFactorMode.authenticator
                            ? l10n.authenticatorCodeLabel
                            : l10n.recoveryCodeLabel,
                        hintText: _mode == _TwoFactorMode.authenticator
                            ? l10n.authenticatorCodeHint
                            : l10n.recoveryCodeHint,
                        errorText: serverError,
                      ),
                      validator: (value) {
                        final entered = value?.trim() ?? '';
                        if (entered.isEmpty) {
                          return _mode == _TwoFactorMode.authenticator
                              ? l10n.codeRequired
                              : l10n.recoveryCodeRequired;
                        }
                        if (_mode == _TwoFactorMode.authenticator &&
                            !RegExp(r'^\d{6}$').hasMatch(entered)) {
                          return l10n.codeSixDigits;
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) =>
                          isLoading || expired ? null : _submit(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton(
                      key: const Key('verify-button'),
                      onPressed: isLoading || expired ? null : _submit,
                      child: isLoading
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: BrandColors.ink,
                              ),
                            )
                          : Text(l10n.verifyAction),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      key: const Key('return-to-login'),
                      onPressed: isLoading
                          ? null
                          : ref
                                .read(authControllerProvider.notifier)
                                .returnToLogin,
                      child: Text(l10n.backToLogin),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TwoFactorNotice extends StatelessWidget {
  const _TwoFactorNotice({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: colors.errorContainer,
          borderRadius: BorderRadius.circular(AppRadii.input),
        ),
        child: Text(message, style: TextStyle(color: colors.onErrorContainer)),
      ),
    );
  }
}
