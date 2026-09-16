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

  /// No description provided for @packagesCatalogEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد باقات بعد'**
  String get packagesCatalogEmptyTitle;

  /// No description provided for @packagesCatalogEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'لا تتوفر باقات للعرض حالياً.'**
  String get packagesCatalogEmptyBody;

  /// No description provided for @loadMorePackages.
  ///
  /// In ar, this message translates to:
  /// **'تحميل المزيد'**
  String get loadMorePackages;

  /// No description provided for @categoryFilterActive.
  ///
  /// In ar, this message translates to:
  /// **'تصفية حسب التصنيف'**
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

  /// No description provided for @buyNowAction.
  ///
  /// In ar, this message translates to:
  /// **'اشترِ الآن'**
  String get buyNowAction;

  /// No description provided for @buyNowTitle.
  ///
  /// In ar, this message translates to:
  /// **'اشترِ الآن'**
  String get buyNowTitle;

  /// No description provided for @purchaseDetailsTitle.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل الشراء'**
  String get purchaseDetailsTitle;

  /// No description provided for @requirementsTitle.
  ///
  /// In ar, this message translates to:
  /// **'البيانات المطلوبة'**
  String get requirementsTitle;

  /// No description provided for @quantityLabel.
  ///
  /// In ar, this message translates to:
  /// **'الكمية'**
  String get quantityLabel;

  /// No description provided for @quantityInvalid.
  ///
  /// In ar, this message translates to:
  /// **'أدخل كمية صحيحة لا تقل عن 1.'**
  String get quantityInvalid;

  /// No description provided for @quantityValue.
  ///
  /// In ar, this message translates to:
  /// **'الكمية: {quantity}'**
  String quantityValue(int quantity);

  /// No description provided for @requestedAmountLabel.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ {unit}'**
  String requestedAmountLabel(String unit);

  /// No description provided for @requestedAmountInvalid.
  ///
  /// In ar, this message translates to:
  /// **'أدخل مبلغاً صالحاً ضمن النطاق المسموح.'**
  String get requestedAmountInvalid;

  /// No description provided for @requestedAmountValue.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ: {amount}'**
  String requestedAmountValue(int amount);

  /// No description provided for @unitPriceLabel.
  ///
  /// In ar, this message translates to:
  /// **'سعر الوحدة'**
  String get unitPriceLabel;

  /// No description provided for @requirementRequired.
  ///
  /// In ar, this message translates to:
  /// **'هذا الحقل مطلوب.'**
  String get requirementRequired;

  /// No description provided for @continueToReviewAction.
  ///
  /// In ar, this message translates to:
  /// **'متابعة للمراجعة'**
  String get continueToReviewAction;

  /// No description provided for @quotingPurchase.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ تجهيز عرض السعر'**
  String get quotingPurchase;

  /// No description provided for @purchaseUnavailableTitle.
  ///
  /// In ar, this message translates to:
  /// **'الشراء غير متاح'**
  String get purchaseUnavailableTitle;

  /// No description provided for @purchaseUnavailableBody.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن شراء هذا المنتج حالياً.'**
  String get purchaseUnavailableBody;

  /// No description provided for @checkoutReviewTitle.
  ///
  /// In ar, this message translates to:
  /// **'مراجعة الشراء'**
  String get checkoutReviewTitle;

  /// No description provided for @quoteMissingBody.
  ///
  /// In ar, this message translates to:
  /// **'عرض السعر لم يعد متاحاً. ابدأ الشراء مجدداً.'**
  String get quoteMissingBody;

  /// No description provided for @orderTotalsTitle.
  ///
  /// In ar, this message translates to:
  /// **'الإجماليات'**
  String get orderTotalsTitle;

  /// No description provided for @lineTotalLabel.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي البند'**
  String get lineTotalLabel;

  /// No description provided for @finalTotalLabel.
  ///
  /// In ar, this message translates to:
  /// **'الإجمالي'**
  String get finalTotalLabel;

  /// No description provided for @walletSectionTitle.
  ///
  /// In ar, this message translates to:
  /// **'المحفظة'**
  String get walletSectionTitle;

  /// No description provided for @availableToSpendLabel.
  ///
  /// In ar, this message translates to:
  /// **'المتاح للإنفاق'**
  String get availableToSpendLabel;

  /// No description provided for @walletUnavailableBody.
  ///
  /// In ar, this message translates to:
  /// **'رصيد المحفظة غير متاح مؤقتاً.'**
  String get walletUnavailableBody;

  /// No description provided for @quoteExpiresAt.
  ///
  /// In ar, this message translates to:
  /// **'ينتهي عرض السعر في {timestamp}'**
  String quoteExpiresAt(String timestamp);

  /// No description provided for @confirmWalletChargeAction.
  ///
  /// In ar, this message translates to:
  /// **'ادفع من المحفظة'**
  String get confirmWalletChargeAction;

  /// No description provided for @confirmWalletChargeHint.
  ///
  /// In ar, this message translates to:
  /// **'سيتم خصم الإجمالي الظاهر أعلاه من محفظتك.'**
  String get confirmWalletChargeHint;

  /// No description provided for @submittingPurchase.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ معالجة الشراء'**
  String get submittingPurchase;

  /// No description provided for @refreshQuoteAction.
  ///
  /// In ar, this message translates to:
  /// **'تحديث عرض السعر'**
  String get refreshQuoteAction;

  /// No description provided for @priceChangedBody.
  ///
  /// In ar, this message translates to:
  /// **'تغير السعر أو تفاصيل الشراء. راجع الإجمالي المحدّث قبل الدفع.'**
  String get priceChangedBody;

  /// No description provided for @insufficientBalanceBody.
  ///
  /// In ar, this message translates to:
  /// **'رصيد محفظتك المتاح غير كافٍ لهذا الشراء.'**
  String get insufficientBalanceBody;

  /// No description provided for @checkoutRecoveryTitle.
  ///
  /// In ar, this message translates to:
  /// **'التحقق من الشراء'**
  String get checkoutRecoveryTitle;

  /// No description provided for @checkoutRecoveryIdleBody.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد شراء بانتظار الاسترداد.'**
  String get checkoutRecoveryIdleBody;

  /// No description provided for @checkoutRecoveryProcessingBody.
  ///
  /// In ar, this message translates to:
  /// **'نتحقق مما إذا اكتمل الشراء. يرجى الانتظار.'**
  String get checkoutRecoveryProcessingBody;

  /// No description provided for @checkoutFailedTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر إكمال الشراء'**
  String get checkoutFailedTitle;

  /// No description provided for @checkoutRetryRequiredTitle.
  ///
  /// In ar, this message translates to:
  /// **'يجب إعادة بدء الشراء'**
  String get checkoutRetryRequiredTitle;

  /// No description provided for @checkoutRetryRequiredBody.
  ///
  /// In ar, this message translates to:
  /// **'لم يكتمل هذا الشراء. ابدأ مجدداً من صفحة المنتج.'**
  String get checkoutRetryRequiredBody;

  /// No description provided for @checkoutAttemptNotFoundBody.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد شراء معلّق لهذا الحساب.'**
  String get checkoutAttemptNotFoundBody;

  /// No description provided for @purchaseSuccessTitle.
  ///
  /// In ar, this message translates to:
  /// **'تم الشراء بنجاح'**
  String get purchaseSuccessTitle;

  /// No description provided for @purchaseSuccessBody.
  ///
  /// In ar, this message translates to:
  /// **'اكتمل الدفع من المحفظة.'**
  String get purchaseSuccessBody;

  /// No description provided for @viewReceiptAction.
  ///
  /// In ar, this message translates to:
  /// **'عرض الإيصال'**
  String get viewReceiptAction;

  /// No description provided for @receiptTitle.
  ///
  /// In ar, this message translates to:
  /// **'الإيصال'**
  String get receiptTitle;

  /// No description provided for @loadingReceipt.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ تحميل الإيصال'**
  String get loadingReceipt;

  /// No description provided for @receiptItemsTitle.
  ///
  /// In ar, this message translates to:
  /// **'العناصر'**
  String get receiptItemsTitle;

  /// No description provided for @orderNumberLabel.
  ///
  /// In ar, this message translates to:
  /// **'الطلب {orderNumber}'**
  String orderNumberLabel(String orderNumber);

  /// No description provided for @paymentStatusLabel.
  ///
  /// In ar, this message translates to:
  /// **'حالة الدفع: {status}'**
  String paymentStatusLabel(String status);

  /// No description provided for @orderNotFoundTitle.
  ///
  /// In ar, this message translates to:
  /// **'الطلب غير موجود'**
  String get orderNotFoundTitle;

  /// No description provided for @orderNotFoundBody.
  ///
  /// In ar, this message translates to:
  /// **'هذا الطلب غير متاح لحسابك.'**
  String get orderNotFoundBody;

  /// No description provided for @backToHomeAction.
  ///
  /// In ar, this message translates to:
  /// **'العودة إلى الرئيسية'**
  String get backToHomeAction;

  /// No description provided for @purchasingUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'الشراء غير متاح مؤقتاً.'**
  String get purchasingUnavailable;

  /// No description provided for @productUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'هذا المنتج غير متاح.'**
  String get productUnavailable;

  /// No description provided for @invalidCustomAmount.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ المخصص غير صالح.'**
  String get invalidCustomAmount;

  /// No description provided for @priceChanged.
  ///
  /// In ar, this message translates to:
  /// **'تغير السعر. راجع عرض السعر المحدّث.'**
  String get priceChanged;

  /// No description provided for @insufficientWalletBalance.
  ///
  /// In ar, this message translates to:
  /// **'رصيد المحفظة غير كافٍ.'**
  String get insufficientWalletBalance;

  /// No description provided for @idempotencyConflict.
  ///
  /// In ar, this message translates to:
  /// **'تتعارض محاولة الشراء مع طلب آخر. جارٍ التحقق من الحالة.'**
  String get idempotencyConflict;

  /// No description provided for @checkoutInProgress.
  ///
  /// In ar, this message translates to:
  /// **'لا يزال هذا الشراء قيد المعالجة.'**
  String get checkoutInProgress;

  /// No description provided for @checkoutRetryRequired.
  ///
  /// In ar, this message translates to:
  /// **'يجب إعادة محاولة هذا الشراء بحذر. ابدأ مجدداً إذا لزم الأمر.'**
  String get checkoutRetryRequired;

  /// No description provided for @checkoutFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشل الشراء. لم يتم اتخاذ إجراء إضافي.'**
  String get checkoutFailed;

  /// No description provided for @orderNotFound.
  ///
  /// In ar, this message translates to:
  /// **'الطلب غير موجود.'**
  String get orderNotFound;

  /// No description provided for @ordersTitle.
  ///
  /// In ar, this message translates to:
  /// **'الطلبات'**
  String get ordersTitle;

  /// No description provided for @ordersLoading.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ تحميل الطلبات'**
  String get ordersLoading;

  /// No description provided for @ordersUnavailableTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل الطلبات'**
  String get ordersUnavailableTitle;

  /// No description provided for @ordersEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد طلبات بعد'**
  String get ordersEmptyTitle;

  /// No description provided for @ordersEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'ستظهر مشترياتك المكتملة هنا.'**
  String get ordersEmptyBody;

  /// No description provided for @loadMoreOrders.
  ///
  /// In ar, this message translates to:
  /// **'تحميل المزيد من الطلبات'**
  String get loadMoreOrders;

  /// No description provided for @ordersLoadingMore.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ تحميل المزيد من الطلبات'**
  String get ordersLoadingMore;

  /// No description provided for @refreshingOrders.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ تحديث الطلبات'**
  String get refreshingOrders;

  /// No description provided for @orderTitleFallback.
  ///
  /// In ar, this message translates to:
  /// **'طلب'**
  String get orderTitleFallback;

  /// No description provided for @orderCardSemantics.
  ///
  /// In ar, this message translates to:
  /// **'{title}، الطلب {orderNumber}، أُنشئ في {date}، الإجمالي {total}، الحالة {state}، عدد العناصر {itemCount}'**
  String orderCardSemantics(
    String title,
    String orderNumber,
    String date,
    String total,
    String state,
    int itemCount,
  );

  /// No description provided for @orderCreatedLabel.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ الإنشاء: {date}'**
  String orderCreatedLabel(String date);

  /// No description provided for @orderPaidLabel.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ الدفع: {date}'**
  String orderPaidLabel(String date);

  /// No description provided for @customerStateLabel.
  ///
  /// In ar, this message translates to:
  /// **'الحالة: {state}'**
  String customerStateLabel(String state);

  /// No description provided for @orderItemCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, zero {لا عناصر} one {عنصر واحد} two {عنصران} few {{count} عناصر} many {{count} عنصراً} other {{count} عنصر}}'**
  String orderItemCount(int count);

  /// No description provided for @orderDetailTitle.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل الطلب'**
  String get orderDetailTitle;

  /// No description provided for @refreshOrderAction.
  ///
  /// In ar, this message translates to:
  /// **'تحديث الطلب'**
  String get refreshOrderAction;

  /// No description provided for @loadingOrderDetail.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ تحميل تفاصيل الطلب'**
  String get loadingOrderDetail;

  /// No description provided for @orderStatusRefreshing.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ تحديث حالة الطلب'**
  String get orderStatusRefreshing;

  /// No description provided for @orderPollingEnded.
  ///
  /// In ar, this message translates to:
  /// **'توقفت التحديثات التلقائية. حدّث للتحقق مجدداً.'**
  String get orderPollingEnded;

  /// No description provided for @orderNumberHeading.
  ///
  /// In ar, this message translates to:
  /// **'رقم الطلب'**
  String get orderNumberHeading;

  /// No description provided for @orderStatusSection.
  ///
  /// In ar, this message translates to:
  /// **'الحالة'**
  String get orderStatusSection;

  /// No description provided for @paymentLabel.
  ///
  /// In ar, this message translates to:
  /// **'الدفع'**
  String get paymentLabel;

  /// No description provided for @fulfillmentLabel.
  ///
  /// In ar, this message translates to:
  /// **'التنفيذ'**
  String get fulfillmentLabel;

  /// No description provided for @fulfillmentSummaryTitle.
  ///
  /// In ar, this message translates to:
  /// **'ملخص التنفيذ'**
  String get fulfillmentSummaryTitle;

  /// No description provided for @fulfillmentSummaryTotal.
  ///
  /// In ar, this message translates to:
  /// **'الإجمالي'**
  String get fulfillmentSummaryTotal;

  /// No description provided for @fulfillmentSummaryCount.
  ///
  /// In ar, this message translates to:
  /// **'{label}: {count}'**
  String fulfillmentSummaryCount(String label, int count);

  /// No description provided for @paymentStatusPaid.
  ///
  /// In ar, this message translates to:
  /// **'مدفوع'**
  String get paymentStatusPaid;

  /// No description provided for @paymentStatusPending.
  ///
  /// In ar, this message translates to:
  /// **'بانتظار الدفع'**
  String get paymentStatusPending;

  /// No description provided for @paymentStatusProcessing.
  ///
  /// In ar, this message translates to:
  /// **'الدفع قيد المعالجة'**
  String get paymentStatusProcessing;

  /// No description provided for @paymentStatusFulfilled.
  ///
  /// In ar, this message translates to:
  /// **'مدفوع'**
  String get paymentStatusFulfilled;

  /// No description provided for @paymentStatusFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشل الدفع'**
  String get paymentStatusFailed;

  /// No description provided for @paymentStatusRefunded.
  ///
  /// In ar, this message translates to:
  /// **'مسترد'**
  String get paymentStatusRefunded;

  /// No description provided for @paymentStatusCancelled.
  ///
  /// In ar, this message translates to:
  /// **'أُلغي الدفع'**
  String get paymentStatusCancelled;

  /// No description provided for @fulfillmentStatusPending.
  ///
  /// In ar, this message translates to:
  /// **'قيد الانتظار'**
  String get fulfillmentStatusPending;

  /// No description provided for @fulfillmentStatusQueued.
  ///
  /// In ar, this message translates to:
  /// **'في قائمة الانتظار'**
  String get fulfillmentStatusQueued;

  /// No description provided for @fulfillmentStatusProcessing.
  ///
  /// In ar, this message translates to:
  /// **'قيد التنفيذ'**
  String get fulfillmentStatusProcessing;

  /// No description provided for @fulfillmentStatusCompleted.
  ///
  /// In ar, this message translates to:
  /// **'مكتمل'**
  String get fulfillmentStatusCompleted;

  /// No description provided for @fulfillmentStatusFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشل'**
  String get fulfillmentStatusFailed;

  /// No description provided for @fulfillmentStatusCancelled.
  ///
  /// In ar, this message translates to:
  /// **'ملغى'**
  String get fulfillmentStatusCancelled;

  /// No description provided for @customerStateNeedsAttention.
  ///
  /// In ar, this message translates to:
  /// **'يتطلب انتباهاً'**
  String get customerStateNeedsAttention;

  /// No description provided for @customerStateInProgress.
  ///
  /// In ar, this message translates to:
  /// **'قيد التنفيذ'**
  String get customerStateInProgress;

  /// No description provided for @customerStateDelivered.
  ///
  /// In ar, this message translates to:
  /// **'تم التسليم'**
  String get customerStateDelivered;

  /// No description provided for @customerStateRefunded.
  ///
  /// In ar, this message translates to:
  /// **'مسترد'**
  String get customerStateRefunded;

  /// No description provided for @statusOther.
  ///
  /// In ar, this message translates to:
  /// **'أخرى'**
  String get statusOther;

  /// No description provided for @navHome.
  ///
  /// In ar, this message translates to:
  /// **'الرئيسية'**
  String get navHome;

  /// No description provided for @navPackages.
  ///
  /// In ar, this message translates to:
  /// **'الباقات'**
  String get navPackages;

  /// No description provided for @navOrders.
  ///
  /// In ar, this message translates to:
  /// **'الطلبات'**
  String get navOrders;

  /// No description provided for @navAccount.
  ///
  /// In ar, this message translates to:
  /// **'الحساب'**
  String get navAccount;

  /// No description provided for @languagePreferenceTitle.
  ///
  /// In ar, this message translates to:
  /// **'اللغة'**
  String get languagePreferenceTitle;

  /// No description provided for @languagePreferenceSystem.
  ///
  /// In ar, this message translates to:
  /// **'لغة الجهاز'**
  String get languagePreferenceSystem;

  /// No description provided for @languagePreferenceArabic.
  ///
  /// In ar, this message translates to:
  /// **'العربية'**
  String get languagePreferenceArabic;

  /// No description provided for @languagePreferenceEnglish.
  ///
  /// In ar, this message translates to:
  /// **'English'**
  String get languagePreferenceEnglish;

  /// No description provided for @searchOrdersLabel.
  ///
  /// In ar, this message translates to:
  /// **'البحث في الطلبات'**
  String get searchOrdersLabel;

  /// No description provided for @searchOrdersHint.
  ///
  /// In ar, this message translates to:
  /// **'رقم الطلب أو اسم العنصر'**
  String get searchOrdersHint;

  /// No description provided for @ordersSearchTooShort.
  ///
  /// In ar, this message translates to:
  /// **'أدخل حرفين على الأقل للبحث.'**
  String get ordersSearchTooShort;

  /// No description provided for @ordersNoMatchesTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد طلبات مطابقة'**
  String get ordersNoMatchesTitle;

  /// No description provided for @ordersNoMatchesBody.
  ///
  /// In ar, this message translates to:
  /// **'جرّب رقم طلب أو اسم عنصر أو حالة مختلفة.'**
  String get ordersNoMatchesBody;

  /// No description provided for @filterAll.
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get filterAll;

  /// No description provided for @filterNeedsAttention.
  ///
  /// In ar, this message translates to:
  /// **'يتطلب انتباهاً'**
  String get filterNeedsAttention;

  /// No description provided for @filterInProgress.
  ///
  /// In ar, this message translates to:
  /// **'قيد التنفيذ'**
  String get filterInProgress;

  /// No description provided for @filterDelivered.
  ///
  /// In ar, this message translates to:
  /// **'تم التسليم'**
  String get filterDelivered;

  /// No description provided for @filterRefunded.
  ///
  /// In ar, this message translates to:
  /// **'مسترد'**
  String get filterRefunded;

  /// No description provided for @customerStateBadgeSemantics.
  ///
  /// In ar, this message translates to:
  /// **'حالة الطلب: {state}'**
  String customerStateBadgeSemantics(String state);

  /// No description provided for @receiptDoneAction.
  ///
  /// In ar, this message translates to:
  /// **'تم'**
  String get receiptDoneAction;

  /// No description provided for @packageImageLabel.
  ///
  /// In ar, this message translates to:
  /// **'صورة الباقة'**
  String get packageImageLabel;

  /// No description provided for @categoryImageLabel.
  ///
  /// In ar, this message translates to:
  /// **'صورة التصنيف'**
  String get categoryImageLabel;

  /// No description provided for @imageUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر عرض الصورة'**
  String get imageUnavailable;

  /// No description provided for @openWalletAction.
  ///
  /// In ar, this message translates to:
  /// **'فتح المحفظة'**
  String get openWalletAction;

  /// No description provided for @walletTitle.
  ///
  /// In ar, this message translates to:
  /// **'المحفظة'**
  String get walletTitle;

  /// No description provided for @walletLoading.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ تحميل المحفظة'**
  String get walletLoading;

  /// No description provided for @walletRefreshing.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ تحديث المحفظة'**
  String get walletRefreshing;

  /// No description provided for @addFundsAction.
  ///
  /// In ar, this message translates to:
  /// **'إضافة رصيد'**
  String get addFundsAction;

  /// No description provided for @pendingTopupBanner.
  ///
  /// In ar, this message translates to:
  /// **'طلب شحن بانتظار موافقة الموظفين. لم يُضف الرصيد بعد.'**
  String get pendingTopupBanner;

  /// No description provided for @viewPendingTopupAction.
  ///
  /// In ar, this message translates to:
  /// **'عرض طلب الشحن المعلّق'**
  String get viewPendingTopupAction;

  /// No description provided for @transactionsTitle.
  ///
  /// In ar, this message translates to:
  /// **'النشاط'**
  String get transactionsTitle;

  /// No description provided for @transactionsEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد نشاط في المحفظة بعد'**
  String get transactionsEmptyTitle;

  /// No description provided for @transactionsEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'ستظهر هنا المشتريات وطلبات الشحن المعتمدة والأنشطة الأخرى.'**
  String get transactionsEmptyBody;

  /// No description provided for @loadMoreTransactions.
  ///
  /// In ar, this message translates to:
  /// **'تحميل المزيد من النشاط'**
  String get loadMoreTransactions;

  /// No description provided for @topupsTitle.
  ///
  /// In ar, this message translates to:
  /// **'طلبات الشحن'**
  String get topupsTitle;

  /// No description provided for @topupsEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد طلبات شحن بعد'**
  String get topupsEmptyTitle;

  /// No description provided for @topupsEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'تبقى طلبات الشحن اليدوي معلّقة حتى موافقة الموظفين.'**
  String get topupsEmptyBody;

  /// No description provided for @loadMoreTopups.
  ///
  /// In ar, this message translates to:
  /// **'تحميل المزيد من طلبات الشحن'**
  String get loadMoreTopups;

  /// No description provided for @topupFormTitle.
  ///
  /// In ar, this message translates to:
  /// **'إضافة رصيد'**
  String get topupFormTitle;

  /// No description provided for @topupAmountLabel.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ'**
  String get topupAmountLabel;

  /// No description provided for @topupAmountHint.
  ///
  /// In ar, this message translates to:
  /// **'0.00'**
  String get topupAmountHint;

  /// No description provided for @topupCurrencyLabel.
  ///
  /// In ar, this message translates to:
  /// **'العملة'**
  String get topupCurrencyLabel;

  /// No description provided for @topupCurrencyUsd.
  ///
  /// In ar, this message translates to:
  /// **'USD'**
  String get topupCurrencyUsd;

  /// No description provided for @topupCurrencyTry.
  ///
  /// In ar, this message translates to:
  /// **'TRY'**
  String get topupCurrencyTry;

  /// No description provided for @topupCurrencyHelp.
  ///
  /// In ar, this message translates to:
  /// **'أدخل المبلغ الذي سترسله. لا تحوّله بنفسك.'**
  String get topupCurrencyHelp;

  /// No description provided for @paymentMethodLabel.
  ///
  /// In ar, this message translates to:
  /// **'طريقة الدفع'**
  String get paymentMethodLabel;

  /// No description provided for @paymentInstructionsTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعليمات الدفع'**
  String get paymentInstructionsTitle;

  /// No description provided for @attachProofLabel.
  ///
  /// In ar, this message translates to:
  /// **'إرفاق إثبات (اختياري)'**
  String get attachProofLabel;

  /// No description provided for @chooseProofAction.
  ///
  /// In ar, this message translates to:
  /// **'اختيار ملف'**
  String get chooseProofAction;

  /// No description provided for @removeProofAction.
  ///
  /// In ar, this message translates to:
  /// **'إزالة الإثبات'**
  String get removeProofAction;

  /// No description provided for @proofSelectedLabel.
  ///
  /// In ar, this message translates to:
  /// **'المحدد: {filename}'**
  String proofSelectedLabel(String filename);

  /// No description provided for @submitTopupAction.
  ///
  /// In ar, this message translates to:
  /// **'إرسال طلب الشحن'**
  String get submitTopupAction;

  /// No description provided for @submittingTopup.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ إرسال طلب الشحن'**
  String get submittingTopup;

  /// No description provided for @topupPendingNotice.
  ///
  /// In ar, this message translates to:
  /// **'يبقى هذا الطلب معلّقاً حتى موافقة الموظفين. الإرسال لا يضيف رصيداً الآن.'**
  String get topupPendingNotice;

  /// No description provided for @recoveringTopup.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ التحقق من طلب الشحن'**
  String get recoveringTopup;

  /// No description provided for @topupDetailTitle.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل الشحن'**
  String get topupDetailTitle;

  /// No description provided for @topupReferenceLabel.
  ///
  /// In ar, this message translates to:
  /// **'المرجع {reference}'**
  String topupReferenceLabel(String reference);

  /// No description provided for @enteredAmountLabel.
  ///
  /// In ar, this message translates to:
  /// **'أدخلت'**
  String get enteredAmountLabel;

  /// No description provided for @walletCreditLabel.
  ///
  /// In ar, this message translates to:
  /// **'مبلغ المحفظة بعد الموافقة'**
  String get walletCreditLabel;

  /// No description provided for @topupStatusPending.
  ///
  /// In ar, this message translates to:
  /// **'بانتظار الموافقة'**
  String get topupStatusPending;

  /// No description provided for @topupStatusApproved.
  ///
  /// In ar, this message translates to:
  /// **'تمت الموافقة'**
  String get topupStatusApproved;

  /// No description provided for @topupStatusCredited.
  ///
  /// In ar, this message translates to:
  /// **'أُضيف إلى المحفظة'**
  String get topupStatusCredited;

  /// No description provided for @topupStatusRejected.
  ///
  /// In ar, this message translates to:
  /// **'مرفوض'**
  String get topupStatusRejected;

  /// No description provided for @topupStatusCancelled.
  ///
  /// In ar, this message translates to:
  /// **'ملغى'**
  String get topupStatusCancelled;

  /// No description provided for @topupHasProof.
  ///
  /// In ar, this message translates to:
  /// **'تم إرفاق إثبات'**
  String get topupHasProof;

  /// No description provided for @topupNoProof.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد إثبات'**
  String get topupNoProof;

  /// No description provided for @retryTopupAction.
  ///
  /// In ar, this message translates to:
  /// **'إرسال طلب جديد'**
  String get retryTopupAction;

  /// No description provided for @refreshWalletAction.
  ///
  /// In ar, this message translates to:
  /// **'تحديث المحفظة'**
  String get refreshWalletAction;

  /// No description provided for @refreshTopupAction.
  ///
  /// In ar, this message translates to:
  /// **'تحديث طلب الشحن'**
  String get refreshTopupAction;

  /// No description provided for @transactionTypePurchase.
  ///
  /// In ar, this message translates to:
  /// **'شراء'**
  String get transactionTypePurchase;

  /// No description provided for @transactionTypeTopup.
  ///
  /// In ar, this message translates to:
  /// **'شحن'**
  String get transactionTypeTopup;

  /// No description provided for @transactionTypeRefund.
  ///
  /// In ar, this message translates to:
  /// **'استرداد'**
  String get transactionTypeRefund;

  /// No description provided for @transactionTypeAdjustment.
  ///
  /// In ar, this message translates to:
  /// **'تعديل'**
  String get transactionTypeAdjustment;

  /// No description provided for @transactionTypeCommission.
  ///
  /// In ar, this message translates to:
  /// **'عمولة'**
  String get transactionTypeCommission;

  /// No description provided for @transactionDirectionCredit.
  ///
  /// In ar, this message translates to:
  /// **'إضافة'**
  String get transactionDirectionCredit;

  /// No description provided for @transactionDirectionDebit.
  ///
  /// In ar, this message translates to:
  /// **'خصم'**
  String get transactionDirectionDebit;

  /// No description provided for @topupRequestPending.
  ///
  /// In ar, this message translates to:
  /// **'لديك طلب شحن معلّق بالفعل.'**
  String get topupRequestPending;

  /// No description provided for @topupNotFound.
  ///
  /// In ar, this message translates to:
  /// **'طلب الشحن هذا غير متاح.'**
  String get topupNotFound;

  /// No description provided for @topupAttemptNotFoundBody.
  ///
  /// In ar, this message translates to:
  /// **'لم يتم العثور على طلب شحن معلّق لهذا الحساب.'**
  String get topupAttemptNotFoundBody;

  /// No description provided for @topupInProgress.
  ///
  /// In ar, this message translates to:
  /// **'طلب الشحن هذا ما زال قيد المعالجة.'**
  String get topupInProgress;

  /// No description provided for @topupRetryRequired.
  ///
  /// In ar, this message translates to:
  /// **'يجب إعادة محاولة طلب الشحن بنفس الطلب.'**
  String get topupRetryRequired;

  /// No description provided for @paymentMethodUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'طريقة الدفع هذه غير متاحة.'**
  String get paymentMethodUnavailable;

  /// No description provided for @proofNotFound.
  ///
  /// In ar, this message translates to:
  /// **'إثبات الدفع غير موجود.'**
  String get proofNotFound;

  /// No description provided for @invalidTopupAmount.
  ///
  /// In ar, this message translates to:
  /// **'مبلغ الشحن هذا غير صالح.'**
  String get invalidTopupAmount;

  /// No description provided for @topupConversionUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن تحويل هذه العملة الآن. أدخل المبلغ بالدولار أو حاول لاحقاً.'**
  String get topupConversionUnavailable;

  /// No description provided for @topupAmountRequired.
  ///
  /// In ar, this message translates to:
  /// **'أدخل مبلغاً.'**
  String get topupAmountRequired;

  /// No description provided for @paymentMethodRequired.
  ///
  /// In ar, this message translates to:
  /// **'اختر طريقة دفع.'**
  String get paymentMethodRequired;

  /// No description provided for @walletUnavailableTitle.
  ///
  /// In ar, this message translates to:
  /// **'المحفظة غير متاحة'**
  String get walletUnavailableTitle;

  /// No description provided for @topupCardSemantics.
  ///
  /// In ar, this message translates to:
  /// **'شحن {reference}، {status}، {amount}'**
  String topupCardSemantics(String reference, String status, String amount);

  /// No description provided for @transactionCardSemantics.
  ///
  /// In ar, this message translates to:
  /// **'{type} {direction}، {amount}، {date}'**
  String transactionCardSemantics(
    String type,
    String direction,
    String amount,
    String date,
  );
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
