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
  String get homeBrowseSubtitle =>
      'Browse packages, product options, and prices.';

  @override
  String get homePlaceholder => 'The foundation is ready';

  @override
  String get homePlaceholderBody =>
      'Shopping features will arrive in later milestones.';

  @override
  String get accountTitle => 'Account';

  @override
  String get catalogLoading => 'Loading catalog';

  @override
  String get catalogUnavailableTitle => 'Catalog unavailable';

  @override
  String get catalogUnavailableBody =>
      'Check your connection and try again. You are still signed in.';

  @override
  String get searchPackagesLabel => 'Search packages';

  @override
  String get searchPackagesHint => 'Search for a package';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get browseAllPackages => 'Browse all packages';

  @override
  String get frequentlyOrderedTitle => 'Frequently ordered';

  @override
  String get featuredPackagesTitle => 'Featured packages';

  @override
  String get featuredPackagesEmpty => 'No featured packages right now.';

  @override
  String get categoriesTitle => 'Categories';

  @override
  String get packagesTitle => 'Packages';

  @override
  String get packagesEmptyTitle => 'No packages found';

  @override
  String get packagesEmptyBody => 'Try a different search or category.';

  @override
  String get loadMorePackages => 'Load more';

  @override
  String get categoryFilterActive => 'Category filter';

  @override
  String get clearCategoryFilter => 'Clear category';

  @override
  String get categoryFilterInvalid =>
      'That category is not valid. Choose another.';

  @override
  String get searchQueryInvalid =>
      'That search is not valid. Use at least two characters.';

  @override
  String get packageDetailTitle => 'Package details';

  @override
  String get packageNotFoundTitle => 'Package not found';

  @override
  String get packageNotFound => 'This package is not available.';

  @override
  String get backToPackages => 'Back to packages';

  @override
  String get productOptionsTitle => 'Product options';

  @override
  String get productOptionsEmpty => 'This package has no active products.';

  @override
  String get fixedAmountMode => 'Fixed price';

  @override
  String get customAmountMode => 'Custom amount';

  @override
  String get fromPriceLabel => 'From';

  @override
  String get minimumPriceLabel => 'Minimum';

  @override
  String get priceHidden => 'Price hidden';

  @override
  String get priceUnavailable => 'Price unavailable';

  @override
  String priceFrom(String price) {
    return 'From $price';
  }

  @override
  String get customPriceCalculatedLater =>
      'The exact price is calculated later after you enter an amount.';

  @override
  String get customAmountConfigUnavailable =>
      'Custom amount settings are incomplete.';

  @override
  String customAmountMin(int value) {
    return 'Min: $value';
  }

  @override
  String customAmountMax(int value) {
    return 'Max: $value';
  }

  @override
  String customAmountStep(int value) {
    return 'Step: $value';
  }

  @override
  String customAmountUnit(String label) {
    return 'Unit: $label';
  }

  @override
  String timesOrdered(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ordered $count times',
      one: 'Ordered once',
      zero: 'Not ordered yet',
    );
    return '$_temp0';
  }

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

  @override
  String get buyNowAction => 'Buy now';

  @override
  String get buyNowTitle => 'Buy now';

  @override
  String get purchaseDetailsTitle => 'Purchase details';

  @override
  String get requirementsTitle => 'Required details';

  @override
  String get quantityLabel => 'Quantity';

  @override
  String get quantityInvalid => 'Enter a valid quantity of at least 1.';

  @override
  String quantityValue(int quantity) {
    return 'Quantity: $quantity';
  }

  @override
  String requestedAmountLabel(String unit) {
    return 'Amount $unit';
  }

  @override
  String get requestedAmountInvalid =>
      'Enter a valid amount within the allowed range.';

  @override
  String requestedAmountValue(int amount) {
    return 'Amount: $amount';
  }

  @override
  String get unitPriceLabel => 'Unit price';

  @override
  String get requirementRequired => 'This field is required.';

  @override
  String get continueToReviewAction => 'Continue to review';

  @override
  String get quotingPurchase => 'Getting your quote';

  @override
  String get purchaseUnavailableTitle => 'Purchase unavailable';

  @override
  String get purchaseUnavailableBody =>
      'This product cannot be purchased right now.';

  @override
  String get checkoutReviewTitle => 'Review purchase';

  @override
  String get quoteMissingBody =>
      'Your quote is no longer available. Start the purchase again.';

  @override
  String get orderTotalsTitle => 'Totals';

  @override
  String get lineTotalLabel => 'Line total';

  @override
  String get finalTotalLabel => 'Total';

  @override
  String get walletSectionTitle => 'Wallet';

  @override
  String get availableToSpendLabel => 'Available to spend';

  @override
  String get walletUnavailableBody =>
      'Wallet balance is temporarily unavailable.';

  @override
  String quoteExpiresAt(String timestamp) {
    return 'Quote expires at $timestamp';
  }

  @override
  String get confirmWalletChargeAction => 'Pay with wallet';

  @override
  String get confirmWalletChargeHint =>
      'Your wallet will be charged for the total shown above.';

  @override
  String get submittingPurchase => 'Processing purchase';

  @override
  String get refreshQuoteAction => 'Refresh quote';

  @override
  String get priceChangedBody =>
      'The price or purchase details changed. Review the updated total before paying.';

  @override
  String get insufficientBalanceBody =>
      'Your available wallet balance is not enough for this purchase.';

  @override
  String get checkoutRecoveryTitle => 'Checking your purchase';

  @override
  String get checkoutRecoveryIdleBody =>
      'There is no purchase waiting to be recovered.';

  @override
  String get checkoutRecoveryProcessingBody =>
      'We are confirming whether your purchase completed. Please wait.';

  @override
  String get checkoutFailedTitle => 'Purchase could not be completed';

  @override
  String get checkoutRetryRequiredTitle => 'Purchase must be restarted';

  @override
  String get checkoutRetryRequiredBody =>
      'This purchase did not finish. Start again from the product page.';

  @override
  String get checkoutAttemptNotFoundBody =>
      'No pending purchase was found for this account.';

  @override
  String get purchaseSuccessTitle => 'Purchase successful';

  @override
  String get purchaseSuccessBody => 'Your wallet payment was completed.';

  @override
  String get viewReceiptAction => 'View receipt';

  @override
  String get receiptTitle => 'Receipt';

  @override
  String get loadingReceipt => 'Loading receipt';

  @override
  String get receiptItemsTitle => 'Items';

  @override
  String orderNumberLabel(String orderNumber) {
    return 'Order $orderNumber';
  }

  @override
  String paymentStatusLabel(String status) {
    return 'Payment status: $status';
  }

  @override
  String get orderNotFoundTitle => 'Order not found';

  @override
  String get orderNotFoundBody =>
      'This order is not available for your account.';

  @override
  String get backToHomeAction => 'Back to home';

  @override
  String get purchasingUnavailable => 'Purchasing is temporarily unavailable.';

  @override
  String get productUnavailable => 'This product is unavailable.';

  @override
  String get invalidCustomAmount => 'That custom amount is not valid.';

  @override
  String get priceChanged => 'The price changed. Review the updated quote.';

  @override
  String get insufficientWalletBalance => 'Your wallet balance is not enough.';

  @override
  String get idempotencyConflict =>
      'This purchase attempt conflicts with another request. Checking status.';

  @override
  String get checkoutInProgress => 'This purchase is still processing.';

  @override
  String get checkoutRetryRequired =>
      'This purchase must be retried carefully. Start again if needed.';

  @override
  String get checkoutFailed =>
      'The purchase failed. No further action was taken.';

  @override
  String get orderNotFound => 'Order not found.';

  @override
  String get ordersTitle => 'Orders';

  @override
  String get ordersLoading => 'Loading orders';

  @override
  String get ordersUnavailableTitle => 'Orders unavailable';

  @override
  String get ordersEmptyTitle => 'No orders yet';

  @override
  String get ordersEmptyBody => 'Your completed purchases will appear here.';

  @override
  String get loadMoreOrders => 'Load more orders';

  @override
  String get ordersLoadingMore => 'Loading more orders';

  @override
  String get refreshingOrders => 'Refreshing orders';

  @override
  String get orderTitleFallback => 'Order';

  @override
  String orderCardSemantics(
    String title,
    String orderNumber,
    String date,
    String total,
    String state,
    int itemCount,
  ) {
    return '$title, order $orderNumber, created $date, total $total, status $state, $itemCount items';
  }

  @override
  String orderCreatedLabel(String date) {
    return 'Created: $date';
  }

  @override
  String orderPaidLabel(String date) {
    return 'Paid: $date';
  }

  @override
  String customerStateLabel(String state) {
    return 'Status: $state';
  }

  @override
  String orderItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get orderDetailTitle => 'Order detail';

  @override
  String get refreshOrderAction => 'Refresh order';

  @override
  String get loadingOrderDetail => 'Loading order detail';

  @override
  String get orderStatusRefreshing => 'Refreshing order status';

  @override
  String get orderPollingEnded =>
      'Automatic updates paused. Refresh to check again.';

  @override
  String get orderNumberHeading => 'Order number';

  @override
  String get orderStatusSection => 'Status';

  @override
  String get paymentLabel => 'Payment';

  @override
  String get fulfillmentLabel => 'Fulfillment';

  @override
  String get fulfillmentSummaryTitle => 'Fulfillment summary';

  @override
  String get fulfillmentSummaryTotal => 'Total';

  @override
  String fulfillmentSummaryCount(String label, int count) {
    return '$label: $count';
  }

  @override
  String get paymentStatusPaid => 'Paid';

  @override
  String get paymentStatusPending => 'Payment pending';

  @override
  String get paymentStatusProcessing => 'Payment processing';

  @override
  String get paymentStatusFulfilled => 'Paid';

  @override
  String get paymentStatusFailed => 'Payment failed';

  @override
  String get paymentStatusRefunded => 'Refunded';

  @override
  String get paymentStatusCancelled => 'Payment cancelled';

  @override
  String get fulfillmentStatusPending => 'Pending';

  @override
  String get fulfillmentStatusQueued => 'Queued';

  @override
  String get fulfillmentStatusProcessing => 'Processing';

  @override
  String get fulfillmentStatusCompleted => 'Completed';

  @override
  String get fulfillmentStatusFailed => 'Failed';

  @override
  String get fulfillmentStatusCancelled => 'Cancelled';

  @override
  String get customerStateNeedsAttention => 'Needs attention';

  @override
  String get customerStateInProgress => 'In progress';

  @override
  String get customerStateDelivered => 'Delivered';

  @override
  String get customerStateRefunded => 'Refunded';

  @override
  String get statusOther => 'Other';
}
