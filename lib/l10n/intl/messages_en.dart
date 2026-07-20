// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a en locale. All the
// messages from the main program should be duplicated here with the same
// function name.

// Ignore issues from commonly used lints in this file.
// ignore_for_file:unnecessary_brace_in_string_interps, unnecessary_new
// ignore_for_file:prefer_single_quotes,comment_references, directives_ordering
// ignore_for_file:annotate_overrides,prefer_generic_function_type_aliases
// ignore_for_file:unused_import, file_names, avoid_escaping_inner_quotes
// ignore_for_file:unnecessary_string_interpolations, unnecessary_string_escapes

import 'package:intl/intl.dart';
import 'package:intl/message_lookup_by_library.dart';

final messages = new MessageLookup();

typedef String MessageIfAbsent(String messageStr, List<dynamic> args);

class MessageLookup extends MessageLookupByLibrary {
  String get localeName => 'en';

  static String m0(limit) => "The minimum withdrawal commission is ${limit}";

  static String m1(minute) =>
      "Too many password errors, please try again after ${minute} minutes";

  static String m2(rate) => "Current commission rate: ${rate}%";

  static String m3(label) =>
      "Are you sure you want to delete the selected ${label}?";

  static String m4(label) =>
      "Are you sure you want to delete the current ${label}?";

  static String m5(label) => "${label} cannot be empty";

  static String m6(label) => "Current ${label} already exists";

  static String m7(error) => "Sign out failed: ${error}";

  static String m8(amount) => "Max transferable: ¥${amount}";

  static String m9(label) => "No ${label} at the moment";

  static String m10(label) => "${label} must be a number";

  static String m11(statusCode) => "Failed to get messages: ${statusCode}";

  static String m12(error) => "Failed to select images: ${error}";

  static String m13(method) => "Unsupported HTTP method: ${method}";

  static String m14(error) => "Upload failed: ${error}";

  static String m15(amount) => "Order amount: ${amount}";

  static String m16(orderNo) => "Order: ${orderNo}";

  static String m17(page) => "Page ${page}";

  static String m18(label) => "${label} must be between 1024 and 49151";

  static String m19(e) => "Registration failed: ${e}";

  static String m20(count) => "${count} items have been selected";

  static String m21(e) => "Failed to send verification code: ${e}";

  static String m22(date) =>
      "Plan expired on ${date}, please renew to continue using";

  static String m23(days) =>
      "Plan will expire in ${days} days, please renew in time";

  static String m24(days) => "Subscription will expire in ${days} days";

  static String m25(count) => "Total ${count} records";

  static String m26(amount) => "Transfer amount cannot exceed ¥${amount}";

  static String m27(error) => "Transfer failed: ${error}";

  static String m28(amount) =>
      "Transfer success! Transferred ¥${amount} to wallet";

  static String m29(version) => "Current version: ${version}";

  static String m30(version) => "Force update: ${version}";

  static String m31(version) => "New version found: ${version}";

  static String m32(statusCode) =>
      "Server returned error status code ${statusCode}";

  static String m33(label) => "${label} must be a url";

  static String m34(email) =>
      "Verification code has been sent to ${email}, please check and enter the verification code and new password";

  static String m35(error) => "Submission failed: ${error}";

  static String m36(amount) => "Withdrawable amount: ${amount}";

  static String m37(amount) => "¥${amount}";

  static String m38(count, limit) => "${count} active · Limit ${limit}";

  static String m39(count) => "${count} devices";

  static String m40(date) => "Expired on ${date}";

  static String m41(date) => "Valid until ${date}";

  static String m42(date, days) => "Expires on ${date}, ${days} days remaining";

  static String m43(count) => "${count} candidates";

  static String m44(message) => "Subscription import: ${message}";

  static String m45(count) => "${count} nodes";

  static String m46(error) => "Redeem failed: ${error}";

  static String m47(days) => "Used traffic will reset in ${days} days";

