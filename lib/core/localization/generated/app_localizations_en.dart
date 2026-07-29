// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'İndirimGo';

  @override
  String get brandLatin => 'İndirimGo';

  @override
  String get loginEyebrow => 'SHOP WITH CONFIDENCE';

  @override
  String get loginTitle => 'Welcome back';

  @override
  String get loginSubtitle => 'Sign in to your customer account to continue.';

  @override
  String get usernameLabel => 'Username';

  @override
  String get usernameHint => 'Enter your username';

  @override
  String get passwordLabel => 'Password';

  @override
  String get passwordHint => 'Enter your password';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get loginAction => 'Sign in';

  @override
  String get loggingIn => 'Signing in';

  @override
  String get usernameRequired => 'Username is required.';

  @override
  String get passwordRequired => 'Password is required.';

  @override
  String get languageAction => 'العربية';

  @override
  String get secureLoginNote => 'Secure connection to your İndirimGo account';

  @override
  String get twoFactorTitle => 'Two-step verification';

  @override
  String get twoFactorSubtitle =>
      'Enter the 6-digit code from your authenticator app.';

  @override
  String get authenticatorInstructions =>
      'Enter the 6-digit code from your authenticator app.';

  @override
  String get recoveryInstructions => 'Enter one of your saved recovery codes.';

  @override
  String get authenticatorMode => 'Authenticator';

  @override
  String get recoveryMode => 'Recovery code';

  @override
  String get authenticatorCodeLabel => 'Authenticator code';

  @override
  String get authenticatorCodeHint => '000000';

  @override
  String get recoveryCodeLabel => 'Recovery code';

  @override
  String get recoveryCodeHint => 'Enter your recovery code';

  @override
  String get codeRequired => 'Enter your authenticator code.';

  @override
  String get codeSixDigits => 'The code must contain 6 digits.';

  @override
  String get recoveryCodeRequired => 'Enter your recovery code.';

  @override
  String get invalidFieldValue => 'Check this value and try again.';

  @override
  String get verifyAction => 'Verify';

  @override
  String get verifying => 'Verifying';

  @override
  String get backToLogin => 'Back to sign in';

  @override
  String get challengeExpired =>
      'This verification attempt expired. Return and sign in again.';

  @override
  String get startupTitle => 'Checking your session';

  @override
  String get startupSubtitle => 'One moment, please.';

  @override
  String get offlineTitle => 'We could not verify your session';

  @override
  String get offlineSubtitle =>
      'Your sign-in is still saved. Check your connection and try again.';

  @override
  String get serverVerificationTitle =>
      'The service is temporarily unavailable';

  @override
  String get serverVerificationSubtitle =>
      'Your sign-in is still saved. Try again later.';

  @override
  String get storageVerificationTitle =>
      'Secure sign-in storage is unavailable';

  @override
  String get storageVerificationSubtitle =>
      'Restart the app and try again. You may need to sign in again.';

  @override
  String get sessionVerificationTitle => 'We could not verify your session';

  @override
  String get sessionVerificationSubtitle =>
      'Your sign-in is still saved. Try again.';

  @override
  String get retryAction => 'Try again';

  @override
  String get homeTitle => 'Home';

  @override
  String get homePlaceholder => 'The foundation is ready';

  @override
  String get homePlaceholderBody =>
      'Shopping features will arrive in later milestones.';

  @override
  String get accountTitle => 'Account';

  @override
  String welcomeUser(String name) {
    return 'Welcome, $name';
  }

  @override
  String usernameValue(String username) {
    return 'Username: $username';
  }

  @override
  String emailValue(String email) {
    return 'Email: $email';
  }

  @override
  String get logoutAction => 'Sign out';

  @override
  String get loggingOut => 'Signing out';

  @override
  String get sessionFailure =>
      'The operation could not be completed. Try again.';

  @override
  String get networkError =>
      'Could not reach the server. Check your connection.';

  @override
  String get serverError =>
      'The service is temporarily unavailable. Try again later.';

  @override
  String get invalidCredentials => 'The username or password is incorrect.';

  @override
  String get accountInactive => 'This account is inactive. Contact support.';

  @override
  String get accountBlocked => 'This account is blocked. Contact support.';

  @override
  String get customerRoleRequired =>
      'This account cannot use the customer app.';

  @override
  String get invalidTwoFactorCode => 'The authenticator code is invalid.';

  @override
  String get invalidRecoveryCode => 'The recovery code is invalid.';

  @override
  String get twoFactorAttemptsExceeded =>
      'Too many verification attempts. Sign in again.';

  @override
  String get tooManyRequests => 'Too many attempts. Wait and try again.';

  @override
  String rateLimitSeconds(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'Try again in $seconds seconds.',
      one: 'Try again in 1 second.',
      zero: 'Try again now.',
    );
    return '$_temp0';
  }

  @override
  String get unauthenticated => 'Your session ended. Sign in again.';

  @override
  String get configurationErrorTitle => 'App configuration is incomplete';

  @override
  String get configurationErrorBody => 'Run the app with a valid API_BASE_URL.';

  @override
  String get dismissError => 'Dismiss alert';

  @override
  String get errorAnnouncement => 'Error';
}
