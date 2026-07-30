import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appName.
  ///
  /// In ar, this message translates to:
  /// **'إندريم غو'**
  String get appName;

  /// No description provided for @brandLatin.
  ///
  /// In ar, this message translates to:
  /// **'İndirimGo'**
  String get brandLatin;

  /// No description provided for @loginEyebrow.
  ///
  /// In ar, this message translates to:
  /// **'تسوّق بثقة'**
  String get loginEyebrow;

  /// No description provided for @loginTitle.
  ///
  /// In ar, this message translates to:
  /// **'أهلاً بعودتك'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'سجّل الدخول إلى حساب العميل للمتابعة.'**
  String get loginSubtitle;

  /// No description provided for @usernameLabel.
  ///
  /// In ar, this message translates to:
  /// **'اسم المستخدم'**
  String get usernameLabel;

  /// No description provided for @usernameHint.
  ///
  /// In ar, this message translates to:
  /// **'أدخل اسم المستخدم'**
  String get usernameHint;

  /// No description provided for @passwordLabel.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور'**
  String get passwordLabel;

  /// No description provided for @passwordHint.
  ///
  /// In ar, this message translates to:
  /// **'أدخل كلمة المرور'**
  String get passwordHint;

  /// No description provided for @showPassword.
  ///
  /// In ar, this message translates to:
  /// **'إظهار كلمة المرور'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In ar, this message translates to:
  /// **'إخفاء كلمة المرور'**
  String get hidePassword;

  /// No description provided for @loginAction.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول'**
  String get loginAction;

  /// No description provided for @loggingIn.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ تسجيل الدخول'**
  String get loggingIn;

  /// No description provided for @usernameRequired.
  ///
  /// In ar, this message translates to:
  /// **'اسم المستخدم مطلوب.'**
  String get usernameRequired;

  /// No description provided for @passwordRequired.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور مطلوبة.'**
  String get passwordRequired;

  /// No description provided for @languageAction.
  ///
  /// In ar, this message translates to:
  /// **'English'**
  String get languageAction;

  /// No description provided for @secureLoginNote.
  ///
  /// In ar, this message translates to:
  /// **'اتصال آمن بحساب إندريم غو'**
  String get secureLoginNote;

  /// No description provided for @twoFactorTitle.
  ///
  /// In ar, this message translates to:
  /// **'التحقق بخطوتين'**
  String get twoFactorTitle;

  /// No description provided for @twoFactorSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'أدخل رمز تطبيق المصادقة المكوّن من 6 أرقام.'**
  String get twoFactorSubtitle;

  /// No description provided for @authenticatorInstructions.
  ///
  /// In ar, this message translates to:
  /// **'أدخل رمز تطبيق المصادقة المكوّن من 6 أرقام.'**
  String get authenticatorInstructions;

  /// No description provided for @recoveryInstructions.
  ///
  /// In ar, this message translates to:
  /// **'أدخل أحد رموز الاسترداد المحفوظة لديك.'**
  String get recoveryInstructions;

  /// No description provided for @authenticatorMode.
  ///
  /// In ar, this message translates to:
  /// **'رمز المصادقة'**
  String get authenticatorMode;

  /// No description provided for @recoveryMode.
  ///
  /// In ar, this message translates to:
  /// **'رمز الاسترداد'**
  String get recoveryMode;

  /// No description provided for @authenticatorCodeLabel.
  ///
  /// In ar, this message translates to:
  /// **'رمز المصادقة'**
  String get authenticatorCodeLabel;

  /// No description provided for @authenticatorCodeHint.
  ///
  /// In ar, this message translates to:
  /// **'000000'**
  String get authenticatorCodeHint;

  /// No description provided for @recoveryCodeLabel.
  ///
  /// In ar, this message translates to:
  /// **'رمز الاسترداد'**
  String get recoveryCodeLabel;

  /// No description provided for @recoveryCodeHint.
  ///
  /// In ar, this message translates to:
  /// **'أدخل رمز الاسترداد'**
  String get recoveryCodeHint;

  /// No description provided for @codeRequired.
  ///
  /// In ar, this message translates to:
  /// **'أدخل رمز المصادقة.'**
  String get codeRequired;

  /// No description provided for @codeSixDigits.
  ///
  /// In ar, this message translates to:
  /// **'يجب أن يتكوّن الرمز من 6 أرقام.'**
  String get codeSixDigits;

  /// No description provided for @recoveryCodeRequired.
  ///
  /// In ar, this message translates to:
  /// **'أدخل رمز الاسترداد.'**
  String get recoveryCodeRequired;

  /// No description provided for @invalidFieldValue.
  ///
  /// In ar, this message translates to:
  /// **'تحقق من هذه القيمة ثم حاول مجدداً.'**
  String get invalidFieldValue;

  /// No description provided for @verifyAction.
  ///
  /// In ar, this message translates to:
  /// **'تحقق'**
  String get verifyAction;

  /// No description provided for @verifying.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ التحقق'**
  String get verifying;

  /// No description provided for @backToLogin.
  ///
  /// In ar, this message translates to:
  /// **'العودة إلى تسجيل الدخول'**
  String get backToLogin;

  /// No description provided for @challengeExpired.
  ///
  /// In ar, this message translates to:
  /// **'انتهت صلاحية محاولة التحقق. ارجع وسجّل الدخول مجدداً.'**
  String get challengeExpired;

  /// No description provided for @startupTitle.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ التحقق من جلستك'**
  String get startupTitle;

  /// No description provided for @startupSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'لحظة واحدة من فضلك.'**
  String get startupSubtitle;

  /// No description provided for @offlineTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر التحقق من الجلسة'**
  String get offlineTitle;

  /// No description provided for @offlineSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'احتفظنا بتسجيل دخولك. تحقق من الاتصال ثم حاول مرة أخرى.'**
  String get offlineSubtitle;

  /// No description provided for @serverVerificationTitle.
  ///
  /// In ar, this message translates to:
  /// **'الخدمة غير متاحة مؤقتاً'**
  String get serverVerificationTitle;

  /// No description provided for @serverVerificationSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'احتفظنا بتسجيل دخولك. حاول مجدداً لاحقاً.'**
  String get serverVerificationSubtitle;

  /// No description provided for @storageVerificationTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الوصول إلى مخزن تسجيل الدخول الآمن'**
  String get storageVerificationTitle;

  /// No description provided for @storageVerificationSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'أعد تشغيل التطبيق وحاول مجدداً. قد تحتاج إلى تسجيل الدخول مرة أخرى.'**
  String get storageVerificationSubtitle;

  /// No description provided for @sessionVerificationTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر التحقق من جلستك'**
  String get sessionVerificationTitle;

  /// No description provided for @sessionVerificationSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'احتفظنا بتسجيل دخولك. حاول مجدداً.'**
  String get sessionVerificationSubtitle;

  /// No description provided for @retryAction.
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get retryAction;

  /// No description provided for @homeTitle.
  ///
  /// In ar, this message translates to:
  /// **'الرئيسية'**
  String get homeTitle;

  /// No description provided for @homeBrowseSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'استكشف الباقات وخيارات المنتجات والأسعار.'**
  String get homeBrowseSubtitle;

  /// No description provided for @homePlaceholder.
  ///
  /// In ar, this message translates to:
  /// **'الأساس جاهز'**
  String get homePlaceholder;

  /// No description provided for @homePlaceholderBody.
  ///
  /// In ar, this message translates to:
  /// **'ستُضاف مزايا التسوق في مراحل لاحقة.'**
  String get homePlaceholderBody;

  /// No description provided for @accountTitle.
  ///
  /// In ar, this message translates to:
  /// **'الحساب'**
  String get accountTitle;

  /// No description provided for @catalogLoading.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ تحميل الكتالوج'**
  String get catalogLoading;

  /// No description provided for @catalogUnavailableTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل الكتالوج'**
  String get catalogUnavailableTitle;

  /// No description provided for @catalogUnavailableBody.
  ///
  /// In ar, this message translates to:
  /// **'تحقق من الاتصال ثم حاول مجدداً. ما زلت مسجّل الدخول.'**
  String get catalogUnavailableBody;

  /// No description provided for @searchPackagesLabel.
  ///
  /// In ar, this message translates to:
  /// **'البحث في الباقات'**
  String get searchPackagesLabel;

  /// No description provided for @searchPackagesHint.
  ///
  /// In ar, this message translates to:
  /// **'ابحث عن باقة'**
  String get searchPackagesHint;

  /// No description provided for @clearSearch.
  ///
  /// In ar, this message translates to:
  /// **'مسح البحث'**
  String get clearSearch;

  /// No description provided for @browseAllPackages.
  ///
  /// In ar, this message translates to:
  /// **'تصفح كل الباقات'**
  String get browseAllPackages;

  /// No description provided for @frequentlyOrderedTitle.
  ///
  /// In ar, this message translates to:
  /// **'طلبتها كثيراً'**
  String get frequentlyOrderedTitle;

  /// No description provided for @featuredPackagesTitle.
  ///
  /// In ar, this message translates to:
  /// **'باقات مميزة'**
  String get featuredPackagesTitle;

  /// No description provided for @featuredPackagesEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد باقات مميزة حالياً.'**
  String get featuredPackagesEmpty;

  /// No description provided for @categoriesTitle.
  ///
  /// In ar, this message translates to:
  /// **'التصنيفات'**
  String get categoriesTitle;

  /// No description provided for @packagesTitle.
  ///
  /// In ar, this message translates to:
  /// **'الباقات'**
  String get packagesTitle;

  /// No description provided for @packagesEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد باقات'**
  String get packagesEmptyTitle;

  /// No description provided for @packagesEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'جرّب بحثاً أو تصنيفاً مختلفاً.'**
  String get packagesEmptyBody;

  /// No description provided for @loadMorePackages.
  ///
  /// In ar, this message translates to:
  /// **'تحميل المزيد'**
  String get loadMorePackages;

  /// No description provided for @categoryFilterActive.
  ///
  /// In ar, this message translates to:
  /// **'تصنيف محدّد'**
  String get categoryFilterActive;

  /// No description provided for @clearCategoryFilter.
  ///
  /// In ar, this message translates to:
  /// **'إزالة التصنيف'**
  String get clearCategoryFilter;

  /// No description provided for @categoryFilterInvalid.
  ///
  /// In ar, this message translates to:
  /// **'التصنيف غير صالح. اختر تصنيفاً آخر.'**
  String get categoryFilterInvalid;

  /// No description provided for @searchQueryInvalid.
  ///
  /// In ar, this message translates to:
  /// **'استعلام البحث غير صالح. استخدم حرفين على الأقل.'**
  String get searchQueryInvalid;

  /// No description provided for @packageDetailTitle.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل الباقة'**
  String get packageDetailTitle;

  /// No description provided for @packageNotFoundTitle.
  ///
  /// In ar, this message translates to:
  /// **'الباقة غير موجودة'**
  String get packageNotFoundTitle;

  /// No description provided for @packageNotFound.
  ///
  /// In ar, this message translates to:
  /// **'هذه الباقة غير متاحة.'**
  String get packageNotFound;

  /// No description provided for @backToPackages.
  ///
  /// In ar, this message translates to:
  /// **'العودة إلى الباقات'**
  String get backToPackages;

  /// No description provided for @productOptionsTitle.
  ///
  /// In ar, this message translates to:
  /// **'خيارات المنتجات'**
  String get productOptionsTitle;

  /// No description provided for @productOptionsEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد منتجات نشطة في هذه الباقة.'**
  String get productOptionsEmpty;

  /// No description provided for @fixedAmountMode.
  ///
  /// In ar, this message translates to:
  /// **'سعر ثابت'**
  String get fixedAmountMode;

  /// No description provided for @customAmountMode.
  ///
  /// In ar, this message translates to:
  /// **'مبلغ مخصص'**
  String get customAmountMode;

  /// No description provided for @fromPriceLabel.
  ///
  /// In ar, this message translates to:
  /// **'من'**
  String get fromPriceLabel;

  /// No description provided for @minimumPriceLabel.
  ///
  /// In ar, this message translates to:
  /// **'الحد الأدنى'**
  String get minimumPriceLabel;

  /// No description provided for @priceHidden.
  ///
  /// In ar, this message translates to:
  /// **'السعر غير ظاهر'**
  String get priceHidden;

  /// No description provided for @priceUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'السعر غير متاح'**
  String get priceUnavailable;

  /// No description provided for @priceFrom.
  ///
  /// In ar, this message translates to:
  /// **'من {price}'**
  String priceFrom(String price);

  /// No description provided for @customPriceCalculatedLater.
  ///
  /// In ar, this message translates to:
  /// **'يُحسب السعر النهائي لاحقاً بعد إدخال المبلغ.'**
  String get customPriceCalculatedLater;

  /// No description provided for @customAmountConfigUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'إعداد المبلغ المخصص غير مكتمل.'**
  String get customAmountConfigUnavailable;

  /// No description provided for @customAmountMin.
  ///
  /// In ar, this message translates to:
  /// **'الحد الأدنى: {value}'**
  String customAmountMin(int value);

  /// No description provided for @customAmountMax.
  ///
  /// In ar, this message translates to:
  /// **'الحد الأقصى: {value}'**
  String customAmountMax(int value);

  /// No description provided for @customAmountStep.
  ///
  /// In ar, this message translates to:
  /// **'الخطوة: {value}'**
  String customAmountStep(int value);

  /// No description provided for @customAmountUnit.
  ///
  /// In ar, this message translates to:
  /// **'الوحدة: {label}'**
  String customAmountUnit(String label);

  /// No description provided for @timesOrdered.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, zero {لم تُطلب} one {طُلبت مرة واحدة} two {طُلبت مرتين} few {طُلبت {count} مرات} many {طُلبت {count} مرة} other {طُلبت {count} مرة}}'**
  String timesOrdered(int count);

  /// No description provided for @welcomeUser.
  ///
  /// In ar, this message translates to:
  /// **'مرحباً، {name}'**
  String welcomeUser(String name);

  /// No description provided for @usernameValue.
  ///
  /// In ar, this message translates to:
  /// **'اسم المستخدم: {username}'**
  String usernameValue(String username);

  /// No description provided for @emailValue.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني: {email}'**
  String emailValue(String email);

  /// No description provided for @logoutAction.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج'**
  String get logoutAction;

  /// No description provided for @loggingOut.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ تسجيل الخروج'**
  String get loggingOut;

  /// No description provided for @sessionFailure.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر إكمال العملية. حاول مرة أخرى.'**
  String get sessionFailure;

  /// No description provided for @networkError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الاتصال بالخادم. تحقق من الإنترنت.'**
  String get networkError;

  /// No description provided for @serverError.
  ///
  /// In ar, this message translates to:
  /// **'الخدمة غير متاحة مؤقتاً. حاول لاحقاً.'**
  String get serverError;

  /// No description provided for @invalidCredentials.
  ///
  /// In ar, this message translates to:
  /// **'اسم المستخدم أو كلمة المرور غير صحيحة.'**
  String get invalidCredentials;

  /// No description provided for @accountInactive.
  ///
  /// In ar, this message translates to:
  /// **'الحساب غير نشط. يرجى التواصل مع الدعم.'**
  String get accountInactive;

  /// No description provided for @accountBlocked.
  ///
  /// In ar, this message translates to:
  /// **'الحساب محظور. يرجى التواصل مع الدعم.'**
  String get accountBlocked;

  /// No description provided for @customerRoleRequired.
  ///
  /// In ar, this message translates to:
  /// **'هذا الحساب غير متاح في تطبيق العملاء.'**
  String get customerRoleRequired;

  /// No description provided for @invalidTwoFactorCode.
  ///
  /// In ar, this message translates to:
  /// **'رمز المصادقة غير صحيح.'**
  String get invalidTwoFactorCode;

  /// No description provided for @invalidRecoveryCode.
  ///
  /// In ar, this message translates to:
  /// **'رمز الاسترداد غير صحيح.'**
  String get invalidRecoveryCode;

  /// No description provided for @twoFactorAttemptsExceeded.
  ///
  /// In ar, this message translates to:
  /// **'تم تجاوز عدد المحاولات. سجّل الدخول مجدداً.'**
  String get twoFactorAttemptsExceeded;

  /// No description provided for @tooManyRequests.
  ///
  /// In ar, this message translates to:
  /// **'محاولات كثيرة. انتظر قليلاً ثم حاول مجدداً.'**
  String get tooManyRequests;

  /// No description provided for @rateLimitSeconds.
  ///
  /// In ar, this message translates to:
  /// **'{seconds, plural, zero {يمكنك المحاولة الآن.} one {حاول مجدداً بعد ثانية واحدة.} two {حاول مجدداً بعد ثانيتين.} few {حاول مجدداً بعد {seconds} ثوانٍ.} many {حاول مجدداً بعد {seconds} ثانيةً.} other {حاول مجدداً بعد {seconds} ثانية.}}'**
  String rateLimitSeconds(int seconds);

  /// No description provided for @unauthenticated.
  ///
  /// In ar, this message translates to:
  /// **'انتهت الجلسة. سجّل الدخول مجدداً.'**
  String get unauthenticated;

  /// No description provided for @configurationErrorTitle.
  ///
  /// In ar, this message translates to:
  /// **'إعداد التطبيق غير مكتمل'**
  String get configurationErrorTitle;

  /// No description provided for @configurationErrorBody.
  ///
  /// In ar, this message translates to:
  /// **'يجب تشغيل التطبيق مع API_BASE_URL صالح.'**
  String get configurationErrorBody;

  /// No description provided for @dismissError.
  ///
  /// In ar, this message translates to:
  /// **'إغلاق التنبيه'**
  String get dismissError;

  /// No description provided for @errorAnnouncement.
  ///
  /// In ar, this message translates to:
  /// **'خطأ'**
  String get errorAnnouncement;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