  static String m48(time) => "Running time: ${time}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "about": MessageLookupByLibrary.simpleMessage("About"),
    "accessControl": MessageLookupByLibrary.simpleMessage("AccessControl"),
    "accessControlAllowDesc": MessageLookupByLibrary.simpleMessage(
      "Only allow selected app to enter VPN",
    ),
    "accessControlDesc": MessageLookupByLibrary.simpleMessage(
      "Configure application access proxy",
    ),
    "accessControlNotAllowDesc": MessageLookupByLibrary.simpleMessage(
      "The selected application will be excluded from VPN",
    ),
    "account": MessageLookupByLibrary.simpleMessage("Account"),
    "action": MessageLookupByLibrary.simpleMessage("Action"),
    "action_mode": MessageLookupByLibrary.simpleMessage("Switch mode"),
    "action_proxy": MessageLookupByLibrary.simpleMessage("System proxy"),
    "action_start": MessageLookupByLibrary.simpleMessage("Start/Stop"),
    "action_tun": MessageLookupByLibrary.simpleMessage("TUN"),
    "action_view": MessageLookupByLibrary.simpleMessage("Show/Hide"),
    "add": MessageLookupByLibrary.simpleMessage("Add"),
    "addRule": MessageLookupByLibrary.simpleMessage("Add rule"),
    "addedOriginRules": MessageLookupByLibrary.simpleMessage(
      "Attach on the original rules",
    ),
    "address": MessageLookupByLibrary.simpleMessage("Address"),
    "addressHelp": MessageLookupByLibrary.simpleMessage(
      "WebDAV server address",
    ),
    "addressTip": MessageLookupByLibrary.simpleMessage(
      "Please enter a valid WebDAV address",
    ),
    "adminAutoLaunch": MessageLookupByLibrary.simpleMessage(
      "Admin auto launch",
    ),
    "adminAutoLaunchDesc": MessageLookupByLibrary.simpleMessage(
      "Boot up by using admin mode",
    ),
    "ago": MessageLookupByLibrary.simpleMessage(" Ago"),
    "agree": MessageLookupByLibrary.simpleMessage("Agree"),
    "allApps": MessageLookupByLibrary.simpleMessage("All apps"),
    "allowBypass": MessageLookupByLibrary.simpleMessage(
      "Allow applications to bypass VPN",
    ),
    "allowBypassDesc": MessageLookupByLibrary.simpleMessage(
      "Some apps can bypass VPN when turned on",
    ),
    "allowLan": MessageLookupByLibrary.simpleMessage("AllowLan"),
    "allowLanDesc": MessageLookupByLibrary.simpleMessage(
      "Allow access proxy through the LAN",
    ),
    "alreadyHaveAccount": MessageLookupByLibrary.simpleMessage(
      "Already have an account?",
    ),
    "app": MessageLookupByLibrary.simpleMessage("App"),
    "appAccessControl": MessageLookupByLibrary.simpleMessage(
      "App access control",
    ),
    "appDesc": MessageLookupByLibrary.simpleMessage(
      "Processing app related settings",
    ),
    "application": MessageLookupByLibrary.simpleMessage("Application"),
    "applicationDesc": MessageLookupByLibrary.simpleMessage(
      "Modify application related settings",
    ),
    "auto": MessageLookupByLibrary.simpleMessage("Auto"),
    "autoCheckUpdate": MessageLookupByLibrary.simpleMessage(
      "Auto check updates",
    ),
    "autoCheckUpdateDesc": MessageLookupByLibrary.simpleMessage(
      "Auto check for updates when the app starts",
    ),
    "autoCloseConnections": MessageLookupByLibrary.simpleMessage(
      "Auto close connections",
    ),
    "autoCloseConnectionsDesc": MessageLookupByLibrary.simpleMessage(
      "Auto close connections after change node",
    ),
    "autoLaunch": MessageLookupByLibrary.simpleMessage("Start on Boot"),
    "autoLaunchDesc": MessageLookupByLibrary.simpleMessage(
      "Follow the system self startup",
    ),
    "autoRun": MessageLookupByLibrary.simpleMessage("AutoRun"),
    "autoRunDesc": MessageLookupByLibrary.simpleMessage(
      "Auto run when the application is opened",
    ),
    "autoSetSystemDns": MessageLookupByLibrary.simpleMessage(
      "Auto set system DNS",
    ),
    "autoUpdate": MessageLookupByLibrary.simpleMessage("Auto update"),
    "autoUpdateInterval": MessageLookupByLibrary.simpleMessage(
      "Auto update interval (minutes)",
    ),
    "availableCommission": MessageLookupByLibrary.simpleMessage(
      "Commission balance",
    ),
    "backToLogin": MessageLookupByLibrary.simpleMessage("Back to Login"),
    "backendErrorAccountSuspended": MessageLookupByLibrary.simpleMessage(
      "This account has been suspended",
    ),
    "backendErrorCouponEmpty": MessageLookupByLibrary.simpleMessage(
      "Coupon cannot be empty",
    ),
    "backendErrorCouponExpired": MessageLookupByLibrary.simpleMessage(
      "Coupon has expired",
    ),
    "backendErrorCouponInvalid": MessageLookupByLibrary.simpleMessage(
      "Coupon is invalid",
    ),
    "backendErrorCouponLimitExceeded": MessageLookupByLibrary.simpleMessage(
      "Coupon usage limit has been reached",
    ),
    "backendErrorCouponNotFound": MessageLookupByLibrary.simpleMessage(
      "Coupon does not exist",
    ),
    "backendErrorEmailEmpty": MessageLookupByLibrary.simpleMessage(
      "Email cannot be empty",
    ),
    "backendErrorEmailExists": MessageLookupByLibrary.simpleMessage(
      "This email is already registered",
    ),
    "backendErrorEmailFormatInvalid": MessageLookupByLibrary.simpleMessage(
      "Email format is incorrect",
    ),
    "backendErrorFailedToOpenTicket": MessageLookupByLibrary.simpleMessage(
      "Failed to create withdrawal ticket",
    ),
    "backendErrorGiftCardAlreadyUsedByUser":
        MessageLookupByLibrary.simpleMessage(
          "This gift card has already been used by this user",
        ),
    "backendErrorGiftCardEmpty": MessageLookupByLibrary.simpleMessage(
      "Gift card cannot be empty",
    ),
    "backendErrorGiftCardExpired": MessageLookupByLibrary.simpleMessage(
      "This gift card has expired",
    ),
    "backendErrorGiftCardLimitReached": MessageLookupByLibrary.simpleMessage(
      "This gift card has reached its usage limit",
    ),
    "backendErrorGiftCardNotFound": MessageLookupByLibrary.simpleMessage(
      "This gift card does not exist",
    ),
    "backendErrorGiftCardNotYetValid": MessageLookupByLibrary.simpleMessage(
      "This gift card is not yet valid",
    ),
    "backendErrorGiftCardTypeNotSuitable": MessageLookupByLibrary.simpleMessage(
      "This gift card type is not applicable",
    ),
    "backendErrorGiftCardTypeUnknown": MessageLookupByLibrary.simpleMessage(
      "Unknown gift card type",
    ),
    "backendErrorIncorrectEmailOrPassword":
        MessageLookupByLibrary.simpleMessage("Incorrect email or password"),
    "backendErrorInsufficientCommissionBalance":
        MessageLookupByLibrary.simpleMessage("Insufficient commission balance"),
    "backendErrorInviteCodeInvalid": MessageLookupByLibrary.simpleMessage(
      "Invite code is invalid",
    ),
    "backendErrorInviteCodeNotFound": MessageLookupByLibrary.simpleMessage(
      "Invite code does not exist",
    ),
    "backendErrorInviteLimitReached": MessageLookupByLibrary.simpleMessage(
      "Maximum number of invites reached",
    ),
    "backendErrorMinimumWithdrawalCommission": m0,
    "backendErrorMinimumWithdrawalCommissionGeneric":
        MessageLookupByLibrary.simpleMessage(
          "The minimum withdrawal commission has not been reached",
        ),
    "backendErrorNewPasswordEmpty": MessageLookupByLibrary.simpleMessage(
      "New password cannot be empty",
    ),
    "backendErrorOldPasswordWrong": MessageLookupByLibrary.simpleMessage(
      "Old password is incorrect",
    ),
    "backendErrorOrderNotFound": MessageLookupByLibrary.simpleMessage(
      "Order does not exist",
    ),
    "backendErrorPasswordEmpty": MessageLookupByLibrary.simpleMessage(
      "Password cannot be empty",
    ),
    "backendErrorPasswordTooShort": MessageLookupByLibrary.simpleMessage(
      "Password must be longer than 8 characters",
    ),
    "backendErrorPlanNotFound": MessageLookupByLibrary.simpleMessage(
      "Plan does not exist",
    ),
    "backendErrorResetFailed": MessageLookupByLibrary.simpleMessage(
      "Reset failed, please try again later",
    ),
    "backendErrorSaveFailed": MessageLookupByLibrary.simpleMessage(
      "Save failed, please try again later",
    ),
    "backendErrorTicketClosed": MessageLookupByLibrary.simpleMessage(
      "Ticket is closed",
    ),
    "backendErrorTicketNotFound": MessageLookupByLibrary.simpleMessage(
      "Ticket does not exist",
    ),
    "backendErrorTooManyPasswordErrors": m1,
    "backendErrorTooManyPasswordErrorsGeneric":
        MessageLookupByLibrary.simpleMessage(
          "Too many password errors, please try again later",
        ),
    "backendErrorTooManyRequests": MessageLookupByLibrary.simpleMessage(
      "Too many requests, please try again later",
    ),
    "backendErrorTransferAmountEmpty": MessageLookupByLibrary.simpleMessage(
      "Transfer amount cannot be empty",
    ),
    "backendErrorTransferAmountInvalid": MessageLookupByLibrary.simpleMessage(
      "Transfer amount parameter is invalid",
    ),
    "backendErrorTransferFailed": MessageLookupByLibrary.simpleMessage(
      "Transfer failed",
    ),
    "backendErrorUserNotFound": MessageLookupByLibrary.simpleMessage(
      "User does not exist",
    ),
    "backendErrorVerificationCodeInvalid": MessageLookupByLibrary.simpleMessage(
      "Verification code is incorrect",
    ),
    "backendErrorWithdrawNotSupported": MessageLookupByLibrary.simpleMessage(
      "Withdrawal is currently not supported",
    ),
    "backendErrorWithdrawalAccountEmpty": MessageLookupByLibrary.simpleMessage(
      "Withdrawal account cannot be empty",
    ),
    "backendErrorWithdrawalMethodEmpty": MessageLookupByLibrary.simpleMessage(
      "Withdrawal method cannot be empty",
    ),
    "backendErrorWithdrawalMethodUnsupported":
        MessageLookupByLibrary.simpleMessage("Unsupported withdrawal method"),
    "backendFallbackCouponFailed": MessageLookupByLibrary.simpleMessage(
      "Coupon check failed",
    ),
    "backendFallbackEmailVerifyFailed": MessageLookupByLibrary.simpleMessage(
      "Failed to send verification code",
    ),
    "backendFallbackLoginFailed": MessageLookupByLibrary.simpleMessage(
      "Login failed",
    ),
    "backendFallbackOperationFailed": MessageLookupByLibrary.simpleMessage(
      "Operation failed",
    ),
    "backendFallbackOrderFailed": MessageLookupByLibrary.simpleMessage(
      "Order operation failed",
    ),
    "backendFallbackPasswordFailed": MessageLookupByLibrary.simpleMessage(
      "Password operation failed",
    ),
    "backendFallbackRegisterFailed": MessageLookupByLibrary.simpleMessage(
      "Register failed",
    ),
    "backendFallbackTicketFailed": MessageLookupByLibrary.simpleMessage(
      "Ticket operation failed",
    ),
    "backendFallbackTransferFailed": MessageLookupByLibrary.simpleMessage(
      "Transfer failed",
    ),
    "backup": MessageLookupByLibrary.simpleMessage("Backup"),
    "backupAndRecovery": MessageLookupByLibrary.simpleMessage(
      "Backup and Recovery",
    ),
    "backupAndRecoveryDesc": MessageLookupByLibrary.simpleMessage(
      "Sync data via WebDAV or file",
    ),
    "backupSuccess": MessageLookupByLibrary.simpleMessage("Backup success"),
    "basicConfig": MessageLookupByLibrary.simpleMessage("Basic configuration"),
    "basicConfigDesc": MessageLookupByLibrary.simpleMessage(
      "Modify the basic configuration globally",
    ),
    "bind": MessageLookupByLibrary.simpleMessage("Bind"),
    "blacklistMode": MessageLookupByLibrary.simpleMessage("Blacklist mode"),
    "bypassDomain": MessageLookupByLibrary.simpleMessage("Bypass domain"),
    "bypassDomainDesc": MessageLookupByLibrary.simpleMessage(
      "Only takes effect when the system proxy is enabled",
    ),
    "cacheCorrupt": MessageLookupByLibrary.simpleMessage(
      "The cache is corrupt. Do you want to clear it?",
    ),
    "cancel": MessageLookupByLibrary.simpleMessage("Cancel"),
    "cancelFilterSystemApp": MessageLookupByLibrary.simpleMessage(
      "Cancel filter system app",
    ),
    "cancelSelectAll": MessageLookupByLibrary.simpleMessage(
      "Cancel select all",
    ),
    "cannotGetWebUrl": MessageLookupByLibrary.simpleMessage(
      "Cannot get web URL, please contact support",
    ),
    "cannotOpenBrowser": MessageLookupByLibrary.simpleMessage(
      "Cannot open browser, please visit web manually",
    ),
    "checkError": MessageLookupByLibrary.simpleMessage("Check error"),
    "checkNetwork": MessageLookupByLibrary.simpleMessage(
      "Please check network and retry",
    ),
    "checkUpdate": MessageLookupByLibrary.simpleMessage("Check for updates"),
    "checkUpdateError": MessageLookupByLibrary.simpleMessage(
      "The current application is already the latest version",
    ),
    "checking": MessageLookupByLibrary.simpleMessage("Checking..."),
    "clearCacheAndRestart": MessageLookupByLibrary.simpleMessage(
      "Clear cache and restart",
    ),
    "clearData": MessageLookupByLibrary.simpleMessage("Clear Data"),
    "clearLogs": MessageLookupByLibrary.simpleMessage("Clear logs"),
    "clearLogsConfirm": MessageLookupByLibrary.simpleMessage(
      "Clear the current logs and request records? This action cannot be undone.",
    ),
    "clipboardExport": MessageLookupByLibrary.simpleMessage("Export clipboard"),
    "clipboardImport": MessageLookupByLibrary.simpleMessage("Clipboard import"),
    "close": MessageLookupByLibrary.simpleMessage("Close"),
    "color": MessageLookupByLibrary.simpleMessage("Color"),
    "colorSchemes": MessageLookupByLibrary.simpleMessage("Color schemes"),
    "columns": MessageLookupByLibrary.simpleMessage("Columns"),
    "commissionHistory": MessageLookupByLibrary.simpleMessage(
      "Commission History",
    ),
    "commissionRate": MessageLookupByLibrary.simpleMessage("Rate"),
    "commissionSettled": MessageLookupByLibrary.simpleMessage(
      "Commission settled after friend subscription",
    ),
    "compatible": MessageLookupByLibrary.simpleMessage("Compatibility mode"),
    "compatibleDesc": MessageLookupByLibrary.simpleMessage(
      "Opening it will lose part of its application ability and gain the support of full amount of Clash.",
    ),
    "complete": MessageLookupByLibrary.simpleMessage("Complete"),
    "completeWithdrawal": MessageLookupByLibrary.simpleMessage(
      "Web version provides complete withdrawal features",
    ),
    "configurationError": MessageLookupByLibrary.simpleMessage(
      "Application configuration error, please contact support",
    ),
    "confirm": MessageLookupByLibrary.simpleMessage("Confirm"),
    "confirmLogout": MessageLookupByLibrary.simpleMessage("Confirm sign out"),
    "confirmNewPassword": MessageLookupByLibrary.simpleMessage(
      "Confirm New Password",
    ),
    "confirmTransfer": MessageLookupByLibrary.simpleMessage("Confirm Transfer"),
    "connected": MessageLookupByLibrary.simpleMessage("Connected"),
    "connections": MessageLookupByLibrary.simpleMessage("Connections"),
    "connectionsDesc": MessageLookupByLibrary.simpleMessage(
      "View current connections data",
    ),
    "connectivity": MessageLookupByLibrary.simpleMessage("Connectivity："),
    "contactMe": MessageLookupByLibrary.simpleMessage("Contact me"),
    "contactSupport": MessageLookupByLibrary.simpleMessage("Support"),
    "content": MessageLookupByLibrary.simpleMessage("Content"),
    "contentScheme": MessageLookupByLibrary.simpleMessage("Content"),
    "copiedToClipboard": MessageLookupByLibrary.simpleMessage(
      "Copied to clipboard",
    ),
    "copy": MessageLookupByLibrary.simpleMessage("Copy"),
    "copyEnvVar": MessageLookupByLibrary.simpleMessage(
      "Copying environment variables",
    ),
    "copyInviteLink": MessageLookupByLibrary.simpleMessage("Copy Link"),
    "copyLink": MessageLookupByLibrary.simpleMessage("Copy link"),
    "copyLogs": MessageLookupByLibrary.simpleMessage("Copy logs"),
    "copySuccess": MessageLookupByLibrary.simpleMessage("Copy success"),
    "core": MessageLookupByLibrary.simpleMessage("Core"),
    "coreInfo": MessageLookupByLibrary.simpleMessage("Core info"),
    "country": MessageLookupByLibrary.simpleMessage("Country"),
    "crashTest": MessageLookupByLibrary.simpleMessage("Crash test"),
    "create": MessageLookupByLibrary.simpleMessage("Create"),
    "createAccount": MessageLookupByLibrary.simpleMessage("Create Account"),
    "credentialsSaved": MessageLookupByLibrary.simpleMessage(
      "Credentials saved",
    ),
    "currentCommissionRate": m2,
    "customerServiceLoadFailed": MessageLookupByLibrary.simpleMessage(
      "Customer service page failed to load, please try again later",
    ),
    "customerServiceLoadingSlow": MessageLookupByLibrary.simpleMessage(
      "Customer service page is loading slowly, please wait...",
    ),
    "cut": MessageLookupByLibrary.simpleMessage("Cut"),
    "dark": MessageLookupByLibrary.simpleMessage("Dark"),
    "dashboard": MessageLookupByLibrary.simpleMessage("Dashboard"),
    "days": MessageLookupByLibrary.simpleMessage("Days"),
    "defaultNameserver": MessageLookupByLibrary.simpleMessage(
      "Default nameserver",
    ),
    "defaultNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "For resolving DNS server",
    ),
    "defaultSort": MessageLookupByLibrary.simpleMessage("Sort by default"),
    "defaultText": MessageLookupByLibrary.simpleMessage("Default"),
    "delay": MessageLookupByLibrary.simpleMessage("Delay"),
    "delaySort": MessageLookupByLibrary.simpleMessage("Sort by delay"),
    "delete": MessageLookupByLibrary.simpleMessage("Delete"),
    "deleteMultipTip": m3,
    "deleteTip": m4,
    "desc": MessageLookupByLibrary.simpleMessage(
      "A multi-platform proxy client based on ClashMeta",
    ),
    "detectionTip": MessageLookupByLibrary.simpleMessage(
      "Relying on third-party api is for reference only",
    ),
    "developerMode": MessageLookupByLibrary.simpleMessage("Developer mode"),
    "developerModeEnableTip": MessageLookupByLibrary.simpleMessage(
      "Developer mode is enabled.",
    ),
    "direct": MessageLookupByLibrary.simpleMessage("Direct"),
    "disclaimer": MessageLookupByLibrary.simpleMessage("Important Notice"),
    "disclaimerDesc": MessageLookupByLibrary.simpleMessage(
      "This software is currently in public beta. If you receive update reminders, please update promptly. Older versions may cause service instability or inability to use.",
    ),
    "discoverNewVersion": MessageLookupByLibrary.simpleMessage(
      "Discover the new version",
    ),
    "discovery": MessageLookupByLibrary.simpleMessage(
      "Discovery a new version",
    ),
    "dnsDesc": MessageLookupByLibrary.simpleMessage(
      "Update DNS related settings",
    ),
    "dnsMode": MessageLookupByLibrary.simpleMessage("DNS mode"),
    "doYouWantToPass": MessageLookupByLibrary.simpleMessage(
      "Do you want to pass",
    ),
    "domain": MessageLookupByLibrary.simpleMessage("Domain"),
    "domainStatusAvailable": MessageLookupByLibrary.simpleMessage(
      "Service Available",
    ),
    "domainStatusChecking": MessageLookupByLibrary.simpleMessage("Checking..."),
    "domainStatusUnavailable": MessageLookupByLibrary.simpleMessage(
      "Service Unavailable",
    ),
    "download": MessageLookupByLibrary.simpleMessage("Download"),
    "edit": MessageLookupByLibrary.simpleMessage("Edit"),
    "emailAddress": MessageLookupByLibrary.simpleMessage("Email Address"),
    "emailVerificationCode": MessageLookupByLibrary.simpleMessage(
      "Email Verification Code",
    ),
    "emptyTip": m5,
    "en": MessageLookupByLibrary.simpleMessage("English"),
    "enableOverride": MessageLookupByLibrary.simpleMessage("Enable override"),
    "enterEmailForReset": MessageLookupByLibrary.simpleMessage(
      "Please enter your email address and we will send a verification code to your email",
    ),
    "enterTransferAmount": MessageLookupByLibrary.simpleMessage(
      "Enter transfer amount",
    ),
    "enterTransferAmountError": MessageLookupByLibrary.simpleMessage(
      "Please enter transfer amount",
    ),
    "entries": MessageLookupByLibrary.simpleMessage(" entries"),
    "exclude": MessageLookupByLibrary.simpleMessage("Hidden from recent tasks"),
    "excludeDesc": MessageLookupByLibrary.simpleMessage(
      "When the app is in the background, the app is hidden from the recent task",
    ),
    "existsTip": m6,
    "exit": MessageLookupByLibrary.simpleMessage("Exit"),
    "expand": MessageLookupByLibrary.simpleMessage("Standard"),
    "expirationTime": MessageLookupByLibrary.simpleMessage("Expiration time"),
    "exportFile": MessageLookupByLibrary.simpleMessage("Export file"),
    "exportLogs": MessageLookupByLibrary.simpleMessage("Export logs"),
    "exportSuccess": MessageLookupByLibrary.simpleMessage("Export Success"),
    "expressiveScheme": MessageLookupByLibrary.simpleMessage("Expressive"),
    "externalController": MessageLookupByLibrary.simpleMessage(
      "ExternalController",
    ),
    "externalControllerDesc": MessageLookupByLibrary.simpleMessage(
      "Once enabled, the Clash kernel can be controlled on port 9090",
    ),
    "externalLink": MessageLookupByLibrary.simpleMessage("External link"),
    "externalResources": MessageLookupByLibrary.simpleMessage(
      "External resources",
    ),
    "fakeipFilter": MessageLookupByLibrary.simpleMessage("Fakeip filter"),
    "fakeipRange": MessageLookupByLibrary.simpleMessage("Fakeip range"),
    "fallback": MessageLookupByLibrary.simpleMessage("Fallback"),
    "fallbackDesc": MessageLookupByLibrary.simpleMessage(
      "Generally use offshore DNS",
    ),
    "fallbackFilter": MessageLookupByLibrary.simpleMessage("Fallback filter"),
    "fidelityScheme": MessageLookupByLibrary.simpleMessage("Fidelity"),
    "file": MessageLookupByLibrary.simpleMessage("File"),
    "fileDesc": MessageLookupByLibrary.simpleMessage("Directly upload profile"),
    "fileIsUpdate": MessageLookupByLibrary.simpleMessage(
      "The file has been modified. Do you want to save the changes?",
    ),
    "fillInfoToRegister": MessageLookupByLibrary.simpleMessage(
      "Please fill in the following information to complete registration",
    ),
    "filterSystemApp": MessageLookupByLibrary.simpleMessage(
      "Filter system app",
    ),
    "findProcessMode": MessageLookupByLibrary.simpleMessage("Find process"),
    "findProcessModeDesc": MessageLookupByLibrary.simpleMessage(
      "There is a certain performance loss after opening",
    ),
    "fontFamily": MessageLookupByLibrary.simpleMessage("FontFamily"),
    "forgotPassword": MessageLookupByLibrary.simpleMessage("Forgot Password"),
    "fourColumns": MessageLookupByLibrary.simpleMessage("Four columns"),
    "friendInviteReward": MessageLookupByLibrary.simpleMessage(
      "Earn commission when your invited friends spend",
    ),
    "fruitSaladScheme": MessageLookupByLibrary.simpleMessage("FruitSalad"),
    "general": MessageLookupByLibrary.simpleMessage("General"),
    "generalDesc": MessageLookupByLibrary.simpleMessage(
      "Modify general settings",
    ),
    "generateInviteCode": MessageLookupByLibrary.simpleMessage(
      "Generate invite code",
    ),
    "generatingInviteCode": MessageLookupByLibrary.simpleMessage(
      "Generating invite code...",
    ),
    "geoData": MessageLookupByLibrary.simpleMessage("GeoData"),
    "geodataLoader": MessageLookupByLibrary.simpleMessage(
      "Geo Low Memory Mode",
    ),
    "geodataLoaderDesc": MessageLookupByLibrary.simpleMessage(
      "Enabling will use the Geo low memory loader",
    ),
    "geoipCode": MessageLookupByLibrary.simpleMessage("Geoip code"),
    "getOriginRules": MessageLookupByLibrary.simpleMessage(
      "Get original rules",
    ),
    "global": MessageLookupByLibrary.simpleMessage("Global Proxy"),
    "go": MessageLookupByLibrary.simpleMessage("Go"),
    "goDownload": MessageLookupByLibrary.simpleMessage("Go to download"),
    "goToWeb": MessageLookupByLibrary.simpleMessage("Go to Web"),
    "hasCacheChange": MessageLookupByLibrary.simpleMessage(
      "Do you want to cache the changes?",
    ),
    "hostsDesc": MessageLookupByLibrary.simpleMessage("Add Hosts"),
    "hotkeyConflict": MessageLookupByLibrary.simpleMessage("Hotkey conflict"),
    "hotkeyManagement": MessageLookupByLibrary.simpleMessage(
      "Hotkey Management",
    ),
    "hotkeyManagementDesc": MessageLookupByLibrary.simpleMessage(
      "Use keyboard to control applications",
    ),
    "hours": MessageLookupByLibrary.simpleMessage("Hours"),
    "iUnderstand": MessageLookupByLibrary.simpleMessage("I Understand"),
    "icon": MessageLookupByLibrary.simpleMessage("Icon"),
    "iconConfiguration": MessageLookupByLibrary.simpleMessage(
      "Icon configuration",
    ),
    "iconStyle": MessageLookupByLibrary.simpleMessage("Icon style"),
    "import": MessageLookupByLibrary.simpleMessage("Import"),
    "importFile": MessageLookupByLibrary.simpleMessage("Import from file"),
    "importFromURL": MessageLookupByLibrary.simpleMessage("Import from URL"),
    "importUrl": MessageLookupByLibrary.simpleMessage("Import from URL"),
    "infiniteTime": MessageLookupByLibrary.simpleMessage("Long term effective"),
    "init": MessageLookupByLibrary.simpleMessage("Init"),
    "inputCorrectHotkey": MessageLookupByLibrary.simpleMessage(
      "Please enter the correct hotkey",
    ),
    "intelligentSelected": MessageLookupByLibrary.simpleMessage(
      "Intelligent selection",
    ),
    "internet": MessageLookupByLibrary.simpleMessage("Internet"),
    "interval": MessageLookupByLibrary.simpleMessage("Interval"),
    "intranetIP": MessageLookupByLibrary.simpleMessage("Intranet IP"),
    "invalidTransferAmount": MessageLookupByLibrary.simpleMessage(
      "Please enter valid transfer amount",
    ),
    "invite": MessageLookupByLibrary.simpleMessage("Invite"),
    "inviteCode": MessageLookupByLibrary.simpleMessage("Invite Code"),
    "inviteCodeGenFailed": MessageLookupByLibrary.simpleMessage(
      "Invite code generation failed",
    ),
    "inviteCodeGenerated": MessageLookupByLibrary.simpleMessage(
      "Invite code generated",
    ),
    "inviteCodeOptional": MessageLookupByLibrary.simpleMessage(
      "Invite Code (optional)",
    ),
    "inviteCodeRequired": MessageLookupByLibrary.simpleMessage(
      "Invite Code Required",
    ),
    "inviteCodeRequiredMessage": MessageLookupByLibrary.simpleMessage(
      "Registration requires an invite code. Please contact a registered user to get an invite code before registering.",
    ),
    "inviteLinkCopied": MessageLookupByLibrary.simpleMessage(
      "Invite link copied, share with friends",
    ),
    "inviteRegisterReward": MessageLookupByLibrary.simpleMessage(
      "Invite friends to register and subscribe to earn commission",
    ),
    "inviteRules": MessageLookupByLibrary.simpleMessage("Invite Rules"),
    "inviteStats": MessageLookupByLibrary.simpleMessage("Invite Stats"),
    "ipcidr": MessageLookupByLibrary.simpleMessage("Ipcidr"),
    "ipv6Desc": MessageLookupByLibrary.simpleMessage(
      "When turned on it will be able to receive IPv6 traffic",
    ),
    "ipv6InboundDesc": MessageLookupByLibrary.simpleMessage(
      "Allow IPv6 inbound",
    ),
    "just": MessageLookupByLibrary.simpleMessage("Just"),
    "keepAliveIntervalDesc": MessageLookupByLibrary.simpleMessage(
      "Tcp keep alive interval",
    ),
    "key": MessageLookupByLibrary.simpleMessage("Key"),
    "language": MessageLookupByLibrary.simpleMessage("Language"),
    "layout": MessageLookupByLibrary.simpleMessage("Layout"),
    "light": MessageLookupByLibrary.simpleMessage("Light"),
    "list": MessageLookupByLibrary.simpleMessage("List"),
    "listen": MessageLookupByLibrary.simpleMessage("Listen"),
    "loadMore": MessageLookupByLibrary.simpleMessage("Load More"),
    "loading": MessageLookupByLibrary.simpleMessage("Loading..."),
    "local": MessageLookupByLibrary.simpleMessage("Local"),
    "localBackupDesc": MessageLookupByLibrary.simpleMessage(
      "Backup local data to local",
    ),
    "localRecoveryDesc": MessageLookupByLibrary.simpleMessage(
      "Recovery data from file",
    ),
    "logLevel": MessageLookupByLibrary.simpleMessage("LogLevel"),
    "logcat": MessageLookupByLibrary.simpleMessage("Logcat"),
    "logcatDesc": MessageLookupByLibrary.simpleMessage(
      "When enabled, Logs will appear in the root menu",
    ),
    "loggedOutSuccess": MessageLookupByLibrary.simpleMessage("Signed out"),
    "loginNow": MessageLookupByLibrary.simpleMessage("Login Now"),
    "logout": MessageLookupByLibrary.simpleMessage("Sign out"),
    "logoutConfirmMsg": MessageLookupByLibrary.simpleMessage(
      "Are you sure you want to sign out? You need to sign in again.",
    ),
    "logoutFailed": m7,
    "logs": MessageLookupByLibrary.simpleMessage("Logs"),
    "logsCleared": MessageLookupByLibrary.simpleMessage(
      "Logs and request records cleared",
    ),
    "logsDesc": MessageLookupByLibrary.simpleMessage("Log capture records"),
    "logsTest": MessageLookupByLibrary.simpleMessage("Logs test"),
    "loopback": MessageLookupByLibrary.simpleMessage("Loopback unlock tool"),
    "loopbackDesc": MessageLookupByLibrary.simpleMessage(
      "Used for UWP loopback unlocking",
    ),
    "loose": MessageLookupByLibrary.simpleMessage("Loose"),
    "maxTransferable": m8,
    "memoryInfo": MessageLookupByLibrary.simpleMessage("Memory info"),
    "messageTest": MessageLookupByLibrary.simpleMessage("Message test"),
    "messageTestTip": MessageLookupByLibrary.simpleMessage(
      "This is a message.",
    ),
    "min": MessageLookupByLibrary.simpleMessage("Min"),
    "minimizeOnExit": MessageLookupByLibrary.simpleMessage("Minimize on exit"),
    "minimizeOnExitDesc": MessageLookupByLibrary.simpleMessage(
      "Modify the default system exit event",
    ),
    "minutes": MessageLookupByLibrary.simpleMessage("Minutes"),
    "mixedPort": MessageLookupByLibrary.simpleMessage("Mixed Port"),
    "mode": MessageLookupByLibrary.simpleMessage("Mode"),
    "monochromeScheme": MessageLookupByLibrary.simpleMessage("Monochrome"),
    "months": MessageLookupByLibrary.simpleMessage("Months"),
    "more": MessageLookupByLibrary.simpleMessage("More"),
    "myInviteQr": MessageLookupByLibrary.simpleMessage("My Invite QR"),
    "name": MessageLookupByLibrary.simpleMessage("Name"),
    "nameSort": MessageLookupByLibrary.simpleMessage("Sort by name"),
    "nameserver": MessageLookupByLibrary.simpleMessage("Nameserver"),
    "nameserverDesc": MessageLookupByLibrary.simpleMessage(
      "For resolving domain",
    ),
    "nameserverPolicy": MessageLookupByLibrary.simpleMessage(
      "Nameserver policy",
    ),
    "nameserverPolicyDesc": MessageLookupByLibrary.simpleMessage(
      "Specify the corresponding nameserver policy",
    ),
    "network": MessageLookupByLibrary.simpleMessage("Network"),
    "networkDesc": MessageLookupByLibrary.simpleMessage(
      "Modify network-related settings",
    ),
    "networkDetection": MessageLookupByLibrary.simpleMessage(
      "Network detection",
    ),
    "networkSpeed": MessageLookupByLibrary.simpleMessage("Network speed"),
    "neutralScheme": MessageLookupByLibrary.simpleMessage("Neutral"),
    "newMessageFromSupport": MessageLookupByLibrary.simpleMessage(
      "New message from support",
    ),
    "newPassword": MessageLookupByLibrary.simpleMessage("New Password"),
    "noCommissionRecord": MessageLookupByLibrary.simpleMessage(
      "No commission records",
    ),
    "noData": MessageLookupByLibrary.simpleMessage("No data"),
    "noHotKey": MessageLookupByLibrary.simpleMessage("No HotKey"),
    "noIcon": MessageLookupByLibrary.simpleMessage("None"),
    "noInfo": MessageLookupByLibrary.simpleMessage("No info"),
    "noInvitationData": MessageLookupByLibrary.simpleMessage(
      "No invitation data",
    ),
    "noInviteCode": MessageLookupByLibrary.simpleMessage("No invite code"),
    "noMoreInfoDesc": MessageLookupByLibrary.simpleMessage("No more info"),
    "noNetwork": MessageLookupByLibrary.simpleMessage("No network"),
    "noNetworkApp": MessageLookupByLibrary.simpleMessage("No network APP"),
    "noProxy": MessageLookupByLibrary.simpleMessage("No proxy"),
    "noProxyDesc": MessageLookupByLibrary.simpleMessage(
      "Please create a profile or add a valid profile",
    ),
    "noResolve": MessageLookupByLibrary.simpleMessage("No resolve IP"),
    "nodeSelection": MessageLookupByLibrary.simpleMessage("Node Selection"),
    "none": MessageLookupByLibrary.simpleMessage("none"),
    "notConnected": MessageLookupByLibrary.simpleMessage("Not connected"),
    "notSelectedTip": MessageLookupByLibrary.simpleMessage(
      "The current proxy group cannot be selected.",
    ),
    "nullProfileDesc": MessageLookupByLibrary.simpleMessage(
      "No profile, Please add a profile",
    ),
    "nullTip": m9,
    "numberTip": m10,
    "officialWebsite": MessageLookupByLibrary.simpleMessage("Website"),
    "oneColumn": MessageLookupByLibrary.simpleMessage("One column"),
    "onlineSupport": MessageLookupByLibrary.simpleMessage("Support"),
    "onlineSupportAddMore": MessageLookupByLibrary.simpleMessage("Add More"),
    "onlineSupportApiConfigNotFound": MessageLookupByLibrary.simpleMessage(
      "Online support API configuration not found, please check configuration",
    ),
    "onlineSupportCancel": MessageLookupByLibrary.simpleMessage("Cancel"),
    "onlineSupportClearHistory": MessageLookupByLibrary.simpleMessage(
      "Clear history",
    ),
    "onlineSupportClearHistoryConfirm": MessageLookupByLibrary.simpleMessage(
      "Are you sure you want to clear all chat history? This action cannot be undone.",
    ),
    "onlineSupportClickToSelect": MessageLookupByLibrary.simpleMessage(
      "Click to select images",
    ),
    "onlineSupportConfirm": MessageLookupByLibrary.simpleMessage("Confirm"),
    "onlineSupportConnected": MessageLookupByLibrary.simpleMessage(
      "Successfully connected to support system",
    ),
    "onlineSupportConnecting": MessageLookupByLibrary.simpleMessage(
      "Connecting...",
    ),
    "onlineSupportConnectionError": MessageLookupByLibrary.simpleMessage(
      "Connection error",
    ),
    "onlineSupportDisconnected": MessageLookupByLibrary.simpleMessage(
      "Disconnected",
    ),
    "onlineSupportGetMessagesFailed": m11,
    "onlineSupportInputHint": MessageLookupByLibrary.simpleMessage(
      "Please enter your question...",
    ),
    "onlineSupportNoMessages": MessageLookupByLibrary.simpleMessage(
      "No messages yet, send a message to start consultation",
    ),
    "onlineSupportSelectImages": MessageLookupByLibrary.simpleMessage(
      "Select Images",
    ),
    "onlineSupportSelectImagesFailed": m12,
    "onlineSupportSend": MessageLookupByLibrary.simpleMessage("Send"),
    "onlineSupportSendImage": MessageLookupByLibrary.simpleMessage(
      "Send image",
    ),
    "onlineSupportSendMessageFailed": MessageLookupByLibrary.simpleMessage(
      "Failed to send message: Unable to get authentication token",
    ),
    "onlineSupportSupportedFormats": MessageLookupByLibrary.simpleMessage(
      "Supports JPG, PNG, GIF, WebP, BMP\nMax 10MB",
    ),
    "onlineSupportTitle": MessageLookupByLibrary.simpleMessage(
      "Online Support",
    ),
    "onlineSupportTokenNotFound": MessageLookupByLibrary.simpleMessage(
      "Authentication token not found",
    ),
    "onlineSupportUnsupportedHttpMethod": m13,
    "onlineSupportUploadFailed": m14,
    "onlineSupportWebSocketConfigNotFound": MessageLookupByLibrary.simpleMessage(
      "Online support WebSocket configuration not found, please check configuration",
    ),
    "onlyIcon": MessageLookupByLibrary.simpleMessage("Icon"),
    "onlyOtherApps": MessageLookupByLibrary.simpleMessage(
      "Only third-party apps",
    ),
    "onlyStatisticsProxy": MessageLookupByLibrary.simpleMessage(
      "Only statistics proxy",
    ),
    "onlyStatisticsProxyDesc": MessageLookupByLibrary.simpleMessage(
      "When turned on, only statistics proxy traffic",
    ),
    "openWebFailed": MessageLookupByLibrary.simpleMessage(
      "Failed to open web, please visit manually",
    ),
    "options": MessageLookupByLibrary.simpleMessage("Options"),
    "orderAmount": m15,
    "orderNumber": m16,
    "other": MessageLookupByLibrary.simpleMessage("Other"),
    "otherContributors": MessageLookupByLibrary.simpleMessage(
      "Other contributors",
    ),
    "outboundMode": MessageLookupByLibrary.simpleMessage("Outbound mode"),
    "override": MessageLookupByLibrary.simpleMessage("Override"),
    "overrideDesc": MessageLookupByLibrary.simpleMessage(
      "Override Proxy related config",
    ),
    "overrideDns": MessageLookupByLibrary.simpleMessage("Override Dns"),
    "overrideDnsDesc": MessageLookupByLibrary.simpleMessage(
      "Turning it on will override the DNS options in the profile",
    ),
    "overrideInvalidTip": MessageLookupByLibrary.simpleMessage(
      "Does not take effect in script mode",
    ),
    "overrideOriginRules": MessageLookupByLibrary.simpleMessage(
      "Override the original rule",
    ),
    "pageNumber": m17,
    "palette": MessageLookupByLibrary.simpleMessage("Palette"),
    "password": MessageLookupByLibrary.simpleMessage("Password"),
    "passwordMin8Chars": MessageLookupByLibrary.simpleMessage(
      "Password must be at least 8 characters",
    ),
    "passwordMinLength": MessageLookupByLibrary.simpleMessage(
      "Password must be at least 6 characters",
    ),
    "passwordMismatch": MessageLookupByLibrary.simpleMessage(
      "Passwords do not match",
    ),
    "passwordResetFailed": MessageLookupByLibrary.simpleMessage(
      "Password reset failed",
    ),
    "passwordResetSuccessful": MessageLookupByLibrary.simpleMessage(
      "Password reset successful! Please login with your new password",
    ),
    "passwordsDoNotMatch": MessageLookupByLibrary.simpleMessage(
      "Passwords do not match",
    ),
    "paste": MessageLookupByLibrary.simpleMessage("Paste"),
    "pendingCommission": MessageLookupByLibrary.simpleMessage("Pending"),
    "pendingCommissionTooltipCommissionBalance":
        MessageLookupByLibrary.simpleMessage(
          "Commissions are automatically confirmed three days after your friend places an order and added to the commission balance.",
        ),
    "pendingCommissionTooltipWalletBalance": MessageLookupByLibrary.simpleMessage(
      "Commissions are automatically confirmed three days after your friend places an order and added to the wallet balance.",
    ),
    "plans": MessageLookupByLibrary.simpleMessage("Plans"),
    "pleaseBindWebDAV": MessageLookupByLibrary.simpleMessage(
      "Please bind WebDAV",
    ),
    "pleaseConfirmNewPassword": MessageLookupByLibrary.simpleMessage(
      "Please re-enter new password",
    ),
    "pleaseConfirmPassword": MessageLookupByLibrary.simpleMessage(
      "Please confirm password",
    ),
    "pleaseEnterAtLeast8CharsPassword": MessageLookupByLibrary.simpleMessage(
      "Please enter at least 8 characters password",
    ),
    "pleaseEnterEmail": MessageLookupByLibrary.simpleMessage(
      "Please enter email address",
    ),
    "pleaseEnterEmailAddress": MessageLookupByLibrary.simpleMessage(
      "Please enter email address",
    ),
    "pleaseEnterEmailVerificationCode": MessageLookupByLibrary.simpleMessage(
      "Please enter email verification code",
    ),
    "pleaseEnterInviteCode": MessageLookupByLibrary.simpleMessage(
      "Please enter invite code",
    ),
    "pleaseEnterNewPassword": MessageLookupByLibrary.simpleMessage(
      "Please enter new password",
    ),
    "pleaseEnterPassword": MessageLookupByLibrary.simpleMessage(
      "Please enter password",
    ),
    "pleaseEnterScriptName": MessageLookupByLibrary.simpleMessage(
      "Please enter a script name",
    ),
    "pleaseEnterValidEmail": MessageLookupByLibrary.simpleMessage(
      "Please enter a valid email address",
    ),
    "pleaseEnterValidEmailAddress": MessageLookupByLibrary.simpleMessage(
      "Please enter a valid email address",
    ),
    "pleaseEnterValidVerificationCode": MessageLookupByLibrary.simpleMessage(
      "Please enter a valid verification code",
    ),
    "pleaseEnterVerificationCode": MessageLookupByLibrary.simpleMessage(
      "Please enter email verification code",
    ),
    "pleaseEnterWithdrawAccount": MessageLookupByLibrary.simpleMessage(
      "Please enter withdrawal account",
    ),
    "pleaseEnterYourEmailAddress": MessageLookupByLibrary.simpleMessage(
      "Please enter your email address",
    ),
    "pleaseInputAdminPassword": MessageLookupByLibrary.simpleMessage(
      "Please enter the admin password",
    ),
    "pleaseReEnterPassword": MessageLookupByLibrary.simpleMessage(
      "Please re-enter password",
    ),
    "pleaseSelectWithdrawMethod": MessageLookupByLibrary.simpleMessage(
      "Please select a withdrawal method",
    ),
    "pleaseUploadFile": MessageLookupByLibrary.simpleMessage(
      "Please upload file",
    ),
    "pleaseUploadValidQrcode": MessageLookupByLibrary.simpleMessage(
      "Please upload a valid QR code",
    ),
    "port": MessageLookupByLibrary.simpleMessage("Port"),
    "portConflictTip": MessageLookupByLibrary.simpleMessage(
      "Please enter a different port",
    ),
    "portTip": m18,
    "preferH3Desc": MessageLookupByLibrary.simpleMessage(
      "Prioritize the use of DOH\'s http/3",
    ),
    "pressKeyboard": MessageLookupByLibrary.simpleMessage(
      "Please press the keyboard.",
    ),
    "preview": MessageLookupByLibrary.simpleMessage("Preview"),
    "profile": MessageLookupByLibrary.simpleMessage("Profile"),
    "profileAutoUpdateIntervalInvalidValidationDesc":
        MessageLookupByLibrary.simpleMessage(
          "Please input a valid interval time format",
        ),
    "profileAutoUpdateIntervalNullValidationDesc":
        MessageLookupByLibrary.simpleMessage(
          "Please enter the auto update interval time",
        ),
    "profileHasUpdate": MessageLookupByLibrary.simpleMessage(
      "The profile has been modified. Do you want to disable auto update?",
    ),
    "profileNameNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "Please input the profile name",
    ),
    "profileParseErrorDesc": MessageLookupByLibrary.simpleMessage(
      "profile parse error",
    ),
    "profileUrlInvalidValidationDesc": MessageLookupByLibrary.simpleMessage(
      "Please input a valid profile URL",
    ),
    "profileUrlNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "Please input the profile URL",
    ),
    "profiles": MessageLookupByLibrary.simpleMessage("Profiles"),
    "profilesSort": MessageLookupByLibrary.simpleMessage("Profiles sort"),
    "project": MessageLookupByLibrary.simpleMessage("Project"),
    "providers": MessageLookupByLibrary.simpleMessage("Providers"),
    "proxies": MessageLookupByLibrary.simpleMessage("Proxies"),
    "proxiesSetting": MessageLookupByLibrary.simpleMessage("Proxies setting"),
    "proxyGroup": MessageLookupByLibrary.simpleMessage("Proxy group"),
    "proxyNameserver": MessageLookupByLibrary.simpleMessage("Proxy nameserver"),
    "proxyNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "Domain for resolving proxy nodes",
    ),
    "proxyPort": MessageLookupByLibrary.simpleMessage("ProxyPort"),
    "proxyPortDesc": MessageLookupByLibrary.simpleMessage(
      "Set the Clash listening port",
    ),
    "proxyProviders": MessageLookupByLibrary.simpleMessage("Proxy providers"),
    "pureBlackMode": MessageLookupByLibrary.simpleMessage("Pure black mode"),
    "qrcode": MessageLookupByLibrary.simpleMessage("QR code"),
    "qrcodeDesc": MessageLookupByLibrary.simpleMessage(
      "Scan QR code to obtain profile",
    ),
    "rainbowScheme": MessageLookupByLibrary.simpleMessage("Rainbow"),
    "recovery": MessageLookupByLibrary.simpleMessage("Recovery"),
    "recoveryAll": MessageLookupByLibrary.simpleMessage("Recovery all data"),
    "recoveryProfiles": MessageLookupByLibrary.simpleMessage(
      "Only recovery profiles",
    ),
    "recoveryStrategy": MessageLookupByLibrary.simpleMessage(
      "Recovery strategy",
    ),
    "recoveryStrategy_compatible": MessageLookupByLibrary.simpleMessage(
      "Compatible",
    ),
    "recoveryStrategy_override": MessageLookupByLibrary.simpleMessage(
      "Override",
    ),
    "recoverySuccess": MessageLookupByLibrary.simpleMessage("Recovery success"),
    "redirPort": MessageLookupByLibrary.simpleMessage("Redir Port"),
    "redo": MessageLookupByLibrary.simpleMessage("redo"),
    "refresh": MessageLookupByLibrary.simpleMessage("Refresh"),
    "regExp": MessageLookupByLibrary.simpleMessage("RegExp"),
    "registerAccount": MessageLookupByLibrary.simpleMessage("Register Account"),
    "registerSuccessSaveCredentials": MessageLookupByLibrary.simpleMessage(
      "Registration successful - Saving credentials:",
    ),
    "registrationFailed": m19,
    "rememberPassword": MessageLookupByLibrary.simpleMessage(
      "Remember your password?",
    ),
    "remote": MessageLookupByLibrary.simpleMessage("Remote"),
    "remoteBackupDesc": MessageLookupByLibrary.simpleMessage(
      "Backup local data to WebDAV",
    ),
    "remoteRecoveryDesc": MessageLookupByLibrary.simpleMessage(
      "Recovery data from WebDAV",
    ),
    "remove": MessageLookupByLibrary.simpleMessage("Remove"),
    "rename": MessageLookupByLibrary.simpleMessage("Rename"),
    "requests": MessageLookupByLibrary.simpleMessage("Requests"),
    "requestsDesc": MessageLookupByLibrary.simpleMessage(
      "View recently request records",
    ),
    "resendVerificationCode": MessageLookupByLibrary.simpleMessage(
      "Resend Verification Code",
    ),
    "reset": MessageLookupByLibrary.simpleMessage("Reset"),
    "resetPassword": MessageLookupByLibrary.simpleMessage("Reset Password"),
    "resetTip": MessageLookupByLibrary.simpleMessage("Make sure to reset"),
    "resources": MessageLookupByLibrary.simpleMessage("Resources"),
    "resourcesDesc": MessageLookupByLibrary.simpleMessage(
      "External resource related info",
    ),
    "respectRules": MessageLookupByLibrary.simpleMessage("Respect rules"),
    "respectRulesDesc": MessageLookupByLibrary.simpleMessage(
      "DNS connection following rules, need to configure proxy-server-nameserver",
    ),
    "routeAddress": MessageLookupByLibrary.simpleMessage("Route address"),
    "routeAddressDesc": MessageLookupByLibrary.simpleMessage(
      "Config listen route address",
    ),
    "routeMode": MessageLookupByLibrary.simpleMessage("Route mode"),
    "routeMode_bypassPrivate": MessageLookupByLibrary.simpleMessage(
      "Bypass private route address",
    ),
    "routeMode_config": MessageLookupByLibrary.simpleMessage("Use config"),
    "rule": MessageLookupByLibrary.simpleMessage("Smart Routing"),
    "ruleName": MessageLookupByLibrary.simpleMessage("Rule name"),
    "ruleProviders": MessageLookupByLibrary.simpleMessage("Rule providers"),
    "ruleTarget": MessageLookupByLibrary.simpleMessage("Rule target"),
    "save": MessageLookupByLibrary.simpleMessage("Save"),
    "saveChanges": MessageLookupByLibrary.simpleMessage(
      "Do you want to save the changes?",
    ),
    "saveQr": MessageLookupByLibrary.simpleMessage("Save QR"),
    "saveQrCodeFeature": MessageLookupByLibrary.simpleMessage(
      "Save QR feature coming soon",
    ),
    "saveTip": MessageLookupByLibrary.simpleMessage(
      "Are you sure you want to save?",
    ),
    "script": MessageLookupByLibrary.simpleMessage("Script"),
    "search": MessageLookupByLibrary.simpleMessage("Search"),
    "seconds": MessageLookupByLibrary.simpleMessage("Seconds"),
    "selectAll": MessageLookupByLibrary.simpleMessage("Select all"),
    "selectTheme": MessageLookupByLibrary.simpleMessage("Select Theme"),
    "selected": MessageLookupByLibrary.simpleMessage("Selected"),
    "selectedCountTitle": m20,
    "sendCodeFailed": MessageLookupByLibrary.simpleMessage(
      "Failed to send verification code",
    ),
    "sendVerificationCode": MessageLookupByLibrary.simpleMessage(
      "Send Verification Code",
    ),
    "sendVerificationCodeFailed": m21,
    "setNewPassword": MessageLookupByLibrary.simpleMessage("Set New Password"),
    "settings": MessageLookupByLibrary.simpleMessage("Settings"),
    "show": MessageLookupByLibrary.simpleMessage("Show Window"),
    "shrink": MessageLookupByLibrary.simpleMessage("Shrink"),
    "silentLaunch": MessageLookupByLibrary.simpleMessage("SilentLaunch"),
    "silentLaunchDesc": MessageLookupByLibrary.simpleMessage(
      "Start in the background",
    ),
    "size": MessageLookupByLibrary.simpleMessage("Size"),
    "socksPort": MessageLookupByLibrary.simpleMessage("Socks Port"),
    "sort": MessageLookupByLibrary.simpleMessage("Sort"),
    "source": MessageLookupByLibrary.simpleMessage("Source"),
    "sourceIp": MessageLookupByLibrary.simpleMessage("Source IP"),
    "stackMode": MessageLookupByLibrary.simpleMessage("Stack mode"),
    "standard": MessageLookupByLibrary.simpleMessage("Standard"),
    "start": MessageLookupByLibrary.simpleMessage("Connect"),
    "startVpn": MessageLookupByLibrary.simpleMessage("Starting VPN..."),
    "status": MessageLookupByLibrary.simpleMessage("Status"),
    "statusDesc": MessageLookupByLibrary.simpleMessage(
      "System DNS will be used when turned off",
    ),
    "stop": MessageLookupByLibrary.simpleMessage("Disconnect"),
    "stopVpn": MessageLookupByLibrary.simpleMessage("Stopping VPN..."),
    "style": MessageLookupByLibrary.simpleMessage("Style"),
    "subRule": MessageLookupByLibrary.simpleMessage("Sub rule"),
    "submit": MessageLookupByLibrary.simpleMessage("Submit"),
    "subscriptionExpired": MessageLookupByLibrary.simpleMessage(
      "Subscription expired",
    ),
    "subscriptionExpiredDetail": m22,
    "subscriptionExpiresToday": MessageLookupByLibrary.simpleMessage(
      "Subscription expires today",
    ),
    "subscriptionExpiresTodayDetail": MessageLookupByLibrary.simpleMessage(
      "Plan will expire today, please renew immediately to avoid service interruption",
    ),
    "subscriptionExpiringInDays": MessageLookupByLibrary.simpleMessage(
      "Subscription expiring soon",
    ),
    "subscriptionExpiringInDaysDetail": m23,
    "subscriptionImportFailed": MessageLookupByLibrary.simpleMessage(
      "Subscription import failed",
    ),
    "subscriptionImportSuccess": MessageLookupByLibrary.simpleMessage(
      "Subscription imported",
    ),
    "subscriptionNoSubscription": MessageLookupByLibrary.simpleMessage(
      "No subscription",
    ),
    "subscriptionNoSubscriptionDetail": MessageLookupByLibrary.simpleMessage(
      "No available subscription plan found, please purchase a plan to use",
    ),
    "subscriptionNotLoggedIn": MessageLookupByLibrary.simpleMessage(
      "Not logged in",
    ),
    "subscriptionNotLoggedInDetail": MessageLookupByLibrary.simpleMessage(
      "Please login first",
    ),
    "subscriptionTrafficExhausted": MessageLookupByLibrary.simpleMessage(
      "Traffic exhausted",
    ),
    "subscriptionTrafficExhaustedDetail": MessageLookupByLibrary.simpleMessage(
      "Plan traffic has been used up, please reset traffic or change plan",
    ),
    "subscriptionUpdateFailed": MessageLookupByLibrary.simpleMessage(
      "Subscription update failed",
    ),
    "subscriptionUpdateSuccess": MessageLookupByLibrary.simpleMessage(
      "Subscription updated",
    ),
    "subscriptionValid": MessageLookupByLibrary.simpleMessage(
      "Subscription valid",
    ),
    "subscriptionValidDetail": m24,
    "switchTheme": MessageLookupByLibrary.simpleMessage("Switch Theme"),
    "sync": MessageLookupByLibrary.simpleMessage("Sync"),
    "system": MessageLookupByLibrary.simpleMessage("System"),
    "systemApp": MessageLookupByLibrary.simpleMessage("System APP"),
    "systemFont": MessageLookupByLibrary.simpleMessage("System font"),
    "systemProxy": MessageLookupByLibrary.simpleMessage("System proxy"),
    "systemProxyDesc": MessageLookupByLibrary.simpleMessage(
      "Attach HTTP proxy to VpnService",
    ),
    "tab": MessageLookupByLibrary.simpleMessage("Tab"),
    "tapToConnect": MessageLookupByLibrary.simpleMessage("Tap to connect"),
    "tcpConcurrent": MessageLookupByLibrary.simpleMessage("TCP concurrent"),
    "tcpConcurrentDesc": MessageLookupByLibrary.simpleMessage(
      "Enabling it will allow TCP concurrency",
    ),
    "testUrl": MessageLookupByLibrary.simpleMessage("Test url"),
    "textScale": MessageLookupByLibrary.simpleMessage("Text Scaling"),
    "theme": MessageLookupByLibrary.simpleMessage("Theme"),
    "themeColor": MessageLookupByLibrary.simpleMessage("Theme color"),
    "themeDesc": MessageLookupByLibrary.simpleMessage(
      "Set dark mode,adjust the color",
    ),
    "themeMode": MessageLookupByLibrary.simpleMessage("Theme mode"),
    "threeColumns": MessageLookupByLibrary.simpleMessage("Three columns"),
    "ticketRecords": MessageLookupByLibrary.simpleMessage("Ticket"),
    "tight": MessageLookupByLibrary.simpleMessage("Tight"),
    "time": MessageLookupByLibrary.simpleMessage("Time"),
    "tip": MessageLookupByLibrary.simpleMessage("tip"),
    "toggle": MessageLookupByLibrary.simpleMessage("Toggle"),
    "tonalSpotScheme": MessageLookupByLibrary.simpleMessage("TonalSpot"),
    "tools": MessageLookupByLibrary.simpleMessage("Tools"),
    "totalCommission": MessageLookupByLibrary.simpleMessage("Earnings"),
    "totalInvites": MessageLookupByLibrary.simpleMessage("Invites"),
    "totalRecords": m25,
    "tproxyPort": MessageLookupByLibrary.simpleMessage("Tproxy Port"),
    "trafficUsage": MessageLookupByLibrary.simpleMessage("Traffic usage"),
    "transfer": MessageLookupByLibrary.simpleMessage("Transfer"),
    "transferAmount": MessageLookupByLibrary.simpleMessage("Transfer Amount"),
    "transferAmountExceeded": m26,
    "transferFailed": m27,
    "transferNote": MessageLookupByLibrary.simpleMessage(
      "Transferred balance can be used for in-app purchases",
    ),
    "transferSuccess": MessageLookupByLibrary.simpleMessage(
      "Transfer Success!",
    ),
    "transferSuccessMsg": m28,
    "transferToWallet": MessageLookupByLibrary.simpleMessage(
      "Transfer to Wallet",
    ),
    "transferring": MessageLookupByLibrary.simpleMessage("Transferring..."),
    "trayDisconnect": MessageLookupByLibrary.simpleMessage(
      "Disconnect connection",
    ),
    "trayStartConnection": MessageLookupByLibrary.simpleMessage(
      "Start connection",
    ),
    "tun": MessageLookupByLibrary.simpleMessage(
      "Virtual network adapter (TUN)",
    ),
    "tunDesc": MessageLookupByLibrary.simpleMessage(
      "only effective in administrator mode",
    ),
    "twoColumns": MessageLookupByLibrary.simpleMessage("Two columns"),
    "unableToUpdateCurrentProfileDesc": MessageLookupByLibrary.simpleMessage(
      "unable to update current profile",
    ),
    "undo": MessageLookupByLibrary.simpleMessage("undo"),
    "unifiedDelay": MessageLookupByLibrary.simpleMessage("Unified delay"),
    "unifiedDelayDesc": MessageLookupByLibrary.simpleMessage(
      "Remove extra delays such as handshaking",
    ),
    "unknown": MessageLookupByLibrary.simpleMessage("Unknown"),
    "unnamed": MessageLookupByLibrary.simpleMessage("Unnamed"),
    "update": MessageLookupByLibrary.simpleMessage("Update"),
    "updateCheckAllServersUnavailable": MessageLookupByLibrary.simpleMessage(
      "All configured update servers are unavailable",
    ),
    "updateCheckCurrentVersion": m29,
    "updateCheckForceUpdate": m30,
    "updateCheckMustUpdate": MessageLookupByLibrary.simpleMessage(
      "Must Update",
    ),
    "updateCheckNewVersionFound": m31,
    "updateCheckNoServerUrlsConfigured": MessageLookupByLibrary.simpleMessage(
      "No update server URLs configured, please check configuration",
    ),
    "updateCheckReleaseNotes": MessageLookupByLibrary.simpleMessage(
      "Release Notes:",
    ),
    "updateCheckServerError": m32,
    "updateCheckServerTemporarilyUnavailable":
        MessageLookupByLibrary.simpleMessage(
          "Server temporarily unavailable, please try again later",
        ),
    "updateCheckServerUrlNotConfigured": MessageLookupByLibrary.simpleMessage(
      "Update server URL not configured, please check configuration",
    ),
    "updateCheckUpdateLater": MessageLookupByLibrary.simpleMessage(
      "Update Later",
    ),
    "updateCheckUpdateNow": MessageLookupByLibrary.simpleMessage("Update Now"),
    "upload": MessageLookupByLibrary.simpleMessage("Upload"),
    "url": MessageLookupByLibrary.simpleMessage("URL"),
    "urlDesc": MessageLookupByLibrary.simpleMessage(
      "Obtain profile through URL",
    ),
    "urlTip": m33,
    "useHosts": MessageLookupByLibrary.simpleMessage("Use hosts"),
    "useSystemHosts": MessageLookupByLibrary.simpleMessage("Use system hosts"),
    "userCenter": MessageLookupByLibrary.simpleMessage("User Center"),
    "value": MessageLookupByLibrary.simpleMessage("Value"),
    "verificationCode": MessageLookupByLibrary.simpleMessage(
      "Verification Code",
    ),
    "verificationCode6Digits": MessageLookupByLibrary.simpleMessage(
      "Verification code should be 6 digits",
    ),
    "verificationCodeSent": MessageLookupByLibrary.simpleMessage(
      "Verification code has been sent to your email, please check",
    ),
    "verificationCodeSentCheckEmail": MessageLookupByLibrary.simpleMessage(
      "Verification code sent, please check your email",
    ),
    "verificationCodeSentTo": m34,
    "vibrantScheme": MessageLookupByLibrary.simpleMessage("Vibrant"),
    "view": MessageLookupByLibrary.simpleMessage("View"),
    "viewHistory": MessageLookupByLibrary.simpleMessage("View History"),
    "visitWebVersion": MessageLookupByLibrary.simpleMessage(
      "Please visit web version to withdraw",
    ),
    "vpnDesc": MessageLookupByLibrary.simpleMessage(
      "Modify VPN related settings",
    ),
    "vpnEnableDesc": MessageLookupByLibrary.simpleMessage(
      "Auto routes all system traffic through VpnService",
    ),
    "vpnSystemProxyDesc": MessageLookupByLibrary.simpleMessage(
      "Attach HTTP proxy to VpnService",
    ),
    "vpnTip": MessageLookupByLibrary.simpleMessage(
      "Changes take effect after restarting the VPN",
    ),
    "walletBalance": MessageLookupByLibrary.simpleMessage("Balance"),
    "walletDetails": MessageLookupByLibrary.simpleMessage("Wallet Details"),
    "webDAVConfiguration": MessageLookupByLibrary.simpleMessage(
      "WebDAV configuration",
    ),
    "whitelistMode": MessageLookupByLibrary.simpleMessage("Whitelist mode"),
    "withdraw": MessageLookupByLibrary.simpleMessage("Withdraw"),
    "withdrawAccount": MessageLookupByLibrary.simpleMessage(
      "Withdrawal account",
    ),
    "withdrawCommission": MessageLookupByLibrary.simpleMessage(
      "Withdraw Commission",
    ),
    "withdrawMethod": MessageLookupByLibrary.simpleMessage("Withdrawal method"),
    "withdrawRequestSubmitted": MessageLookupByLibrary.simpleMessage(
      "Withdrawal request submitted",
    ),
    "withdrawRequestSubmittedWaitReview": MessageLookupByLibrary.simpleMessage(
      "Withdrawal request submitted, please wait for review",
    ),
    "withdrawSubmissionFailed": MessageLookupByLibrary.simpleMessage(
      "Submission failed",
    ),
    "withdrawSubmissionFailedWithError": m35,
    "withdrawSubmissionNote": MessageLookupByLibrary.simpleMessage(
      "The withdrawal request will be submitted through the ticket system. Please wait for admin review.",
    ),
    "withdrawableAmount": m36,
    "withdrawalAvailable": MessageLookupByLibrary.simpleMessage(
      "Available commission can be withdrawn",
    ),
    "xboard": MessageLookupByLibrary.simpleMessage("Home"),
    "xboard24HourCustomerService": MessageLookupByLibrary.simpleMessage(
      "24-hour customer service support",
    ),
    "xboardAccountBalance": MessageLookupByLibrary.simpleMessage("Balance"),
    "xboardAccountBanned": MessageLookupByLibrary.simpleMessage(
      "Account banned",
    ),
    "xboardAccountBannedDetail": MessageLookupByLibrary.simpleMessage(
      "This account has been banned. Please contact support.",
    ),
    "xboardAccountInfo": MessageLookupByLibrary.simpleMessage("My Account"),
    "xboardAccountManagement": MessageLookupByLibrary.simpleMessage(
      "Account management",
    ),
    "xboardActualPaidAmount": MessageLookupByLibrary.simpleMessage(
      "Payable amount",
    ),
    "xboardAddLinkToConfig": MessageLookupByLibrary.simpleMessage(
      "Add this subscription link to your configuration",
    ),
    "xboardAddingToConfigList": MessageLookupByLibrary.simpleMessage(
      "Adding to configuration list",
    ),
    "xboardAfterPurchasingPlan": MessageLookupByLibrary.simpleMessage(
      "After purchasing a plan, you will enjoy:",
    ),
    "xboardApiUrlNotConfigured": MessageLookupByLibrary.simpleMessage(
      "API URL not configured",
    ),
    "xboardAutoCheckEvery5Seconds": MessageLookupByLibrary.simpleMessage(
      "System checks every 5 seconds, will redirect automatically after payment",
    ),
    "xboardAutoDetectPaymentStatus": MessageLookupByLibrary.simpleMessage(
      "Auto-detect payment status",
    ),
    "xboardAutoOpeningPaymentPage": MessageLookupByLibrary.simpleMessage(
      "Auto-opening payment page, please return to app after payment",
    ),
    "xboardAutoRenewal": MessageLookupByLibrary.simpleMessage("Auto renewal"),
    "xboardAutoRenewalDescription": MessageLookupByLibrary.simpleMessage(
      "Your balance will be used to renew the plan before it expires. Keep enough balance available.",
    ),
    "xboardAutoRenewalDisabled": MessageLookupByLibrary.simpleMessage(
      "Auto renewal disabled",
    ),
    "xboardAutoRenewalEnabled": MessageLookupByLibrary.simpleMessage(
      "Auto renewal enabled",
    ),
    "xboardAutoRenewalNoPlan": MessageLookupByLibrary.simpleMessage(
      "Purchase a plan to enable auto renewal.",
    ),
    "xboardAutoRenewalUpdateFailed": MessageLookupByLibrary.simpleMessage(
      "Could not update auto renewal. Try again later.",
    ),
    "xboardAutoTesting": MessageLookupByLibrary.simpleMessage("Auto testing"),
    "xboardBack": MessageLookupByLibrary.simpleMessage("Back"),
    "xboardBalancePay": MessageLookupByLibrary.simpleMessage(
      "Pay with balance",
    ),
    "xboardBalanceWithAmount": m37,
    "xboardBrowserNotOpenedTip": MessageLookupByLibrary.simpleMessage(
      "If browser doesn\'t open automatically, click \\\"Reopen\\\" or copy link manually",
    ),
    "xboardBuyMoreTrafficOrUpgrade": MessageLookupByLibrary.simpleMessage(
      "Please buy more traffic or upgrade plan",
    ),
    "xboardBuyNow": MessageLookupByLibrary.simpleMessage("Buy Now"),
    "xboardBuyPlan": MessageLookupByLibrary.simpleMessage("Buy plan"),
    "xboardBuyoutPlan": MessageLookupByLibrary.simpleMessage("Buyout plan"),
    "xboardCancel": MessageLookupByLibrary.simpleMessage("Cancel"),
    "xboardCancelOrder": MessageLookupByLibrary.simpleMessage("Cancel order"),
    "xboardCancelPayment": MessageLookupByLibrary.simpleMessage(
      "Cancel payment",
    ),
    "xboardCanceling": MessageLookupByLibrary.simpleMessage("Canceling..."),
    "xboardChangePassword": MessageLookupByLibrary.simpleMessage(
      "Change password",
    ),
    "xboardCheckOrders": MessageLookupByLibrary.simpleMessage("View orders"),
    "xboardCheckPaymentFailed": MessageLookupByLibrary.simpleMessage(
      "Failed to check payment status",
    ),
    "xboardCheckPaymentStatus": MessageLookupByLibrary.simpleMessage(
      "Check payment status",
    ),
    "xboardCheckStatus": MessageLookupByLibrary.simpleMessage("Check status"),
    "xboardChecking": MessageLookupByLibrary.simpleMessage("Checking"),
    "xboardCheckingCachedSubscription": MessageLookupByLibrary.simpleMessage(
      "Offline mode: checking cached subscription",
    ),
    "xboardCheckingSubscription": MessageLookupByLibrary.simpleMessage(
      "Checking subscription",
    ),
    "xboardCleaningOldConfig": MessageLookupByLibrary.simpleMessage(
      "Cleaning old configuration",
    ),
    "xboardClearError": MessageLookupByLibrary.simpleMessage("Clear error"),
    "xboardClickToCopy": MessageLookupByLibrary.simpleMessage("Click to copy"),
    "xboardClickToSetupNodes": MessageLookupByLibrary.simpleMessage(
      "Click to setup nodes",
    ),
    "xboardCloseTicket": MessageLookupByLibrary.simpleMessage("Close ticket"),
    "xboardCloseTicketConfirm": MessageLookupByLibrary.simpleMessage(
      "Close this ticket? You will not be able to reply after it is closed.",
    ),
    "xboardCommissionConfirmed": MessageLookupByLibrary.simpleMessage(
      "Confirmed",
    ),
    "xboardCommissionIssuing": MessageLookupByLibrary.simpleMessage("Issuing"),
    "xboardCommissionOffsetAmount": MessageLookupByLibrary.simpleMessage(
      "Commission deduction",
    ),
    "xboardCompletePaymentInBrowser": MessageLookupByLibrary.simpleMessage(
      "2. Please complete payment in your browser",
    ),
    "xboardConfigDownloadFailed": MessageLookupByLibrary.simpleMessage(
      "Configuration download failed, please check subscription link",
    ),
    "xboardConfigFormatError": MessageLookupByLibrary.simpleMessage(
      "Configuration format error, please contact service provider",
    ),
    "xboardConfigSaveFailed": MessageLookupByLibrary.simpleMessage(
      "Configuration save failed, please check storage space",
    ),
    "xboardConfigurationError": MessageLookupByLibrary.simpleMessage(
      "Configuration error",
    ),
    "xboardConfirm": MessageLookupByLibrary.simpleMessage("Confirm"),
    "xboardConfirmAction": MessageLookupByLibrary.simpleMessage("Confirm"),
    "xboardConfirmChange": MessageLookupByLibrary.simpleMessage(
      "Confirm change",
    ),
    "xboardConfirmClose": MessageLookupByLibrary.simpleMessage("Close"),
    "xboardConfirmNewPeriod": MessageLookupByLibrary.simpleMessage(
      "Start the next traffic period?",
    ),
    "xboardConfirmPassword": MessageLookupByLibrary.simpleMessage(
      "Confirm Password",
    ),
    "xboardConfirmPurchase": MessageLookupByLibrary.simpleMessage(
      "Confirm purchase",
    ),
    "xboardConfirmRenewPlan": MessageLookupByLibrary.simpleMessage(
      "Confirm renewal",
    ),
    "xboardConfirmResetTraffic": MessageLookupByLibrary.simpleMessage(
      "Confirm traffic reset",
    ),
    "xboardCongratulationsSubscriptionActivated":
        MessageLookupByLibrary.simpleMessage(
          "Congratulations! Your subscription has been successfully purchased and activated",
        ),
    "xboardConnectGlobalQualityNodes": MessageLookupByLibrary.simpleMessage(
      "Connect to global quality nodes",
    ),
    "xboardConnecting": MessageLookupByLibrary.simpleMessage("Connecting"),
    "xboardConnectionHealth": MessageLookupByLibrary.simpleMessage(
      "Connection Health",
    ),
    "xboardConnectionHealthSubtitle": MessageLookupByLibrary.simpleMessage(
      "Check server, subscription, node, and device status",
    ),
    "xboardConnectionTimeout": MessageLookupByLibrary.simpleMessage(
      "Connection timeout, please check network connection",
    ),
    "xboardContactCustomerService": MessageLookupByLibrary.simpleMessage(
      "Contact Customer Service",
    ),
    "xboardCopyDiagnosticBundle": MessageLookupByLibrary.simpleMessage(
      "Copy diagnostics",
    ),
    "xboardCopyFailed": MessageLookupByLibrary.simpleMessage("Copy failed"),
    "xboardCopyInviteCode": MessageLookupByLibrary.simpleMessage(
      "Copy Invite Code",
    ),
    "xboardCopyInviteLink": MessageLookupByLibrary.simpleMessage("Copy Link"),
    "xboardCopyLink": MessageLookupByLibrary.simpleMessage("Copy Link"),
    "xboardCopyPaymentLink": MessageLookupByLibrary.simpleMessage("Copy Link"),
    "xboardCopySubscriptionLinkAbove": MessageLookupByLibrary.simpleMessage(
      "Copy the subscription link above",
    ),
    "xboardCoreStageCheckingHelper": MessageLookupByLibrary.simpleMessage(
      "Checking helper",
    ),
    "xboardCoreStageConnected": MessageLookupByLibrary.simpleMessage(
      "Connected",
    ),
    "xboardCoreStageCoreConnecting": MessageLookupByLibrary.simpleMessage(
      "Reconnecting core",
    ),
    "xboardCoreStageFailed": MessageLookupByLibrary.simpleMessage(
      "Connection failed",
    ),
    "xboardCoreStageHelperReady": MessageLookupByLibrary.simpleMessage(
      "Helper reused",
    ),
    "xboardCoreStageStartingService": MessageLookupByLibrary.simpleMessage(
      "Starting service",
    ),
    "xboardCoreStageStopping": MessageLookupByLibrary.simpleMessage(
      "Disconnecting",
    ),
    "xboardCoreStageTunApplying": MessageLookupByLibrary.simpleMessage(
      "Applying TUN",
    ),
    "xboardCouponExpired": MessageLookupByLibrary.simpleMessage(
      "Coupon expired",
    ),
    "xboardCouponNotYetActive": MessageLookupByLibrary.simpleMessage(
      "Coupon not yet active",
    ),
    "xboardCouponOptional": MessageLookupByLibrary.simpleMessage(
      "Coupon (optional)",
    ),
    "xboardCreateTicket": MessageLookupByLibrary.simpleMessage("Create ticket"),
    "xboardCreateTicketHint": MessageLookupByLibrary.simpleMessage(
      "Create a ticket to contact support.",
    ),
    "xboardCreatedAt": MessageLookupByLibrary.simpleMessage("Created at"),
    "xboardCreatingOrder": MessageLookupByLibrary.simpleMessage(
      "Creating order",
    ),
    "xboardCreatingOrderPleaseWait": MessageLookupByLibrary.simpleMessage(
      "We are creating a new order for you, please wait",
    ),
    "xboardCreditedAmount": MessageLookupByLibrary.simpleMessage(
      "Amount credited",
    ),
    "xboardCurrentBalance": MessageLookupByLibrary.simpleMessage(
      "Current balance",
    ),
    "xboardCurrentBusinessApi": MessageLookupByLibrary.simpleMessage(
      "Current business API",
    ),
    "xboardCurrentDomain": MessageLookupByLibrary.simpleMessage(
      "Current domain",
    ),
    "xboardCurrentGateway": MessageLookupByLibrary.simpleMessage(
      "Current gateway",
    ),
    "xboardCurrentNode": MessageLookupByLibrary.simpleMessage("Current node"),
    "xboardCurrentPassword": MessageLookupByLibrary.simpleMessage(
      "Current password",
    ),
    "xboardCurrentPlanBased": MessageLookupByLibrary.simpleMessage(
      "Based on current plan",
    ),
    "xboardCurrentVersion": MessageLookupByLibrary.simpleMessage(
      "Current version",
    ),
    "xboardCustomRechargeAmount": MessageLookupByLibrary.simpleMessage(
      "Custom recharge amount",
    ),
    "xboardDays": MessageLookupByLibrary.simpleMessage("days"),
    "xboardDeductedBalance": MessageLookupByLibrary.simpleMessage(
      "Deducted balance",
    ),
    "xboardDeductibleBalance": MessageLookupByLibrary.simpleMessage(
      "Available balance",
    ),
    "xboardDeductibleDuringPayment": MessageLookupByLibrary.simpleMessage(
      "Deductible during payment",
    ),
    "xboardDeviceAutoOfflineHint": MessageLookupByLibrary.simpleMessage(
      "Devices offline for more than 30 days will be automatically removed.",
    ),
    "xboardDeviceCurrentDeviceLabel": MessageLookupByLibrary.simpleMessage(
      "Current device",
    ),
    "xboardDeviceExpired": MessageLookupByLibrary.simpleMessage("Expired"),
    "xboardDeviceHealth": MessageLookupByLibrary.simpleMessage("Device status"),
    "xboardDeviceHistory": MessageLookupByLibrary.simpleMessage("History"),
    "xboardDeviceHistoryHint": MessageLookupByLibrary.simpleMessage(
      "Only removal records within 90 days are kept. Older records will be automatically cleaned up.",
    ),
    "xboardDeviceKickedContent": MessageLookupByLibrary.simpleMessage(
      "This account signed in on another device, so this device has been disconnected. Sign in again or manage your devices to continue.",
    ),
    "xboardDeviceKickedTitle": MessageLookupByLibrary.simpleMessage(
      "Device Signed Out",
    ),
    "xboardDeviceLabelId": MessageLookupByLibrary.simpleMessage("Device ID"),
    "xboardDeviceLabelLastIp": MessageLookupByLibrary.simpleMessage("Last IP"),
    "xboardDeviceLabelLastOnline": MessageLookupByLibrary.simpleMessage(
      "Last online",
    ),
    "xboardDeviceLabelOsVersion": MessageLookupByLibrary.simpleMessage(
      "OS Version",
    ),
    "xboardDeviceLabelRegion": MessageLookupByLibrary.simpleMessage("Location"),
    "xboardDeviceLabelRevokedAt": MessageLookupByLibrary.simpleMessage(
      "Revoked at",
    ),
    "xboardDeviceLabelRevokedBy": MessageLookupByLibrary.simpleMessage(
      "Revoked by",
    ),
    "xboardDeviceManagement": MessageLookupByLibrary.simpleMessage(
      "Device Management",
    ),
    "xboardDeviceNoRecords": MessageLookupByLibrary.simpleMessage(
      "No device records",
    ),
    "xboardDeviceNoRecordsHint": MessageLookupByLibrary.simpleMessage(
      "Devices you\'ve signed in with will appear here for easy management.",
    ),
    "xboardDeviceOffline": MessageLookupByLibrary.simpleMessage("Offline"),
    "xboardDeviceOnline": MessageLookupByLibrary.simpleMessage("Online"),
    "xboardDeviceRemoveCurrentConfirm": MessageLookupByLibrary.simpleMessage(
      "This is your current device. Removing it will log you out immediately.",
    ),
    "xboardDeviceRemoveTitle": MessageLookupByLibrary.simpleMessage(
      "Remove device",
    ),
    "xboardDeviceRemoved": MessageLookupByLibrary.simpleMessage(
      "Device removed",
    ),
    "xboardDeviceRevoked": MessageLookupByLibrary.simpleMessage("Removed"),
    "xboardDeviceSessionRevokedContent": MessageLookupByLibrary.simpleMessage(
      "This device\'s login access was removed and its connection was stopped. Sign in again to continue.",
    ),
    "xboardDeviceSessionRevokedTitle": MessageLookupByLibrary.simpleMessage(
      "Device Removed",
    ),
    "xboardDeviceSummary": m38,
    "xboardDeviceUnit": m39,
    "xboardDeviceUnknown": MessageLookupByLibrary.simpleMessage("Unknown"),
    "xboardDeviceUnknownVersion": MessageLookupByLibrary.simpleMessage(
      "Unknown version",
    ),
    "xboardDeviceUnlimited": MessageLookupByLibrary.simpleMessage("Unlimited"),
    "xboardDiagnosticBundleCopied": MessageLookupByLibrary.simpleMessage(
      "Diagnostics copied",
    ),
    "xboardDiagnosticBusinessServices": MessageLookupByLibrary.simpleMessage(
      "Business services",
    ),
    "xboardDiagnosticHealthyAccount": MessageLookupByLibrary.simpleMessage(
      "Account and subscription are available",
    ),
    "xboardDiagnosticHealthyCore": MessageLookupByLibrary.simpleMessage(
      "Proxy core is running",
    ),
    "xboardDiagnosticHealthyGateway": MessageLookupByLibrary.simpleMessage(
      "Current business gateway is available",
    ),
    "xboardDiagnosticHealthyHeartbeat": MessageLookupByLibrary.simpleMessage(
      "Device heartbeat succeeded",
    ),
    "xboardDiagnosticHealthyItems": MessageLookupByLibrary.simpleMessage(
      "Healthy items",
    ),
    "xboardDiagnosticHealthyNodes": MessageLookupByLibrary.simpleMessage(
      "Available proxy nodes",
    ),
    "xboardDiagnosticHealthyProxy": MessageLookupByLibrary.simpleMessage(
      "System proxy is running on port",
    ),
    "xboardDiagnosticIssueCore": MessageLookupByLibrary.simpleMessage(
      "Proxy core is not running",
    ),
    "xboardDiagnosticIssueGateway": MessageLookupByLibrary.simpleMessage(
      "No available business gateway",
    ),
    "xboardDiagnosticIssueNodes": MessageLookupByLibrary.simpleMessage(
      "No available proxy nodes",
    ),
    "xboardDiagnosticIssueProxy": MessageLookupByLibrary.simpleMessage(
      "System proxy is enabled but not running",
    ),
    "xboardDiagnosticLatestNetwork": MessageLookupByLibrary.simpleMessage(
      "Latest network connectivity check",
    ),
    "xboardDiagnosticNetworkConnectivity": MessageLookupByLibrary.simpleMessage(
      "Network connectivity",
    ),
    "xboardDiagnosticNetworkNotRun": MessageLookupByLibrary.simpleMessage(
      "Network connectivity diagnostics have not been run",
    ),
    "xboardDiagnosticNetworkSnapshotTime": MessageLookupByLibrary.simpleMessage(
      "Checked at",
    ),
    "xboardDiagnosticNoticeGateways": MessageLookupByLibrary.simpleMessage(
      "Unverified backup gateways",
    ),
    "xboardDiagnosticNoticeTun": MessageLookupByLibrary.simpleMessage(
      "TUN is configured but is not currently active; traffic is using another proxy mode",
    ),
    "xboardDiagnosticNotices": MessageLookupByLibrary.simpleMessage(
      "Items requiring attention",
    ),
    "xboardDiagnosticOverall": MessageLookupByLibrary.simpleMessage(
      "Overall status",
    ),
    "xboardDiagnosticOverallAbnormal": MessageLookupByLibrary.simpleMessage(
      "Issues detected",
    ),
    "xboardDiagnosticOverallAttention": MessageLookupByLibrary.simpleMessage(
      "Generally healthy, with items requiring attention",
    ),
    "xboardDiagnosticOverallHealthy": MessageLookupByLibrary.simpleMessage(
      "Healthy",
    ),
    "xboardDiagnosticOverallServiceHealthy": MessageLookupByLibrary.simpleMessage(
      "Services and system proxy are healthy; network connectivity has not been verified",
    ),
    "xboardDiagnosticPlatform": MessageLookupByLibrary.simpleMessage(
      "Platform",
    ),
    "xboardDiagnosticProblems": MessageLookupByLibrary.simpleMessage(
      "Problems",
    ),
    "xboardDiagnosticProxyAndSystem": MessageLookupByLibrary.simpleMessage(
      "Proxy and system",
    ),
    "xboardDiagnosticServiceStatus": MessageLookupByLibrary.simpleMessage(
      "Service status",
    ),
    "xboardDiagnosticSuggestion": MessageLookupByLibrary.simpleMessage(
      "Suggestion",
    ),
    "xboardDiagnosticSuggestionNone": MessageLookupByLibrary.simpleMessage(
      "The current connection is working normally; no action is required.",
    ),
    "xboardDiagnosticSuggestionRepair": MessageLookupByLibrary.simpleMessage(
      "Refresh status or use one-click repair, then rerun network diagnostics and copy the report.",
    ),
    "xboardDiagnosticSuggestionRunNetwork": MessageLookupByLibrary.simpleMessage(
      "Services and system proxy settings are healthy. Run network diagnostics to verify the node endpoint, TLS, and proxy route.",
    ),
    "xboardDiagnosticSuggestionTun": MessageLookupByLibrary.simpleMessage(
      "The connection is usable. Enable TUN only if some apps cannot use the system proxy.",
    ),
    "xboardDiagnosticSummaryTitle": MessageLookupByLibrary.simpleMessage(
      "FastCat diagnostic report",
    ),
    "xboardDiagnosticsCenter": MessageLookupByLibrary.simpleMessage(
      "Diagnostics center",
    ),
    "xboardDiagnosticsCenterSubtitle": MessageLookupByLibrary.simpleMessage(
      "Check service status, proxy configuration, and network connectivity",
    ),
    "xboardDisconnecting": MessageLookupByLibrary.simpleMessage(
      "Disconnecting",
    ),
    "xboardDiscountAmount": MessageLookupByLibrary.simpleMessage(
      "Discount amount",
    ),
    "xboardDiscounted": MessageLookupByLibrary.simpleMessage("Discounted"),
    "xboardDiscountedPrice": MessageLookupByLibrary.simpleMessage(
      "Discounted price",
    ),
    "xboardDocsCenter": MessageLookupByLibrary.simpleMessage("Docs center"),
    "xboardDownloadingConfig": MessageLookupByLibrary.simpleMessage(
      "Downloading configuration file",
    ),
    "xboardEmail": MessageLookupByLibrary.simpleMessage("Email"),
    "xboardEmailUnavailable": MessageLookupByLibrary.simpleMessage(
      "Email unavailable",
    ),
    "xboardEnableTun": MessageLookupByLibrary.simpleMessage("Enable TUN"),
    "xboardEnjoyFastNetworkExperience": MessageLookupByLibrary.simpleMessage(
      "Enjoy fast network experience",
    ),
    "xboardEnterAmount": MessageLookupByLibrary.simpleMessage("Enter amount"),
    "xboardEnterCouponCode": MessageLookupByLibrary.simpleMessage(
      "Enter coupon code",
    ),
    "xboardEnterGiftCardCode": MessageLookupByLibrary.simpleMessage(
      "Enter gift card code",
    ),
    "xboardEnterGiftCardCodeHint": MessageLookupByLibrary.simpleMessage(
      "Enter gift card redemption code",
    ),
    "xboardExcellent": MessageLookupByLibrary.simpleMessage("Excellent"),
    "xboardExpiredOnDate": m40,
    "xboardExpiresOnDate": m41,
    "xboardExpiresOnWithDays": m42,
    "xboardExpiryTime": MessageLookupByLibrary.simpleMessage("Expiry time"),
    "xboardFailedToCheckPaymentStatus": MessageLookupByLibrary.simpleMessage(
      "Failed to check payment status",
    ),
    "xboardFailedToGetSubscriptionInfo": MessageLookupByLibrary.simpleMessage(
      "Failed to get subscription information",
    ),
    "xboardFailedToOpenPaymentLink": MessageLookupByLibrary.simpleMessage(
      "Failed to open payment link",
    ),
    "xboardFailedToOpenPaymentPage": MessageLookupByLibrary.simpleMessage(
      "Failed to open payment page",
    ),
    "xboardFair": MessageLookupByLibrary.simpleMessage("Fair"),
    "xboardForceUpdate": MessageLookupByLibrary.simpleMessage("Force update"),
    "xboardForgotPassword": MessageLookupByLibrary.simpleMessage(
      "Forgot Password",
    ),
    "xboardGatewayCandidateCount": m43,
    "xboardGatewayStatus": MessageLookupByLibrary.simpleMessage(
      "Gateway status",
    ),
    "xboardGetGroupLinkFailed": MessageLookupByLibrary.simpleMessage(
      "Failed to get group link",
    ),
    "xboardGettingIP": MessageLookupByLibrary.simpleMessage("Getting..."),
    "xboardGiftCardAlreadyUsedByUser": MessageLookupByLibrary.simpleMessage(
      "Redeem failed: this gift card has already been used by this user",
    ),
    "xboardGiftCardCode": MessageLookupByLibrary.simpleMessage(
      "Gift card code",
    ),
    "xboardGiftCardCodeLabel": MessageLookupByLibrary.simpleMessage(
      "Gift Card Code",
    ),
    "xboardGiftCardNotFound": MessageLookupByLibrary.simpleMessage(
      "Redeem failed: this gift card does not exist",
    ),
    "xboardGiftCardRedeem": MessageLookupByLibrary.simpleMessage(
      "Gift card redeem",
    ),
    "xboardGiftCardRedeemSuccessRefreshed": MessageLookupByLibrary.simpleMessage(
      "Redeem successful: user information has been refreshed automatically",
    ),
    "xboardGiftCardRedeemTitle": MessageLookupByLibrary.simpleMessage(
      "Gift Card Redeem",
    ),
    "xboardGlobalNodes": MessageLookupByLibrary.simpleMessage("Global nodes"),
    "xboardGlobalProxy": MessageLookupByLibrary.simpleMessage("Global proxy"),
    "xboardGood": MessageLookupByLibrary.simpleMessage("Good"),
    "xboardGotIt": MessageLookupByLibrary.simpleMessage("Got it"),
    "xboardGroup": MessageLookupByLibrary.simpleMessage("Group"),
    "xboardGroupLinkNotConfigured": MessageLookupByLibrary.simpleMessage(
      "Group link not configured",
    ),
    "xboardHalfYearlyPayment": MessageLookupByLibrary.simpleMessage(
      "Half-yearly",
    ),
    "xboardHandleLater": MessageLookupByLibrary.simpleMessage("Handle later"),
    "xboardHandlingFee": MessageLookupByLibrary.simpleMessage("Handling fee"),
    "xboardHealthCoreRunning": MessageLookupByLibrary.simpleMessage("Running"),
    "xboardHealthDisabled": MessageLookupByLibrary.simpleMessage("Disabled"),
    "xboardHealthDns": MessageLookupByLibrary.simpleMessage("DNS"),
    "xboardHealthDnsCustom": MessageLookupByLibrary.simpleMessage(
      "Using custom DNS",
    ),
    "xboardHealthDnsDefault": MessageLookupByLibrary.simpleMessage(
      "Using default DNS",
    ),
    "xboardHealthEnabled": MessageLookupByLibrary.simpleMessage("Enabled"),
    "xboardHealthHelper": MessageLookupByLibrary.simpleMessage("Helper"),
    "xboardHealthHelperAvailable": MessageLookupByLibrary.simpleMessage(
      "Available",
    ),
    "xboardHealthHelperCheckFailed": MessageLookupByLibrary.simpleMessage(
      "Check failed",
    ),
    "xboardHealthHelperChecking": MessageLookupByLibrary.simpleMessage(
      "Checking",
    ),
    "xboardHealthHelperNoResponse": MessageLookupByLibrary.simpleMessage(
      "Helper HTTP is not responding",
    ),
    "xboardHealthHelperNotRequired": MessageLookupByLibrary.simpleMessage(
      "Windows helper is not required on this platform",
    ),
    "xboardHealthHelperUnavailable": MessageLookupByLibrary.simpleMessage(
      "Unavailable",
    ),
    "xboardHealthLastEvent": MessageLookupByLibrary.simpleMessage(
      "Latest event",
    ),
    "xboardHealthSubscriptionImport": m44,
    "xboardHealthTunApplied": MessageLookupByLibrary.simpleMessage("Applied"),
    "xboardHealthTunPending": MessageLookupByLibrary.simpleMessage(
      "Waiting to apply",
    ),
    "xboardHealthy": MessageLookupByLibrary.simpleMessage("Healthy"),
    "xboardHigh": MessageLookupByLibrary.simpleMessage("High"),
    "xboardHighSpeedNetwork": MessageLookupByLibrary.simpleMessage(
      "High-speed network",
    ),
    "xboardHome": MessageLookupByLibrary.simpleMessage("Home"),
    "xboardImageUploadUnavailable": MessageLookupByLibrary.simpleMessage(
      "Image upload is not configured. Contact support.",
    ),
    "xboardImportFailed": MessageLookupByLibrary.simpleMessage("Import failed"),
    "xboardImportSuccess": MessageLookupByLibrary.simpleMessage(
      "Import successful",
    ),
    "xboardImportingSubscription": MessageLookupByLibrary.simpleMessage(
      "Importing subscription",
    ),
    "xboardInsufficientBalance": MessageLookupByLibrary.simpleMessage(
      "Insufficient balance",
    ),
    "xboardInvalidCredentials": MessageLookupByLibrary.simpleMessage(
      "Invalid username or password",
    ),
    "xboardInvalidOrExpiredCoupon": MessageLookupByLibrary.simpleMessage(
      "Invalid or expired coupon code",
    ),
    "xboardInvalidResponseFormat": MessageLookupByLibrary.simpleMessage(
      "Invalid response format from server",
    ),
    "xboardInviteCode": MessageLookupByLibrary.simpleMessage("Invite Code"),
    "xboardJoinGroup": MessageLookupByLibrary.simpleMessage("Join Group"),
    "xboardKeepSubscriptionLinkSafe": MessageLookupByLibrary.simpleMessage(
      "Please keep your subscription link safe and don\'t share with others",
    ),
    "xboardLater": MessageLookupByLibrary.simpleMessage("Later"),
    "xboardLoadFailedCheckNetwork": MessageLookupByLibrary.simpleMessage(
      "Failed to load. Check your network.",
    ),
    "xboardLoadingConfiguration": MessageLookupByLibrary.simpleMessage(
      "Loading configuration...",
    ),
    "xboardLoadingFailed": MessageLookupByLibrary.simpleMessage(
      "Loading failed",
    ),
    "xboardLoadingPaymentPage": MessageLookupByLibrary.simpleMessage(
      "Loading payment page",
    ),
    "xboardLocalIP": MessageLookupByLibrary.simpleMessage("Local IP"),
    "xboardLoggedIn": MessageLookupByLibrary.simpleMessage("Logged In"),
    "xboardLoggingIn": MessageLookupByLibrary.simpleMessage("Logging in..."),
    "xboardLogin": MessageLookupByLibrary.simpleMessage("Login"),
    "xboardLoginErrorConfigLoad": MessageLookupByLibrary.simpleMessage(
      "Configuration load failed, please try again later",
    ),
    "xboardLoginErrorCredentials": MessageLookupByLibrary.simpleMessage(
      "Invalid credentials, please check your account and password",
    ),
    "xboardLoginErrorDeviceLimit": MessageLookupByLibrary.simpleMessage(
      "Device limit reached. Release an offline device first.",
    ),
    "xboardLoginErrorLimited": MessageLookupByLibrary.simpleMessage(
      "Too many login attempts. Please try again later.",
    ),
    "xboardLoginErrorNetwork": MessageLookupByLibrary.simpleMessage(
      "Service is temporarily unavailable, please try again later.",
    ),
    "xboardLoginExpired": MessageLookupByLibrary.simpleMessage(
      "Login expired, please login again",
    ),
    "xboardLoginFailed": MessageLookupByLibrary.simpleMessage("Login failed"),
    "xboardLoginSuccess": MessageLookupByLibrary.simpleMessage(
      "Login successful",
    ),
    "xboardLoginToViewSubscription": MessageLookupByLibrary.simpleMessage(
      "Please login to view subscription usage",
    ),
    "xboardLogout": MessageLookupByLibrary.simpleMessage("Sign out"),
    "xboardLogoutConfirmContent": MessageLookupByLibrary.simpleMessage(
      "Are you sure you want to sign out? You will need to sign in again.",
    ),
    "xboardLogoutConfirmTitle": MessageLookupByLibrary.simpleMessage(
      "Confirm sign out",
    ),
    "xboardLogoutFailed": MessageLookupByLibrary.simpleMessage(
      "Sign out failed",
    ),
    "xboardLogoutForceAction": MessageLookupByLibrary.simpleMessage(
      "Sign out anyway",
    ),
    "xboardLogoutForceConfirmContent": MessageLookupByLibrary.simpleMessage(
      "Forced sign-out clears the local session and node cache. You may be unable to sign in again until the service recovers. Continue?",
    ),
    "xboardLogoutForceConfirmTitle": MessageLookupByLibrary.simpleMessage(
      "Confirm forced sign-out",
    ),
    "xboardLogoutProtectedContent": MessageLookupByLibrary.simpleMessage(
      "The service connection is currently unstable. Signing out may prevent you from signing in again for a while. Keep this session until the service recovers.",
    ),
    "xboardLogoutProtectedTitle": MessageLookupByLibrary.simpleMessage(
      "Sign-in protection is active",
    ),
    "xboardLogoutSuccess": MessageLookupByLibrary.simpleMessage("Signed out"),
    "xboardLow": MessageLookupByLibrary.simpleMessage("Low"),
    "xboardManageDevices": MessageLookupByLibrary.simpleMessage(
      "Manage devices",
    ),
    "xboardMaybeLater": MessageLookupByLibrary.simpleMessage("Maybe later"),
    "xboardMedium": MessageLookupByLibrary.simpleMessage("Medium"),
    "xboardMine": MessageLookupByLibrary.simpleMessage("Mine"),
    "xboardMissingRequiredField": MessageLookupByLibrary.simpleMessage(
      "Missing required field",
    ),
    "xboardMonthlyPayment": MessageLookupByLibrary.simpleMessage("Monthly"),
    "xboardMonthlyRenewal": MessageLookupByLibrary.simpleMessage(
      "Monthly renewal",
    ),
    "xboardMustUpdate": MessageLookupByLibrary.simpleMessage("Must update"),
    "xboardMyServices": MessageLookupByLibrary.simpleMessage("My services"),
    "xboardMyTickets": MessageLookupByLibrary.simpleMessage("My tickets"),
    "xboardMyWallet": MessageLookupByLibrary.simpleMessage("My wallet"),
    "xboardNeedsAttention": MessageLookupByLibrary.simpleMessage(
      "Needs attention",
    ),
    "xboardNetworkConnectionFailed": MessageLookupByLibrary.simpleMessage(
      "Network connection failed, please check network settings",
    ),
    "xboardNetworkDiagnostics": MessageLookupByLibrary.simpleMessage(
      "Network diagnostics",
    ),
    "xboardNetworkDiagnosticsConclusion": MessageLookupByLibrary.simpleMessage(
      "Diagnostic conclusion",
    ),
    "xboardNetworkDiagnosticsConclusionDisconnectedDns":
        MessageLookupByLibrary.simpleMessage(
          "VPN is not connected, and the basic network DNS result is abnormal. Fix the local network or DNS before diagnosing the node route.",
        ),
    "xboardNetworkDiagnosticsConclusionDisconnectedHealthy":
        MessageLookupByLibrary.simpleMessage(
          "VPN is not connected. The basic network is working normally; connect VPN to diagnose the node route.",
        ),
    "xboardNetworkDiagnosticsConclusionDisconnectedNetwork":
        MessageLookupByLibrary.simpleMessage(
          "VPN is not connected, and the basic network appears abnormal or unreachable.",
        ),
    "xboardNetworkDiagnosticsConclusionDns":
        MessageLookupByLibrary.simpleMessage(
          "DNS results are abnormal. Check DNS settings or the current network.",
        ),
    "xboardNetworkDiagnosticsConclusionHealthy":
        MessageLookupByLibrary.simpleMessage(
          "DNS and network routes are working normally.",
        ),
    "xboardNetworkDiagnosticsConclusionNetwork":
        MessageLookupByLibrary.simpleMessage(
          "The local network appears abnormal or unreachable.",
        ),
    "xboardNetworkDiagnosticsConclusionNodeDns":
        MessageLookupByLibrary.simpleMessage(
          "The selected node domain could not be resolved on the current network.",
        ),
    "xboardNetworkDiagnosticsConclusionNodeUnknown":
        MessageLookupByLibrary.simpleMessage(
          "VPN is connected, but the current node could not be identified.",
        ),
    "xboardNetworkDiagnosticsConclusionProtocol":
        MessageLookupByLibrary.simpleMessage(
          "The node endpoint is reachable, but the proxy protocol handshake failed. Check transport and authentication parameters.",
        ),
    "xboardNetworkDiagnosticsConclusionProxy":
        MessageLookupByLibrary.simpleMessage(
          "The proxy node or proxy route is unavailable.",
        ),
    "xboardNetworkDiagnosticsConclusionProxyWorking":
        MessageLookupByLibrary.simpleMessage(
          "The proxy route is working normally. Some direct targets are restricted on the current network, which does not affect proxy use.",
        ),
    "xboardNetworkDiagnosticsConclusionTcp": MessageLookupByLibrary.simpleMessage(
      "Direct internet access works, but the selected node TCP endpoint timed out. The endpoint may be unreachable or restricted by the current network.",
    ),
    "xboardNetworkDiagnosticsConclusionTcpRefused":
        MessageLookupByLibrary.simpleMessage(
          "The selected node endpoint refused the TCP connection. Check the server process and listening port.",
        ),
    "xboardNetworkDiagnosticsConclusionTls": MessageLookupByLibrary.simpleMessage(
      "TCP connectivity succeeded, but the node TLS handshake failed. Check SNI, certificates, or network TLS filtering.",
    ),
    "xboardNetworkDiagnosticsConclusionUdp": MessageLookupByLibrary.simpleMessage(
      "The UDP-based node timed out while direct internet access works. UDP may be unavailable or restricted on the current network.",
    ),
    "xboardNetworkDiagnosticsConnectFirst":
        MessageLookupByLibrary.simpleMessage(
          "Connect the VPN before running network diagnostics.",
        ),
    "xboardNetworkDiagnosticsConnected": MessageLookupByLibrary.simpleMessage(
      "Connected",
    ),
    "xboardNetworkDiagnosticsCopied": MessageLookupByLibrary.simpleMessage(
      "Diagnostics report copied",
    ),
    "xboardNetworkDiagnosticsCopyReport": MessageLookupByLibrary.simpleMessage(
      "Copy report",
    ),
    "xboardNetworkDiagnosticsCoreUnavailable": MessageLookupByLibrary.simpleMessage(
      "Layered diagnostics are unavailable in the current core. Update or fully restart the client; the HTTPS results below remain valid.",
    ),
    "xboardNetworkDiagnosticsDescription": MessageLookupByLibrary.simpleMessage(
      "DNS checks use the system resolver. Node diagnostics then check the actual endpoint DNS, TCP or UDP transport, proxy handshake, and HTTP reachability.",
    ),
    "xboardNetworkDiagnosticsDirectHttps": MessageLookupByLibrary.simpleMessage(
      "Local direct HTTPS (domestic baseline)",
    ),
    "xboardNetworkDiagnosticsDisconnected":
        MessageLookupByLibrary.simpleMessage("Disconnected"),
    "xboardNetworkDiagnosticsDisconnectedInvalidated":
        MessageLookupByLibrary.simpleMessage(
          "The VPN disconnected. Network diagnostics stopped and the current results were cleared.",
        ),
    "xboardNetworkDiagnosticsDns": MessageLookupByLibrary.simpleMessage(
      "DNS resolution",
    ),
    "xboardNetworkDiagnosticsDomain": MessageLookupByLibrary.simpleMessage(
      "Domain",
    ),
    "xboardNetworkDiagnosticsEmptyResult": MessageLookupByLibrary.simpleMessage(
      "Empty result",
    ),
    "xboardNetworkDiagnosticsEndpointUnavailable":
        MessageLookupByLibrary.simpleMessage(
          "Node endpoint information is unavailable",
        ),
    "xboardNetworkDiagnosticsExpectedFakeIp":
        MessageLookupByLibrary.simpleMessage("Expected fake-IP result"),
    "xboardNetworkDiagnosticsHttpFailed": MessageLookupByLibrary.simpleMessage(
      "The proxy connected, but the HTTP test failed",
    ),
    "xboardNetworkDiagnosticsHttps": MessageLookupByLibrary.simpleMessage(
      "HTTPS reachability",
    ),
    "xboardNetworkDiagnosticsIpConnectivity":
        MessageLookupByLibrary.simpleMessage("IPv4 / IPv6 connectivity"),
    "xboardNetworkDiagnosticsNetworkEthernet":
        MessageLookupByLibrary.simpleMessage("Ethernet"),
    "xboardNetworkDiagnosticsNetworkMobile":
        MessageLookupByLibrary.simpleMessage("Mobile network"),
    "xboardNetworkDiagnosticsNetworkNone": MessageLookupByLibrary.simpleMessage(
      "No network",
    ),
    "xboardNetworkDiagnosticsNetworkOther":
        MessageLookupByLibrary.simpleMessage("Other network"),
    "xboardNetworkDiagnosticsNetworkType": MessageLookupByLibrary.simpleMessage(
      "Network type",
    ),
    "xboardNetworkDiagnosticsNode": MessageLookupByLibrary.simpleMessage(
      "Current node",
    ),
    "xboardNetworkDiagnosticsNodeDns": MessageLookupByLibrary.simpleMessage(
      "Node DNS",
    ),
    "xboardNetworkDiagnosticsNodeDnsFailed":
        MessageLookupByLibrary.simpleMessage("Node domain resolution failed"),
    "xboardNetworkDiagnosticsNodeDnsSuccess":
        MessageLookupByLibrary.simpleMessage(
          "Node domain resolved successfully",
        ),
    "xboardNetworkDiagnosticsNodeEndpoint":
        MessageLookupByLibrary.simpleMessage("Node endpoint"),
    "xboardNetworkDiagnosticsNodeHandshake":
        MessageLookupByLibrary.simpleMessage("TLS / proxy handshake / HTTP"),
    "xboardNetworkDiagnosticsNodeHttpSuccess":
        MessageLookupByLibrary.simpleMessage(
          "Node handshake and HTTP test succeeded",
        ),
    "xboardNetworkDiagnosticsNodeLayers": MessageLookupByLibrary.simpleMessage(
      "Node connection layers",
    ),
    "xboardNetworkDiagnosticsNodeTcp": MessageLookupByLibrary.simpleMessage(
      "TCP port",
    ),
    "xboardNetworkDiagnosticsNodeTls": MessageLookupByLibrary.simpleMessage(
      "TLS handshake",
    ),
    "xboardNetworkDiagnosticsProtocolFailed": MessageLookupByLibrary.simpleMessage(
      "The node endpoint is reachable, but the proxy protocol handshake failed",
    ),
    "xboardNetworkDiagnosticsProxyHttps": MessageLookupByLibrary.simpleMessage(
      "Node proxy HTTPS (international reference)",
    ),
    "xboardNetworkDiagnosticsReachable": MessageLookupByLibrary.simpleMessage(
      "Reachable",
    ),
    "xboardNetworkDiagnosticsReportTitle": MessageLookupByLibrary.simpleMessage(
      "FastCat network diagnostics report",
    ),
    "xboardNetworkDiagnosticsRunning": MessageLookupByLibrary.simpleMessage(
      "Diagnosing...",
    ),
    "xboardNetworkDiagnosticsRunningTime": MessageLookupByLibrary.simpleMessage(
      "Running time",
    ),
    "xboardNetworkDiagnosticsStart": MessageLookupByLibrary.simpleMessage(
      "Start diagnostics",
    ),
    "xboardNetworkDiagnosticsSubtitle": MessageLookupByLibrary.simpleMessage(
      "Check VPN status, DNS resolution, and HTTPS reachability",
    ),
    "xboardNetworkDiagnosticsSuspiciousAddress":
        MessageLookupByLibrary.simpleMessage(
          "Possible DNS pollution: private or reserved address",
        ),
    "xboardNetworkDiagnosticsTargetHuawei204":
        MessageLookupByLibrary.simpleMessage("Huawei 204"),
    "xboardNetworkDiagnosticsTargetVivo204":
        MessageLookupByLibrary.simpleMessage("vivo 204"),
    "xboardNetworkDiagnosticsTargetXiaomi204":
        MessageLookupByLibrary.simpleMessage("Xiaomi 204"),
    "xboardNetworkDiagnosticsTcpRefused": MessageLookupByLibrary.simpleMessage(
      "TCP connection was refused; the server port may not be listening",
    ),
    "xboardNetworkDiagnosticsTcpSkippedUdp":
        MessageLookupByLibrary.simpleMessage(
          "UDP-based node; TCP port check is not applicable",
        ),
    "xboardNetworkDiagnosticsTcpSuccess": MessageLookupByLibrary.simpleMessage(
      "TCP connection succeeded",
    ),
    "xboardNetworkDiagnosticsTcpTimeout": MessageLookupByLibrary.simpleMessage(
      "TCP connection timed out; the endpoint may be unreachable or restricted by this network",
    ),
    "xboardNetworkDiagnosticsTcpUnreachable":
        MessageLookupByLibrary.simpleMessage("No route to the node endpoint"),
    "xboardNetworkDiagnosticsTestDomain": MessageLookupByLibrary.simpleMessage(
      "Test domain",
    ),
    "xboardNetworkDiagnosticsTime": MessageLookupByLibrary.simpleMessage(
      "Time",
    ),
    "xboardNetworkDiagnosticsTimeout": MessageLookupByLibrary.simpleMessage(
      "Timed out",
    ),
    "xboardNetworkDiagnosticsTlsFailed": MessageLookupByLibrary.simpleMessage(
      "TCP succeeded, but the TLS handshake failed",
    ),
    "xboardNetworkDiagnosticsUdpFailed": MessageLookupByLibrary.simpleMessage(
      "The UDP node test timed out; UDP may be unavailable or restricted on this network",
    ),
    "xboardNetworkDiagnosticsUnavailable": MessageLookupByLibrary.simpleMessage(
      "Not available",
    ),
    "xboardNetworkDiagnosticsUnreachable": MessageLookupByLibrary.simpleMessage(
      "Unreachable",
    ),
    "xboardNetworkDiagnosticsViaNode": MessageLookupByLibrary.simpleMessage(
      "Via current node",
    ),
    "xboardNetworkDiagnosticsVpnRequired": MessageLookupByLibrary.simpleMessage(
      "VPN is not connected. Node DNS, port, TLS, and proxy-route diagnostics were skipped.",
    ),
    "xboardNetworkDiagnosticsVpnStatus": MessageLookupByLibrary.simpleMessage(
      "VPN status",
    ),
    "xboardNewPeriodCheckingResult": MessageLookupByLibrary.simpleMessage(
      "Checking the operation result",
    ),
    "xboardNewPeriodConfirmContent": MessageLookupByLibrary.simpleMessage(
      "This resets used traffic and deducts the remaining duration of the current traffic period from your plan. This action cannot be undone. Continue?",
    ),
    "xboardNewPeriodFailed": MessageLookupByLibrary.simpleMessage(
      "Could not start a new traffic period. Try again later.",
    ),
    "xboardNewPeriodResultUncertainContent": MessageLookupByLibrary.simpleMessage(
      "The network response was interrupted, so the new traffic period cannot be confirmed yet. Check the result instead of submitting again.",
    ),
    "xboardNewPeriodResultUncertainTitle": MessageLookupByLibrary.simpleMessage(
      "Unable to confirm the result",
    ),
    "xboardNewPeriodStarting": MessageLookupByLibrary.simpleMessage(
      "Starting the new traffic period",
    ),
    "xboardNewPeriodSuccess": MessageLookupByLibrary.simpleMessage(
      "The new traffic period has started",
    ),
    "xboardNewPeriodTrafficExhaustedDetail": MessageLookupByLibrary.simpleMessage(
      "Your plan traffic is used up. You can start the next traffic period early.",
    ),
    "xboardNewVersionFound": MessageLookupByLibrary.simpleMessage(
      "New version found",
    ),
    "xboardNext": MessageLookupByLibrary.simpleMessage("Next"),
    "xboardNoAvailableNodes": MessageLookupByLibrary.simpleMessage(
      "No available nodes",
    ),
    "xboardNoAvailablePlan": MessageLookupByLibrary.simpleMessage(
      "No available plan",
    ),
    "xboardNoAvailableSubscription": MessageLookupByLibrary.simpleMessage(
      "No available subscription",
    ),
    "xboardNoDocuments": MessageLookupByLibrary.simpleMessage("No documents"),
    "xboardNoGatewayActive": MessageLookupByLibrary.simpleMessage(
      "No active gateway",
    ),
    "xboardNoInternetConnection": MessageLookupByLibrary.simpleMessage(
      "No internet connection, please check network settings",
    ),
    "xboardNoMessages": MessageLookupByLibrary.simpleMessage("No messages"),
    "xboardNoOrderRecords": MessageLookupByLibrary.simpleMessage(
      "No order records",
    ),
    "xboardNoPaymentMethods": MessageLookupByLibrary.simpleMessage(
      "No payment methods",
    ),
    "xboardNoPlansAvailable": MessageLookupByLibrary.simpleMessage(
      "No plans available",
    ),
    "xboardNoSubscriptionInfo": MessageLookupByLibrary.simpleMessage(
      "No subscription information",
    ),
    "xboardNoSubscriptionPlans": MessageLookupByLibrary.simpleMessage(
      "No subscription plans",
    ),
    "xboardNoTicketRecords": MessageLookupByLibrary.simpleMessage(
      "No ticket records",
    ),
    "xboardNoTrafficRecords": MessageLookupByLibrary.simpleMessage(
      "No traffic records",
    ),
    "xboardNodeCount": m45,
    "xboardNodeHealth": MessageLookupByLibrary.simpleMessage("Node status"),
    "xboardNodeName": MessageLookupByLibrary.simpleMessage("Node Name"),
    "xboardNodeSelection": MessageLookupByLibrary.simpleMessage(
      "Node selection",
    ),
    "xboardNone": MessageLookupByLibrary.simpleMessage("None"),
    "xboardNormal": MessageLookupByLibrary.simpleMessage("Normal"),
    "xboardNotLoggedIn": MessageLookupByLibrary.simpleMessage("Not Logged In"),
    "xboardOfflineButActive": MessageLookupByLibrary.simpleMessage(
      "Offline, using slot",
    ),
    "xboardOneClickRepair": MessageLookupByLibrary.simpleMessage(
      "One-click repair",
    ),
    "xboardOneTimePayment": MessageLookupByLibrary.simpleMessage("One-time"),
    "xboardOnlineSupport": MessageLookupByLibrary.simpleMessage(
      "Online support",
    ),
    "xboardOpenPaymentFailed": MessageLookupByLibrary.simpleMessage(
      "Failed to open payment page",
    ),
    "xboardOpenPaymentLinkFailed": MessageLookupByLibrary.simpleMessage(
      "Failed to open payment link",
    ),
    "xboardOperationFailed": MessageLookupByLibrary.simpleMessage(
      "Operation failed",
    ),
    "xboardOperationTips": MessageLookupByLibrary.simpleMessage(
      "Operation tips",
    ),
    "xboardOrderAmount": MessageLookupByLibrary.simpleMessage("Order amount"),
    "xboardOrderCreationFailed": MessageLookupByLibrary.simpleMessage(
      "Order creation failed",
    ),
    "xboardOrderInfo": MessageLookupByLibrary.simpleMessage("Order info"),
    "xboardOrderLoadingFailed": MessageLookupByLibrary.simpleMessage(
      "Failed to load order",
    ),
    "xboardOrderNotFound": MessageLookupByLibrary.simpleMessage(
      "Order not found",
    ),
    "xboardOrderNumber": MessageLookupByLibrary.simpleMessage("Order number"),
    "xboardOrderRecords": MessageLookupByLibrary.simpleMessage("Order records"),
    "xboardOrderStatus": MessageLookupByLibrary.simpleMessage("Order status"),
    "xboardOrderStatusCancelled": MessageLookupByLibrary.simpleMessage(
      "Cancelled",
    ),
    "xboardOrderStatusCompleted": MessageLookupByLibrary.simpleMessage(
      "Completed",
    ),
    "xboardOrderStatusOffset": MessageLookupByLibrary.simpleMessage("Offset"),
    "xboardOrderStatusOpening": MessageLookupByLibrary.simpleMessage(
      "Activating",
    ),
    "xboardOrderStatusPending": MessageLookupByLibrary.simpleMessage(
      "Pending payment",
    ),
    "xboardOriginalPrice": MessageLookupByLibrary.simpleMessage(
      "Original price",
    ),
    "xboardPackageAmount": MessageLookupByLibrary.simpleMessage(
      "Package amount",
    ),
    "xboardPassword": MessageLookupByLibrary.simpleMessage("Password"),
    "xboardPasswordChanged": MessageLookupByLibrary.simpleMessage(
      "Password changed successfully",
    ),
    "xboardPayNow": MessageLookupByLibrary.simpleMessage("Pay now"),
    "xboardPayableAmount": MessageLookupByLibrary.simpleMessage(
      "Payable amount",
    ),
    "xboardPaymentCancelled": MessageLookupByLibrary.simpleMessage(
      "Payment cancelled",
    ),
    "xboardPaymentComplete": MessageLookupByLibrary.simpleMessage(
      "Payment Complete",
    ),
    "xboardPaymentCompleted": MessageLookupByLibrary.simpleMessage(
      "Payment completed!",
    ),
    "xboardPaymentFailed": MessageLookupByLibrary.simpleMessage(
      "Payment failed",
    ),
    "xboardPaymentGateway": MessageLookupByLibrary.simpleMessage(
      "Payment gateway",
    ),
    "xboardPaymentInfo": MessageLookupByLibrary.simpleMessage(
      "Payment information",
    ),
    "xboardPaymentInstructions1": MessageLookupByLibrary.simpleMessage(
      "1. Payment page has been opened automatically",
    ),
    "xboardPaymentInstructions2": MessageLookupByLibrary.simpleMessage(
      "2. Please complete payment in your browser",
    ),
    "xboardPaymentInstructions3": MessageLookupByLibrary.simpleMessage(
      "3. Return to app after payment, system will detect automatically",
    ),
    "xboardPaymentLink": MessageLookupByLibrary.simpleMessage("Payment link"),
    "xboardPaymentLinkCopied": MessageLookupByLibrary.simpleMessage(
      "Payment link copied to clipboard",
    ),
    "xboardPaymentMethodVerified": MessageLookupByLibrary.simpleMessage(
      "Payment method verified",
    ),
    "xboardPaymentMethodVerifiedPreparing":
        MessageLookupByLibrary.simpleMessage(
          "Payment method verified, preparing to redirect to payment page",
        ),
    "xboardPaymentMethods": MessageLookupByLibrary.simpleMessage(
      "Payment methods",
    ),
    "xboardPaymentPageAutoOpened": MessageLookupByLibrary.simpleMessage(
      "1. Payment page has been opened automatically",
    ),
    "xboardPaymentPageOpenedCompleteAndReturn":
        MessageLookupByLibrary.simpleMessage(
          "Payment page opened, please complete payment and return to app",
        ),
    "xboardPaymentPageOpenedInBrowser": MessageLookupByLibrary.simpleMessage(
      "Payment page opened in browser, please return to app after payment",
    ),
    "xboardPaymentSuccess": MessageLookupByLibrary.simpleMessage(
      "Payment successful",
    ),
    "xboardPaymentSuccessful": MessageLookupByLibrary.simpleMessage(
      "🎉 Payment successful!",
    ),
    "xboardPendingOrdersHint": MessageLookupByLibrary.simpleMessage(
      "If you paid but it has not arrived, refresh the order status.",
    ),
    "xboardPeriod": MessageLookupByLibrary.simpleMessage("Period"),
    "xboardPlanBased": MessageLookupByLibrary.simpleMessage("Based on plan"),
    "xboardPlanExpiryReminder": MessageLookupByLibrary.simpleMessage(
      "Plan expiry email reminder",
    ),
    "xboardPlanInfo": MessageLookupByLibrary.simpleMessage("Plans"),
    "xboardPlanName": MessageLookupByLibrary.simpleMessage("Plan name"),
    "xboardPlanNotFound": MessageLookupByLibrary.simpleMessage(
      "Plan not found",
    ),
    "xboardPlans": MessageLookupByLibrary.simpleMessage("Store"),
    "xboardPleaseEnterGiftCardCode": MessageLookupByLibrary.simpleMessage(
      "Please enter gift card code",
    ),
    "xboardPleaseSelectPaymentPeriod": MessageLookupByLibrary.simpleMessage(
      "Please select payment period",
    ),
    "xboardPleaseWait": MessageLookupByLibrary.simpleMessage("Please wait"),
    "xboardPoor": MessageLookupByLibrary.simpleMessage("Poor"),
    "xboardPreparingImport": MessageLookupByLibrary.simpleMessage(
      "Preparing import",
    ),
    "xboardPreparingPaymentPage": MessageLookupByLibrary.simpleMessage(
      "Preparing payment page, redirecting soon",
    ),
    "xboardPrevious": MessageLookupByLibrary.simpleMessage("Previous"),
    "xboardPriority": MessageLookupByLibrary.simpleMessage("Priority"),
    "xboardProcessing": MessageLookupByLibrary.simpleMessage("Processing..."),
    "xboardProductInfo": MessageLookupByLibrary.simpleMessage("Product info"),
    "xboardProfessionalSupport": MessageLookupByLibrary.simpleMessage(
      "Professional support",
    ),
    "xboardProfile": MessageLookupByLibrary.simpleMessage("Profile"),
    "xboardProtectNetworkPrivacy": MessageLookupByLibrary.simpleMessage(
      "Protect your network privacy",
    ),
    "xboardProxy": MessageLookupByLibrary.simpleMessage("Proxy"),
    "xboardProxyActualAddress": MessageLookupByLibrary.simpleMessage(
      "System address",
    ),
    "xboardProxyClientSetting": MessageLookupByLibrary.simpleMessage(
      "Client setting",
    ),
    "xboardProxyExpectedAddress": MessageLookupByLibrary.simpleMessage(
      "Expected address",
    ),
    "xboardProxyListening": MessageLookupByLibrary.simpleMessage("Listening"),
    "xboardProxyLocalPort": MessageLookupByLibrary.simpleMessage("Local port"),
    "xboardProxyMode": MessageLookupByLibrary.simpleMessage("Proxy Mode"),
    "xboardProxyModeDirectDescription": MessageLookupByLibrary.simpleMessage(
      "All traffic connects directly without proxy",
    ),
    "xboardProxyModeGlobalDescription": MessageLookupByLibrary.simpleMessage(
      "All traffic goes through proxy server",
    ),
    "xboardProxyModeRuleDescription": MessageLookupByLibrary.simpleMessage(
      "Automatically select direct or proxy based on rules",
    ),
    "xboardProxyNotListening": MessageLookupByLibrary.simpleMessage(
      "Not listening",
    ),
    "xboardProxyRepairCoreNotRunning": MessageLookupByLibrary.simpleMessage(
      "The proxy core is not running. Connect first, then run one-click repair.",
    ),
    "xboardProxyRepairPortUnavailable": MessageLookupByLibrary.simpleMessage(
      "The local proxy port is not listening; system proxy was not enabled.",
    ),
    "xboardProxyRepairVerifyFailed": MessageLookupByLibrary.simpleMessage(
      "System proxy verification failed after repair; the IP or port still does not match.",
    ),
    "xboardProxyRepairWriteFailed": MessageLookupByLibrary.simpleMessage(
      "Failed to write the device system proxy settings.",
    ),
    "xboardProxyStatusClientDisabled": MessageLookupByLibrary.simpleMessage(
      "The client system proxy setting is not enabled",
    ),
    "xboardProxyStatusMismatch": MessageLookupByLibrary.simpleMessage(
      "The system proxy IP or port does not match the client",
    ),
    "xboardProxyStatusPortUnavailable": MessageLookupByLibrary.simpleMessage(
      "The local proxy port is not listening",
    ),
    "xboardProxyStatusReadFailed": MessageLookupByLibrary.simpleMessage(
      "Unable to read the system proxy status",
    ),
    "xboardProxyStatusSource": MessageLookupByLibrary.simpleMessage(
      "System source",
    ),
    "xboardProxyStatusStale": MessageLookupByLibrary.simpleMessage(
      "The core is stopped, but a stale system proxy is still enabled",
    ),
    "xboardProxyStatusSystemDisabled": MessageLookupByLibrary.simpleMessage(
      "The device system proxy is not enabled",
    ),
    "xboardProxyStatusTunActive": MessageLookupByLibrary.simpleMessage(
      "TUN is active; system proxy is not required",
    ),
    "xboardPurchasePlan": MessageLookupByLibrary.simpleMessage("Purchase plan"),
    "xboardPurchaseSubscription": MessageLookupByLibrary.simpleMessage(
      "Purchase subscription",
    ),
    "xboardPurchaseSubscriptionToUse": MessageLookupByLibrary.simpleMessage(
      "Please purchase a subscription to use",
    ),
    "xboardPurchaseTraffic": MessageLookupByLibrary.simpleMessage(
      "Purchase traffic",
    ),
    "xboardQuarterlyPayment": MessageLookupByLibrary.simpleMessage("Quarterly"),
    "xboardRecharge": MessageLookupByLibrary.simpleMessage("Recharge"),
    "xboardRechargeAmount": MessageLookupByLibrary.simpleMessage(
      "Recharge amount",
    ),
    "xboardRechargeBalance": MessageLookupByLibrary.simpleMessage(
      "Recharge balance",
    ),
    "xboardRechargeBalanceTip": MessageLookupByLibrary.simpleMessage(
      "The recharge amount will be added to your account balance.",
    ),
    "xboardRechargeBonus": MessageLookupByLibrary.simpleMessage(
      "Recharge bonus",
    ),
    "xboardRechargeNow": MessageLookupByLibrary.simpleMessage("Recharge now"),
    "xboardRedeemFailed": MessageLookupByLibrary.simpleMessage("Redeem failed"),
    "xboardRedeemFailedWithError": m46,
    "xboardRedeemNow": MessageLookupByLibrary.simpleMessage("Redeem now"),
    "xboardRedeemSuccess": MessageLookupByLibrary.simpleMessage(
      "Redeem successful",
    ),
    "xboardRefresh": MessageLookupByLibrary.simpleMessage("Refresh"),
    "xboardRefreshFailedHint": MessageLookupByLibrary.simpleMessage(
      "Subscription refresh failed, please refresh manually later",
    ),
    "xboardRefreshStatus": MessageLookupByLibrary.simpleMessage(
      "Refresh status",
    ),
    "xboardRefundAmount": MessageLookupByLibrary.simpleMessage(
      "Refund to wallet",
    ),
    "xboardRegister": MessageLookupByLibrary.simpleMessage("Register"),
    "xboardRegisterFailed": MessageLookupByLibrary.simpleMessage(
      "Registration failed",
    ),
    "xboardRegisterSuccess": MessageLookupByLibrary.simpleMessage(
      "Registration successful! Redirecting to login page...",
    ),
    "xboardReleaseOfflineDevices": MessageLookupByLibrary.simpleMessage(
      "Release offline devices",
    ),
    "xboardReleaseOfflineDevicesConfirm": MessageLookupByLibrary.simpleMessage(
      "This will remove offline devices that still occupy your device limit. Your current device will not be affected. Continue?",
    ),
    "xboardReload": MessageLookupByLibrary.simpleMessage("Reload"),
    "xboardReloadNodes": MessageLookupByLibrary.simpleMessage("Reload nodes"),
    "xboardRelogin": MessageLookupByLibrary.simpleMessage("Login Again"),
    "xboardRemainingBalance": MessageLookupByLibrary.simpleMessage("Remaining"),
    "xboardRememberPassword": MessageLookupByLibrary.simpleMessage(
      "Remember Password",
    ),
    "xboardRenewPlan": MessageLookupByLibrary.simpleMessage("Renew plan"),
    "xboardRenewToContinue": MessageLookupByLibrary.simpleMessage(
      "Please renew to continue using",
    ),
    "xboardReopen": MessageLookupByLibrary.simpleMessage("Reopen"),
    "xboardReopenPayment": MessageLookupByLibrary.simpleMessage(
      "Reopen Payment",
    ),
    "xboardReopenPaymentPageTip": MessageLookupByLibrary.simpleMessage(
      "To reopen, click the \\\"Reopen\\\" button below",
    ),
    "xboardRepairCompleted": MessageLookupByLibrary.simpleMessage(
      "Repair completed",
    ),
    "xboardReplyFailedRetry": MessageLookupByLibrary.simpleMessage(
      "Reply failed. Please try again later.",
    ),
    "xboardReplyHint": MessageLookupByLibrary.simpleMessage("Enter a reply..."),
    "xboardResetCurrentPlanTraffic": MessageLookupByLibrary.simpleMessage(
      "Reset current plan traffic",
    ),
    "xboardResetTraffic": MessageLookupByLibrary.simpleMessage("Reset traffic"),
    "xboardResetTrafficByPlanCycle": MessageLookupByLibrary.simpleMessage(
      "Reset traffic by plan cycle",
    ),
    "xboardResetTrafficConfirmContent": MessageLookupByLibrary.simpleMessage(
      "This will reset the used traffic, but will not extend the plan duration. Continue?",
    ),
    "xboardResetTrafficInDays": m47,
    "xboardResetTrafficToday": MessageLookupByLibrary.simpleMessage(
      "Used traffic has been reset today",
    ),
    "xboardRetry": MessageLookupByLibrary.simpleMessage("Retry"),
    "xboardRetryGet": MessageLookupByLibrary.simpleMessage("Retry"),
    "xboardReturn": MessageLookupByLibrary.simpleMessage("Return"),
    "xboardReturnAfterPaymentAutoDetect": MessageLookupByLibrary.simpleMessage(
      "3. Return to app after payment, system will detect automatically",
    ),
    "xboardRunDiagnosis": MessageLookupByLibrary.simpleMessage("Run check"),
    "xboardRunningTime": m48,
    "xboardSecureEncryption": MessageLookupByLibrary.simpleMessage(
      "Secure encryption",
    ),
    "xboardSelectPaymentMethod": MessageLookupByLibrary.simpleMessage(
      "Select payment method",
    ),
    "xboardSelectPaymentPeriod": MessageLookupByLibrary.simpleMessage(
      "Select payment period",
    ),
    "xboardSelectPeriod": MessageLookupByLibrary.simpleMessage(
      "Please select purchase period",
    ),
    "xboardSelectRechargeAmount": MessageLookupByLibrary.simpleMessage(
      "Select recharge amount",
    ),
    "xboardSendVerificationCode": MessageLookupByLibrary.simpleMessage(
      "Send Verification Code",
    ),
    "xboardServerError": MessageLookupByLibrary.simpleMessage("Server error"),
    "xboardServerStatus": MessageLookupByLibrary.simpleMessage("Server status"),
    "xboardServiceConnectionDegraded": MessageLookupByLibrary.simpleMessage(
      "Service connection unstable",
    ),
    "xboardServiceOfflineCacheMode": MessageLookupByLibrary.simpleMessage(
      "Offline cache mode",
    ),
    "xboardServiceRecovering": MessageLookupByLibrary.simpleMessage(
      "Restoring connection",
    ),
    "xboardSetup": MessageLookupByLibrary.simpleMessage("Setup"),
    "xboardSixMonthCycle": MessageLookupByLibrary.simpleMessage(
      "6-month cycle",
    ),
    "xboardSmartLatencyStarted": MessageLookupByLibrary.simpleMessage(
      "Smart latency test started",
    ),
    "xboardSmartRouting": MessageLookupByLibrary.simpleMessage("Smart routing"),
    "xboardSoftwareSettings": MessageLookupByLibrary.simpleMessage(
      "Software settings",
    ),
    "xboardSpeedLimit": MessageLookupByLibrary.simpleMessage("Speed"),
    "xboardStartNewPeriod": MessageLookupByLibrary.simpleMessage(
      "Start next traffic period",
    ),
    "xboardStartProxy": MessageLookupByLibrary.simpleMessage("Start Proxy"),
    "xboardStop": MessageLookupByLibrary.simpleMessage("Stop"),
    "xboardStopProxy": MessageLookupByLibrary.simpleMessage("Stop Proxy"),
    "xboardStreamingAccessible": MessageLookupByLibrary.simpleMessage(
      "Accessible",
    ),
    "xboardStreamingAccessibleCount": MessageLookupByLibrary.simpleMessage(
      "Accessible services",
    ),
    "xboardStreamingBlocked": MessageLookupByLibrary.simpleMessage(
      "IP blocked by service",
    ),
    "xboardStreamingCancelled": MessageLookupByLibrary.simpleMessage(
      "Cancelled",
    ),
    "xboardStreamingCheck": MessageLookupByLibrary.simpleMessage(
      "Streaming & AI check",
    ),
    "xboardStreamingCheckSubtitle": MessageLookupByLibrary.simpleMessage(
      "Check common streaming and AI services through the current node",
    ),
    "xboardStreamingChecking": MessageLookupByLibrary.simpleMessage(
      "Checking…",
    ),
    "xboardStreamingConnectFirst": MessageLookupByLibrary.simpleMessage(
      "Connect the VPN first. Streaming and AI checks must run through the current node.",
    ),
    "xboardStreamingConnected": MessageLookupByLibrary.simpleMessage(
      "VPN connected",
    ),
    "xboardStreamingCopyReport": MessageLookupByLibrary.simpleMessage(
      "Copy report",
    ),
    "xboardStreamingCurrentNode": MessageLookupByLibrary.simpleMessage(
      "Current node",
    ),
    "xboardStreamingDisclaimer": MessageLookupByLibrary.simpleMessage(
      "Results are based on service-endpoint and public-page access through the current node and are for reference only. Service policies, account regions, sign-in status, and licensing restrictions may affect actual use.",
    ),
    "xboardStreamingDisconnected": MessageLookupByLibrary.simpleMessage(
      "The VPN disconnected. These results are no longer valid.",
    ),
    "xboardStreamingError": MessageLookupByLibrary.simpleMessage(
      "Check failed",
    ),
    "xboardStreamingExitRegion": MessageLookupByLibrary.simpleMessage(
      "Exit region",
    ),
    "xboardStreamingNodeChanged": MessageLookupByLibrary.simpleMessage(
      "The node changed during the check. Run the check again.",
    ),
    "xboardStreamingNodeUnavailable": MessageLookupByLibrary.simpleMessage(
      "The current node is temporarily unavailable. Try again shortly.",
    ),
    "xboardStreamingNotConnected": MessageLookupByLibrary.simpleMessage(
      "VPN not connected",
    ),
    "xboardStreamingPartiallyAccessible": MessageLookupByLibrary.simpleMessage(
      "Partially available",
    ),
    "xboardStreamingProgress": MessageLookupByLibrary.simpleMessage("Progress"),
    "xboardStreamingReportCopied": MessageLookupByLibrary.simpleMessage(
      "Streaming and AI check report copied",
    ),
    "xboardStreamingReportDetail": MessageLookupByLibrary.simpleMessage(
      "Evidence",
    ),
    "xboardStreamingReportSystem": MessageLookupByLibrary.simpleMessage(
      "System",
    ),
    "xboardStreamingReportTime": MessageLookupByLibrary.simpleMessage(
      "Checked at",
    ),
    "xboardStreamingReportTitle": MessageLookupByLibrary.simpleMessage(
      "FastCat Streaming & AI Check Report",
    ),
    "xboardStreamingReportVersion": MessageLookupByLibrary.simpleMessage(
      "Client version",
    ),
    "xboardStreamingRestricted": MessageLookupByLibrary.simpleMessage(
      "Region restricted",
    ),
    "xboardStreamingResults": MessageLookupByLibrary.simpleMessage("Results"),
    "xboardStreamingRetest": MessageLookupByLibrary.simpleMessage(
      "Check again",
    ),
    "xboardStreamingStart": MessageLookupByLibrary.simpleMessage("Start check"),
    "xboardStreamingSummary": MessageLookupByLibrary.simpleMessage("Summary"),
    "xboardStreamingSummaryAccessible": MessageLookupByLibrary.simpleMessage(
      "Confirmed available",
    ),
    "xboardStreamingSummaryInconclusive": MessageLookupByLibrary.simpleMessage(
      "Error/inconclusive",
    ),
    "xboardStreamingSummaryPartial": MessageLookupByLibrary.simpleMessage(
      "Partially available",
    ),
    "xboardStreamingSummaryRestricted": MessageLookupByLibrary.simpleMessage(
      "Restricted/unavailable",
    ),
    "xboardStreamingSummaryVerification": MessageLookupByLibrary.simpleMessage(
      "Verification required",
    ),
    "xboardStreamingTimeout": MessageLookupByLibrary.simpleMessage("Timed out"),
    "xboardStreamingUnavailable": MessageLookupByLibrary.simpleMessage(
      "Unavailable",
    ),
    "xboardStreamingUncertain": MessageLookupByLibrary.simpleMessage(
      "Unable to confirm",
    ),
    "xboardStreamingUnknown": MessageLookupByLibrary.simpleMessage("Unknown"),
    "xboardStreamingVerificationRequired": MessageLookupByLibrary.simpleMessage(
      "Browser verification required",
    ),
    "xboardStreamingVisit": MessageLookupByLibrary.simpleMessage("Visit"),
    "xboardSubmitOrder": MessageLookupByLibrary.simpleMessage("Submit order"),
    "xboardSubmitTicket": MessageLookupByLibrary.simpleMessage("Submit ticket"),
    "xboardSubmitting": MessageLookupByLibrary.simpleMessage("Submitting..."),
    "xboardSubscription": MessageLookupByLibrary.simpleMessage("Subscription"),
    "xboardSubscriptionCopied": MessageLookupByLibrary.simpleMessage(
      "Subscription link copied to clipboard",
    ),
    "xboardSubscriptionExpired": MessageLookupByLibrary.simpleMessage(
      "Subscription expired",
    ),
    "xboardSubscriptionHasExpired": MessageLookupByLibrary.simpleMessage(
      "Subscription has expired",
    ),
    "xboardSubscriptionHealth": MessageLookupByLibrary.simpleMessage(
      "Subscription status",
    ),
    "xboardSubscriptionInfo": MessageLookupByLibrary.simpleMessage(
      "Subscription information",
    ),
    "xboardSubscriptionLink": MessageLookupByLibrary.simpleMessage(
      "Subscription link",
    ),
    "xboardSubscriptionLinkCopied": MessageLookupByLibrary.simpleMessage(
      "Subscription link copied to clipboard",
    ),
    "xboardSubscriptionPurchase": MessageLookupByLibrary.simpleMessage(
      "Subscription purchase",
    ),
    "xboardSubscriptionSlowUsingCache": MessageLookupByLibrary.simpleMessage(
      "Server response is slow; using cached data",
    ),
    "xboardSubscriptionStatus": MessageLookupByLibrary.simpleMessage(
      "Subscription status",
    ),
    "xboardSurplusAmount": MessageLookupByLibrary.simpleMessage(
      "Surplus amount",
    ),
    "xboardSwitch": MessageLookupByLibrary.simpleMessage("Switch"),
    "xboardSyncingSubscription": MessageLookupByLibrary.simpleMessage(
      "Syncing account subscription...",
    ),
    "xboardTestCurrentNode": MessageLookupByLibrary.simpleMessage(
      "Test current node",
    ),
    "xboardTestLatency": MessageLookupByLibrary.simpleMessage("Test latency"),
    "xboardTesting": MessageLookupByLibrary.simpleMessage("Testing"),
    "xboardThirtySixMonthCycle": MessageLookupByLibrary.simpleMessage(
      "36-month cycle",
    ),
    "xboardThreeMonthCycle": MessageLookupByLibrary.simpleMessage(
      "3-month cycle",
    ),
    "xboardThreeYearPayment": MessageLookupByLibrary.simpleMessage(
      "Three-year",
    ),
    "xboardTicketClosed": MessageLookupByLibrary.simpleMessage("Closed"),
    "xboardTicketClosedMessage": MessageLookupByLibrary.simpleMessage(
      "Ticket closed",
    ),
    "xboardTicketDescription": MessageLookupByLibrary.simpleMessage(
      "Description",
    ),
    "xboardTicketDescriptionHint": MessageLookupByLibrary.simpleMessage(
      "Describe your issue in detail",
    ),
    "xboardTicketDetails": MessageLookupByLibrary.simpleMessage(
      "Ticket details",
    ),
    "xboardTicketPendingReply": MessageLookupByLibrary.simpleMessage(
      "Pending reply",
    ),
    "xboardTicketReplied": MessageLookupByLibrary.simpleMessage("Replied"),
    "xboardTicketTitle": MessageLookupByLibrary.simpleMessage("Ticket title"),
    "xboardTicketTitleHint": MessageLookupByLibrary.simpleMessage(
      "Enter ticket title",
    ),
    "xboardTimeout": MessageLookupByLibrary.simpleMessage("Timeout"),
    "xboardTokenExpiredContent": MessageLookupByLibrary.simpleMessage(
      "Your login session has expired. Please login again to continue.",
    ),
    "xboardTokenExpiredTitle": MessageLookupByLibrary.simpleMessage(
      "Login Expired",
    ),
    "xboardToolsSettings": MessageLookupByLibrary.simpleMessage(
      "Tools Settings",
    ),
    "xboardTotal": MessageLookupByLibrary.simpleMessage("Total"),
    "xboardTotalTraffic": MessageLookupByLibrary.simpleMessage("Total"),
    "xboardTraffic": MessageLookupByLibrary.simpleMessage("Traffic"),
    "xboardTrafficDetails": MessageLookupByLibrary.simpleMessage(
      "Traffic details",
    ),
    "xboardTrafficExhausted": MessageLookupByLibrary.simpleMessage(
      "Traffic exhausted",
    ),
    "xboardTrafficExhaustedRenewConfirmContent":
        MessageLookupByLibrary.simpleMessage(
          "Renewing the plan will not reset traffic immediately. To use service right away, reset traffic or switch plans. Continue?",
        ),
    "xboardTrafficLogHint": MessageLookupByLibrary.simpleMessage(
      "Only showing traffic data from the last 30 days",
    ),
    "xboardTrafficReminder": MessageLookupByLibrary.simpleMessage(
      "Traffic usage email reminder",
    ),
    "xboardTrafficUsedUp": MessageLookupByLibrary.simpleMessage(
      "Traffic used up",
    ),
    "xboardTunAllTraffic": MessageLookupByLibrary.simpleMessage(
      "All-traffic proxy",
    ),
    "xboardTunAllTrafficDescription": MessageLookupByLibrary.simpleMessage(
      "Captures traffic from all apps without separate configuration.",
    ),
    "xboardTunEnabled": MessageLookupByLibrary.simpleMessage("TUN enabled"),
    "xboardTunGlobalRecommendation": MessageLookupByLibrary.simpleMessage(
      "Fallback: Global + TUN when rules mode does not work as expected",
    ),
    "xboardTunModeDescription": MessageLookupByLibrary.simpleMessage(
      "TUN mode uses a virtual network interface to proxy application traffic more completely.",
    ),
    "xboardTunModeTitle": MessageLookupByLibrary.simpleMessage("TUN mode"),
    "xboardTunPerformance": MessageLookupByLibrary.simpleMessage(
      "Performance optimization",
    ),
    "xboardTunPerformanceDescription": MessageLookupByLibrary.simpleMessage(
      "Reduces proxy layers to improve network speed.",
    ),
    "xboardTunRecommendedUsage": MessageLookupByLibrary.simpleMessage(
      "Recommended usage",
    ),
    "xboardTunRuleRecommendation": MessageLookupByLibrary.simpleMessage(
      "Daily use: Rules + TUN for smart routing and best performance",
    ),
    "xboardTunTransparentProxy": MessageLookupByLibrary.simpleMessage(
      "Transparent proxy",
    ),
    "xboardTunTransparentProxyDescription":
        MessageLookupByLibrary.simpleMessage(
          "Apps use the proxy without extra setup for better compatibility.",
        ),
    "xboardTwelveMonthCycle": MessageLookupByLibrary.simpleMessage(
      "12-month cycle",
    ),
    "xboardTwentyFourMonthCycle": MessageLookupByLibrary.simpleMessage(
      "24-month cycle",
    ),
    "xboardTwoYearPayment": MessageLookupByLibrary.simpleMessage("Two-year"),
    "xboardUnauthorizedAccess": MessageLookupByLibrary.simpleMessage(
      "Unauthorized access, please login first",
    ),
    "xboardUnknownErrorRetry": MessageLookupByLibrary.simpleMessage(
      "Unknown error, please retry",
    ),
    "xboardUnknownPeriod": MessageLookupByLibrary.simpleMessage(
      "Unknown period",
    ),
    "xboardUnknownPlan": MessageLookupByLibrary.simpleMessage("Unknown plan"),
    "xboardUnknownUser": MessageLookupByLibrary.simpleMessage("Unknown User"),
    "xboardUnlimited": MessageLookupByLibrary.simpleMessage("Unlimited"),
    "xboardUnlimitedSpeed": MessageLookupByLibrary.simpleMessage(
      "Unlimited speed",
    ),
    "xboardUnselected": MessageLookupByLibrary.simpleMessage("Unselected"),
    "xboardUnsupportedCouponType": MessageLookupByLibrary.simpleMessage(
      "Unsupported coupon type",
    ),
    "xboardUpdateContent": MessageLookupByLibrary.simpleMessage(
      "Update content:",
    ),
    "xboardUpdateLater": MessageLookupByLibrary.simpleMessage("Update Later"),
    "xboardUpdateNodes": MessageLookupByLibrary.simpleMessage("Update nodes"),
    "xboardUpdateNow": MessageLookupByLibrary.simpleMessage("Update Now"),
    "xboardUpdateSubscriptionRegularly": MessageLookupByLibrary.simpleMessage(
      "Update subscription regularly to get latest nodes",
    ),
    "xboardUploadImage": MessageLookupByLibrary.simpleMessage("Upload image"),
    "xboardUsageInstructions": MessageLookupByLibrary.simpleMessage(
      "Usage instructions",
    ),
    "xboardUseBalance": MessageLookupByLibrary.simpleMessage("Use balance"),
    "xboardUsed": MessageLookupByLibrary.simpleMessage("Used"),
    "xboardUsedTraffic": MessageLookupByLibrary.simpleMessage("Used"),
    "xboardValidatingConfigFormat": MessageLookupByLibrary.simpleMessage(
      "Validating configuration format",
    ),
    "xboardValidationFailed": MessageLookupByLibrary.simpleMessage(
      "Validation failed",
    ),
    "xboardValidityPeriod": MessageLookupByLibrary.simpleMessage("Expires"),
    "xboardVerify": MessageLookupByLibrary.simpleMessage("Verify"),
    "xboardVeryPoor": MessageLookupByLibrary.simpleMessage("Very poor"),
    "xboardWaitingForPayment": MessageLookupByLibrary.simpleMessage(
      "Waiting for payment",
    ),
    "xboardWaitingPaymentCompletion": MessageLookupByLibrary.simpleMessage(
      "Waiting for payment completion",
    ),
    "xboardWalletBalance": MessageLookupByLibrary.simpleMessage(
      "Wallet balance",
    ),
    "xboardYearlyPayment": MessageLookupByLibrary.simpleMessage("Yearly"),
    "years": MessageLookupByLibrary.simpleMessage("Years"),
    "zh_CN": MessageLookupByLibrary.simpleMessage("Simplified Chinese"),
    "zoom": MessageLookupByLibrary.simpleMessage("Zoom"),
  };
}
