// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'إندريم غو';

  @override
  String get brandLatin => 'İndirimGo';

  @override
  String get loginEyebrow => 'تسوّق بثقة';

  @override
  String get loginTitle => 'أهلاً بعودتك';

  @override
  String get loginSubtitle => 'سجّل الدخول إلى حساب العميل للمتابعة.';

  @override
  String get usernameLabel => 'اسم المستخدم';

  @override
  String get usernameHint => 'أدخل اسم المستخدم';

  @override
  String get passwordLabel => 'كلمة المرور';

  @override
  String get passwordHint => 'أدخل كلمة المرور';

  @override
  String get showPassword => 'إظهار كلمة المرور';

  @override
  String get hidePassword => 'إخفاء كلمة المرور';

  @override
  String get loginAction => 'تسجيل الدخول';

  @override
  String get loggingIn => 'جارٍ تسجيل الدخول';

  @override
  String get usernameRequired => 'اسم المستخدم مطلوب.';

  @override
  String get passwordRequired => 'كلمة المرور مطلوبة.';

  @override
  String get languageAction => 'English';

  @override
  String get secureLoginNote => 'اتصال آمن بحساب إندريم غو';

  @override
  String get twoFactorTitle => 'التحقق بخطوتين';

  @override
  String get twoFactorSubtitle => 'أدخل رمز تطبيق المصادقة المكوّن من 6 أرقام.';

  @override
  String get authenticatorMode => 'رمز المصادقة';

  @override
  String get recoveryMode => 'رمز الاسترداد';

  @override
  String get authenticatorCodeLabel => 'رمز المصادقة';

  @override
  String get authenticatorCodeHint => '000000';

  @override
  String get recoveryCodeLabel => 'رمز الاسترداد';

  @override
  String get recoveryCodeHint => 'أدخل رمز الاسترداد';

  @override
  String get codeRequired => 'أدخل رمز المصادقة.';

  @override
  String get codeSixDigits => 'يجب أن يتكوّن الرمز من 6 أرقام.';

  @override
  String get recoveryCodeRequired => 'أدخل رمز الاسترداد.';

  @override
  String get verifyAction => 'تحقق';

  @override
  String get verifying => 'جارٍ التحقق';

  @override
  String get backToLogin => 'العودة إلى تسجيل الدخول';

  @override
  String get challengeExpired =>
      'انتهت صلاحية محاولة التحقق. ارجع وسجّل الدخول مجدداً.';

  @override
  String get startupTitle => 'جارٍ التحقق من جلستك';

  @override
  String get startupSubtitle => 'لحظة واحدة من فضلك.';

  @override
  String get offlineTitle => 'تعذّر التحقق من الجلسة';

  @override
  String get offlineSubtitle =>
      'احتفظنا بتسجيل دخولك. تحقق من الاتصال ثم حاول مرة أخرى.';

  @override
  String get retryAction => 'إعادة المحاولة';

  @override
  String get homeTitle => 'الرئيسية';

  @override
  String get homePlaceholder => 'الأساس جاهز';

  @override
  String get homePlaceholderBody => 'ستُضاف مزايا التسوق في مراحل لاحقة.';

  @override
  String get accountTitle => 'الحساب';

  @override
  String welcomeUser(String name) {
    return 'مرحباً، $name';
  }

  @override
  String usernameValue(String username) {
    return 'اسم المستخدم: $username';
  }

  @override
  String emailValue(String email) {
    return 'البريد الإلكتروني: $email';
  }

  @override
  String get logoutAction => 'تسجيل الخروج';

  @override
  String get loggingOut => 'جارٍ تسجيل الخروج';

  @override
  String get sessionFailure => 'تعذّر إكمال العملية. حاول مرة أخرى.';

  @override
  String get networkError => 'تعذّر الاتصال بالخادم. تحقق من الإنترنت.';

  @override
  String get serverError => 'الخدمة غير متاحة مؤقتاً. حاول لاحقاً.';

  @override
  String get invalidCredentials => 'اسم المستخدم أو كلمة المرور غير صحيحة.';

  @override
  String get accountInactive => 'الحساب غير نشط. يرجى التواصل مع الدعم.';

  @override
  String get accountBlocked => 'الحساب محظور. يرجى التواصل مع الدعم.';

  @override
  String get customerRoleRequired => 'هذا الحساب غير متاح في تطبيق العملاء.';

  @override
  String get invalidTwoFactorCode => 'رمز المصادقة غير صحيح.';

  @override
  String get invalidRecoveryCode => 'رمز الاسترداد غير صحيح.';

  @override
  String get twoFactorAttemptsExceeded =>
      'تم تجاوز عدد المحاولات. سجّل الدخول مجدداً.';

  @override
  String get tooManyRequests => 'محاولات كثيرة. انتظر قليلاً ثم حاول مجدداً.';

  @override
  String rateLimitSeconds(int seconds) {
    return 'حاول مجدداً بعد $seconds ثانية.';
  }

  @override
  String get unauthenticated => 'انتهت الجلسة. سجّل الدخول مجدداً.';

  @override
  String get configurationErrorTitle => 'إعداد التطبيق غير مكتمل';

  @override
  String get configurationErrorBody =>
      'يجب تشغيل التطبيق مع API_BASE_URL صالح.';

  @override
  String get dismissError => 'إغلاق التنبيه';

  @override
  String get errorAnnouncement => 'خطأ';
}
