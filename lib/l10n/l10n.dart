// GENERATED CODE - DO NOT MODIFY BY HAND
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'intl/messages_all.dart';

// **************************************************************************
// Generator: Flutter Intl IDE plugin
// Made by Localizely
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, lines_longer_than_80_chars
// ignore_for_file: join_return_with_assignment, prefer_final_in_for_each
// ignore_for_file: avoid_redundant_argument_values, avoid_escaping_inner_quotes

class AppLocalizations {
  AppLocalizations();

  static AppLocalizations? _current;

  static AppLocalizations get current {
    assert(
      _current != null,
      'No instance of AppLocalizations was loaded. Try to initialize the AppLocalizations delegate before accessing AppLocalizations.current.',
    );
    return _current!;
  }

  static const AppLocalizationDelegate delegate = AppLocalizationDelegate();

  static Future<AppLocalizations> load(Locale locale) {
    final name =
        (locale.countryCode?.isEmpty ?? false)
            ? locale.languageCode
            : locale.toString();
    final localeName = Intl.canonicalizedLocale(name);
    return initializeMessages(localeName).then((_) {
      Intl.defaultLocale = localeName;
      final instance = AppLocalizations();
      AppLocalizations._current = instance;

      return instance;
    });
  }

  static AppLocalizations of(BuildContext context) {
    final instance = AppLocalizations.maybeOf(context);
    assert(
      instance != null,
      'No instance of AppLocalizations present in the widget tree. Did you add AppLocalizations.delegate in localizationsDelegates?',
    );
    return instance!;
  }

  static AppLocalizations? maybeOf(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  /// `Smart Routing`
  String get rule {
    return Intl.message('Smart Routing', name: 'rule', desc: '', args: []);
  }

  /// `Global Proxy`
  String get global {
    return Intl.message('Global Proxy', name: 'global', desc: '', args: []);
  }

  /// `Direct`
  String get direct {
    return Intl.message('Direct', name: 'direct', desc: '', args: []);
  }

  /// `Dashboard`
  String get dashboard {
    return Intl.message('Dashboard', name: 'dashboard', desc: '', args: []);
  }

  /// `Proxies`
  String get proxies {
    return Intl.message('Proxies', name: 'proxies', desc: '', args: []);
  }

  /// `Node Selection`
  String get nodeSelection {
    return Intl.message(
      'Node Selection',
      name: 'nodeSelection',
      desc: '',
      args: [],
    );
  }

  /// `Profile`
  String get profile {
    return Intl.message('Profile', name: 'profile', desc: '', args: []);
  }

  /// `Profiles`
  String get profiles {
    return Intl.message('Profiles', name: 'profiles', desc: '', args: []);
  }

  /// `Tools`
  String get tools {
    return Intl.message('Tools', name: 'tools', desc: '', args: []);
  }

  /// `Logs`
  String get logs {
    return Intl.message('Logs', name: 'logs', desc: '', args: []);
  }

  /// `Log capture records`
  String get logsDesc {
    return Intl.message(
      'Log capture records',
      name: 'logsDesc',
      desc: '',
      args: [],
    );
  }

  /// `Resources`
  String get resources {
    return Intl.message('Resources', name: 'resources', desc: '', args: []);
  }

  /// `External resource related info`
  String get resourcesDesc {
    return Intl.message(
      'External resource related info',
      name: 'resourcesDesc',
      desc: '',
      args: [],
    );
  }

  /// `Traffic usage`
  String get trafficUsage {
    return Intl.message(
      'Traffic usage',
      name: 'trafficUsage',
      desc: '',
      args: [],
    );
  }

  /// `Core info`
  String get coreInfo {
    return Intl.message('Core info', name: 'coreInfo', desc: '', args: []);
  }

  /// `Network speed`
  String get networkSpeed {
    return Intl.message(
      'Network speed',
      name: 'networkSpeed',
      desc: '',
      args: [],
    );
  }

  /// `Outbound mode`
  String get outboundMode {
    return Intl.message(
      'Outbound mode',
      name: 'outboundMode',
      desc: '',
      args: [],
    );
  }

  /// `Network detection`
  String get networkDetection {
    return Intl.message(
      'Network detection',
      name: 'networkDetection',
      desc: '',
      args: [],
    );
  }

  /// `Upload`
  String get upload {
    return Intl.message('Upload', name: 'upload', desc: '', args: []);
  }

  /// `Download`
  String get download {
    return Intl.message('Download', name: 'download', desc: '', args: []);
  }

  /// `No proxy`
  String get noProxy {
    return Intl.message('No proxy', name: 'noProxy', desc: '', args: []);
  }

  /// `Please create a profile or add a valid profile`
  String get noProxyDesc {
    return Intl.message(
      'Please create a profile or add a valid profile',
      name: 'noProxyDesc',
      desc: '',
      args: [],
    );
  }

  /// `No profile, Please add a profile`
  String get nullProfileDesc {
    return Intl.message(
      'No profile, Please add a profile',
      name: 'nullProfileDesc',
      desc: '',
      args: [],
    );
  }

  /// `Settings`
  String get settings {
    return Intl.message('Settings', name: 'settings', desc: '', args: []);
  }

  /// `Language`
  String get language {
    return Intl.message('Language', name: 'language', desc: '', args: []);
  }

  /// `Default`
  String get defaultText {
    return Intl.message('Default', name: 'defaultText', desc: '', args: []);
  }

  /// `More`
  String get more {
    return Intl.message('More', name: 'more', desc: '', args: []);
  }

  /// `Other`
  String get other {
    return Intl.message('Other', name: 'other', desc: '', args: []);
  }

  /// `About`
  String get about {
    return Intl.message('About', name: 'about', desc: '', args: []);
  }

  /// `Checking...`
  String get domainStatusChecking {
    return Intl.message(
      'Checking...',
      name: 'domainStatusChecking',
      desc: '',
      args: [],
    );
  }

  /// `Service Available`
  String get domainStatusAvailable {
    return Intl.message(
      'Service Available',
      name: 'domainStatusAvailable',
      desc: '',
      args: [],
    );
  }

  /// `Service Unavailable`
  String get domainStatusUnavailable {
    return Intl.message(
      'Service Unavailable',
      name: 'domainStatusUnavailable',
      desc: '',
      args: [],
    );
  }

  /// `English`
  String get en {
    return Intl.message('English', name: 'en', desc: '', args: []);
  }

  /// `Simplified Chinese`
  String get zh_CN {
    return Intl.message(
      'Simplified Chinese',
      name: 'zh_CN',
      desc: '',
      args: [],
    );
  }

  /// `Theme`
  String get theme {
    return Intl.message('Theme', name: 'theme', desc: '', args: []);
  }

  /// `Set dark mode,adjust the color`
  String get themeDesc {
    return Intl.message(
      'Set dark mode,adjust the color',
      name: 'themeDesc',
      desc: '',
      args: [],
    );
  }

  /// `Override`
  String get override {
    return Intl.message('Override', name: 'override', desc: '', args: []);
  }

  /// `Override Proxy related config`
  String get overrideDesc {
    return Intl.message(
      'Override Proxy related config',
      name: 'overrideDesc',
      desc: '',
      args: [],
    );
  }

  /// `AllowLan`
  String get allowLan {
    return Intl.message('AllowLan', name: 'allowLan', desc: '', args: []);
  }

  /// `Allow access proxy through the LAN`
  String get allowLanDesc {
    return Intl.message(
      'Allow access proxy through the LAN',
      name: 'allowLanDesc',
      desc: '',
      args: [],
    );
  }

  /// `Virtual network adapter (TUN)`
  String get tun {
    return Intl.message(
      'Virtual network adapter (TUN)',
      name: 'tun',
      desc: '',
      args: [],
    );
  }

  /// `only effective in administrator mode`
  String get tunDesc {
    return Intl.message(
      'only effective in administrator mode',
      name: 'tunDesc',
      desc: '',
      args: [],
    );
  }

  /// `Minimize on exit`
  String get minimizeOnExit {
    return Intl.message(
      'Minimize on exit',
      name: 'minimizeOnExit',
      desc: '',
      args: [],
    );
  }

  /// `Modify the default system exit event`
  String get minimizeOnExitDesc {
    return Intl.message(
      'Modify the default system exit event',
      name: 'minimizeOnExitDesc',
      desc: '',
      args: [],
    );
  }

  /// `Start on Boot`
  String get autoLaunch {
    return Intl.message(
      'Start on Boot',
      name: 'autoLaunch',
      desc: '',
      args: [],
    );
  }

  /// `Follow the system self startup`
  String get autoLaunchDesc {
    return Intl.message(
      'Follow the system self startup',
      name: 'autoLaunchDesc',
      desc: '',
      args: [],
    );
  }

  /// `SilentLaunch`
  String get silentLaunch {
    return Intl.message(
      'SilentLaunch',
      name: 'silentLaunch',
      desc: '',
      args: [],
    );
  }

  /// `Start in the background`
  String get silentLaunchDesc {
    return Intl.message(
      'Start in the background',
      name: 'silentLaunchDesc',
      desc: '',
      args: [],
    );
  }

  /// `AutoRun`
  String get autoRun {
    return Intl.message('AutoRun', name: 'autoRun', desc: '', args: []);
  }

  /// `Auto run when the application is opened`
  String get autoRunDesc {
    return Intl.message(
      'Auto run when the application is opened',
      name: 'autoRunDesc',
      desc: '',
      args: [],
    );
  }

  /// `Startup`
  String get xboardStartup {
    return Intl.message('Startup', name: 'xboardStartup', desc: '', args: []);
  }

  /// `Launch at startup and connect to the proxy automatically`
  String get xboardStartupDescription {
    return Intl.message(
      'Launch at startup and connect to the proxy automatically',
      name: 'xboardStartupDescription',
      desc: '',
      args: [],
    );
  }

  /// `Connect to the proxy automatically when the app opens`
  String get xboardAutoRunDescription {
    return Intl.message(
      'Connect to the proxy automatically when the app opens',
      name: 'xboardAutoRunDescription',
      desc: '',
      args: [],
    );
  }

  /// `Logcat`
  String get logcat {
    return Intl.message('Logcat', name: 'logcat', desc: '', args: []);
  }

  /// `When enabled, Logs will appear in the root menu`
  String get logcatDesc {
    return Intl.message(
      'When enabled, Logs will appear in the root menu',
      name: 'logcatDesc',
      desc: '',
      args: [],
    );
  }

  /// `Auto check updates`
  String get autoCheckUpdate {
    return Intl.message(
      'Auto check updates',
      name: 'autoCheckUpdate',
      desc: '',
      args: [],
    );
  }

  /// `Auto check for updates when the app starts`
  String get autoCheckUpdateDesc {
    return Intl.message(
      'Auto check for updates when the app starts',
      name: 'autoCheckUpdateDesc',
      desc: '',
      args: [],
    );
  }

  /// `AccessControl`
  String get accessControl {
    return Intl.message(
      'AccessControl',
      name: 'accessControl',
      desc: '',
      args: [],
    );
  }

  /// `Configure application access proxy`
  String get accessControlDesc {
    return Intl.message(
      'Configure application access proxy',
      name: 'accessControlDesc',
      desc: '',
      args: [],
    );
  }

  /// `Application`
  String get application {
    return Intl.message('Application', name: 'application', desc: '', args: []);
  }

  /// `Modify application related settings`
  String get applicationDesc {
    return Intl.message(
      'Modify application related settings',
      name: 'applicationDesc',
      desc: '',
      args: [],
    );
  }

  /// `Edit`
  String get edit {
    return Intl.message('Edit', name: 'edit', desc: '', args: []);
  }

  /// `Confirm`
  String get confirm {
    return Intl.message('Confirm', name: 'confirm', desc: '', args: []);
  }

  /// `Update`
  String get update {
    return Intl.message('Update', name: 'update', desc: '', args: []);
  }

  /// `Add`
  String get add {
    return Intl.message('Add', name: 'add', desc: '', args: []);
  }

  /// `Save`
  String get save {
    return Intl.message('Save', name: 'save', desc: '', args: []);
  }

  /// `Delete`
  String get delete {
    return Intl.message('Delete', name: 'delete', desc: '', args: []);
  }

  /// `Years`
  String get years {
    return Intl.message('Years', name: 'years', desc: '', args: []);
  }

  /// `Months`
  String get months {
    return Intl.message('Months', name: 'months', desc: '', args: []);
  }

  /// `Hours`
  String get hours {
    return Intl.message('Hours', name: 'hours', desc: '', args: []);
  }

  /// `Days`
  String get days {
    return Intl.message('Days', name: 'days', desc: '', args: []);
  }

  /// `Minutes`
  String get minutes {
    return Intl.message('Minutes', name: 'minutes', desc: '', args: []);
  }

  /// `Seconds`
  String get seconds {
    return Intl.message('Seconds', name: 'seconds', desc: '', args: []);
  }

  /// ` Ago`
  String get ago {
    return Intl.message(' Ago', name: 'ago', desc: '', args: []);
  }

  /// `Just`
  String get just {
    return Intl.message('Just', name: 'just', desc: '', args: []);
  }

  /// `QR code`
  String get qrcode {
    return Intl.message('QR code', name: 'qrcode', desc: '', args: []);
  }

  /// `Scan QR code to obtain profile`
  String get qrcodeDesc {
    return Intl.message(
      'Scan QR code to obtain profile',
      name: 'qrcodeDesc',
      desc: '',
      args: [],
    );
  }

  /// `URL`
  String get url {
    return Intl.message('URL', name: 'url', desc: '', args: []);
  }

  /// `Obtain profile through URL`
  String get urlDesc {
    return Intl.message(
      'Obtain profile through URL',
      name: 'urlDesc',
      desc: '',
      args: [],
    );
  }

  /// `File`
  String get file {
    return Intl.message('File', name: 'file', desc: '', args: []);
  }

  /// `Directly upload profile`
  String get fileDesc {
    return Intl.message(
      'Directly upload profile',
      name: 'fileDesc',
      desc: '',
      args: [],
    );
  }

  /// `Name`
  String get name {
    return Intl.message('Name', name: 'name', desc: '', args: []);
  }

  /// `Please input the profile name`
  String get profileNameNullValidationDesc {
    return Intl.message(
      'Please input the profile name',
      name: 'profileNameNullValidationDesc',
      desc: '',
      args: [],
    );
  }

  /// `Please input the profile URL`
  String get profileUrlNullValidationDesc {
    return Intl.message(
      'Please input the profile URL',
      name: 'profileUrlNullValidationDesc',
      desc: '',
      args: [],
    );
  }

  /// `Please input a valid profile URL`
  String get profileUrlInvalidValidationDesc {
    return Intl.message(
      'Please input a valid profile URL',
      name: 'profileUrlInvalidValidationDesc',
      desc: '',
      args: [],
    );
  }

  /// `Auto update`
  String get autoUpdate {
    return Intl.message('Auto update', name: 'autoUpdate', desc: '', args: []);
  }

  /// `Auto update interval (minutes)`
  String get autoUpdateInterval {
    return Intl.message(
      'Auto update interval (minutes)',
      name: 'autoUpdateInterval',
      desc: '',
      args: [],
    );
  }

  /// `Please enter the auto update interval time`
  String get profileAutoUpdateIntervalNullValidationDesc {
    return Intl.message(
      'Please enter the auto update interval time',
      name: 'profileAutoUpdateIntervalNullValidationDesc',
      desc: '',
      args: [],
    );
  }

  /// `Please input a valid interval time format`
  String get profileAutoUpdateIntervalInvalidValidationDesc {
    return Intl.message(
      'Please input a valid interval time format',
      name: 'profileAutoUpdateIntervalInvalidValidationDesc',
      desc: '',
      args: [],
    );
  }

  /// `Theme mode`
  String get themeMode {
    return Intl.message('Theme mode', name: 'themeMode', desc: '', args: []);
  }

  /// `Theme color`
  String get themeColor {
    return Intl.message('Theme color', name: 'themeColor', desc: '', args: []);
  }

  /// `Preview`
  String get preview {
    return Intl.message('Preview', name: 'preview', desc: '', args: []);
  }

  /// `Auto`
  String get auto {
    return Intl.message('Auto', name: 'auto', desc: '', args: []);
  }

  /// `Light`
  String get light {
    return Intl.message('Light', name: 'light', desc: '', args: []);
  }

  /// `Dark`
  String get dark {
    return Intl.message('Dark', name: 'dark', desc: '', args: []);
  }

  /// `Import from URL`
  String get importFromURL {
    return Intl.message(
      'Import from URL',
      name: 'importFromURL',
      desc: '',
      args: [],
    );
  }

  /// `Submit`
  String get submit {
    return Intl.message('Submit', name: 'submit', desc: '', args: []);
  }

  /// `Do you want to pass`
  String get doYouWantToPass {
    return Intl.message(
      'Do you want to pass',
      name: 'doYouWantToPass',
      desc: '',
      args: [],
    );
  }

  /// `Create`
  String get create {
    return Intl.message('Create', name: 'create', desc: '', args: []);
  }

  /// `Sort by default`
  String get defaultSort {
    return Intl.message(
      'Sort by default',
      name: 'defaultSort',
      desc: '',
      args: [],
    );
  }

  /// `Sort by delay`
  String get delaySort {
    return Intl.message('Sort by delay', name: 'delaySort', desc: '', args: []);
  }

  /// `Sort by name`
  String get nameSort {
    return Intl.message('Sort by name', name: 'nameSort', desc: '', args: []);
  }

  /// `Please upload file`
  String get pleaseUploadFile {
    return Intl.message(
      'Please upload file',
      name: 'pleaseUploadFile',
      desc: '',
      args: [],
    );
  }

  /// `Please upload a valid QR code`
  String get pleaseUploadValidQrcode {
    return Intl.message(
      'Please upload a valid QR code',
      name: 'pleaseUploadValidQrcode',
      desc: '',
      args: [],
    );
  }

  /// `Blacklist mode`
  String get blacklistMode {
    return Intl.message(
      'Blacklist mode',
      name: 'blacklistMode',
      desc: '',
      args: [],
    );
  }

  /// `Whitelist mode`
  String get whitelistMode {
    return Intl.message(
      'Whitelist mode',
      name: 'whitelistMode',
      desc: '',
      args: [],
    );
  }

  /// `Filter system app`
  String get filterSystemApp {
    return Intl.message(
      'Filter system app',
      name: 'filterSystemApp',
      desc: '',
      args: [],
    );
  }

  /// `Cancel filter system app`
  String get cancelFilterSystemApp {
    return Intl.message(
      'Cancel filter system app',
      name: 'cancelFilterSystemApp',
      desc: '',
      args: [],
    );
  }

  /// `Select all`
  String get selectAll {
    return Intl.message('Select all', name: 'selectAll', desc: '', args: []);
  }

  /// `Cancel select all`
  String get cancelSelectAll {
    return Intl.message(
      'Cancel select all',
      name: 'cancelSelectAll',
      desc: '',
      args: [],
    );
  }

  /// `App access control`
  String get appAccessControl {
    return Intl.message(
      'App access control',
      name: 'appAccessControl',
      desc: '',
      args: [],
    );
  }

  /// `Only allow selected app to enter VPN`
  String get accessControlAllowDesc {
    return Intl.message(
      'Only allow selected app to enter VPN',
      name: 'accessControlAllowDesc',
      desc: '',
      args: [],
    );
  }

  /// `The selected application will be excluded from VPN`
  String get accessControlNotAllowDesc {
    return Intl.message(
      'The selected application will be excluded from VPN',
      name: 'accessControlNotAllowDesc',
      desc: '',
      args: [],
    );
  }

  /// `Selected`
  String get selected {
    return Intl.message('Selected', name: 'selected', desc: '', args: []);
  }

  /// `unable to update current profile`
  String get unableToUpdateCurrentProfileDesc {
    return Intl.message(
      'unable to update current profile',
      name: 'unableToUpdateCurrentProfileDesc',
      desc: '',
      args: [],
    );
  }

  /// `No more info`
  String get noMoreInfoDesc {
    return Intl.message(
      'No more info',
      name: 'noMoreInfoDesc',
      desc: '',
      args: [],
    );
  }

  /// `profile parse error`
  String get profileParseErrorDesc {
    return Intl.message(
      'profile parse error',
      name: 'profileParseErrorDesc',
      desc: '',
      args: [],
    );
  }

  /// `ProxyPort`
  String get proxyPort {
    return Intl.message('ProxyPort', name: 'proxyPort', desc: '', args: []);
  }

  /// `Set the Clash listening port`
  String get proxyPortDesc {
    return Intl.message(
      'Set the Clash listening port',
      name: 'proxyPortDesc',
      desc: '',
      args: [],
    );
  }

  /// `Port`
  String get port {
    return Intl.message('Port', name: 'port', desc: '', args: []);
  }

  /// `LogLevel`
  String get logLevel {
    return Intl.message('LogLevel', name: 'logLevel', desc: '', args: []);
  }

  /// `Show Window`
  String get show {
    return Intl.message('Show Window', name: 'show', desc: '', args: []);
  }

  /// `Exit`
  String get exit {
    return Intl.message('Exit', name: 'exit', desc: '', args: []);
  }

  /// `System proxy`
  String get systemProxy {
    return Intl.message(
      'System proxy',
      name: 'systemProxy',
      desc: '',
      args: [],
    );
  }

  /// `Project`
  String get project {
    return Intl.message('Project', name: 'project', desc: '', args: []);
  }

  /// `Core`
  String get core {
    return Intl.message('Core', name: 'core', desc: '', args: []);
  }

  /// `A multi-platform proxy client based on ClashMeta`
  String get desc {
    return Intl.message(
      'A multi-platform proxy client based on ClashMeta',
      name: 'desc',
      desc: '',
      args: [],
    );
  }

  /// `Starting VPN...`
  String get startVpn {
    return Intl.message(
      'Starting VPN...',
      name: 'startVpn',
      desc: '',
      args: [],
    );
  }

  /// `Stopping VPN...`
  String get stopVpn {
    return Intl.message('Stopping VPN...', name: 'stopVpn', desc: '', args: []);
  }

  /// `Discovery a new version`
  String get discovery {
    return Intl.message(
      'Discovery a new version',
      name: 'discovery',
      desc: '',
      args: [],
    );
  }

  /// `Compatibility mode`
  String get compatible {
    return Intl.message(
      'Compatibility mode',
      name: 'compatible',
      desc: '',
      args: [],
    );
  }

  /// `Opening it will lose part of its application ability and gain the support of full amount of Clash.`
  String get compatibleDesc {
    return Intl.message(
      'Opening it will lose part of its application ability and gain the support of full amount of Clash.',
      name: 'compatibleDesc',
      desc: '',
      args: [],
    );
  }

  /// `The current proxy group cannot be selected.`
  String get notSelectedTip {
    return Intl.message(
      'The current proxy group cannot be selected.',
      name: 'notSelectedTip',
      desc: '',
      args: [],
    );
  }

  /// `tip`
  String get tip {
    return Intl.message('tip', name: 'tip', desc: '', args: []);
  }

  /// `Backup and Recovery`
  String get backupAndRecovery {
    return Intl.message(
      'Backup and Recovery',
      name: 'backupAndRecovery',
      desc: '',
      args: [],
    );
  }

  /// `Sync data via WebDAV or file`
  String get backupAndRecoveryDesc {
    return Intl.message(
      'Sync data via WebDAV or file',
      name: 'backupAndRecoveryDesc',
      desc: '',
      args: [],
    );
  }

  /// `Account`
  String get account {
    return Intl.message('Account', name: 'account', desc: '', args: []);
  }

  /// `Backup`
  String get backup {
    return Intl.message('Backup', name: 'backup', desc: '', args: []);
  }

  /// `Recovery`
  String get recovery {
    return Intl.message('Recovery', name: 'recovery', desc: '', args: []);
  }

  /// `Only recovery profiles`
  String get recoveryProfiles {
    return Intl.message(
      'Only recovery profiles',
      name: 'recoveryProfiles',
      desc: '',
      args: [],
    );
  }

  /// `Recovery all data`
  String get recoveryAll {
    return Intl.message(
      'Recovery all data',
      name: 'recoveryAll',
      desc: '',
      args: [],
    );
  }

  /// `Recovery success`
  String get recoverySuccess {
    return Intl.message(
      'Recovery success',
      name: 'recoverySuccess',
      desc: '',
      args: [],
    );
  }

  /// `Backup success`
  String get backupSuccess {
    return Intl.message(
      'Backup success',
      name: 'backupSuccess',
      desc: '',
      args: [],
    );
  }

  /// `No info`
  String get noInfo {
    return Intl.message('No info', name: 'noInfo', desc: '', args: []);
  }

  /// `Please bind WebDAV`
  String get pleaseBindWebDAV {
    return Intl.message(
      'Please bind WebDAV',
      name: 'pleaseBindWebDAV',
      desc: '',
      args: [],
    );
  }

  /// `Bind`
  String get bind {
    return Intl.message('Bind', name: 'bind', desc: '', args: []);
  }

  /// `Connectivity：`
  String get connectivity {
    return Intl.message(
      'Connectivity：',
      name: 'connectivity',
      desc: '',
      args: [],
    );
  }

  /// `WebDAV configuration`
  String get webDAVConfiguration {
    return Intl.message(
      'WebDAV configuration',
      name: 'webDAVConfiguration',
      desc: '',
      args: [],
    );
  }

  /// `Address`
  String get address {
    return Intl.message('Address', name: 'address', desc: '', args: []);
  }

  /// `WebDAV server address`
  String get addressHelp {
    return Intl.message(
      'WebDAV server address',
      name: 'addressHelp',
      desc: '',
      args: [],
    );
  }

  /// `Please enter a valid WebDAV address`
  String get addressTip {
    return Intl.message(
      'Please enter a valid WebDAV address',
      name: 'addressTip',
      desc: '',
      args: [],
    );
  }

  /// `Password`
  String get password {
    return Intl.message('Password', name: 'password', desc: '', args: []);
  }

  /// `Check for updates`
  String get checkUpdate {
    return Intl.message(
      'Check for updates',
      name: 'checkUpdate',
      desc: '',
      args: [],
    );
  }

  /// `Discover the new version`
  String get discoverNewVersion {
    return Intl.message(
      'Discover the new version',
      name: 'discoverNewVersion',
      desc: '',
      args: [],
    );
  }

  /// `The current application is already the latest version`
  String get checkUpdateError {
    return Intl.message(
      'The current application is already the latest version',
      name: 'checkUpdateError',
      desc: '',
      args: [],
    );
  }

  /// `Go to download`
  String get goDownload {
    return Intl.message(
      'Go to download',
      name: 'goDownload',
      desc: '',
      args: [],
    );
  }

  /// `Unknown`
  String get unknown {
    return Intl.message('Unknown', name: 'unknown', desc: '', args: []);
  }

  /// `GeoData`
  String get geoData {
    return Intl.message('GeoData', name: 'geoData', desc: '', args: []);
  }

  /// `External resources`
  String get externalResources {
    return Intl.message(
      'External resources',
      name: 'externalResources',
      desc: '',
      args: [],
    );
  }

  /// `Checking...`
  String get checking {
    return Intl.message('Checking...', name: 'checking', desc: '', args: []);
  }

  /// `Country`
  String get country {
    return Intl.message('Country', name: 'country', desc: '', args: []);
  }

  /// `Check error`
  String get checkError {
    return Intl.message('Check error', name: 'checkError', desc: '', args: []);
  }

  /// `Search`
  String get search {
    return Intl.message('Search', name: 'search', desc: '', args: []);
  }

  /// `Allow applications to bypass VPN`
  String get allowBypass {
    return Intl.message(
      'Allow applications to bypass VPN',
      name: 'allowBypass',
      desc: '',
      args: [],
    );
  }

  /// `Some apps can bypass VPN when turned on`
  String get allowBypassDesc {
    return Intl.message(
      'Some apps can bypass VPN when turned on',
      name: 'allowBypassDesc',
      desc: '',
      args: [],
    );
  }

  /// `ExternalController`
  String get externalController {
    return Intl.message(
      'ExternalController',
      name: 'externalController',
      desc: '',
      args: [],
    );
  }

  /// `Once enabled, the Clash kernel can be controlled on port 9090`
  String get externalControllerDesc {
    return Intl.message(
      'Once enabled, the Clash kernel can be controlled on port 9090',
      name: 'externalControllerDesc',
      desc: '',
      args: [],
    );
  }

  /// `When turned on it will be able to receive IPv6 traffic`
  String get ipv6Desc {
    return Intl.message(
      'When turned on it will be able to receive IPv6 traffic',
      name: 'ipv6Desc',
      desc: '',
      args: [],
    );
  }

  /// `App`
  String get app {
    return Intl.message('App', name: 'app', desc: '', args: []);
  }

  /// `General`
  String get general {
    return Intl.message('General', name: 'general', desc: '', args: []);
  }

  /// `Attach HTTP proxy to VpnService`
  String get vpnSystemProxyDesc {
    return Intl.message(
      'Attach HTTP proxy to VpnService',
      name: 'vpnSystemProxyDesc',
      desc: '',
      args: [],
    );
  }

  /// `Attach HTTP proxy to VpnService`
  String get systemProxyDesc {
    return Intl.message(
      'Attach HTTP proxy to VpnService',
      name: 'systemProxyDesc',
      desc: '',
      args: [],
    );
  }

  /// `Unified delay`
  String get unifiedDelay {
    return Intl.message(
      'Unified delay',
      name: 'unifiedDelay',
      desc: '',
      args: [],
    );
  }

  /// `Remove extra delays such as handshaking`
  String get unifiedDelayDesc {
    return Intl.message(
      'Remove extra delays such as handshaking',
      name: 'unifiedDelayDesc',
      desc: '',
      args: [],
    );
  }

  /// `TCP concurrent`
  String get tcpConcurrent {
    return Intl.message(
      'TCP concurrent',
      name: 'tcpConcurrent',
      desc: '',
      args: [],
    );
  }

  /// `Enabling it will allow TCP concurrency`
  String get tcpConcurrentDesc {
    return Intl.message(
      'Enabling it will allow TCP concurrency',
      name: 'tcpConcurrentDesc',
      desc: '',
      args: [],
    );
  }

  /// `Geo Low Memory Mode`
  String get geodataLoader {
    return Intl.message(
      'Geo Low Memory Mode',
      name: 'geodataLoader',
      desc: '',
      args: [],
    );
  }

  /// `Enabling will use the Geo low memory loader`
  String get geodataLoaderDesc {
    return Intl.message(
      'Enabling will use the Geo low memory loader',
      name: 'geodataLoaderDesc',
      desc: '',
      args: [],
    );
  }

  /// `Requests`
  String get requests {
    return Intl.message('Requests', name: 'requests', desc: '', args: []);
  }

  /// `View recently request records`
  String get requestsDesc {
    return Intl.message(
      'View recently request records',
      name: 'requestsDesc',
      desc: '',
      args: [],
    );
  }

  /// `Find process`
  String get findProcessMode {
    return Intl.message(
      'Find process',
      name: 'findProcessMode',
      desc: '',
      args: [],
    );
  }

  /// `Init`
  String get init {
    return Intl.message('Init', name: 'init', desc: '', args: []);
  }

  /// `Long term effective`
  String get infiniteTime {
    return Intl.message(
      'Long term effective',
      name: 'infiniteTime',
      desc: '',
      args: [],
    );
  }

  /// `Expiration time`
  String get expirationTime {
    return Intl.message(
      'Expiration time',
      name: 'expirationTime',
      desc: '',
      args: [],
    );
  }

  /// `Connections`
  String get connections {
    return Intl.message('Connections', name: 'connections', desc: '', args: []);
  }

  /// `View current connections data`
  String get connectionsDesc {
    return Intl.message(
      'View current connections data',
      name: 'connectionsDesc',
      desc: '',
      args: [],
    );
  }

  /// `Plans`
  String get plans {
    return Intl.message('Plans', name: 'plans', desc: '', args: []);
  }

  /// `Support`
  String get onlineSupport {
    return Intl.message('Support', name: 'onlineSupport', desc: '', args: []);
  }

  /// `Intranet IP`
  String get intranetIP {
    return Intl.message('Intranet IP', name: 'intranetIP', desc: '', args: []);
  }

  /// `View`
  String get view {
    return Intl.message('View', name: 'view', desc: '', args: []);
  }

  /// `Cut`
  String get cut {
    return Intl.message('Cut', name: 'cut', desc: '', args: []);
  }

  /// `Copy`
  String get copy {
    return Intl.message('Copy', name: 'copy', desc: '', args: []);
  }

  /// `Paste`
  String get paste {
    return Intl.message('Paste', name: 'paste', desc: '', args: []);
  }

  /// `Test url`
  String get testUrl {
    return Intl.message('Test url', name: 'testUrl', desc: '', args: []);
  }

  /// `Sync`
  String get sync {
    return Intl.message('Sync', name: 'sync', desc: '', args: []);
  }

  /// `Hidden from recent tasks`
  String get exclude {
    return Intl.message(
      'Hidden from recent tasks',
      name: 'exclude',
      desc: '',
      args: [],
    );
  }

  /// `When the app is in the background, the app is hidden from the recent task`
  String get excludeDesc {
    return Intl.message(
      'When the app is in the background, the app is hidden from the recent task',
      name: 'excludeDesc',
      desc: '',
      args: [],
    );
  }

  /// `One column`
  String get oneColumn {
    return Intl.message('One column', name: 'oneColumn', desc: '', args: []);
  }

  /// `Two columns`
  String get twoColumns {
    return Intl.message('Two columns', name: 'twoColumns', desc: '', args: []);
  }

  /// `Three columns`
  String get threeColumns {
    return Intl.message(
      'Three columns',
      name: 'threeColumns',
      desc: '',
      args: [],
    );
  }

  /// `Four columns`
  String get fourColumns {
    return Intl.message(
      'Four columns',
      name: 'fourColumns',
      desc: '',
      args: [],
    );
  }

  /// `Standard`
  String get expand {
    return Intl.message('Standard', name: 'expand', desc: '', args: []);
  }

  /// `Shrink`
  String get shrink {
    return Intl.message('Shrink', name: 'shrink', desc: '', args: []);
  }

  /// `Min`
  String get min {
    return Intl.message('Min', name: 'min', desc: '', args: []);
  }

  /// `Tab`
  String get tab {
    return Intl.message('Tab', name: 'tab', desc: '', args: []);
  }

  /// `List`
  String get list {
    return Intl.message('List', name: 'list', desc: '', args: []);
  }

  /// `Delay`
  String get delay {
    return Intl.message('Delay', name: 'delay', desc: '', args: []);
  }

  /// `Style`
  String get style {
    return Intl.message('Style', name: 'style', desc: '', args: []);
  }

  /// `Size`
  String get size {
    return Intl.message('Size', name: 'size', desc: '', args: []);
  }

  /// `Sort`
  String get sort {
    return Intl.message('Sort', name: 'sort', desc: '', args: []);
  }

  /// `Columns`
  String get columns {
    return Intl.message('Columns', name: 'columns', desc: '', args: []);
  }

  /// `Proxies setting`
  String get proxiesSetting {
    return Intl.message(
      'Proxies setting',
      name: 'proxiesSetting',
      desc: '',
      args: [],
    );
  }

  /// `Proxy group`
  String get proxyGroup {
    return Intl.message('Proxy group', name: 'proxyGroup', desc: '', args: []);
  }

  /// `Go`
  String get go {
    return Intl.message('Go', name: 'go', desc: '', args: []);
  }

  /// `External link`
  String get externalLink {
    return Intl.message(
      'External link',
      name: 'externalLink',
      desc: '',
      args: [],
    );
  }

  /// `Other contributors`
  String get otherContributors {
    return Intl.message(
      'Other contributors',
      name: 'otherContributors',
      desc: '',
      args: [],
    );
  }

  /// `Auto close connections`
  String get autoCloseConnections {
    return Intl.message(
      'Auto close connections',
      name: 'autoCloseConnections',
      desc: '',
      args: [],
    );
  }

  /// `Auto close connections after change node`
  String get autoCloseConnectionsDesc {
    return Intl.message(
      'Auto close connections after change node',
      name: 'autoCloseConnectionsDesc',
      desc: '',
      args: [],
    );
  }

  /// `Only statistics proxy`
  String get onlyStatisticsProxy {
    return Intl.message(
      'Only statistics proxy',
      name: 'onlyStatisticsProxy',
      desc: '',
      args: [],
    );
  }

  /// `When turned on, only statistics proxy traffic`
  String get onlyStatisticsProxyDesc {
    return Intl.message(
      'When turned on, only statistics proxy traffic',
      name: 'onlyStatisticsProxyDesc',
      desc: '',
      args: [],
    );
  }

  /// `Pure black mode`
  String get pureBlackMode {
    return Intl.message(
      'Pure black mode',
      name: 'pureBlackMode',
      desc: '',
      args: [],
    );
  }

  /// `Tcp keep alive interval`
  String get keepAliveIntervalDesc {
    return Intl.message(
      'Tcp keep alive interval',
      name: 'keepAliveIntervalDesc',
      desc: '',
      args: [],
    );
  }

  /// ` entries`
  String get entries {
    return Intl.message(' entries', name: 'entries', desc: '', args: []);
  }

  /// `Local`
  String get local {
    return Intl.message('Local', name: 'local', desc: '', args: []);
  }

  /// `Remote`
  String get remote {
    return Intl.message('Remote', name: 'remote', desc: '', args: []);
  }

  /// `Backup local data to WebDAV`
  String get remoteBackupDesc {
    return Intl.message(
      'Backup local data to WebDAV',
      name: 'remoteBackupDesc',
      desc: '',
      args: [],
    );
  }

  /// `Recovery data from WebDAV`
  String get remoteRecoveryDesc {
    return Intl.message(
      'Recovery data from WebDAV',
      name: 'remoteRecoveryDesc',
      desc: '',
      args: [],
    );
  }

  /// `Backup local data to local`
  String get localBackupDesc {
    return Intl.message(
      'Backup local data to local',
      name: 'localBackupDesc',
      desc: '',
      args: [],
    );
  }

  /// `Recovery data from file`
  String get localRecoveryDesc {
    return Intl.message(
      'Recovery data from file',
      name: 'localRecoveryDesc',
      desc: '',
      args: [],
    );
  }

  /// `Mode`
  String get mode {
    return Intl.message('Mode', name: 'mode', desc: '', args: []);
  }

  /// `Time`
  String get time {
    return Intl.message('Time', name: 'time', desc: '', args: []);
  }

  /// `Source`
  String get source {
    return Intl.message('Source', name: 'source', desc: '', args: []);
  }

  /// `All apps`
  String get allApps {
    return Intl.message('All apps', name: 'allApps', desc: '', args: []);
  }

  /// `Only third-party apps`
  String get onlyOtherApps {
    return Intl.message(
      'Only third-party apps',
      name: 'onlyOtherApps',
      desc: '',
      args: [],
    );
  }

  /// `Action`
  String get action {
    return Intl.message('Action', name: 'action', desc: '', args: []);
  }

  /// `Intelligent selection`
  String get intelligentSelected {
    return Intl.message(
      'Intelligent selection',
      name: 'intelligentSelected',
      desc: '',
      args: [],
    );
  }

  /// `Clipboard import`
  String get clipboardImport {
    return Intl.message(
      'Clipboard import',
      name: 'clipboardImport',
      desc: '',
      args: [],
    );
  }

  /// `Export clipboard`
  String get clipboardExport {
    return Intl.message(
      'Export clipboard',
      name: 'clipboardExport',
      desc: '',
      args: [],
    );
  }

  /// `Layout`
  String get layout {
    return Intl.message('Layout', name: 'layout', desc: '', args: []);
  }

  /// `Tight`
  String get tight {
    return Intl.message('Tight', name: 'tight', desc: '', args: []);
  }

  /// `Standard`
  String get standard {
    return Intl.message('Standard', name: 'standard', desc: '', args: []);
  }

  /// `Loose`
  String get loose {
    return Intl.message('Loose', name: 'loose', desc: '', args: []);
  }

  /// `Profiles sort`
  String get profilesSort {
    return Intl.message(
      'Profiles sort',
      name: 'profilesSort',
      desc: '',
      args: [],
    );
  }

  /// `Connect`
  String get start {
    return Intl.message('Connect', name: 'start', desc: '', args: []);
  }

  /// `Disconnect`
  String get stop {
    return Intl.message('Disconnect', name: 'stop', desc: '', args: []);
  }

  /// `Start connection`
  String get trayStartConnection {
    return Intl.message(
      'Start connection',
      name: 'trayStartConnection',
      desc: '',
      args: [],
    );
  }

  /// `Disconnect connection`
  String get trayDisconnect {
    return Intl.message(
      'Disconnect connection',
      name: 'trayDisconnect',
      desc: '',
      args: [],
    );
  }

  /// `Processing app related settings`
  String get appDesc {
    return Intl.message(
      'Processing app related settings',
      name: 'appDesc',
      desc: '',
      args: [],
    );
  }

  /// `Modify VPN related settings`
  String get vpnDesc {
    return Intl.message(
      'Modify VPN related settings',
      name: 'vpnDesc',
      desc: '',
      args: [],
    );
  }

  /// `Update DNS related settings`
  String get dnsDesc {
    return Intl.message(
      'Update DNS related settings',
      name: 'dnsDesc',
      desc: '',
      args: [],
    );
  }

  /// `Key`
  String get key {
    return Intl.message('Key', name: 'key', desc: '', args: []);
  }

  /// `Value`
  String get value {
    return Intl.message('Value', name: 'value', desc: '', args: []);
  }

  /// `Add Hosts`
  String get hostsDesc {
    return Intl.message('Add Hosts', name: 'hostsDesc', desc: '', args: []);
  }

  /// `Changes take effect after restarting the VPN`
  String get vpnTip {
    return Intl.message(
      'Changes take effect after restarting the VPN',
      name: 'vpnTip',
      desc: '',
      args: [],
    );
  }

  /// `Auto routes all system traffic through VpnService`
  String get vpnEnableDesc {
    return Intl.message(
      'Auto routes all system traffic through VpnService',
      name: 'vpnEnableDesc',
      desc: '',
      args: [],
    );
  }

  /// `Options`
  String get options {
    return Intl.message('Options', name: 'options', desc: '', args: []);
  }

  /// `Loopback unlock tool`
  String get loopback {
    return Intl.message(
      'Loopback unlock tool',
      name: 'loopback',
      desc: '',
      args: [],
    );
  }

  /// `Used for UWP loopback unlocking`
  String get loopbackDesc {
    return Intl.message(
      'Used for UWP loopback unlocking',
      name: 'loopbackDesc',
      desc: '',
      args: [],
    );
  }

  /// `Providers`
  String get providers {
    return Intl.message('Providers', name: 'providers', desc: '', args: []);
  }

  /// `Proxy providers`
  String get proxyProviders {
    return Intl.message(
      'Proxy providers',
      name: 'proxyProviders',
      desc: '',
      args: [],
    );
  }

  /// `Rule providers`
  String get ruleProviders {
    return Intl.message(
      'Rule providers',
      name: 'ruleProviders',
      desc: '',
      args: [],
    );
  }

  /// `Override Dns`
  String get overrideDns {
    return Intl.message(
      'Override Dns',
      name: 'overrideDns',
      desc: '',
      args: [],
    );
  }

  /// `Turning it on will override the DNS options in the profile`
  String get overrideDnsDesc {
    return Intl.message(
      'Turning it on will override the DNS options in the profile',
      name: 'overrideDnsDesc',
      desc: '',
      args: [],
    );
  }

  /// `Status`
  String get status {
    return Intl.message('Status', name: 'status', desc: '', args: []);
  }

  /// `System DNS will be used when turned off`
  String get statusDesc {
    return Intl.message(
      'System DNS will be used when turned off',
      name: 'statusDesc',
      desc: '',
      args: [],
    );
  }

  /// `Prioritize the use of DOH's http/3`
  String get preferH3Desc {
    return Intl.message(
      'Prioritize the use of DOH\'s http/3',
      name: 'preferH3Desc',
      desc: '',
      args: [],
    );
  }

  /// `Respect rules`
  String get respectRules {
    return Intl.message(
      'Respect rules',
      name: 'respectRules',
      desc: '',
      args: [],
    );
  }

  /// `DNS connection following rules, need to configure proxy-server-nameserver`
  String get respectRulesDesc {
    return Intl.message(
      'DNS connection following rules, need to configure proxy-server-nameserver',
      name: 'respectRulesDesc',
      desc: '',
      args: [],
    );
  }

  /// `DNS mode`
  String get dnsMode {
    return Intl.message('DNS mode', name: 'dnsMode', desc: '', args: []);
  }

  /// `Fakeip range`
  String get fakeipRange {
    return Intl.message(
      'Fakeip range',
      name: 'fakeipRange',
      desc: '',
      args: [],
    );
  }

  /// `Fakeip filter`
  String get fakeipFilter {
    return Intl.message(
      'Fakeip filter',
      name: 'fakeipFilter',
      desc: '',
      args: [],
    );
  }

  /// `Default nameserver`
  String get defaultNameserver {
    return Intl.message(
      'Default nameserver',
      name: 'defaultNameserver',
      desc: '',
      args: [],
    );
  }

  /// `For resolving DNS server`
  String get defaultNameserverDesc {
    return Intl.message(
      'For resolving DNS server',
      name: 'defaultNameserverDesc',
      desc: '',
      args: [],
    );
  }

  /// `Nameserver`
  String get nameserver {
    return Intl.message('Nameserver', name: 'nameserver', desc: '', args: []);
  }

  /// `For resolving domain`
  String get nameserverDesc {
    return Intl.message(
      'For resolving domain',
      name: 'nameserverDesc',
      desc: '',
      args: [],
    );
  }

  /// `Use hosts`
  String get useHosts {
    return Intl.message('Use hosts', name: 'useHosts', desc: '', args: []);
  }

  /// `Use system hosts`
  String get useSystemHosts {
    return Intl.message(
      'Use system hosts',
      name: 'useSystemHosts',
      desc: '',
      args: [],
    );
  }

  /// `Nameserver policy`
  String get nameserverPolicy {
    return Intl.message(
      'Nameserver policy',
      name: 'nameserverPolicy',
      desc: '',
      args: [],
    );
  }

  /// `Specify the corresponding nameserver policy`
  String get nameserverPolicyDesc {
    return Intl.message(
      'Specify the corresponding nameserver policy',
      name: 'nameserverPolicyDesc',
      desc: '',
      args: [],
    );
  }

  /// `Proxy nameserver`
  String get proxyNameserver {
    return Intl.message(
      'Proxy nameserver',
      name: 'proxyNameserver',
      desc: '',
      args: [],
    );
  }

  /// `Domain for resolving proxy nodes`
  String get proxyNameserverDesc {
    return Intl.message(
      'Domain for resolving proxy nodes',
      name: 'proxyNameserverDesc',
      desc: '',
      args: [],
    );
  }

  /// `Fallback`
  String get fallback {
    return Intl.message('Fallback', name: 'fallback', desc: '', args: []);
  }

  /// `Generally use offshore DNS`
  String get fallbackDesc {
    return Intl.message(
      'Generally use offshore DNS',
      name: 'fallbackDesc',
      desc: '',
      args: [],
    );
  }

  /// `Fallback filter`
  String get fallbackFilter {
    return Intl.message(
      'Fallback filter',
      name: 'fallbackFilter',
      desc: '',
      args: [],
    );
  }

  /// `Geoip code`
  String get geoipCode {
    return Intl.message('Geoip code', name: 'geoipCode', desc: '', args: []);
  }

  /// `Ipcidr`
  String get ipcidr {
    return Intl.message('Ipcidr', name: 'ipcidr', desc: '', args: []);
  }

  /// `Domain`
  String get domain {
    return Intl.message('Domain', name: 'domain', desc: '', args: []);
  }

  /// `Reset`
  String get reset {
    return Intl.message('Reset', name: 'reset', desc: '', args: []);
  }

  /// `Show/Hide`
  String get action_view {
    return Intl.message('Show/Hide', name: 'action_view', desc: '', args: []);
  }

  /// `Start/Stop`
  String get action_start {
    return Intl.message('Start/Stop', name: 'action_start', desc: '', args: []);
  }

  /// `Switch mode`
  String get action_mode {
    return Intl.message('Switch mode', name: 'action_mode', desc: '', args: []);
  }

  /// `System proxy`
  String get action_proxy {
    return Intl.message(
      'System proxy',
      name: 'action_proxy',
      desc: '',
      args: [],
    );
  }

  /// `TUN`
  String get action_tun {
    return Intl.message('TUN', name: 'action_tun', desc: '', args: []);
  }

  /// `Important Notice`
  String get disclaimer {
    return Intl.message(
      'Important Notice',
      name: 'disclaimer',
      desc: '',
      args: [],
    );
  }

  /// `This software is currently in public beta. If you receive update reminders, please update promptly. Older versions may cause service instability or inability to use.`
  String get disclaimerDesc {
    return Intl.message(
      'This software is currently in public beta. If you receive update reminders, please update promptly. Older versions may cause service instability or inability to use.',
      name: 'disclaimerDesc',
      desc: '',
      args: [],
    );
  }

  /// `Agree`
  String get agree {
    return Intl.message('Agree', name: 'agree', desc: '', args: []);
  }

  /// `Hotkey Management`
  String get hotkeyManagement {
    return Intl.message(
      'Hotkey Management',
      name: 'hotkeyManagement',
      desc: '',
      args: [],
    );
  }

  /// `Use keyboard to control applications`
  String get hotkeyManagementDesc {
    return Intl.message(
      'Use keyboard to control applications',
      name: 'hotkeyManagementDesc',
      desc: '',
      args: [],
    );
  }

  /// `Please press the keyboard.`
  String get pressKeyboard {
    return Intl.message(
      'Please press the keyboard.',
      name: 'pressKeyboard',
      desc: '',
      args: [],
    );
  }

  /// `Please enter the correct hotkey`
  String get inputCorrectHotkey {
    return Intl.message(
      'Please enter the correct hotkey',
      name: 'inputCorrectHotkey',
      desc: '',
      args: [],
    );
  }

  /// `Hotkey conflict`
  String get hotkeyConflict {
    return Intl.message(
      'Hotkey conflict',
      name: 'hotkeyConflict',
      desc: '',
      args: [],
    );
  }

  /// `Remove`
  String get remove {
    return Intl.message('Remove', name: 'remove', desc: '', args: []);
  }

  /// `No HotKey`
  String get noHotKey {
    return Intl.message('No HotKey', name: 'noHotKey', desc: '', args: []);
  }

  /// `No network`
  String get noNetwork {
    return Intl.message('No network', name: 'noNetwork', desc: '', args: []);
  }

  /// `Allow IPv6 inbound`
  String get ipv6InboundDesc {
    return Intl.message(
      'Allow IPv6 inbound',
      name: 'ipv6InboundDesc',
      desc: '',
      args: [],
    );
  }

  /// `Export logs`
  String get exportLogs {
    return Intl.message('Export logs', name: 'exportLogs', desc: '', args: []);
  }

  /// `Copy logs`
  String get copyLogs {
    return Intl.message('Copy logs', name: 'copyLogs', desc: '', args: []);
  }

  /// `Clear logs`
  String get clearLogs {
    return Intl.message('Clear logs', name: 'clearLogs', desc: '', args: []);
  }

  /// `Clear the current logs and request records? This action cannot be undone.`
  String get clearLogsConfirm {
    return Intl.message(
      'Clear the current logs and request records? This action cannot be undone.',
      name: 'clearLogsConfirm',
      desc: '',
      args: [],
    );
  }

  /// `Logs and request records cleared`
  String get logsCleared {
    return Intl.message(
      'Logs and request records cleared',
      name: 'logsCleared',
      desc: '',
      args: [],
    );
  }

  /// `Export Success`
  String get exportSuccess {
    return Intl.message(
      'Export Success',
      name: 'exportSuccess',
      desc: '',
      args: [],
    );
  }

  /// `Icon style`
  String get iconStyle {
    return Intl.message('Icon style', name: 'iconStyle', desc: '', args: []);
  }

  /// `Icon`
  String get onlyIcon {
    return Intl.message('Icon', name: 'onlyIcon', desc: '', args: []);
  }

  /// `None`
  String get noIcon {
    return Intl.message('None', name: 'noIcon', desc: '', args: []);
  }

  /// `Stack mode`
  String get stackMode {
    return Intl.message('Stack mode', name: 'stackMode', desc: '', args: []);
  }

  /// `Network`
  String get network {
    return Intl.message('Network', name: 'network', desc: '', args: []);
  }

  /// `Modify network-related settings`
  String get networkDesc {
    return Intl.message(
      'Modify network-related settings',
      name: 'networkDesc',
      desc: '',
      args: [],
    );
  }

  /// `Bypass domain`
  String get bypassDomain {
    return Intl.message(
      'Bypass domain',
      name: 'bypassDomain',
      desc: '',
      args: [],
    );
  }

  /// `Only takes effect when the system proxy is enabled`
  String get bypassDomainDesc {
    return Intl.message(
      'Only takes effect when the system proxy is enabled',
      name: 'bypassDomainDesc',
      desc: '',
      args: [],
    );
  }

  /// `Make sure to reset`
  String get resetTip {
    return Intl.message(
      'Make sure to reset',
      name: 'resetTip',
      desc: '',
      args: [],
    );
  }

  /// `RegExp`
  String get regExp {
    return Intl.message('RegExp', name: 'regExp', desc: '', args: []);
  }

  /// `Icon`
  String get icon {
    return Intl.message('Icon', name: 'icon', desc: '', args: []);
  }

  /// `Icon configuration`
  String get iconConfiguration {
    return Intl.message(
      'Icon configuration',
      name: 'iconConfiguration',
      desc: '',
      args: [],
    );
  }

  /// `No data`
  String get noData {
    return Intl.message('No data', name: 'noData', desc: '', args: []);
  }

  /// `Admin auto launch`
  String get adminAutoLaunch {
    return Intl.message(
      'Admin auto launch',
      name: 'adminAutoLaunch',
      desc: '',
      args: [],
    );
  }

  /// `Boot up by using admin mode`
  String get adminAutoLaunchDesc {
    return Intl.message(
      'Boot up by using admin mode',
      name: 'adminAutoLaunchDesc',
      desc: '',
      args: [],
    );
  }

  /// `FontFamily`
  String get fontFamily {
    return Intl.message('FontFamily', name: 'fontFamily', desc: '', args: []);
  }

  /// `System font`
  String get systemFont {
    return Intl.message('System font', name: 'systemFont', desc: '', args: []);
  }

  /// `Toggle`
  String get toggle {
    return Intl.message('Toggle', name: 'toggle', desc: '', args: []);
  }

  /// `System`
  String get system {
    return Intl.message('System', name: 'system', desc: '', args: []);
  }

  /// `Route mode`
  String get routeMode {
    return Intl.message('Route mode', name: 'routeMode', desc: '', args: []);
  }

  /// `Bypass private route address`
  String get routeMode_bypassPrivate {
    return Intl.message(
      'Bypass private route address',
      name: 'routeMode_bypassPrivate',
      desc: '',
      args: [],
    );
  }

  /// `Use config`
  String get routeMode_config {
    return Intl.message(
      'Use config',
      name: 'routeMode_config',
      desc: '',
      args: [],
    );
  }

  /// `Route address`
  String get routeAddress {
    return Intl.message(
      'Route address',
      name: 'routeAddress',
      desc: '',
      args: [],
    );
  }

  /// `Config listen route address`
  String get routeAddressDesc {
    return Intl.message(
      'Config listen route address',
      name: 'routeAddressDesc',
      desc: '',
      args: [],
    );
  }

  /// `Please enter the admin password`
  String get pleaseInputAdminPassword {
    return Intl.message(
      'Please enter the admin password',
      name: 'pleaseInputAdminPassword',
      desc: '',
      args: [],
    );
  }

  /// `Copying environment variables`
  String get copyEnvVar {
    return Intl.message(
      'Copying environment variables',
      name: 'copyEnvVar',
      desc: '',
      args: [],
    );
  }

  /// `Memory info`
  String get memoryInfo {
    return Intl.message('Memory info', name: 'memoryInfo', desc: '', args: []);
  }

  /// `Cancel`
  String get cancel {
    return Intl.message('Cancel', name: 'cancel', desc: '', args: []);
  }

  /// `The file has been modified. Do you want to save the changes?`
  String get fileIsUpdate {
    return Intl.message(
      'The file has been modified. Do you want to save the changes?',
      name: 'fileIsUpdate',
      desc: '',
      args: [],
    );
  }

  /// `The profile has been modified. Do you want to disable auto update?`
  String get profileHasUpdate {
    return Intl.message(
      'The profile has been modified. Do you want to disable auto update?',
      name: 'profileHasUpdate',
      desc: '',
      args: [],
    );
  }

  /// `Do you want to cache the changes?`
  String get hasCacheChange {
    return Intl.message(
      'Do you want to cache the changes?',
      name: 'hasCacheChange',
      desc: '',
      args: [],
    );
  }

  /// `Copy success`
  String get copySuccess {
    return Intl.message(
      'Copy success',
      name: 'copySuccess',
      desc: '',
      args: [],
    );
  }

  /// `Copy link`
  String get copyLink {
    return Intl.message('Copy link', name: 'copyLink', desc: '', args: []);
  }

  /// `Export file`
  String get exportFile {
    return Intl.message('Export file', name: 'exportFile', desc: '', args: []);
  }

  /// `The cache is corrupt. Do you want to clear it?`
  String get cacheCorrupt {
    return Intl.message(
      'The cache is corrupt. Do you want to clear it?',
      name: 'cacheCorrupt',
      desc: '',
      args: [],
    );
  }

  /// `Relying on third-party api is for reference only`
  String get detectionTip {
    return Intl.message(
      'Relying on third-party api is for reference only',
      name: 'detectionTip',
      desc: '',
      args: [],
    );
  }

  /// `Listen`
  String get listen {
    return Intl.message('Listen', name: 'listen', desc: '', args: []);
  }

  /// `undo`
  String get undo {
    return Intl.message('undo', name: 'undo', desc: '', args: []);
  }

  /// `redo`
  String get redo {
    return Intl.message('redo', name: 'redo', desc: '', args: []);
  }

  /// `none`
  String get none {
    return Intl.message('none', name: 'none', desc: '', args: []);
  }

  /// `Basic configuration`
  String get basicConfig {
    return Intl.message(
      'Basic configuration',
      name: 'basicConfig',
      desc: '',
      args: [],
    );
  }

  /// `Modify the basic configuration globally`
  String get basicConfigDesc {
    return Intl.message(
      'Modify the basic configuration globally',
      name: 'basicConfigDesc',
      desc: '',
      args: [],
    );
  }

  /// `{count} items have been selected`
  String selectedCountTitle(Object count) {
    return Intl.message(
      '$count items have been selected',
      name: 'selectedCountTitle',
      desc: '',
      args: [count],
    );
  }

  /// `Add rule`
  String get addRule {
    return Intl.message('Add rule', name: 'addRule', desc: '', args: []);
  }

  /// `Rule name`
  String get ruleName {
    return Intl.message('Rule name', name: 'ruleName', desc: '', args: []);
  }

  /// `Content`
  String get content {
    return Intl.message('Content', name: 'content', desc: '', args: []);
  }

  /// `Sub rule`
  String get subRule {
    return Intl.message('Sub rule', name: 'subRule', desc: '', args: []);
  }

  /// `Rule target`
  String get ruleTarget {
    return Intl.message('Rule target', name: 'ruleTarget', desc: '', args: []);
  }

  /// `Source IP`
  String get sourceIp {
    return Intl.message('Source IP', name: 'sourceIp', desc: '', args: []);
  }

  /// `No resolve IP`
  String get noResolve {
    return Intl.message('No resolve IP', name: 'noResolve', desc: '', args: []);
  }

  /// `Get original rules`
  String get getOriginRules {
    return Intl.message(
      'Get original rules',
      name: 'getOriginRules',
      desc: '',
      args: [],
    );
  }

  /// `Override the original rule`
  String get overrideOriginRules {
    return Intl.message(
      'Override the original rule',
      name: 'overrideOriginRules',
      desc: '',
      args: [],
    );
  }

  /// `Attach on the original rules`
  String get addedOriginRules {
    return Intl.message(
      'Attach on the original rules',
      name: 'addedOriginRules',
      desc: '',
      args: [],
    );
  }

  /// `Enable override`
  String get enableOverride {
    return Intl.message(
      'Enable override',
      name: 'enableOverride',
      desc: '',
      args: [],
    );
  }

  /// `Do you want to save the changes?`
  String get saveChanges {
    return Intl.message(
      'Do you want to save the changes?',
      name: 'saveChanges',
      desc: '',
      args: [],
    );
  }

  /// `Modify general settings`
  String get generalDesc {
    return Intl.message(
      'Modify general settings',
      name: 'generalDesc',
      desc: '',
      args: [],
    );
  }

  /// `There is a certain performance loss after opening`
  String get findProcessModeDesc {
    return Intl.message(
      'There is a certain performance loss after opening',
      name: 'findProcessModeDesc',
      desc: '',
      args: [],
    );
  }

  /// `Are you sure you want to save?`
  String get saveTip {
    return Intl.message(
      'Are you sure you want to save?',
      name: 'saveTip',
      desc: '',
      args: [],
    );
  }

  /// `Color schemes`
  String get colorSchemes {
    return Intl.message(
      'Color schemes',
      name: 'colorSchemes',
      desc: '',
      args: [],
    );
  }

  /// `Palette`
  String get palette {
    return Intl.message('Palette', name: 'palette', desc: '', args: []);
  }

  /// `TonalSpot`
  String get tonalSpotScheme {
    return Intl.message(
      'TonalSpot',
      name: 'tonalSpotScheme',
      desc: '',
      args: [],
    );
  }

  /// `Fidelity`
  String get fidelityScheme {
    return Intl.message('Fidelity', name: 'fidelityScheme', desc: '', args: []);
  }

  /// `Monochrome`
  String get monochromeScheme {
    return Intl.message(
      'Monochrome',
      name: 'monochromeScheme',
      desc: '',
      args: [],
    );
  }

  /// `Neutral`
  String get neutralScheme {
    return Intl.message('Neutral', name: 'neutralScheme', desc: '', args: []);
  }

  /// `Vibrant`
  String get vibrantScheme {
    return Intl.message('Vibrant', name: 'vibrantScheme', desc: '', args: []);
  }

  /// `Expressive`
  String get expressiveScheme {
    return Intl.message(
      'Expressive',
      name: 'expressiveScheme',
      desc: '',
      args: [],
    );
  }

  /// `Content`
  String get contentScheme {
    return Intl.message('Content', name: 'contentScheme', desc: '', args: []);
  }

  /// `Rainbow`
  String get rainbowScheme {
    return Intl.message('Rainbow', name: 'rainbowScheme', desc: '', args: []);
  }

  /// `FruitSalad`
  String get fruitSaladScheme {
    return Intl.message(
      'FruitSalad',
      name: 'fruitSaladScheme',
      desc: '',
      args: [],
    );
  }

  /// `Developer mode`
  String get developerMode {
    return Intl.message(
      'Developer mode',
      name: 'developerMode',
      desc: '',
      args: [],
    );
  }

  /// `Developer mode is enabled.`
  String get developerModeEnableTip {
    return Intl.message(
      'Developer mode is enabled.',
      name: 'developerModeEnableTip',
      desc: '',
      args: [],
    );
  }

  /// `Message test`
  String get messageTest {
    return Intl.message(
      'Message test',
      name: 'messageTest',
      desc: '',
      args: [],
    );
  }

  /// `This is a message.`
  String get messageTestTip {
    return Intl.message(
      'This is a message.',
      name: 'messageTestTip',
      desc: '',
      args: [],
    );
  }

  /// `Crash test`
  String get crashTest {
    return Intl.message('Crash test', name: 'crashTest', desc: '', args: []);
  }

  /// `Clear Data`
  String get clearData {
    return Intl.message('Clear Data', name: 'clearData', desc: '', args: []);
  }

  /// `Zoom`
  String get zoom {
    return Intl.message('Zoom', name: 'zoom', desc: '', args: []);
  }

  /// `Text Scaling`
  String get textScale {
    return Intl.message('Text Scaling', name: 'textScale', desc: '', args: []);
  }

  /// `Internet`
  String get internet {
    return Intl.message('Internet', name: 'internet', desc: '', args: []);
  }

  /// `System APP`
  String get systemApp {
    return Intl.message('System APP', name: 'systemApp', desc: '', args: []);
  }

  /// `No network APP`
  String get noNetworkApp {
    return Intl.message(
      'No network APP',
      name: 'noNetworkApp',
      desc: '',
      args: [],
    );
  }

  /// `Contact me`
  String get contactMe {
    return Intl.message('Contact me', name: 'contactMe', desc: '', args: []);
  }

  /// `Recovery strategy`
  String get recoveryStrategy {
    return Intl.message(
      'Recovery strategy',
      name: 'recoveryStrategy',
      desc: '',
      args: [],
    );
  }

  /// `Override`
  String get recoveryStrategy_override {
    return Intl.message(
      'Override',
      name: 'recoveryStrategy_override',
      desc: '',
      args: [],
    );
  }

  /// `Compatible`
  String get recoveryStrategy_compatible {
    return Intl.message(
      'Compatible',
      name: 'recoveryStrategy_compatible',
      desc: '',
      args: [],
    );
  }

  /// `Logs test`
  String get logsTest {
    return Intl.message('Logs test', name: 'logsTest', desc: '', args: []);
  }

  /// `{label} cannot be empty`
  String emptyTip(Object label) {
    return Intl.message(
      '$label cannot be empty',
      name: 'emptyTip',
      desc: '',
      args: [label],
    );
  }

  /// `{label} must be a url`
  String urlTip(Object label) {
    return Intl.message(
      '$label must be a url',
      name: 'urlTip',
      desc: '',
      args: [label],
    );
  }

  /// `{label} must be a number`
  String numberTip(Object label) {
    return Intl.message(
      '$label must be a number',
      name: 'numberTip',
      desc: '',
      args: [label],
    );
  }

  /// `Interval`
  String get interval {
    return Intl.message('Interval', name: 'interval', desc: '', args: []);
  }

  /// `Current {label} already exists`
  String existsTip(Object label) {
    return Intl.message(
      'Current $label already exists',
      name: 'existsTip',
      desc: '',
      args: [label],
    );
  }

  /// `Are you sure you want to delete the current {label}?`
  String deleteTip(Object label) {
    return Intl.message(
      'Are you sure you want to delete the current $label?',
      name: 'deleteTip',
      desc: '',
      args: [label],
    );
  }

  /// `Are you sure you want to delete the selected {label}?`
  String deleteMultipTip(Object label) {
    return Intl.message(
      'Are you sure you want to delete the selected $label?',
      name: 'deleteMultipTip',
      desc: '',
      args: [label],
    );
  }

  /// `No {label} at the moment`
  String nullTip(Object label) {
    return Intl.message(
      'No $label at the moment',
      name: 'nullTip',
      desc: '',
      args: [label],
    );
  }

  /// `Script`
  String get script {
    return Intl.message('Script', name: 'script', desc: '', args: []);
  }

  /// `Color`
  String get color {
    return Intl.message('Color', name: 'color', desc: '', args: []);
  }

  /// `Rename`
  String get rename {
    return Intl.message('Rename', name: 'rename', desc: '', args: []);
  }

  /// `Unnamed`
  String get unnamed {
    return Intl.message('Unnamed', name: 'unnamed', desc: '', args: []);
  }

  /// `Please enter a script name`
  String get pleaseEnterScriptName {
    return Intl.message(
      'Please enter a script name',
      name: 'pleaseEnterScriptName',
      desc: '',
      args: [],
    );
  }

  /// `Does not take effect in script mode`
  String get overrideInvalidTip {
    return Intl.message(
      'Does not take effect in script mode',
      name: 'overrideInvalidTip',
      desc: '',
      args: [],
    );
  }

  /// `Mixed Port`
  String get mixedPort {
    return Intl.message('Mixed Port', name: 'mixedPort', desc: '', args: []);
  }

  /// `Socks Port`
  String get socksPort {
    return Intl.message('Socks Port', name: 'socksPort', desc: '', args: []);
  }

  /// `Redir Port`
  String get redirPort {
    return Intl.message('Redir Port', name: 'redirPort', desc: '', args: []);
  }

  /// `Tproxy Port`
  String get tproxyPort {
    return Intl.message('Tproxy Port', name: 'tproxyPort', desc: '', args: []);
  }

  /// `{label} must be between 1024 and 49151`
  String portTip(Object label) {
    return Intl.message(
      '$label must be between 1024 and 49151',
      name: 'portTip',
      desc: '',
      args: [label],
    );
  }

  /// `Please enter a different port`
  String get portConflictTip {
    return Intl.message(
      'Please enter a different port',
      name: 'portConflictTip',
      desc: '',
      args: [],
    );
  }

  /// `Import`
  String get import {
    return Intl.message('Import', name: 'import', desc: '', args: []);
  }

  /// `Import from file`
  String get importFile {
    return Intl.message(
      'Import from file',
      name: 'importFile',
      desc: '',
      args: [],
    );
  }

  /// `Import from URL`
  String get importUrl {
    return Intl.message(
      'Import from URL',
      name: 'importUrl',
      desc: '',
      args: [],
    );
  }

  /// `Auto set system DNS`
  String get autoSetSystemDns {
    return Intl.message(
      'Auto set system DNS',
      name: 'autoSetSystemDns',
      desc: '',
      args: [],
    );
  }

  /// `Login`
  String get xboardLogin {
    return Intl.message('Login', name: 'xboardLogin', desc: '', args: []);
  }

  /// `Register`
  String get xboardRegister {
    return Intl.message('Register', name: 'xboardRegister', desc: '', args: []);
  }

  /// `Sign out`
  String get xboardLogout {
    return Intl.message('Sign out', name: 'xboardLogout', desc: '', args: []);
  }

  /// `Email`
  String get xboardEmail {
    return Intl.message('Email', name: 'xboardEmail', desc: '', args: []);
  }

  /// `Password`
  String get xboardPassword {
    return Intl.message('Password', name: 'xboardPassword', desc: '', args: []);
  }

  /// `Confirm Password`
  String get xboardConfirmPassword {
    return Intl.message(
      'Confirm Password',
      name: 'xboardConfirmPassword',
      desc: '',
      args: [],
    );
  }

  /// `Invite Code`
  String get xboardInviteCode {
    return Intl.message(
      'Invite Code',
      name: 'xboardInviteCode',
      desc: '',
      args: [],
    );
  }

  /// `Remember Password`
  String get xboardRememberPassword {
    return Intl.message(
      'Remember Password',
      name: 'xboardRememberPassword',
      desc: '',
      args: [],
    );
  }

  /// `Forgot Password`
  String get xboardForgotPassword {
    return Intl.message(
      'Forgot Password',
      name: 'xboardForgotPassword',
      desc: '',
      args: [],
    );
  }

  /// `Login successful`
  String get xboardLoginSuccess {
    return Intl.message(
      'Login successful',
      name: 'xboardLoginSuccess',
      desc: '',
      args: [],
    );
  }

  /// `Login failed`
  String get xboardLoginFailed {
    return Intl.message(
      'Login failed',
      name: 'xboardLoginFailed',
      desc: '',
      args: [],
    );
  }

  /// `Registration successful! Redirecting to login page...`
  String get xboardRegisterSuccess {
    return Intl.message(
      'Registration successful! Redirecting to login page...',
      name: 'xboardRegisterSuccess',
      desc: '',
      args: [],
    );
  }

  /// `Registration failed`
  String get xboardRegisterFailed {
    return Intl.message(
      'Registration failed',
      name: 'xboardRegisterFailed',
      desc: '',
      args: [],
    );
  }

  /// `Confirm sign out`
  String get xboardLogoutConfirmTitle {
    return Intl.message(
      'Confirm sign out',
      name: 'xboardLogoutConfirmTitle',
      desc: '',
      args: [],
    );
  }

  /// `Are you sure you want to sign out? You will need to sign in again.`
  String get xboardLogoutConfirmContent {
    return Intl.message(
      'Are you sure you want to sign out? You will need to sign in again.',
      name: 'xboardLogoutConfirmContent',
      desc: '',
      args: [],
    );
  }

  /// `Sign-in protection is active`
  String get xboardLogoutProtectedTitle {
    return Intl.message(
      'Sign-in protection is active',
      name: 'xboardLogoutProtectedTitle',
      desc: '',
      args: [],
    );
  }

  /// `The service connection is currently unstable. Signing out may prevent you from signing in again for a while. Keep this session until the service recovers.`
  String get xboardLogoutProtectedContent {
    return Intl.message(
      'The service connection is currently unstable. Signing out may prevent you from signing in again for a while. Keep this session until the service recovers.',
      name: 'xboardLogoutProtectedContent',
      desc: '',
      args: [],
    );
  }

  /// `Sign out anyway`
  String get xboardLogoutForceAction {
    return Intl.message(
      'Sign out anyway',
      name: 'xboardLogoutForceAction',
      desc: '',
      args: [],
    );
  }

  /// `Confirm forced sign-out`
  String get xboardLogoutForceConfirmTitle {
    return Intl.message(
      'Confirm forced sign-out',
      name: 'xboardLogoutForceConfirmTitle',
      desc: '',
      args: [],
    );
  }

  /// `Forced sign-out clears the local session and node cache. You may be unable to sign in again until the service recovers. Continue?`
  String get xboardLogoutForceConfirmContent {
    return Intl.message(
      'Forced sign-out clears the local session and node cache. You may be unable to sign in again until the service recovers. Continue?',
      name: 'xboardLogoutForceConfirmContent',
      desc: '',
      args: [],
    );
  }

  /// `Signed out`
  String get xboardLogoutSuccess {
    return Intl.message(
      'Signed out',
      name: 'xboardLogoutSuccess',
      desc: '',
      args: [],
    );
  }

  /// `Sign out failed`
  String get xboardLogoutFailed {
    return Intl.message(
      'Sign out failed',
      name: 'xboardLogoutFailed',
      desc: '',
      args: [],
    );
  }

  /// `Login Expired`
  String get xboardTokenExpiredTitle {
    return Intl.message(
      'Login Expired',
      name: 'xboardTokenExpiredTitle',
      desc: '',
      args: [],
    );
  }

  /// `Your login session has expired. Please login again to continue.`
  String get xboardTokenExpiredContent {
    return Intl.message(
      'Your login session has expired. Please login again to continue.',
      name: 'xboardTokenExpiredContent',
      desc: '',
      args: [],
    );
  }

  /// `Device Signed Out`
  String get xboardDeviceKickedTitle {
    return Intl.message(
      'Device Signed Out',
      name: 'xboardDeviceKickedTitle',
      desc: '',
      args: [],
    );
  }

  /// `This account signed in on another device, so this device has been disconnected. Sign in again or manage your devices to continue.`
  String get xboardDeviceKickedContent {
    return Intl.message(
      'This account signed in on another device, so this device has been disconnected. Sign in again or manage your devices to continue.',
      name: 'xboardDeviceKickedContent',
      desc: '',
      args: [],
    );
  }

  /// `Device Removed`
  String get xboardDeviceSessionRevokedTitle {
    return Intl.message(
      'Device Removed',
      name: 'xboardDeviceSessionRevokedTitle',
      desc: '',
      args: [],
    );
  }

  /// `This device's login access was removed and its connection was stopped. Sign in again to continue.`
  String get xboardDeviceSessionRevokedContent {
    return Intl.message(
      'This device\'s login access was removed and its connection was stopped. Sign in again to continue.',
      name: 'xboardDeviceSessionRevokedContent',
      desc: '',
      args: [],
    );
  }

  /// `Login Again`
  String get xboardRelogin {
    return Intl.message(
      'Login Again',
      name: 'xboardRelogin',
      desc: '',
      args: [],
    );
  }

  /// `Cancel`
  String get xboardCancel {
    return Intl.message('Cancel', name: 'xboardCancel', desc: '', args: []);
  }

  /// `Confirm`
  String get xboardConfirm {
    return Intl.message('Confirm', name: 'xboardConfirm', desc: '', args: []);
  }

  /// `Store`
  String get xboardPlans {
    return Intl.message('Store', name: 'xboardPlans', desc: '', args: []);
  }

  /// `Subscription`
  String get xboardSubscription {
    return Intl.message(
      'Subscription',
      name: 'xboardSubscription',
      desc: '',
      args: [],
    );
  }

  /// `Current node`
  String get xboardCurrentNode {
    return Intl.message(
      'Current node',
      name: 'xboardCurrentNode',
      desc: '',
      args: [],
    );
  }

  /// `Node Name`
  String get xboardNodeName {
    return Intl.message(
      'Node Name',
      name: 'xboardNodeName',
      desc: '',
      args: [],
    );
  }

  /// `Group`
  String get xboardGroup {
    return Intl.message('Group', name: 'xboardGroup', desc: '', args: []);
  }

  /// `Profile`
  String get xboardProfile {
    return Intl.message('Profile', name: 'xboardProfile', desc: '', args: []);
  }

  /// `Local IP`
  String get xboardLocalIP {
    return Intl.message('Local IP', name: 'xboardLocalIP', desc: '', args: []);
  }

  /// `Getting...`
  String get xboardGettingIP {
    return Intl.message(
      'Getting...',
      name: 'xboardGettingIP',
      desc: '',
      args: [],
    );
  }

  /// `Unknown User`
  String get xboardUnknownUser {
    return Intl.message(
      'Unknown User',
      name: 'xboardUnknownUser',
      desc: '',
      args: [],
    );
  }

  /// `Logged In`
  String get xboardLoggedIn {
    return Intl.message(
      'Logged In',
      name: 'xboardLoggedIn',
      desc: '',
      args: [],
    );
  }

  /// `Not Logged In`
  String get xboardNotLoggedIn {
    return Intl.message(
      'Not Logged In',
      name: 'xboardNotLoggedIn',
      desc: '',
      args: [],
    );
  }

  /// `Unselected`
  String get xboardUnselected {
    return Intl.message(
      'Unselected',
      name: 'xboardUnselected',
      desc: '',
      args: [],
    );
  }

  /// `None`
  String get xboardNone {
    return Intl.message('None', name: 'xboardNone', desc: '', args: []);
  }

  /// `Plans`
  String get xboardPlanInfo {
    return Intl.message('Plans', name: 'xboardPlanInfo', desc: '', args: []);
  }

  /// `Subscription purchase`
  String get xboardSubscriptionPurchase {
    return Intl.message(
      'Subscription purchase',
      name: 'xboardSubscriptionPurchase',
      desc: '',
      args: [],
    );
  }

  /// `Buy Now`
  String get xboardBuyNow {
    return Intl.message('Buy Now', name: 'xboardBuyNow', desc: '', args: []);
  }

  /// `Retry`
  String get xboardRetry {
    return Intl.message('Retry', name: 'xboardRetry', desc: '', args: []);
  }

  /// `Refresh`
  String get xboardRefresh {
    return Intl.message('Refresh', name: 'xboardRefresh', desc: '', args: []);
  }

  /// `Copy Link`
  String get xboardCopyLink {
    return Intl.message(
      'Copy Link',
      name: 'xboardCopyLink',
      desc: '',
      args: [],
    );
  }

  /// `Subscription link copied to clipboard`
  String get xboardSubscriptionCopied {
    return Intl.message(
      'Subscription link copied to clipboard',
      name: 'xboardSubscriptionCopied',
      desc: '',
      args: [],
    );
  }

  /// `Reload`
  String get xboardReload {
    return Intl.message('Reload', name: 'xboardReload', desc: '', args: []);
  }

  /// `Processing...`
  String get xboardProcessing {
    return Intl.message(
      'Processing...',
      name: 'xboardProcessing',
      desc: '',
      args: [],
    );
  }

  /// `Please select purchase period`
  String get xboardSelectPeriod {
    return Intl.message(
      'Please select purchase period',
      name: 'xboardSelectPeriod',
      desc: '',
      args: [],
    );
  }

  /// `Operation failed`
  String get xboardOperationFailed {
    return Intl.message(
      'Operation failed',
      name: 'xboardOperationFailed',
      desc: '',
      args: [],
    );
  }

  /// `Failed to open payment page`
  String get xboardOpenPaymentFailed {
    return Intl.message(
      'Failed to open payment page',
      name: 'xboardOpenPaymentFailed',
      desc: '',
      args: [],
    );
  }

  /// `1. Payment page has been opened automatically`
  String get xboardPaymentInstructions1 {
    return Intl.message(
      '1. Payment page has been opened automatically',
      name: 'xboardPaymentInstructions1',
      desc: '',
      args: [],
    );
  }

  /// `2. Please complete payment in your browser`
  String get xboardPaymentInstructions2 {
    return Intl.message(
      '2. Please complete payment in your browser',
      name: 'xboardPaymentInstructions2',
      desc: '',
      args: [],
    );
  }

  /// `3. Return to app after payment, system will detect automatically`
  String get xboardPaymentInstructions3 {
    return Intl.message(
      '3. Return to app after payment, system will detect automatically',
      name: 'xboardPaymentInstructions3',
      desc: '',
      args: [],
    );
  }

  /// `Order number`
  String get xboardOrderNumber {
    return Intl.message(
      'Order number',
      name: 'xboardOrderNumber',
      desc: '',
      args: [],
    );
  }

  /// `Reopen Payment`
  String get xboardReopenPayment {
    return Intl.message(
      'Reopen Payment',
      name: 'xboardReopenPayment',
      desc: '',
      args: [],
    );
  }

  /// `Copy Link`
  String get xboardCopyPaymentLink {
    return Intl.message(
      'Copy Link',
      name: 'xboardCopyPaymentLink',
      desc: '',
      args: [],
    );
  }

  /// `Payment Complete`
  String get xboardPaymentComplete {
    return Intl.message(
      'Payment Complete',
      name: 'xboardPaymentComplete',
      desc: '',
      args: [],
    );
  }

  /// `Cancel payment`
  String get xboardCancelPayment {
    return Intl.message(
      'Cancel payment',
      name: 'xboardCancelPayment',
      desc: '',
      args: [],
    );
  }

  /// `Payment successful`
  String get xboardPaymentSuccess {
    return Intl.message(
      'Payment successful',
      name: 'xboardPaymentSuccess',
      desc: '',
      args: [],
    );
  }

  /// `Payment cancelled`
  String get xboardPaymentCancelled {
    return Intl.message(
      'Payment cancelled',
      name: 'xboardPaymentCancelled',
      desc: '',
      args: [],
    );
  }

  /// `Order not found`
  String get xboardOrderNotFound {
    return Intl.message(
      'Order not found',
      name: 'xboardOrderNotFound',
      desc: '',
      args: [],
    );
  }

  /// `Failed to check payment status`
  String get xboardCheckPaymentFailed {
    return Intl.message(
      'Failed to check payment status',
      name: 'xboardCheckPaymentFailed',
      desc: '',
      args: [],
    );
  }

  /// `Payment completed!`
  String get xboardPaymentCompleted {
    return Intl.message(
      'Payment completed!',
      name: 'xboardPaymentCompleted',
      desc: '',
      args: [],
    );
  }

  /// `No plans available`
  String get xboardNoPlansAvailable {
    return Intl.message(
      'No plans available',
      name: 'xboardNoPlansAvailable',
      desc: '',
      args: [],
    );
  }

  /// `Back`
  String get xboardBack {
    return Intl.message('Back', name: 'xboardBack', desc: '', args: []);
  }

  /// `Copy failed`
  String get xboardCopyFailed {
    return Intl.message(
      'Copy failed',
      name: 'xboardCopyFailed',
      desc: '',
      args: [],
    );
  }

  /// `Payment link copied to clipboard`
  String get xboardPaymentLinkCopied {
    return Intl.message(
      'Payment link copied to clipboard',
      name: 'xboardPaymentLinkCopied',
      desc: '',
      args: [],
    );
  }

  /// `Failed to open payment link`
  String get xboardOpenPaymentLinkFailed {
    return Intl.message(
      'Failed to open payment link',
      name: 'xboardOpenPaymentLinkFailed',
      desc: '',
      args: [],
    );
  }

  /// `Send Verification Code`
  String get xboardSendVerificationCode {
    return Intl.message(
      'Send Verification Code',
      name: 'xboardSendVerificationCode',
      desc: '',
      args: [],
    );
  }

  /// `Enable TUN`
  String get xboardEnableTun {
    return Intl.message(
      'Enable TUN',
      name: 'xboardEnableTun',
      desc: '',
      args: [],
    );
  }

  /// `Previous`
  String get xboardPrevious {
    return Intl.message('Previous', name: 'xboardPrevious', desc: '', args: []);
  }

  /// `Next`
  String get xboardNext {
    return Intl.message('Next', name: 'xboardNext', desc: '', args: []);
  }

  /// `Later`
  String get xboardLater {
    return Intl.message('Later', name: 'xboardLater', desc: '', args: []);
  }

  /// `Clear error`
  String get xboardClearError {
    return Intl.message(
      'Clear error',
      name: 'xboardClearError',
      desc: '',
      args: [],
    );
  }

  /// `Update Later`
  String get xboardUpdateLater {
    return Intl.message(
      'Update Later',
      name: 'xboardUpdateLater',
      desc: '',
      args: [],
    );
  }

  /// `Force update`
  String get xboardForceUpdate {
    return Intl.message(
      'Force update',
      name: 'xboardForceUpdate',
      desc: '',
      args: [],
    );
  }

  /// `New version found`
  String get xboardNewVersionFound {
    return Intl.message(
      'New version found',
      name: 'xboardNewVersionFound',
      desc: '',
      args: [],
    );
  }

  /// `Current version`
  String get xboardCurrentVersion {
    return Intl.message(
      'Current version',
      name: 'xboardCurrentVersion',
      desc: '',
      args: [],
    );
  }

  /// `Update content:`
  String get xboardUpdateContent {
    return Intl.message(
      'Update content:',
      name: 'xboardUpdateContent',
      desc: '',
      args: [],
    );
  }

  /// `Must update`
  String get xboardMustUpdate {
    return Intl.message(
      'Must update',
      name: 'xboardMustUpdate',
      desc: '',
      args: [],
    );
  }

  /// `Update Now`
  String get xboardUpdateNow {
    return Intl.message(
      'Update Now',
      name: 'xboardUpdateNow',
      desc: '',
      args: [],
    );
  }

  /// `No subscription information`
  String get xboardNoSubscriptionInfo {
    return Intl.message(
      'No subscription information',
      name: 'xboardNoSubscriptionInfo',
      desc: '',
      args: [],
    );
  }

  /// `Please login to view subscription usage`
  String get xboardLoginToViewSubscription {
    return Intl.message(
      'Please login to view subscription usage',
      name: 'xboardLoginToViewSubscription',
      desc: '',
      args: [],
    );
  }

  /// `No available subscription`
  String get xboardNoAvailableSubscription {
    return Intl.message(
      'No available subscription',
      name: 'xboardNoAvailableSubscription',
      desc: '',
      args: [],
    );
  }

  /// `Please purchase a subscription to use`
  String get xboardPurchaseSubscriptionToUse {
    return Intl.message(
      'Please purchase a subscription to use',
      name: 'xboardPurchaseSubscriptionToUse',
      desc: '',
      args: [],
    );
  }

  /// `Subscription expired`
  String get xboardSubscriptionExpired {
    return Intl.message(
      'Subscription expired',
      name: 'xboardSubscriptionExpired',
      desc: '',
      args: [],
    );
  }

  /// `Please renew to continue using`
  String get xboardRenewToContinue {
    return Intl.message(
      'Please renew to continue using',
      name: 'xboardRenewToContinue',
      desc: '',
      args: [],
    );
  }

  /// `Traffic exhausted`
  String get xboardTrafficExhausted {
    return Intl.message(
      'Traffic exhausted',
      name: 'xboardTrafficExhausted',
      desc: '',
      args: [],
    );
  }

  /// `Please buy more traffic or upgrade plan`
  String get xboardBuyMoreTrafficOrUpgrade {
    return Intl.message(
      'Please buy more traffic or upgrade plan',
      name: 'xboardBuyMoreTrafficOrUpgrade',
      desc: '',
      args: [],
    );
  }

  /// `Expiry time`
  String get xboardExpiryTime {
    return Intl.message(
      'Expiry time',
      name: 'xboardExpiryTime',
      desc: '',
      args: [],
    );
  }

  /// `Used`
  String get xboardUsed {
    return Intl.message('Used', name: 'xboardUsed', desc: '', args: []);
  }

  /// `Used`
  String get xboardUsedTraffic {
    return Intl.message('Used', name: 'xboardUsedTraffic', desc: '', args: []);
  }

  /// `Total`
  String get xboardTotalTraffic {
    return Intl.message(
      'Total',
      name: 'xboardTotalTraffic',
      desc: '',
      args: [],
    );
  }

  /// `Expires`
  String get xboardValidityPeriod {
    return Intl.message(
      'Expires',
      name: 'xboardValidityPeriod',
      desc: '',
      args: [],
    );
  }

  /// `days`
  String get xboardDays {
    return Intl.message('days', name: 'xboardDays', desc: '', args: []);
  }

  /// `Monthly`
  String get xboardMonthlyPayment {
    return Intl.message(
      'Monthly',
      name: 'xboardMonthlyPayment',
      desc: '',
      args: [],
    );
  }

  /// `Monthly renewal`
  String get xboardMonthlyRenewal {
    return Intl.message(
      'Monthly renewal',
      name: 'xboardMonthlyRenewal',
      desc: '',
      args: [],
    );
  }

  /// `Quarterly`
  String get xboardQuarterlyPayment {
    return Intl.message(
      'Quarterly',
      name: 'xboardQuarterlyPayment',
      desc: '',
      args: [],
    );
  }

  /// `3-month cycle`
  String get xboardThreeMonthCycle {
    return Intl.message(
      '3-month cycle',
      name: 'xboardThreeMonthCycle',
      desc: '',
      args: [],
    );
  }

  /// `Half-yearly`
  String get xboardHalfYearlyPayment {
    return Intl.message(
      'Half-yearly',
      name: 'xboardHalfYearlyPayment',
      desc: '',
      args: [],
    );
  }

  /// `6-month cycle`
  String get xboardSixMonthCycle {
    return Intl.message(
      '6-month cycle',
      name: 'xboardSixMonthCycle',
      desc: '',
      args: [],
    );
  }

  /// `Yearly`
  String get xboardYearlyPayment {
    return Intl.message(
      'Yearly',
      name: 'xboardYearlyPayment',
      desc: '',
      args: [],
    );
  }

  /// `12-month cycle`
  String get xboardTwelveMonthCycle {
    return Intl.message(
      '12-month cycle',
      name: 'xboardTwelveMonthCycle',
      desc: '',
      args: [],
    );
  }

  /// `Two-year`
  String get xboardTwoYearPayment {
    return Intl.message(
      'Two-year',
      name: 'xboardTwoYearPayment',
      desc: '',
      args: [],
    );
  }

  /// `24-month cycle`
  String get xboardTwentyFourMonthCycle {
    return Intl.message(
      '24-month cycle',
      name: 'xboardTwentyFourMonthCycle',
      desc: '',
      args: [],
    );
  }

  /// `Three-year`
  String get xboardThreeYearPayment {
    return Intl.message(
      'Three-year',
      name: 'xboardThreeYearPayment',
      desc: '',
      args: [],
    );
  }

  /// `36-month cycle`
  String get xboardThirtySixMonthCycle {
    return Intl.message(
      '36-month cycle',
      name: 'xboardThirtySixMonthCycle',
      desc: '',
      args: [],
    );
  }

  /// `One-time`
  String get xboardOneTimePayment {
    return Intl.message(
      'One-time',
      name: 'xboardOneTimePayment',
      desc: '',
      args: [],
    );
  }

  /// `Buyout plan`
  String get xboardBuyoutPlan {
    return Intl.message(
      'Buyout plan',
      name: 'xboardBuyoutPlan',
      desc: '',
      args: [],
    );
  }

  /// `Please select payment period`
  String get xboardPleaseSelectPaymentPeriod {
    return Intl.message(
      'Please select payment period',
      name: 'xboardPleaseSelectPaymentPeriod',
      desc: '',
      args: [],
    );
  }

  /// `Order creation failed`
  String get xboardOrderCreationFailed {
    return Intl.message(
      'Order creation failed',
      name: 'xboardOrderCreationFailed',
      desc: '',
      args: [],
    );
  }

  /// `Failed to open payment page`
  String get xboardFailedToOpenPaymentPage {
    return Intl.message(
      'Failed to open payment page',
      name: 'xboardFailedToOpenPaymentPage',
      desc: '',
      args: [],
    );
  }

  /// `Select payment period`
  String get xboardSelectPaymentPeriod {
    return Intl.message(
      'Select payment period',
      name: 'xboardSelectPaymentPeriod',
      desc: '',
      args: [],
    );
  }

  /// `Select payment method`
  String get xboardSelectPaymentMethod {
    return Intl.message(
      'Select payment method',
      name: 'xboardSelectPaymentMethod',
      desc: '',
      args: [],
    );
  }

  /// `Handling fee`
  String get xboardHandlingFee {
    return Intl.message(
      'Handling fee',
      name: 'xboardHandlingFee',
      desc: '',
      args: [],
    );
  }

  /// `Coupon not yet active`
  String get xboardCouponNotYetActive {
    return Intl.message(
      'Coupon not yet active',
      name: 'xboardCouponNotYetActive',
      desc: '',
      args: [],
    );
  }

  /// `Coupon expired`
  String get xboardCouponExpired {
    return Intl.message(
      'Coupon expired',
      name: 'xboardCouponExpired',
      desc: '',
      args: [],
    );
  }

  /// `Unsupported coupon type`
  String get xboardUnsupportedCouponType {
    return Intl.message(
      'Unsupported coupon type',
      name: 'xboardUnsupportedCouponType',
      desc: '',
      args: [],
    );
  }

  /// `Invalid or expired coupon code`
  String get xboardInvalidOrExpiredCoupon {
    return Intl.message(
      'Invalid or expired coupon code',
      name: 'xboardInvalidOrExpiredCoupon',
      desc: '',
      args: [],
    );
  }

  /// `Validation failed`
  String get xboardValidationFailed {
    return Intl.message(
      'Validation failed',
      name: 'xboardValidationFailed',
      desc: '',
      args: [],
    );
  }

  /// `Balance`
  String get xboardAccountBalance {
    return Intl.message(
      'Balance',
      name: 'xboardAccountBalance',
      desc: '',
      args: [],
    );
  }

  /// `Deductible during payment`
  String get xboardDeductibleDuringPayment {
    return Intl.message(
      'Deductible during payment',
      name: 'xboardDeductibleDuringPayment',
      desc: '',
      args: [],
    );
  }

  /// `Coupon (optional)`
  String get xboardCouponOptional {
    return Intl.message(
      'Coupon (optional)',
      name: 'xboardCouponOptional',
      desc: '',
      args: [],
    );
  }

  /// `Discounted`
  String get xboardDiscounted {
    return Intl.message(
      'Discounted',
      name: 'xboardDiscounted',
      desc: '',
      args: [],
    );
  }

  /// `Enter coupon code`
  String get xboardEnterCouponCode {
    return Intl.message(
      'Enter coupon code',
      name: 'xboardEnterCouponCode',
      desc: '',
      args: [],
    );
  }

  /// `Verify`
  String get xboardVerify {
    return Intl.message('Verify', name: 'xboardVerify', desc: '', args: []);
  }

  /// `Purchase subscription`
  String get xboardPurchaseSubscription {
    return Intl.message(
      'Purchase subscription',
      name: 'xboardPurchaseSubscription',
      desc: '',
      args: [],
    );
  }

  /// `Traffic`
  String get xboardTraffic {
    return Intl.message('Traffic', name: 'xboardTraffic', desc: '', args: []);
  }

  /// `Speed`
  String get xboardSpeedLimit {
    return Intl.message('Speed', name: 'xboardSpeedLimit', desc: '', args: []);
  }

  /// `Unlimited`
  String get xboardUnlimited {
    return Intl.message(
      'Unlimited',
      name: 'xboardUnlimited',
      desc: '',
      args: [],
    );
  }

  /// `Confirm purchase`
  String get xboardConfirmPurchase {
    return Intl.message(
      'Confirm purchase',
      name: 'xboardConfirmPurchase',
      desc: '',
      args: [],
    );
  }

  /// `Auto-opening payment page, please return to app after payment`
  String get xboardAutoOpeningPaymentPage {
    return Intl.message(
      'Auto-opening payment page, please return to app after payment',
      name: 'xboardAutoOpeningPaymentPage',
      desc: '',
      args: [],
    );
  }

  /// `Payment page opened in browser, please return to app after payment`
  String get xboardPaymentPageOpenedInBrowser {
    return Intl.message(
      'Payment page opened in browser, please return to app after payment',
      name: 'xboardPaymentPageOpenedInBrowser',
      desc: '',
      args: [],
    );
  }

  /// `Failed to open payment link`
  String get xboardFailedToOpenPaymentLink {
    return Intl.message(
      'Failed to open payment link',
      name: 'xboardFailedToOpenPaymentLink',
      desc: '',
      args: [],
    );
  }

  /// `🎉 Payment successful!`
  String get xboardPaymentSuccessful {
    return Intl.message(
      '🎉 Payment successful!',
      name: 'xboardPaymentSuccessful',
      desc: '',
      args: [],
    );
  }

  /// `Waiting for payment`
  String get xboardWaitingForPayment {
    return Intl.message(
      'Waiting for payment',
      name: 'xboardWaitingForPayment',
      desc: '',
      args: [],
    );
  }

  /// `Pending payment`
  String get xboardOrderStatusPending {
    return Intl.message(
      'Pending payment',
      name: 'xboardOrderStatusPending',
      desc: '',
      args: [],
    );
  }

  /// `Failed to check payment status`
  String get xboardFailedToCheckPaymentStatus {
    return Intl.message(
      'Failed to check payment status',
      name: 'xboardFailedToCheckPaymentStatus',
      desc: '',
      args: [],
    );
  }

  /// `Payment gateway`
  String get xboardPaymentGateway {
    return Intl.message(
      'Payment gateway',
      name: 'xboardPaymentGateway',
      desc: '',
      args: [],
    );
  }

  /// `Return`
  String get xboardReturn {
    return Intl.message('Return', name: 'xboardReturn', desc: '', args: []);
  }

  /// `Payment information`
  String get xboardPaymentInfo {
    return Intl.message(
      'Payment information',
      name: 'xboardPaymentInfo',
      desc: '',
      args: [],
    );
  }

  /// `Payment link`
  String get xboardPaymentLink {
    return Intl.message(
      'Payment link',
      name: 'xboardPaymentLink',
      desc: '',
      args: [],
    );
  }

  /// `Click to copy`
  String get xboardClickToCopy {
    return Intl.message(
      'Click to copy',
      name: 'xboardClickToCopy',
      desc: '',
      args: [],
    );
  }

  /// `Auto-detect payment status`
  String get xboardAutoDetectPaymentStatus {
    return Intl.message(
      'Auto-detect payment status',
      name: 'xboardAutoDetectPaymentStatus',
      desc: '',
      args: [],
    );
  }

  /// `System checks every 5 seconds, will redirect automatically after payment`
  String get xboardAutoCheckEvery5Seconds {
    return Intl.message(
      'System checks every 5 seconds, will redirect automatically after payment',
      name: 'xboardAutoCheckEvery5Seconds',
      desc: '',
      args: [],
    );
  }

  /// `Stop`
  String get xboardStop {
    return Intl.message('Stop', name: 'xboardStop', desc: '', args: []);
  }

  /// `Operation tips`
  String get xboardOperationTips {
    return Intl.message(
      'Operation tips',
      name: 'xboardOperationTips',
      desc: '',
      args: [],
    );
  }

  /// `1. Payment page has been opened automatically`
  String get xboardPaymentPageAutoOpened {
    return Intl.message(
      '1. Payment page has been opened automatically',
      name: 'xboardPaymentPageAutoOpened',
      desc: '',
      args: [],
    );
  }

  /// `2. Please complete payment in your browser`
  String get xboardCompletePaymentInBrowser {
    return Intl.message(
      '2. Please complete payment in your browser',
      name: 'xboardCompletePaymentInBrowser',
      desc: '',
      args: [],
    );
  }

  /// `3. Return to app after payment, system will detect automatically`
  String get xboardReturnAfterPaymentAutoDetect {
    return Intl.message(
      '3. Return to app after payment, system will detect automatically',
      name: 'xboardReturnAfterPaymentAutoDetect',
      desc: '',
      args: [],
    );
  }

  /// `To reopen, click the \"Reopen\" button below`
  String get xboardReopenPaymentPageTip {
    return Intl.message(
      'To reopen, click the \\"Reopen\\" button below',
      name: 'xboardReopenPaymentPageTip',
      desc: '',
      args: [],
    );
  }

  /// `If browser doesn't open automatically, click \"Reopen\" or copy link manually`
  String get xboardBrowserNotOpenedTip {
    return Intl.message(
      'If browser doesn\'t open automatically, click \\"Reopen\\" or copy link manually',
      name: 'xboardBrowserNotOpenedTip',
      desc: '',
      args: [],
    );
  }

  /// `Reopen`
  String get xboardReopen {
    return Intl.message('Reopen', name: 'xboardReopen', desc: '', args: []);
  }

  /// `Checking`
  String get xboardChecking {
    return Intl.message('Checking', name: 'xboardChecking', desc: '', args: []);
  }

  /// `Check status`
  String get xboardCheckStatus {
    return Intl.message(
      'Check status',
      name: 'xboardCheckStatus',
      desc: '',
      args: [],
    );
  }

  /// `Creating order`
  String get xboardCreatingOrder {
    return Intl.message(
      'Creating order',
      name: 'xboardCreatingOrder',
      desc: '',
      args: [],
    );
  }

  /// `Loading payment page`
  String get xboardLoadingPaymentPage {
    return Intl.message(
      'Loading payment page',
      name: 'xboardLoadingPaymentPage',
      desc: '',
      args: [],
    );
  }

  /// `Payment method verified`
  String get xboardPaymentMethodVerified {
    return Intl.message(
      'Payment method verified',
      name: 'xboardPaymentMethodVerified',
      desc: '',
      args: [],
    );
  }

  /// `Waiting for payment completion`
  String get xboardWaitingPaymentCompletion {
    return Intl.message(
      'Waiting for payment completion',
      name: 'xboardWaitingPaymentCompletion',
      desc: '',
      args: [],
    );
  }

  /// `We are creating a new order for you, please wait`
  String get xboardCreatingOrderPleaseWait {
    return Intl.message(
      'We are creating a new order for you, please wait',
      name: 'xboardCreatingOrderPleaseWait',
      desc: '',
      args: [],
    );
  }

  /// `Preparing payment page, redirecting soon`
  String get xboardPreparingPaymentPage {
    return Intl.message(
      'Preparing payment page, redirecting soon',
      name: 'xboardPreparingPaymentPage',
      desc: '',
      args: [],
    );
  }

  /// `Payment method verified, preparing to redirect to payment page`
  String get xboardPaymentMethodVerifiedPreparing {
    return Intl.message(
      'Payment method verified, preparing to redirect to payment page',
      name: 'xboardPaymentMethodVerifiedPreparing',
      desc: '',
      args: [],
    );
  }

  /// `Payment page opened, please complete payment and return to app`
  String get xboardPaymentPageOpenedCompleteAndReturn {
    return Intl.message(
      'Payment page opened, please complete payment and return to app',
      name: 'xboardPaymentPageOpenedCompleteAndReturn',
      desc: '',
      args: [],
    );
  }

  /// `Congratulations! Your subscription has been successfully purchased and activated`
  String get xboardCongratulationsSubscriptionActivated {
    return Intl.message(
      'Congratulations! Your subscription has been successfully purchased and activated',
      name: 'xboardCongratulationsSubscriptionActivated',
      desc: '',
      args: [],
    );
  }

  /// `Handle later`
  String get xboardHandleLater {
    return Intl.message(
      'Handle later',
      name: 'xboardHandleLater',
      desc: '',
      args: [],
    );
  }

  /// `Subscription link copied to clipboard`
  String get xboardSubscriptionLinkCopied {
    return Intl.message(
      'Subscription link copied to clipboard',
      name: 'xboardSubscriptionLinkCopied',
      desc: '',
      args: [],
    );
  }

  /// `Subscription information`
  String get xboardSubscriptionInfo {
    return Intl.message(
      'Subscription information',
      name: 'xboardSubscriptionInfo',
      desc: '',
      args: [],
    );
  }

  /// `Failed to get subscription information`
  String get xboardFailedToGetSubscriptionInfo {
    return Intl.message(
      'Failed to get subscription information',
      name: 'xboardFailedToGetSubscriptionInfo',
      desc: '',
      args: [],
    );
  }

  /// `Retry`
  String get xboardRetryGet {
    return Intl.message('Retry', name: 'xboardRetryGet', desc: '', args: []);
  }

  /// `Subscription link`
  String get xboardSubscriptionLink {
    return Intl.message(
      'Subscription link',
      name: 'xboardSubscriptionLink',
      desc: '',
      args: [],
    );
  }

  /// `Usage instructions`
  String get xboardUsageInstructions {
    return Intl.message(
      'Usage instructions',
      name: 'xboardUsageInstructions',
      desc: '',
      args: [],
    );
  }

  /// `Copy the subscription link above`
  String get xboardCopySubscriptionLinkAbove {
    return Intl.message(
      'Copy the subscription link above',
      name: 'xboardCopySubscriptionLinkAbove',
      desc: '',
      args: [],
    );
  }

  /// `Add this subscription link to your configuration`
  String get xboardAddLinkToConfig {
    return Intl.message(
      'Add this subscription link to your configuration',
      name: 'xboardAddLinkToConfig',
      desc: '',
      args: [],
    );
  }

  /// `Update subscription regularly to get latest nodes`
  String get xboardUpdateSubscriptionRegularly {
    return Intl.message(
      'Update subscription regularly to get latest nodes',
      name: 'xboardUpdateSubscriptionRegularly',
      desc: '',
      args: [],
    );
  }

  /// `Please keep your subscription link safe and don't share with others`
  String get xboardKeepSubscriptionLinkSafe {
    return Intl.message(
      'Please keep your subscription link safe and don\'t share with others',
      name: 'xboardKeepSubscriptionLinkSafe',
      desc: '',
      args: [],
    );
  }

  /// `Loading failed`
  String get xboardLoadingFailed {
    return Intl.message(
      'Loading failed',
      name: 'xboardLoadingFailed',
      desc: '',
      args: [],
    );
  }

  /// `No subscription plans`
  String get xboardNoSubscriptionPlans {
    return Intl.message(
      'No subscription plans',
      name: 'xboardNoSubscriptionPlans',
      desc: '',
      args: [],
    );
  }

  /// `Connection timeout, please check network connection`
  String get xboardConnectionTimeout {
    return Intl.message(
      'Connection timeout, please check network connection',
      name: 'xboardConnectionTimeout',
      desc: '',
      args: [],
    );
  }

  /// `No internet connection, please check network settings`
  String get xboardNoInternetConnection {
    return Intl.message(
      'No internet connection, please check network settings',
      name: 'xboardNoInternetConnection',
      desc: '',
      args: [],
    );
  }

  /// `Server error`
  String get xboardServerError {
    return Intl.message(
      'Server error',
      name: 'xboardServerError',
      desc: '',
      args: [],
    );
  }

  /// `Invalid username or password`
  String get xboardInvalidCredentials {
    return Intl.message(
      'Invalid username or password',
      name: 'xboardInvalidCredentials',
      desc: '',
      args: [],
    );
  }

  /// `Login expired, please login again`
  String get xboardLoginExpired {
    return Intl.message(
      'Login expired, please login again',
      name: 'xboardLoginExpired',
      desc: '',
      args: [],
    );
  }

  /// `Unauthorized access, please login first`
  String get xboardUnauthorizedAccess {
    return Intl.message(
      'Unauthorized access, please login first',
      name: 'xboardUnauthorizedAccess',
      desc: '',
      args: [],
    );
  }

  /// `Plan not found`
  String get xboardPlanNotFound {
    return Intl.message(
      'Plan not found',
      name: 'xboardPlanNotFound',
      desc: '',
      args: [],
    );
  }

  /// `Payment failed`
  String get xboardPaymentFailed {
    return Intl.message(
      'Payment failed',
      name: 'xboardPaymentFailed',
      desc: '',
      args: [],
    );
  }

  /// `Insufficient balance`
  String get xboardInsufficientBalance {
    return Intl.message(
      'Insufficient balance',
      name: 'xboardInsufficientBalance',
      desc: '',
      args: [],
    );
  }

  /// `Invalid response format from server`
  String get xboardInvalidResponseFormat {
    return Intl.message(
      'Invalid response format from server',
      name: 'xboardInvalidResponseFormat',
      desc: '',
      args: [],
    );
  }

  /// `Missing required field`
  String get xboardMissingRequiredField {
    return Intl.message(
      'Missing required field',
      name: 'xboardMissingRequiredField',
      desc: '',
      args: [],
    );
  }

  /// `API URL not configured`
  String get xboardApiUrlNotConfigured {
    return Intl.message(
      'API URL not configured',
      name: 'xboardApiUrlNotConfigured',
      desc: '',
      args: [],
    );
  }

  /// `Configuration error`
  String get xboardConfigurationError {
    return Intl.message(
      'Configuration error',
      name: 'xboardConfigurationError',
      desc: '',
      args: [],
    );
  }

  /// `Testing`
  String get xboardTesting {
    return Intl.message('Testing', name: 'xboardTesting', desc: '', args: []);
  }

  /// `Auto testing`
  String get xboardAutoTesting {
    return Intl.message(
      'Auto testing',
      name: 'xboardAutoTesting',
      desc: '',
      args: [],
    );
  }

  /// `Timeout`
  String get xboardTimeout {
    return Intl.message('Timeout', name: 'xboardTimeout', desc: '', args: []);
  }

  /// `Excellent`
  String get xboardExcellent {
    return Intl.message(
      'Excellent',
      name: 'xboardExcellent',
      desc: '',
      args: [],
    );
  }

  /// `Good`
  String get xboardGood {
    return Intl.message('Good', name: 'xboardGood', desc: '', args: []);
  }

  /// `Fair`
  String get xboardFair {
    return Intl.message('Fair', name: 'xboardFair', desc: '', args: []);
  }

  /// `Poor`
  String get xboardPoor {
    return Intl.message('Poor', name: 'xboardPoor', desc: '', args: []);
  }

  /// `Very poor`
  String get xboardVeryPoor {
    return Intl.message(
      'Very poor',
      name: 'xboardVeryPoor',
      desc: '',
      args: [],
    );
  }

  /// `Preparing import`
  String get xboardPreparingImport {
    return Intl.message(
      'Preparing import',
      name: 'xboardPreparingImport',
      desc: '',
      args: [],
    );
  }

  /// `Cleaning old configuration`
  String get xboardCleaningOldConfig {
    return Intl.message(
      'Cleaning old configuration',
      name: 'xboardCleaningOldConfig',
      desc: '',
      args: [],
    );
  }

  /// `Downloading configuration file`
  String get xboardDownloadingConfig {
    return Intl.message(
      'Downloading configuration file',
      name: 'xboardDownloadingConfig',
      desc: '',
      args: [],
    );
  }

  /// `Validating configuration format`
  String get xboardValidatingConfigFormat {
    return Intl.message(
      'Validating configuration format',
      name: 'xboardValidatingConfigFormat',
      desc: '',
      args: [],
    );
  }

  /// `Adding to configuration list`
  String get xboardAddingToConfigList {
    return Intl.message(
      'Adding to configuration list',
      name: 'xboardAddingToConfigList',
      desc: '',
      args: [],
    );
  }

  /// `Import successful`
  String get xboardImportSuccess {
    return Intl.message(
      'Import successful',
      name: 'xboardImportSuccess',
      desc: '',
      args: [],
    );
  }

  /// `Import failed`
  String get xboardImportFailed {
    return Intl.message(
      'Import failed',
      name: 'xboardImportFailed',
      desc: '',
      args: [],
    );
  }

  /// `Network connection failed, please check network settings`
  String get xboardNetworkConnectionFailed {
    return Intl.message(
      'Network connection failed, please check network settings',
      name: 'xboardNetworkConnectionFailed',
      desc: '',
      args: [],
    );
  }

  /// `Configuration download failed, please check subscription link`
  String get xboardConfigDownloadFailed {
    return Intl.message(
      'Configuration download failed, please check subscription link',
      name: 'xboardConfigDownloadFailed',
      desc: '',
      args: [],
    );
  }

  /// `Configuration format error, please contact service provider`
  String get xboardConfigFormatError {
    return Intl.message(
      'Configuration format error, please contact service provider',
      name: 'xboardConfigFormatError',
      desc: '',
      args: [],
    );
  }

  /// `Configuration save failed, please check storage space`
  String get xboardConfigSaveFailed {
    return Intl.message(
      'Configuration save failed, please check storage space',
      name: 'xboardConfigSaveFailed',
      desc: '',
      args: [],
    );
  }

  /// `Unknown error, please retry`
  String get xboardUnknownErrorRetry {
    return Intl.message(
      'Unknown error, please retry',
      name: 'xboardUnknownErrorRetry',
      desc: '',
      args: [],
    );
  }

  /// `Proxy Mode`
  String get xboardProxyMode {
    return Intl.message(
      'Proxy Mode',
      name: 'xboardProxyMode',
      desc: '',
      args: [],
    );
  }

  /// `Intelligently route traffic by destination region for acceleration (recommended)`
  String get xboardProxyModeRuleDescription {
    return Intl.message(
      'Intelligently route traffic by destination region for acceleration (recommended)',
      name: 'xboardProxyModeRuleDescription',
      desc: '',
      args: [],
    );
  }

  /// `Route all network traffic through the proxy (recommended when specific sites are inaccessible)`
  String get xboardProxyModeGlobalDescription {
    return Intl.message(
      'Route all network traffic through the proxy (recommended when specific sites are inaccessible)',
      name: 'xboardProxyModeGlobalDescription',
      desc: '',
      args: [],
    );
  }

  /// `All traffic connects directly without proxy`
  String get xboardProxyModeDirectDescription {
    return Intl.message(
      'All traffic connects directly without proxy',
      name: 'xboardProxyModeDirectDescription',
      desc: '',
      args: [],
    );
  }

  /// `TUN enabled`
  String get xboardTunEnabled {
    return Intl.message(
      'TUN enabled',
      name: 'xboardTunEnabled',
      desc: '',
      args: [],
    );
  }

  /// `No available nodes`
  String get xboardNoAvailableNodes {
    return Intl.message(
      'No available nodes',
      name: 'xboardNoAvailableNodes',
      desc: '',
      args: [],
    );
  }

  /// `Click to setup nodes`
  String get xboardClickToSetupNodes {
    return Intl.message(
      'Click to setup nodes',
      name: 'xboardClickToSetupNodes',
      desc: '',
      args: [],
    );
  }

  /// `Proxy`
  String get xboardProxy {
    return Intl.message('Proxy', name: 'xboardProxy', desc: '', args: []);
  }

  /// `Switch`
  String get xboardSwitch {
    return Intl.message('Switch', name: 'xboardSwitch', desc: '', args: []);
  }

  /// `Setup`
  String get xboardSetup {
    return Intl.message('Setup', name: 'xboardSetup', desc: '', args: []);
  }

  /// `No available plan`
  String get xboardNoAvailablePlan {
    return Intl.message(
      'No available plan',
      name: 'xboardNoAvailablePlan',
      desc: '',
      args: [],
    );
  }

  /// `Subscription has expired`
  String get xboardSubscriptionHasExpired {
    return Intl.message(
      'Subscription has expired',
      name: 'xboardSubscriptionHasExpired',
      desc: '',
      args: [],
    );
  }

  /// `Traffic used up`
  String get xboardTrafficUsedUp {
    return Intl.message(
      'Traffic used up',
      name: 'xboardTrafficUsedUp',
      desc: '',
      args: [],
    );
  }

  /// `Subscription status`
  String get xboardSubscriptionStatus {
    return Intl.message(
      'Subscription status',
      name: 'xboardSubscriptionStatus',
      desc: '',
      args: [],
    );
  }

  /// `Refresh status`
  String get xboardRefreshStatus {
    return Intl.message(
      'Refresh status',
      name: 'xboardRefreshStatus',
      desc: '',
      args: [],
    );
  }

  /// `Purchase plan`
  String get xboardPurchasePlan {
    return Intl.message(
      'Purchase plan',
      name: 'xboardPurchasePlan',
      desc: '',
      args: [],
    );
  }

  /// `Renew plan`
  String get xboardRenewPlan {
    return Intl.message(
      'Renew plan',
      name: 'xboardRenewPlan',
      desc: '',
      args: [],
    );
  }

  /// `Purchase traffic`
  String get xboardPurchaseTraffic {
    return Intl.message(
      'Purchase traffic',
      name: 'xboardPurchaseTraffic',
      desc: '',
      args: [],
    );
  }

  /// `Confirm`
  String get xboardConfirmAction {
    return Intl.message(
      'Confirm',
      name: 'xboardConfirmAction',
      desc: '',
      args: [],
    );
  }

  /// `After purchasing a plan, you will enjoy:`
  String get xboardAfterPurchasingPlan {
    return Intl.message(
      'After purchasing a plan, you will enjoy:',
      name: 'xboardAfterPurchasingPlan',
      desc: '',
      args: [],
    );
  }

  /// `High-speed network`
  String get xboardHighSpeedNetwork {
    return Intl.message(
      'High-speed network',
      name: 'xboardHighSpeedNetwork',
      desc: '',
      args: [],
    );
  }

  /// `Enjoy fast network experience`
  String get xboardEnjoyFastNetworkExperience {
    return Intl.message(
      'Enjoy fast network experience',
      name: 'xboardEnjoyFastNetworkExperience',
      desc: '',
      args: [],
    );
  }

  /// `Secure encryption`
  String get xboardSecureEncryption {
    return Intl.message(
      'Secure encryption',
      name: 'xboardSecureEncryption',
      desc: '',
      args: [],
    );
  }

  /// `Protect your network privacy`
  String get xboardProtectNetworkPrivacy {
    return Intl.message(
      'Protect your network privacy',
      name: 'xboardProtectNetworkPrivacy',
      desc: '',
      args: [],
    );
  }

  /// `Global nodes`
  String get xboardGlobalNodes {
    return Intl.message(
      'Global nodes',
      name: 'xboardGlobalNodes',
      desc: '',
      args: [],
    );
  }

  /// `Connect to global quality nodes`
  String get xboardConnectGlobalQualityNodes {
    return Intl.message(
      'Connect to global quality nodes',
      name: 'xboardConnectGlobalQualityNodes',
      desc: '',
      args: [],
    );
  }

  /// `Professional support`
  String get xboardProfessionalSupport {
    return Intl.message(
      'Professional support',
      name: 'xboardProfessionalSupport',
      desc: '',
      args: [],
    );
  }

  /// `24-hour customer service support`
  String get xboard24HourCustomerService {
    return Intl.message(
      '24-hour customer service support',
      name: 'xboard24HourCustomerService',
      desc: '',
      args: [],
    );
  }

  /// `Start Proxy`
  String get xboardStartProxy {
    return Intl.message(
      'Start Proxy',
      name: 'xboardStartProxy',
      desc: '',
      args: [],
    );
  }

  /// `Stop Proxy`
  String get xboardStopProxy {
    return Intl.message(
      'Stop Proxy',
      name: 'xboardStopProxy',
      desc: '',
      args: [],
    );
  }

  /// `Running time: {time}`
  String xboardRunningTime(String time) {
    return Intl.message(
      'Running time: $time',
      name: 'xboardRunningTime',
      desc: '',
      args: [time],
    );
  }

  /// `Not logged in`
  String get subscriptionNotLoggedIn {
    return Intl.message(
      'Not logged in',
      name: 'subscriptionNotLoggedIn',
      desc: '',
      args: [],
    );
  }

  /// `Please login first`
  String get subscriptionNotLoggedInDetail {
    return Intl.message(
      'Please login first',
      name: 'subscriptionNotLoggedInDetail',
      desc: '',
      args: [],
    );
  }

  /// `No subscription`
  String get subscriptionNoSubscription {
    return Intl.message(
      'No subscription',
      name: 'subscriptionNoSubscription',
      desc: '',
      args: [],
    );
  }

  /// `No available subscription plan found, please purchase a plan to use`
  String get subscriptionNoSubscriptionDetail {
    return Intl.message(
      'No available subscription plan found, please purchase a plan to use',
      name: 'subscriptionNoSubscriptionDetail',
      desc: '',
      args: [],
    );
  }

  /// `Subscription expired`
  String get subscriptionExpired {
    return Intl.message(
      'Subscription expired',
      name: 'subscriptionExpired',
      desc: '',
      args: [],
    );
  }

  /// `Plan expired on {date}, please renew to continue using`
  String subscriptionExpiredDetail(String date) {
    return Intl.message(
      'Plan expired on $date, please renew to continue using',
      name: 'subscriptionExpiredDetail',
      desc: '',
      args: [date],
    );
  }

  /// `Subscription expires today`
  String get subscriptionExpiresToday {
    return Intl.message(
      'Subscription expires today',
      name: 'subscriptionExpiresToday',
      desc: '',
      args: [],
    );
  }

  /// `Plan will expire today, please renew immediately to avoid service interruption`
  String get subscriptionExpiresTodayDetail {
    return Intl.message(
      'Plan will expire today, please renew immediately to avoid service interruption',
      name: 'subscriptionExpiresTodayDetail',
      desc: '',
      args: [],
    );
  }

  /// `Subscription expiring soon`
  String get subscriptionExpiringInDays {
    return Intl.message(
      'Subscription expiring soon',
      name: 'subscriptionExpiringInDays',
      desc: '',
      args: [],
    );
  }

  /// `Plan will expire in {days} days, please renew in time`
  String subscriptionExpiringInDaysDetail(int days) {
    return Intl.message(
      'Plan will expire in $days days, please renew in time',
      name: 'subscriptionExpiringInDaysDetail',
      desc: '',
      args: [days],
    );
  }

  /// `Traffic exhausted`
  String get subscriptionTrafficExhausted {
    return Intl.message(
      'Traffic exhausted',
      name: 'subscriptionTrafficExhausted',
      desc: '',
      args: [],
    );
  }

  /// `Plan traffic has been used up, please reset traffic or change plan`
  String get subscriptionTrafficExhaustedDetail {
    return Intl.message(
      'Plan traffic has been used up, please reset traffic or change plan',
      name: 'subscriptionTrafficExhaustedDetail',
      desc: '',
      args: [],
    );
  }

  /// `Subscription valid`
  String get subscriptionValid {
    return Intl.message(
      'Subscription valid',
      name: 'subscriptionValid',
      desc: '',
      args: [],
    );
  }

  /// `Subscription will expire in {days} days`
  String subscriptionValidDetail(int days) {
    return Intl.message(
      'Subscription will expire in $days days',
      name: 'subscriptionValidDetail',
      desc: '',
      args: [days],
    );
  }

  /// `Forgot Password`
  String get forgotPassword {
    return Intl.message(
      'Forgot Password',
      name: 'forgotPassword',
      desc: '',
      args: [],
    );
  }

  /// `Reset Password`
  String get resetPassword {
    return Intl.message(
      'Reset Password',
      name: 'resetPassword',
      desc: '',
      args: [],
    );
  }

  /// `Set New Password`
  String get setNewPassword {
    return Intl.message(
      'Set New Password',
      name: 'setNewPassword',
      desc: '',
      args: [],
    );
  }

  /// `Please enter your email address and we will send a verification code to your email`
  String get enterEmailForReset {
    return Intl.message(
      'Please enter your email address and we will send a verification code to your email',
      name: 'enterEmailForReset',
      desc: '',
      args: [],
    );
  }

  /// `Verification code has been sent to your email, please check`
  String get verificationCodeSent {
    return Intl.message(
      'Verification code has been sent to your email, please check',
      name: 'verificationCodeSent',
      desc: '',
      args: [],
    );
  }

  /// `Failed to send verification code`
  String get sendCodeFailed {
    return Intl.message(
      'Failed to send verification code',
      name: 'sendCodeFailed',
      desc: '',
      args: [],
    );
  }

  /// `Verification code has been sent to {email}, please check and enter the verification code and new password`
  String verificationCodeSentTo(String email) {
    return Intl.message(
      'Verification code has been sent to $email, please check and enter the verification code and new password',
      name: 'verificationCodeSentTo',
      desc: '',
      args: [email],
    );
  }

  /// `Email Address`
  String get emailAddress {
    return Intl.message(
      'Email Address',
      name: 'emailAddress',
      desc: '',
      args: [],
    );
  }

  /// `Please enter email address`
  String get pleaseEnterEmail {
    return Intl.message(
      'Please enter email address',
      name: 'pleaseEnterEmail',
      desc: '',
      args: [],
    );
  }

  /// `Please enter a valid email address`
  String get pleaseEnterValidEmail {
    return Intl.message(
      'Please enter a valid email address',
      name: 'pleaseEnterValidEmail',
      desc: '',
      args: [],
    );
  }

  /// `Send Verification Code`
  String get sendVerificationCode {
    return Intl.message(
      'Send Verification Code',
      name: 'sendVerificationCode',
      desc: '',
      args: [],
    );
  }

  /// `Verification Code`
  String get verificationCode {
    return Intl.message(
      'Verification Code',
      name: 'verificationCode',
      desc: '',
      args: [],
    );
  }

  /// `Please enter email verification code`
  String get pleaseEnterVerificationCode {
    return Intl.message(
      'Please enter email verification code',
      name: 'pleaseEnterVerificationCode',
      desc: '',
      args: [],
    );
  }

  /// `Please enter a valid verification code`
  String get pleaseEnterValidVerificationCode {
    return Intl.message(
      'Please enter a valid verification code',
      name: 'pleaseEnterValidVerificationCode',
      desc: '',
      args: [],
    );
  }

  /// `New Password`
  String get newPassword {
    return Intl.message(
      'New Password',
      name: 'newPassword',
      desc: '',
      args: [],
    );
  }

  /// `Please enter new password`
  String get pleaseEnterNewPassword {
    return Intl.message(
      'Please enter new password',
      name: 'pleaseEnterNewPassword',
      desc: '',
      args: [],
    );
  }

  /// `Confirm New Password`
  String get confirmNewPassword {
    return Intl.message(
      'Confirm New Password',
      name: 'confirmNewPassword',
      desc: '',
      args: [],
    );
  }

  /// `Please re-enter new password`
  String get pleaseConfirmNewPassword {
    return Intl.message(
      'Please re-enter new password',
      name: 'pleaseConfirmNewPassword',
      desc: '',
      args: [],
    );
  }

  /// `Passwords do not match`
  String get passwordMismatch {
    return Intl.message(
      'Passwords do not match',
      name: 'passwordMismatch',
      desc: '',
      args: [],
    );
  }

  /// `Password reset successful! Please login with your new password`
  String get passwordResetSuccessful {
    return Intl.message(
      'Password reset successful! Please login with your new password',
      name: 'passwordResetSuccessful',
      desc: '',
      args: [],
    );
  }

  /// `Password reset failed`
  String get passwordResetFailed {
    return Intl.message(
      'Password reset failed',
      name: 'passwordResetFailed',
      desc: '',
      args: [],
    );
  }

  /// `Resend Verification Code`
  String get resendVerificationCode {
    return Intl.message(
      'Resend Verification Code',
      name: 'resendVerificationCode',
      desc: '',
      args: [],
    );
  }

  /// `Remember your password?`
  String get rememberPassword {
    return Intl.message(
      'Remember your password?',
      name: 'rememberPassword',
      desc: '',
      args: [],
    );
  }

  /// `Back to Login`
  String get backToLogin {
    return Intl.message(
      'Back to Login',
      name: 'backToLogin',
      desc: '',
      args: [],
    );
  }

  /// `Password must be at least 6 characters`
  String get passwordMinLength {
    return Intl.message(
      'Password must be at least 6 characters',
      name: 'passwordMinLength',
      desc: '',
      args: [],
    );
  }

  /// `Registration successful - Saving credentials:`
  String get registerSuccessSaveCredentials {
    return Intl.message(
      'Registration successful - Saving credentials:',
      name: 'registerSuccessSaveCredentials',
      desc: '',
      args: [],
    );
  }

  /// `Credentials saved`
  String get credentialsSaved {
    return Intl.message(
      'Credentials saved',
      name: 'credentialsSaved',
      desc: '',
      args: [],
    );
  }

  /// `Registration failed: {e}`
  String registrationFailed(String e) {
    return Intl.message(
      'Registration failed: $e',
      name: 'registrationFailed',
      desc: '',
      args: [e],
    );
  }

  /// `Please enter email address`
  String get pleaseEnterEmailAddress {
    return Intl.message(
      'Please enter email address',
      name: 'pleaseEnterEmailAddress',
      desc: '',
      args: [],
    );
  }

  /// `Please enter a valid email address`
  String get pleaseEnterValidEmailAddress {
    return Intl.message(
      'Please enter a valid email address',
      name: 'pleaseEnterValidEmailAddress',
      desc: '',
      args: [],
    );
  }

  /// `Verification code sent, please check your email`
  String get verificationCodeSentCheckEmail {
    return Intl.message(
      'Verification code sent, please check your email',
      name: 'verificationCodeSentCheckEmail',
      desc: '',
      args: [],
    );
  }

  /// `Failed to send verification code: {e}`
  String sendVerificationCodeFailed(String e) {
    return Intl.message(
      'Failed to send verification code: $e',
      name: 'sendVerificationCodeFailed',
      desc: '',
      args: [e],
    );
  }

  /// `Invite Code Required`
  String get inviteCodeRequired {
    return Intl.message(
      'Invite Code Required',
      name: 'inviteCodeRequired',
      desc: '',
      args: [],
    );
  }

  /// `Registration requires an invite code. Please contact a registered user to get an invite code before registering.`
  String get inviteCodeRequiredMessage {
    return Intl.message(
      'Registration requires an invite code. Please contact a registered user to get an invite code before registering.',
      name: 'inviteCodeRequiredMessage',
      desc: '',
      args: [],
    );
  }

  /// `I Understand`
  String get iUnderstand {
    return Intl.message(
      'I Understand',
      name: 'iUnderstand',
      desc: '',
      args: [],
    );
  }

  /// `Create Account`
  String get createAccount {
    return Intl.message(
      'Create Account',
      name: 'createAccount',
      desc: '',
      args: [],
    );
  }

  /// `Please fill in the following information to complete registration`
  String get fillInfoToRegister {
    return Intl.message(
      'Please fill in the following information to complete registration',
      name: 'fillInfoToRegister',
      desc: '',
      args: [],
    );
  }

  /// `Please enter your email address`
  String get pleaseEnterYourEmailAddress {
    return Intl.message(
      'Please enter your email address',
      name: 'pleaseEnterYourEmailAddress',
      desc: '',
      args: [],
    );
  }

  /// `Please enter at least 8 characters password`
  String get pleaseEnterAtLeast8CharsPassword {
    return Intl.message(
      'Please enter at least 8 characters password',
      name: 'pleaseEnterAtLeast8CharsPassword',
      desc: '',
      args: [],
    );
  }

  /// `Please enter password`
  String get pleaseEnterPassword {
    return Intl.message(
      'Please enter password',
      name: 'pleaseEnterPassword',
      desc: '',
      args: [],
    );
  }

  /// `Password must be at least 8 characters`
  String get passwordMin8Chars {
    return Intl.message(
      'Password must be at least 8 characters',
      name: 'passwordMin8Chars',
      desc: '',
      args: [],
    );
  }

  /// `Please confirm password`
  String get pleaseConfirmPassword {
    return Intl.message(
      'Please confirm password',
      name: 'pleaseConfirmPassword',
      desc: '',
      args: [],
    );
  }

  /// `Please re-enter password`
  String get pleaseReEnterPassword {
    return Intl.message(
      'Please re-enter password',
      name: 'pleaseReEnterPassword',
      desc: '',
      args: [],
    );
  }

  /// `Passwords do not match`
  String get passwordsDoNotMatch {
    return Intl.message(
      'Passwords do not match',
      name: 'passwordsDoNotMatch',
      desc: '',
      args: [],
    );
  }

  /// `Email Verification Code`
  String get emailVerificationCode {
    return Intl.message(
      'Email Verification Code',
      name: 'emailVerificationCode',
      desc: '',
      args: [],
    );
  }

  /// `Please enter email verification code`
  String get pleaseEnterEmailVerificationCode {
    return Intl.message(
      'Please enter email verification code',
      name: 'pleaseEnterEmailVerificationCode',
      desc: '',
      args: [],
    );
  }

  /// `Verification code should be 6 digits`
  String get verificationCode6Digits {
    return Intl.message(
      'Verification code should be 6 digits',
      name: 'verificationCode6Digits',
      desc: '',
      args: [],
    );
  }

  /// `Invite Code`
  String get inviteCode {
    return Intl.message('Invite Code', name: 'inviteCode', desc: '', args: []);
  }

  /// `Please enter invite code`
  String get pleaseEnterInviteCode {
    return Intl.message(
      'Please enter invite code',
      name: 'pleaseEnterInviteCode',
      desc: '',
      args: [],
    );
  }

  /// `Invite Code (optional)`
  String get inviteCodeOptional {
    return Intl.message(
      'Invite Code (optional)',
      name: 'inviteCodeOptional',
      desc: '',
      args: [],
    );
  }

  /// `Loading...`
  String get loading {
    return Intl.message('Loading...', name: 'loading', desc: '', args: []);
  }

  /// `Register Account`
  String get registerAccount {
    return Intl.message(
      'Register Account',
      name: 'registerAccount',
      desc: '',
      args: [],
    );
  }

  /// `Already have an account?`
  String get alreadyHaveAccount {
    return Intl.message(
      'Already have an account?',
      name: 'alreadyHaveAccount',
      desc: '',
      args: [],
    );
  }

  /// `Login Now`
  String get loginNow {
    return Intl.message('Login Now', name: 'loginNow', desc: '', args: []);
  }

  /// `Invite`
  String get invite {
    return Intl.message('Invite', name: 'invite', desc: '', args: []);
  }

  /// `Home`
  String get xboard {
    return Intl.message('Home', name: 'xboard', desc: '', args: []);
  }

  /// `Home`
  String get xboardHome {
    return Intl.message('Home', name: 'xboardHome', desc: '', args: []);
  }

  /// `User Center`
  String get userCenter {
    return Intl.message('User Center', name: 'userCenter', desc: '', args: []);
  }

  /// `Invite Rules`
  String get inviteRules {
    return Intl.message(
      'Invite Rules',
      name: 'inviteRules',
      desc: '',
      args: [],
    );
  }

  /// `Invite friends to register and subscribe to earn commission`
  String get inviteRegisterReward {
    return Intl.message(
      'Invite friends to register and subscribe to earn commission',
      name: 'inviteRegisterReward',
      desc: '',
      args: [],
    );
  }

  /// `Earn commission when your invited friends spend`
  String get friendInviteReward {
    return Intl.message(
      'Earn commission when your invited friends spend',
      name: 'friendInviteReward',
      desc: '',
      args: [],
    );
  }

  /// `Current commission rate: {rate}%`
  String currentCommissionRate(String rate) {
    return Intl.message(
      'Current commission rate: $rate%',
      name: 'currentCommissionRate',
      desc: '',
      args: [rate],
    );
  }

  /// `Commission settled after friend subscription`
  String get commissionSettled {
    return Intl.message(
      'Commission settled after friend subscription',
      name: 'commissionSettled',
      desc: '',
      args: [],
    );
  }

  /// `Available commission can be withdrawn`
  String get withdrawalAvailable {
    return Intl.message(
      'Available commission can be withdrawn',
      name: 'withdrawalAvailable',
      desc: '',
      args: [],
    );
  }

  /// `My Invite QR`
  String get myInviteQr {
    return Intl.message('My Invite QR', name: 'myInviteQr', desc: '', args: []);
  }

  /// `Save QR`
  String get saveQr {
    return Intl.message('Save QR', name: 'saveQr', desc: '', args: []);
  }

  /// `Copy Link`
  String get copyInviteLink {
    return Intl.message(
      'Copy Link',
      name: 'copyInviteLink',
      desc: '',
      args: [],
    );
  }

  /// `Generating invite code...`
  String get generatingInviteCode {
    return Intl.message(
      'Generating invite code...',
      name: 'generatingInviteCode',
      desc: '',
      args: [],
    );
  }

  /// `Invite code generation failed`
  String get inviteCodeGenFailed {
    return Intl.message(
      'Invite code generation failed',
      name: 'inviteCodeGenFailed',
      desc: '',
      args: [],
    );
  }

  /// `Please check network and retry`
  String get checkNetwork {
    return Intl.message(
      'Please check network and retry',
      name: 'checkNetwork',
      desc: '',
      args: [],
    );
  }

  /// `Invite Stats`
  String get inviteStats {
    return Intl.message(
      'Invite Stats',
      name: 'inviteStats',
      desc: '',
      args: [],
    );
  }

  /// `Invites`
  String get totalInvites {
    return Intl.message('Invites', name: 'totalInvites', desc: '', args: []);
  }

  /// `Rate`
  String get commissionRate {
    return Intl.message('Rate', name: 'commissionRate', desc: '', args: []);
  }

  /// `Earnings`
  String get totalCommission {
    return Intl.message(
      'Earnings',
      name: 'totalCommission',
      desc: '',
      args: [],
    );
  }

  /// `Wallet Details`
  String get walletDetails {
    return Intl.message(
      'Wallet Details',
      name: 'walletDetails',
      desc: '',
      args: [],
    );
  }

  /// `Transfer`
  String get transfer {
    return Intl.message('Transfer', name: 'transfer', desc: '', args: []);
  }

  /// `Commission balance`
  String get availableCommission {
    return Intl.message(
      'Commission balance',
      name: 'availableCommission',
      desc: '',
      args: [],
    );
  }

  /// `Pending`
  String get pendingCommission {
    return Intl.message(
      'Pending',
      name: 'pendingCommission',
      desc: '',
      args: [],
    );
  }

  /// `Commissions are automatically confirmed three days after your friend places an order and added to the wallet balance.`
  String get pendingCommissionTooltipWalletBalance {
    return Intl.message(
      'Commissions are automatically confirmed three days after your friend places an order and added to the wallet balance.',
      name: 'pendingCommissionTooltipWalletBalance',
      desc: '',
      args: [],
    );
  }

  /// `Commissions are automatically confirmed three days after your friend places an order and added to the commission balance.`
  String get pendingCommissionTooltipCommissionBalance {
    return Intl.message(
      'Commissions are automatically confirmed three days after your friend places an order and added to the commission balance.',
      name: 'pendingCommissionTooltipCommissionBalance',
      desc: '',
      args: [],
    );
  }

  /// `Balance`
  String get walletBalance {
    return Intl.message('Balance', name: 'walletBalance', desc: '', args: []);
  }

  /// `Commission History`
  String get commissionHistory {
    return Intl.message(
      'Commission History',
      name: 'commissionHistory',
      desc: '',
      args: [],
    );
  }

  /// `Withdraw`
  String get withdraw {
    return Intl.message('Withdraw', name: 'withdraw', desc: '', args: []);
  }

  /// `Ticket`
  String get ticketRecords {
    return Intl.message('Ticket', name: 'ticketRecords', desc: '', args: []);
  }

  /// `No commission records`
  String get noCommissionRecord {
    return Intl.message(
      'No commission records',
      name: 'noCommissionRecord',
      desc: '',
      args: [],
    );
  }

  /// `View History`
  String get viewHistory {
    return Intl.message(
      'View History',
      name: 'viewHistory',
      desc: '',
      args: [],
    );
  }

  /// `Load More`
  String get loadMore {
    return Intl.message('Load More', name: 'loadMore', desc: '', args: []);
  }

  /// `Copied to clipboard`
  String get copiedToClipboard {
    return Intl.message(
      'Copied to clipboard',
      name: 'copiedToClipboard',
      desc: '',
      args: [],
    );
  }

  /// `Save QR feature coming soon`
  String get saveQrCodeFeature {
    return Intl.message(
      'Save QR feature coming soon',
      name: 'saveQrCodeFeature',
      desc: '',
      args: [],
    );
  }

  /// `Invite link copied, share with friends`
  String get inviteLinkCopied {
    return Intl.message(
      'Invite link copied, share with friends',
      name: 'inviteLinkCopied',
      desc: '',
      args: [],
    );
  }

  /// `Withdraw Commission`
  String get withdrawCommission {
    return Intl.message(
      'Withdraw Commission',
      name: 'withdrawCommission',
      desc: '',
      args: [],
    );
  }

  /// `Withdrawable amount: {amount}`
  String withdrawableAmount(String amount) {
    return Intl.message(
      'Withdrawable amount: $amount',
      name: 'withdrawableAmount',
      desc: '',
      args: [amount],
    );
  }

  /// `Please visit web version to withdraw`
  String get visitWebVersion {
    return Intl.message(
      'Please visit web version to withdraw',
      name: 'visitWebVersion',
      desc: '',
      args: [],
    );
  }

  /// `Web version provides complete withdrawal features`
  String get completeWithdrawal {
    return Intl.message(
      'Web version provides complete withdrawal features',
      name: 'completeWithdrawal',
      desc: '',
      args: [],
    );
  }

  /// `Go to Web`
  String get goToWeb {
    return Intl.message('Go to Web', name: 'goToWeb', desc: '', args: []);
  }

  /// `Cannot open browser, please visit web manually`
  String get cannotOpenBrowser {
    return Intl.message(
      'Cannot open browser, please visit web manually',
      name: 'cannotOpenBrowser',
      desc: '',
      args: [],
    );
  }

  /// `Failed to open web, please visit manually`
  String get openWebFailed {
    return Intl.message(
      'Failed to open web, please visit manually',
      name: 'openWebFailed',
      desc: '',
      args: [],
    );
  }

  /// `Cannot get web URL, please contact support`
  String get cannotGetWebUrl {
    return Intl.message(
      'Cannot get web URL, please contact support',
      name: 'cannotGetWebUrl',
      desc: '',
      args: [],
    );
  }

  /// `Transfer to Wallet`
  String get transferToWallet {
    return Intl.message(
      'Transfer to Wallet',
      name: 'transferToWallet',
      desc: '',
      args: [],
    );
  }

  /// `Transfer Success!`
  String get transferSuccess {
    return Intl.message(
      'Transfer Success!',
      name: 'transferSuccess',
      desc: '',
      args: [],
    );
  }

  /// `Transferring...`
  String get transferring {
    return Intl.message(
      'Transferring...',
      name: 'transferring',
      desc: '',
      args: [],
    );
  }

  /// `Transfer Amount`
  String get transferAmount {
    return Intl.message(
      'Transfer Amount',
      name: 'transferAmount',
      desc: '',
      args: [],
    );
  }

  /// `Enter transfer amount`
  String get enterTransferAmount {
    return Intl.message(
      'Enter transfer amount',
      name: 'enterTransferAmount',
      desc: '',
      args: [],
    );
  }

  /// `Max transferable: ¥{amount}`
  String maxTransferable(String amount) {
    return Intl.message(
      'Max transferable: ¥$amount',
      name: 'maxTransferable',
      desc: '',
      args: [amount],
    );
  }

  /// `Transferred balance can be used for in-app purchases`
  String get transferNote {
    return Intl.message(
      'Transferred balance can be used for in-app purchases',
      name: 'transferNote',
      desc: '',
      args: [],
    );
  }

  /// `Confirm Transfer`
  String get confirmTransfer {
    return Intl.message(
      'Confirm Transfer',
      name: 'confirmTransfer',
      desc: '',
      args: [],
    );
  }

  /// `Please enter transfer amount`
  String get enterTransferAmountError {
    return Intl.message(
      'Please enter transfer amount',
      name: 'enterTransferAmountError',
      desc: '',
      args: [],
    );
  }

  /// `Please enter valid transfer amount`
  String get invalidTransferAmount {
    return Intl.message(
      'Please enter valid transfer amount',
      name: 'invalidTransferAmount',
      desc: '',
      args: [],
    );
  }

  /// `Transfer amount cannot exceed ¥{amount}`
  String transferAmountExceeded(String amount) {
    return Intl.message(
      'Transfer amount cannot exceed ¥$amount',
      name: 'transferAmountExceeded',
      desc: '',
      args: [amount],
    );
  }

  /// `Transfer success! Transferred ¥{amount} to wallet`
  String transferSuccessMsg(String amount) {
    return Intl.message(
      'Transfer success! Transferred ¥$amount to wallet',
      name: 'transferSuccessMsg',
      desc: '',
      args: [amount],
    );
  }

  /// `Transfer failed: {error}`
  String transferFailed(String error) {
    return Intl.message(
      'Transfer failed: $error',
      name: 'transferFailed',
      desc: '',
      args: [error],
    );
  }

  /// `Total {count} records`
  String totalRecords(int count) {
    return Intl.message(
      'Total $count records',
      name: 'totalRecords',
      desc: '',
      args: [count],
    );
  }

  /// `Page {page}`
  String pageNumber(int page) {
    return Intl.message(
      'Page $page',
      name: 'pageNumber',
      desc: '',
      args: [page],
    );
  }

  /// `Order: {orderNo}`
  String orderNumber(String orderNo) {
    return Intl.message(
      'Order: $orderNo',
      name: 'orderNumber',
      desc: '',
      args: [orderNo],
    );
  }

  /// `Order amount: {amount}`
  String orderAmount(String amount) {
    return Intl.message(
      'Order amount: $amount',
      name: 'orderAmount',
      desc: '',
      args: [amount],
    );
  }

  /// `Close`
  String get close {
    return Intl.message('Close', name: 'close', desc: '', args: []);
  }

  /// `Refresh`
  String get refresh {
    return Intl.message('Refresh', name: 'refresh', desc: '', args: []);
  }

  /// `Switch Theme`
  String get switchTheme {
    return Intl.message(
      'Switch Theme',
      name: 'switchTheme',
      desc: '',
      args: [],
    );
  }

  /// `Sign out`
  String get logout {
    return Intl.message('Sign out', name: 'logout', desc: '', args: []);
  }

  /// `Select Theme`
  String get selectTheme {
    return Intl.message(
      'Select Theme',
      name: 'selectTheme',
      desc: '',
      args: [],
    );
  }

  /// `Confirm sign out`
  String get confirmLogout {
    return Intl.message(
      'Confirm sign out',
      name: 'confirmLogout',
      desc: '',
      args: [],
    );
  }

  /// `Are you sure you want to sign out? You need to sign in again.`
  String get logoutConfirmMsg {
    return Intl.message(
      'Are you sure you want to sign out? You need to sign in again.',
      name: 'logoutConfirmMsg',
      desc: '',
      args: [],
    );
  }

  /// `Signed out`
  String get loggedOutSuccess {
    return Intl.message(
      'Signed out',
      name: 'loggedOutSuccess',
      desc: '',
      args: [],
    );
  }

  /// `Sign out failed: {error}`
  String logoutFailed(String error) {
    return Intl.message(
      'Sign out failed: $error',
      name: 'logoutFailed',
      desc: '',
      args: [error],
    );
  }

  /// `Complete`
  String get complete {
    return Intl.message('Complete', name: 'complete', desc: '', args: []);
  }

  /// `No invitation data`
  String get noInvitationData {
    return Intl.message(
      'No invitation data',
      name: 'noInvitationData',
      desc: '',
      args: [],
    );
  }

  /// `Force update: {version}`
  String updateCheckForceUpdate(String version) {
    return Intl.message(
      'Force update: $version',
      name: 'updateCheckForceUpdate',
      desc: '',
      args: [version],
    );
  }

  /// `New version found: {version}`
  String updateCheckNewVersionFound(String version) {
    return Intl.message(
      'New version found: $version',
      name: 'updateCheckNewVersionFound',
      desc: '',
      args: [version],
    );
  }

  /// `Current version: {version}`
  String updateCheckCurrentVersion(String version) {
    return Intl.message(
      'Current version: $version',
      name: 'updateCheckCurrentVersion',
      desc: '',
      args: [version],
    );
  }

  /// `Release Notes:`
  String get updateCheckReleaseNotes {
    return Intl.message(
      'Release Notes:',
      name: 'updateCheckReleaseNotes',
      desc: '',
      args: [],
    );
  }

  /// `Update Later`
  String get updateCheckUpdateLater {
    return Intl.message(
      'Update Later',
      name: 'updateCheckUpdateLater',
      desc: '',
      args: [],
    );
  }

  /// `Must Update`
  String get updateCheckMustUpdate {
    return Intl.message(
      'Must Update',
      name: 'updateCheckMustUpdate',
      desc: '',
      args: [],
    );
  }

  /// `Update Now`
  String get updateCheckUpdateNow {
    return Intl.message(
      'Update Now',
      name: 'updateCheckUpdateNow',
      desc: '',
      args: [],
    );
  }

  /// `Update server URL not configured, please check configuration`
  String get updateCheckServerUrlNotConfigured {
    return Intl.message(
      'Update server URL not configured, please check configuration',
      name: 'updateCheckServerUrlNotConfigured',
      desc: '',
      args: [],
    );
  }

  /// `No update server URLs configured, please check configuration`
  String get updateCheckNoServerUrlsConfigured {
    return Intl.message(
      'No update server URLs configured, please check configuration',
      name: 'updateCheckNoServerUrlsConfigured',
      desc: '',
      args: [],
    );
  }

  /// `All configured update servers are unavailable`
  String get updateCheckAllServersUnavailable {
    return Intl.message(
      'All configured update servers are unavailable',
      name: 'updateCheckAllServersUnavailable',
      desc: '',
      args: [],
    );
  }

  /// `Server returned error status code {statusCode}`
  String updateCheckServerError(int statusCode) {
    return Intl.message(
      'Server returned error status code $statusCode',
      name: 'updateCheckServerError',
      desc: '',
      args: [statusCode],
    );
  }

  /// `Server temporarily unavailable, please try again later`
  String get updateCheckServerTemporarilyUnavailable {
    return Intl.message(
      'Server temporarily unavailable, please try again later',
      name: 'updateCheckServerTemporarilyUnavailable',
      desc: '',
      args: [],
    );
  }

  /// `Online Support`
  String get onlineSupportTitle {
    return Intl.message(
      'Online Support',
      name: 'onlineSupportTitle',
      desc: '',
      args: [],
    );
  }

  /// `Successfully connected to support system`
  String get onlineSupportConnected {
    return Intl.message(
      'Successfully connected to support system',
      name: 'onlineSupportConnected',
      desc: '',
      args: [],
    );
  }

  /// `Connecting...`
  String get onlineSupportConnecting {
    return Intl.message(
      'Connecting...',
      name: 'onlineSupportConnecting',
      desc: '',
      args: [],
    );
  }

  /// `Disconnected`
  String get onlineSupportDisconnected {
    return Intl.message(
      'Disconnected',
      name: 'onlineSupportDisconnected',
      desc: '',
      args: [],
    );
  }

  /// `Connection error`
  String get onlineSupportConnectionError {
    return Intl.message(
      'Connection error',
      name: 'onlineSupportConnectionError',
      desc: '',
      args: [],
    );
  }

  /// `No messages yet, send a message to start consultation`
  String get onlineSupportNoMessages {
    return Intl.message(
      'No messages yet, send a message to start consultation',
      name: 'onlineSupportNoMessages',
      desc: '',
      args: [],
    );
  }

  /// `Please enter your question...`
  String get onlineSupportInputHint {
    return Intl.message(
      'Please enter your question...',
      name: 'onlineSupportInputHint',
      desc: '',
      args: [],
    );
  }

  /// `Send image`
  String get onlineSupportSendImage {
    return Intl.message(
      'Send image',
      name: 'onlineSupportSendImage',
      desc: '',
      args: [],
    );
  }

  /// `Clear history`
  String get onlineSupportClearHistory {
    return Intl.message(
      'Clear history',
      name: 'onlineSupportClearHistory',
      desc: '',
      args: [],
    );
  }

  /// `Are you sure you want to clear all chat history? This action cannot be undone.`
  String get onlineSupportClearHistoryConfirm {
    return Intl.message(
      'Are you sure you want to clear all chat history? This action cannot be undone.',
      name: 'onlineSupportClearHistoryConfirm',
      desc: '',
      args: [],
    );
  }

  /// `Cancel`
  String get onlineSupportCancel {
    return Intl.message(
      'Cancel',
      name: 'onlineSupportCancel',
      desc: '',
      args: [],
    );
  }

  /// `Confirm`
  String get onlineSupportConfirm {
    return Intl.message(
      'Confirm',
      name: 'onlineSupportConfirm',
      desc: '',
      args: [],
    );
  }

  /// `Select Images`
  String get onlineSupportSelectImages {
    return Intl.message(
      'Select Images',
      name: 'onlineSupportSelectImages',
      desc: '',
      args: [],
    );
  }

  /// `Click to select images`
  String get onlineSupportClickToSelect {
    return Intl.message(
      'Click to select images',
      name: 'onlineSupportClickToSelect',
      desc: '',
      args: [],
    );
  }

  /// `Supports JPG, PNG, GIF, WebP, BMP\nMax 10MB`
  String get onlineSupportSupportedFormats {
    return Intl.message(
      'Supports JPG, PNG, GIF, WebP, BMP\nMax 10MB',
      name: 'onlineSupportSupportedFormats',
      desc: '',
      args: [],
    );
  }

  /// `Add More`
  String get onlineSupportAddMore {
    return Intl.message(
      'Add More',
      name: 'onlineSupportAddMore',
      desc: '',
      args: [],
    );
  }

  /// `Send`
  String get onlineSupportSend {
    return Intl.message('Send', name: 'onlineSupportSend', desc: '', args: []);
  }

  /// `Failed to select images: {error}`
  String onlineSupportSelectImagesFailed(String error) {
    return Intl.message(
      'Failed to select images: $error',
      name: 'onlineSupportSelectImagesFailed',
      desc: '',
      args: [error],
    );
  }

  /// `Upload failed: {error}`
  String onlineSupportUploadFailed(String error) {
    return Intl.message(
      'Upload failed: $error',
      name: 'onlineSupportUploadFailed',
      desc: '',
      args: [error],
    );
  }

  /// `Online support API configuration not found, please check configuration`
  String get onlineSupportApiConfigNotFound {
    return Intl.message(
      'Online support API configuration not found, please check configuration',
      name: 'onlineSupportApiConfigNotFound',
      desc: '',
      args: [],
    );
  }

  /// `Unsupported HTTP method: {method}`
  String onlineSupportUnsupportedHttpMethod(String method) {
    return Intl.message(
      'Unsupported HTTP method: $method',
      name: 'onlineSupportUnsupportedHttpMethod',
      desc: '',
      args: [method],
    );
  }

  /// `Failed to send message: Unable to get authentication token`
  String get onlineSupportSendMessageFailed {
    return Intl.message(
      'Failed to send message: Unable to get authentication token',
      name: 'onlineSupportSendMessageFailed',
      desc: '',
      args: [],
    );
  }

  /// `Authentication token not found`
  String get onlineSupportTokenNotFound {
    return Intl.message(
      'Authentication token not found',
      name: 'onlineSupportTokenNotFound',
      desc: '',
      args: [],
    );
  }

  /// `Failed to get messages: {statusCode}`
  String onlineSupportGetMessagesFailed(int statusCode) {
    return Intl.message(
      'Failed to get messages: $statusCode',
      name: 'onlineSupportGetMessagesFailed',
      desc: '',
      args: [statusCode],
    );
  }

  /// `Support`
  String get contactSupport {
    return Intl.message('Support', name: 'contactSupport', desc: '', args: []);
  }

  /// `Application configuration error, please contact support`
  String get configurationError {
    return Intl.message(
      'Application configuration error, please contact support',
      name: 'configurationError',
      desc: '',
      args: [],
    );
  }

  /// `Online support WebSocket configuration not found, please check configuration`
  String get onlineSupportWebSocketConfigNotFound {
    return Intl.message(
      'Online support WebSocket configuration not found, please check configuration',
      name: 'onlineSupportWebSocketConfigNotFound',
      desc: '',
      args: [],
    );
  }

  /// `New message from support`
  String get newMessageFromSupport {
    return Intl.message(
      'New message from support',
      name: 'newMessageFromSupport',
      desc: '',
      args: [],
    );
  }

  /// `Website`
  String get officialWebsite {
    return Intl.message('Website', name: 'officialWebsite', desc: '', args: []);
  }

  /// `Not connected`
  String get notConnected {
    return Intl.message(
      'Not connected',
      name: 'notConnected',
      desc: '',
      args: [],
    );
  }

  /// `Tap to connect`
  String get tapToConnect {
    return Intl.message(
      'Tap to connect',
      name: 'tapToConnect',
      desc: '',
      args: [],
    );
  }

  /// `Connected`
  String get connected {
    return Intl.message('Connected', name: 'connected', desc: '', args: []);
  }

  /// `Issuing`
  String get xboardCommissionIssuing {
    return Intl.message(
      'Issuing',
      name: 'xboardCommissionIssuing',
      desc: '',
      args: [],
    );
  }

  /// `Confirmed`
  String get xboardCommissionConfirmed {
    return Intl.message(
      'Confirmed',
      name: 'xboardCommissionConfirmed',
      desc: '',
      args: [],
    );
  }

  /// `Generate invite code`
  String get generateInviteCode {
    return Intl.message(
      'Generate invite code',
      name: 'generateInviteCode',
      desc: '',
      args: [],
    );
  }

  /// `No invite code`
  String get noInviteCode {
    return Intl.message(
      'No invite code',
      name: 'noInviteCode',
      desc: '',
      args: [],
    );
  }

  /// `Account banned`
  String get xboardAccountBanned {
    return Intl.message(
      'Account banned',
      name: 'xboardAccountBanned',
      desc: '',
      args: [],
    );
  }

  /// `This account has been banned. Please contact support.`
  String get xboardAccountBannedDetail {
    return Intl.message(
      'This account has been banned. Please contact support.',
      name: 'xboardAccountBannedDetail',
      desc: '',
      args: [],
    );
  }

  /// `My Account`
  String get xboardAccountInfo {
    return Intl.message(
      'My Account',
      name: 'xboardAccountInfo',
      desc: '',
      args: [],
    );
  }

  /// `Account management`
  String get xboardAccountManagement {
    return Intl.message(
      'Account management',
      name: 'xboardAccountManagement',
      desc: '',
      args: [],
    );
  }

  /// `Auto renewal`
  String get xboardAutoRenewal {
    return Intl.message(
      'Auto renewal',
      name: 'xboardAutoRenewal',
      desc: '',
      args: [],
    );
  }

  /// `Your balance will be used to renew the plan before it expires. Keep enough balance available.`
  String get xboardAutoRenewalDescription {
    return Intl.message(
      'Your balance will be used to renew the plan before it expires. Keep enough balance available.',
      name: 'xboardAutoRenewalDescription',
      desc: '',
      args: [],
    );
  }

  /// `Purchase a plan to enable auto renewal.`
  String get xboardAutoRenewalNoPlan {
    return Intl.message(
      'Purchase a plan to enable auto renewal.',
      name: 'xboardAutoRenewalNoPlan',
      desc: '',
      args: [],
    );
  }

  /// `Auto renewal enabled`
  String get xboardAutoRenewalEnabled {
    return Intl.message(
      'Auto renewal enabled',
      name: 'xboardAutoRenewalEnabled',
      desc: '',
      args: [],
    );
  }

  /// `Auto renewal disabled`
  String get xboardAutoRenewalDisabled {
    return Intl.message(
      'Auto renewal disabled',
      name: 'xboardAutoRenewalDisabled',
      desc: '',
      args: [],
    );
  }

  /// `Could not update auto renewal. Try again later.`
  String get xboardAutoRenewalUpdateFailed {
    return Intl.message(
      'Could not update auto renewal. Try again later.',
      name: 'xboardAutoRenewalUpdateFailed',
      desc: '',
      args: [],
    );
  }

  /// `Pay with balance`
  String get xboardBalancePay {
    return Intl.message(
      'Pay with balance',
      name: 'xboardBalancePay',
      desc: '',
      args: [],
    );
  }

  /// `Cancel order`
  String get xboardCancelOrder {
    return Intl.message(
      'Cancel order',
      name: 'xboardCancelOrder',
      desc: '',
      args: [],
    );
  }

  /// `Canceling...`
  String get xboardCanceling {
    return Intl.message(
      'Canceling...',
      name: 'xboardCanceling',
      desc: '',
      args: [],
    );
  }

  /// `Change password`
  String get xboardChangePassword {
    return Intl.message(
      'Change password',
      name: 'xboardChangePassword',
      desc: '',
      args: [],
    );
  }

  /// `Check payment status`
  String get xboardCheckPaymentStatus {
    return Intl.message(
      'Check payment status',
      name: 'xboardCheckPaymentStatus',
      desc: '',
      args: [],
    );
  }

  /// `Confirm change`
  String get xboardConfirmChange {
    return Intl.message(
      'Confirm change',
      name: 'xboardConfirmChange',
      desc: '',
      args: [],
    );
  }

  /// `Confirm renewal`
  String get xboardConfirmRenewPlan {
    return Intl.message(
      'Confirm renewal',
      name: 'xboardConfirmRenewPlan',
      desc: '',
      args: [],
    );
  }

  /// `Confirm traffic reset`
  String get xboardConfirmResetTraffic {
    return Intl.message(
      'Confirm traffic reset',
      name: 'xboardConfirmResetTraffic',
      desc: '',
      args: [],
    );
  }

  /// `Start the next traffic period?`
  String get xboardConfirmNewPeriod {
    return Intl.message(
      'Start the next traffic period?',
      name: 'xboardConfirmNewPeriod',
      desc: '',
      args: [],
    );
  }

  /// `Create ticket`
  String get xboardCreateTicket {
    return Intl.message(
      'Create ticket',
      name: 'xboardCreateTicket',
      desc: '',
      args: [],
    );
  }

  /// `Create a ticket to contact support.`
  String get xboardCreateTicketHint {
    return Intl.message(
      'Create a ticket to contact support.',
      name: 'xboardCreateTicketHint',
      desc: '',
      args: [],
    );
  }

  /// `Created at`
  String get xboardCreatedAt {
    return Intl.message(
      'Created at',
      name: 'xboardCreatedAt',
      desc: '',
      args: [],
    );
  }

  /// `Current balance`
  String get xboardCurrentBalance {
    return Intl.message(
      'Current balance',
      name: 'xboardCurrentBalance',
      desc: '',
      args: [],
    );
  }

  /// `Current password`
  String get xboardCurrentPassword {
    return Intl.message(
      'Current password',
      name: 'xboardCurrentPassword',
      desc: '',
      args: [],
    );
  }

  /// `Based on current plan`
  String get xboardCurrentPlanBased {
    return Intl.message(
      'Based on current plan',
      name: 'xboardCurrentPlanBased',
      desc: '',
      args: [],
    );
  }

  /// `Custom recharge amount`
  String get xboardCustomRechargeAmount {
    return Intl.message(
      'Custom recharge amount',
      name: 'xboardCustomRechargeAmount',
      desc: '',
      args: [],
    );
  }

  /// `Discount amount`
  String get xboardDiscountAmount {
    return Intl.message(
      'Discount amount',
      name: 'xboardDiscountAmount',
      desc: '',
      args: [],
    );
  }

  /// `Refund to wallet`
  String get xboardRefundAmount {
    return Intl.message(
      'Refund to wallet',
      name: 'xboardRefundAmount',
      desc: '',
      args: [],
    );
  }

  /// `Wallet balance`
  String get xboardWalletBalance {
    return Intl.message(
      'Wallet balance',
      name: 'xboardWalletBalance',
      desc: '',
      args: [],
    );
  }

  /// `Surplus amount`
  String get xboardSurplusAmount {
    return Intl.message(
      'Surplus amount',
      name: 'xboardSurplusAmount',
      desc: '',
      args: [],
    );
  }

  /// `Commission deduction`
  String get xboardCommissionOffsetAmount {
    return Intl.message(
      'Commission deduction',
      name: 'xboardCommissionOffsetAmount',
      desc: '',
      args: [],
    );
  }

  /// `User guide`
  String get xboardDocsCenter {
    return Intl.message(
      'User guide',
      name: 'xboardDocsCenter',
      desc: '',
      args: [],
    );
  }

  /// `No documents`
  String get xboardNoDocuments {
    return Intl.message(
      'No documents',
      name: 'xboardNoDocuments',
      desc: '',
      args: [],
    );
  }

  /// `Email unavailable`
  String get xboardEmailUnavailable {
    return Intl.message(
      'Email unavailable',
      name: 'xboardEmailUnavailable',
      desc: '',
      args: [],
    );
  }

  /// `Enter amount`
  String get xboardEnterAmount {
    return Intl.message(
      'Enter amount',
      name: 'xboardEnterAmount',
      desc: '',
      args: [],
    );
  }

  /// `Enter gift card code`
  String get xboardEnterGiftCardCode {
    return Intl.message(
      'Enter gift card code',
      name: 'xboardEnterGiftCardCode',
      desc: '',
      args: [],
    );
  }

  /// `Gift card code`
  String get xboardGiftCardCode {
    return Intl.message(
      'Gift card code',
      name: 'xboardGiftCardCode',
      desc: '',
      args: [],
    );
  }

  /// `Gift card redeem`
  String get xboardGiftCardRedeem {
    return Intl.message(
      'Gift card redeem',
      name: 'xboardGiftCardRedeem',
      desc: '',
      args: [],
    );
  }

  /// `Global proxy`
  String get xboardGlobalProxy {
    return Intl.message(
      'Global proxy',
      name: 'xboardGlobalProxy',
      desc: '',
      args: [],
    );
  }

  /// `High`
  String get xboardHigh {
    return Intl.message('High', name: 'xboardHigh', desc: '', args: []);
  }

  /// `Importing subscription`
  String get xboardImportingSubscription {
    return Intl.message(
      'Importing subscription',
      name: 'xboardImportingSubscription',
      desc: '',
      args: [],
    );
  }

  /// `Low`
  String get xboardLow {
    return Intl.message('Low', name: 'xboardLow', desc: '', args: []);
  }

  /// `Medium`
  String get xboardMedium {
    return Intl.message('Medium', name: 'xboardMedium', desc: '', args: []);
  }

  /// `My tickets`
  String get xboardMyTickets {
    return Intl.message(
      'My tickets',
      name: 'xboardMyTickets',
      desc: '',
      args: [],
    );
  }

  /// `My wallet`
  String get xboardMyWallet {
    return Intl.message(
      'My wallet',
      name: 'xboardMyWallet',
      desc: '',
      args: [],
    );
  }

  /// `No order records`
  String get xboardNoOrderRecords {
    return Intl.message(
      'No order records',
      name: 'xboardNoOrderRecords',
      desc: '',
      args: [],
    );
  }

  /// `No payment methods`
  String get xboardNoPaymentMethods {
    return Intl.message(
      'No payment methods',
      name: 'xboardNoPaymentMethods',
      desc: '',
      args: [],
    );
  }

  /// `No ticket records`
  String get xboardNoTicketRecords {
    return Intl.message(
      'No ticket records',
      name: 'xboardNoTicketRecords',
      desc: '',
      args: [],
    );
  }

  /// `No traffic records`
  String get xboardNoTrafficRecords {
    return Intl.message(
      'No traffic records',
      name: 'xboardNoTrafficRecords',
      desc: '',
      args: [],
    );
  }

  /// `Node selection`
  String get xboardNodeSelection {
    return Intl.message(
      'Node selection',
      name: 'xboardNodeSelection',
      desc: '',
      args: [],
    );
  }

  /// `Normal`
  String get xboardNormal {
    return Intl.message('Normal', name: 'xboardNormal', desc: '', args: []);
  }

  /// `Order info`
  String get xboardOrderInfo {
    return Intl.message(
      'Order info',
      name: 'xboardOrderInfo',
      desc: '',
      args: [],
    );
  }

  /// `Failed to load order`
  String get xboardOrderLoadingFailed {
    return Intl.message(
      'Failed to load order',
      name: 'xboardOrderLoadingFailed',
      desc: '',
      args: [],
    );
  }

  /// `Order records`
  String get xboardOrderRecords {
    return Intl.message(
      'Order records',
      name: 'xboardOrderRecords',
      desc: '',
      args: [],
    );
  }

  /// `Order status`
  String get xboardOrderStatus {
    return Intl.message(
      'Order status',
      name: 'xboardOrderStatus',
      desc: '',
      args: [],
    );
  }

  /// `Cancelled`
  String get xboardOrderStatusCancelled {
    return Intl.message(
      'Cancelled',
      name: 'xboardOrderStatusCancelled',
      desc: '',
      args: [],
    );
  }

  /// `Completed`
  String get xboardOrderStatusCompleted {
    return Intl.message(
      'Completed',
      name: 'xboardOrderStatusCompleted',
      desc: '',
      args: [],
    );
  }

  /// `Offset`
  String get xboardOrderStatusOffset {
    return Intl.message(
      'Offset',
      name: 'xboardOrderStatusOffset',
      desc: '',
      args: [],
    );
  }

  /// `Activating`
  String get xboardOrderStatusOpening {
    return Intl.message(
      'Activating',
      name: 'xboardOrderStatusOpening',
      desc: '',
      args: [],
    );
  }

  /// `Package amount`
  String get xboardPackageAmount {
    return Intl.message(
      'Package amount',
      name: 'xboardPackageAmount',
      desc: '',
      args: [],
    );
  }

  /// `Recharge amount`
  String get xboardRechargeAmount {
    return Intl.message(
      'Recharge amount',
      name: 'xboardRechargeAmount',
      desc: '',
      args: [],
    );
  }

  /// `Recharge bonus`
  String get xboardRechargeBonus {
    return Intl.message(
      'Recharge bonus',
      name: 'xboardRechargeBonus',
      desc: '',
      args: [],
    );
  }

  /// `Amount credited`
  String get xboardCreditedAmount {
    return Intl.message(
      'Amount credited',
      name: 'xboardCreditedAmount',
      desc: '',
      args: [],
    );
  }

  /// `Original price`
  String get xboardOriginalPrice {
    return Intl.message(
      'Original price',
      name: 'xboardOriginalPrice',
      desc: '',
      args: [],
    );
  }

  /// `Discounted price`
  String get xboardDiscountedPrice {
    return Intl.message(
      'Discounted price',
      name: 'xboardDiscountedPrice',
      desc: '',
      args: [],
    );
  }

  /// `Pay now`
  String get xboardPayNow {
    return Intl.message('Pay now', name: 'xboardPayNow', desc: '', args: []);
  }

  /// `Payable amount`
  String get xboardPayableAmount {
    return Intl.message(
      'Payable amount',
      name: 'xboardPayableAmount',
      desc: '',
      args: [],
    );
  }

  /// `Order amount`
  String get xboardOrderAmount {
    return Intl.message(
      'Order amount',
      name: 'xboardOrderAmount',
      desc: '',
      args: [],
    );
  }

  /// `Payable amount`
  String get xboardActualPaidAmount {
    return Intl.message(
      'Payable amount',
      name: 'xboardActualPaidAmount',
      desc: '',
      args: [],
    );
  }

  /// `Deducted balance`
  String get xboardDeductedBalance {
    return Intl.message(
      'Deducted balance',
      name: 'xboardDeductedBalance',
      desc: '',
      args: [],
    );
  }

  /// `Available balance`
  String get xboardDeductibleBalance {
    return Intl.message(
      'Available balance',
      name: 'xboardDeductibleBalance',
      desc: '',
      args: [],
    );
  }

  /// `Remaining`
  String get xboardRemainingBalance {
    return Intl.message(
      'Remaining',
      name: 'xboardRemainingBalance',
      desc: '',
      args: [],
    );
  }

  /// `Payment methods`
  String get xboardPaymentMethods {
    return Intl.message(
      'Payment methods',
      name: 'xboardPaymentMethods',
      desc: '',
      args: [],
    );
  }

  /// `Period`
  String get xboardPeriod {
    return Intl.message('Period', name: 'xboardPeriod', desc: '', args: []);
  }

  /// `Based on plan`
  String get xboardPlanBased {
    return Intl.message(
      'Based on plan',
      name: 'xboardPlanBased',
      desc: '',
      args: [],
    );
  }

  /// `Plan expiry email reminder`
  String get xboardPlanExpiryReminder {
    return Intl.message(
      'Plan expiry email reminder',
      name: 'xboardPlanExpiryReminder',
      desc: '',
      args: [],
    );
  }

  /// `Plan name`
  String get xboardPlanName {
    return Intl.message(
      'Plan name',
      name: 'xboardPlanName',
      desc: '',
      args: [],
    );
  }

  /// `Please wait`
  String get xboardPleaseWait {
    return Intl.message(
      'Please wait',
      name: 'xboardPleaseWait',
      desc: '',
      args: [],
    );
  }

  /// `Priority`
  String get xboardPriority {
    return Intl.message('Priority', name: 'xboardPriority', desc: '', args: []);
  }

  /// `Product info`
  String get xboardProductInfo {
    return Intl.message(
      'Product info',
      name: 'xboardProductInfo',
      desc: '',
      args: [],
    );
  }

  /// `Recharge`
  String get xboardRecharge {
    return Intl.message('Recharge', name: 'xboardRecharge', desc: '', args: []);
  }

  /// `Recharge balance`
  String get xboardRechargeBalance {
    return Intl.message(
      'Recharge balance',
      name: 'xboardRechargeBalance',
      desc: '',
      args: [],
    );
  }

  /// `The recharge amount will be added to your account balance.`
  String get xboardRechargeBalanceTip {
    return Intl.message(
      'The recharge amount will be added to your account balance.',
      name: 'xboardRechargeBalanceTip',
      desc: '',
      args: [],
    );
  }

  /// `Recharge now`
  String get xboardRechargeNow {
    return Intl.message(
      'Recharge now',
      name: 'xboardRechargeNow',
      desc: '',
      args: [],
    );
  }

  /// `Redeem now`
  String get xboardRedeemNow {
    return Intl.message(
      'Redeem now',
      name: 'xboardRedeemNow',
      desc: '',
      args: [],
    );
  }

  /// `Reset current plan traffic`
  String get xboardResetCurrentPlanTraffic {
    return Intl.message(
      'Reset current plan traffic',
      name: 'xboardResetCurrentPlanTraffic',
      desc: '',
      args: [],
    );
  }

  /// `Reset traffic`
  String get xboardResetTraffic {
    return Intl.message(
      'Reset traffic',
      name: 'xboardResetTraffic',
      desc: '',
      args: [],
    );
  }

  /// `Reset traffic by plan cycle`
  String get xboardResetTrafficByPlanCycle {
    return Intl.message(
      'Reset traffic by plan cycle',
      name: 'xboardResetTrafficByPlanCycle',
      desc: '',
      args: [],
    );
  }

  /// `This will reset the used traffic, but will not extend the plan duration. Continue?`
  String get xboardResetTrafficConfirmContent {
    return Intl.message(
      'This will reset the used traffic, but will not extend the plan duration. Continue?',
      name: 'xboardResetTrafficConfirmContent',
      desc: '',
      args: [],
    );
  }

  /// `Start next traffic period`
  String get xboardStartNewPeriod {
    return Intl.message(
      'Start next traffic period',
      name: 'xboardStartNewPeriod',
      desc: '',
      args: [],
    );
  }

  /// `This resets used traffic and deducts the remaining duration of the current traffic period from your plan. This action cannot be undone. Continue?`
  String get xboardNewPeriodConfirmContent {
    return Intl.message(
      'This resets used traffic and deducts the remaining duration of the current traffic period from your plan. This action cannot be undone. Continue?',
      name: 'xboardNewPeriodConfirmContent',
      desc: '',
      args: [],
    );
  }

  /// `Starting the new traffic period`
  String get xboardNewPeriodStarting {
    return Intl.message(
      'Starting the new traffic period',
      name: 'xboardNewPeriodStarting',
      desc: '',
      args: [],
    );
  }

  /// `Checking the operation result`
  String get xboardNewPeriodCheckingResult {
    return Intl.message(
      'Checking the operation result',
      name: 'xboardNewPeriodCheckingResult',
      desc: '',
      args: [],
    );
  }

  /// `Unable to confirm the result`
  String get xboardNewPeriodResultUncertainTitle {
    return Intl.message(
      'Unable to confirm the result',
      name: 'xboardNewPeriodResultUncertainTitle',
      desc: '',
      args: [],
    );
  }

  /// `The network response was interrupted, so the new traffic period cannot be confirmed yet. Check the result instead of submitting again.`
  String get xboardNewPeriodResultUncertainContent {
    return Intl.message(
      'The network response was interrupted, so the new traffic period cannot be confirmed yet. Check the result instead of submitting again.',
      name: 'xboardNewPeriodResultUncertainContent',
      desc: '',
      args: [],
    );
  }

  /// `The new traffic period has started`
  String get xboardNewPeriodSuccess {
    return Intl.message(
      'The new traffic period has started',
      name: 'xboardNewPeriodSuccess',
      desc: '',
      args: [],
    );
  }

  /// `Could not start a new traffic period. Try again later.`
  String get xboardNewPeriodFailed {
    return Intl.message(
      'Could not start a new traffic period. Try again later.',
      name: 'xboardNewPeriodFailed',
      desc: '',
      args: [],
    );
  }

  /// `Your plan does not have enough remaining time to start a new traffic period.`
  String get xboardNewPeriodInsufficientDuration {
    return Intl.message(
      'Your plan does not have enough remaining time to start a new traffic period.',
      name: 'xboardNewPeriodInsufficientDuration',
      desc: '',
      args: [],
    );
  }

  /// `This plan does not allow starting a new traffic period.`
  String get xboardNewPeriodNotAllowed {
    return Intl.message(
      'This plan does not allow starting a new traffic period.',
      name: 'xboardNewPeriodNotAllowed',
      desc: '',
      args: [],
    );
  }

  /// `Your plan traffic is used up. You can start the next traffic period early.`
  String get xboardNewPeriodTrafficExhaustedDetail {
    return Intl.message(
      'Your plan traffic is used up. You can start the next traffic period early.',
      name: 'xboardNewPeriodTrafficExhaustedDetail',
      desc: '',
      args: [],
    );
  }

  /// `Select recharge amount`
  String get xboardSelectRechargeAmount {
    return Intl.message(
      'Select recharge amount',
      name: 'xboardSelectRechargeAmount',
      desc: '',
      args: [],
    );
  }

  /// `Smart routing`
  String get xboardSmartRouting {
    return Intl.message(
      'Smart routing',
      name: 'xboardSmartRouting',
      desc: '',
      args: [],
    );
  }

  /// `Submit ticket`
  String get xboardSubmitTicket {
    return Intl.message(
      'Submit ticket',
      name: 'xboardSubmitTicket',
      desc: '',
      args: [],
    );
  }

  /// `Submit order`
  String get xboardSubmitOrder {
    return Intl.message(
      'Submit order',
      name: 'xboardSubmitOrder',
      desc: '',
      args: [],
    );
  }

  /// `Submitting...`
  String get xboardSubmitting {
    return Intl.message(
      'Submitting...',
      name: 'xboardSubmitting',
      desc: '',
      args: [],
    );
  }

  /// `Test latency`
  String get xboardTestLatency {
    return Intl.message(
      'Test latency',
      name: 'xboardTestLatency',
      desc: '',
      args: [],
    );
  }

  /// `Closed`
  String get xboardTicketClosed {
    return Intl.message(
      'Closed',
      name: 'xboardTicketClosed',
      desc: '',
      args: [],
    );
  }

  /// `Description`
  String get xboardTicketDescription {
    return Intl.message(
      'Description',
      name: 'xboardTicketDescription',
      desc: '',
      args: [],
    );
  }

  /// `Describe your issue in detail`
  String get xboardTicketDescriptionHint {
    return Intl.message(
      'Describe your issue in detail',
      name: 'xboardTicketDescriptionHint',
      desc: '',
      args: [],
    );
  }

  /// `Pending reply`
  String get xboardTicketPendingReply {
    return Intl.message(
      'Pending reply',
      name: 'xboardTicketPendingReply',
      desc: '',
      args: [],
    );
  }

  /// `Replied`
  String get xboardTicketReplied {
    return Intl.message(
      'Replied',
      name: 'xboardTicketReplied',
      desc: '',
      args: [],
    );
  }

  /// `Ticket title`
  String get xboardTicketTitle {
    return Intl.message(
      'Ticket title',
      name: 'xboardTicketTitle',
      desc: '',
      args: [],
    );
  }

  /// `Enter ticket title`
  String get xboardTicketTitleHint {
    return Intl.message(
      'Enter ticket title',
      name: 'xboardTicketTitleHint',
      desc: '',
      args: [],
    );
  }

  /// `Total`
  String get xboardTotal {
    return Intl.message('Total', name: 'xboardTotal', desc: '', args: []);
  }

  /// `Traffic details`
  String get xboardTrafficDetails {
    return Intl.message(
      'Traffic details',
      name: 'xboardTrafficDetails',
      desc: '',
      args: [],
    );
  }

  /// `Only showing traffic data from the last 30 days`
  String get xboardTrafficLogHint {
    return Intl.message(
      'Only showing traffic data from the last 30 days',
      name: 'xboardTrafficLogHint',
      desc: '',
      args: [],
    );
  }

  /// `Renewing the plan will not reset traffic immediately. To use service right away, reset traffic or switch plans. Continue?`
  String get xboardTrafficExhaustedRenewConfirmContent {
    return Intl.message(
      'Renewing the plan will not reset traffic immediately. To use service right away, reset traffic or switch plans. Continue?',
      name: 'xboardTrafficExhaustedRenewConfirmContent',
      desc: '',
      args: [],
    );
  }

  /// `Traffic usage email reminder`
  String get xboardTrafficReminder {
    return Intl.message(
      'Traffic usage email reminder',
      name: 'xboardTrafficReminder',
      desc: '',
      args: [],
    );
  }

  /// `Unknown period`
  String get xboardUnknownPeriod {
    return Intl.message(
      'Unknown period',
      name: 'xboardUnknownPeriod',
      desc: '',
      args: [],
    );
  }

  /// `Unknown plan`
  String get xboardUnknownPlan {
    return Intl.message(
      'Unknown plan',
      name: 'xboardUnknownPlan',
      desc: '',
      args: [],
    );
  }

  /// `Unlimited speed`
  String get xboardUnlimitedSpeed {
    return Intl.message(
      'Unlimited speed',
      name: 'xboardUnlimitedSpeed',
      desc: '',
      args: [],
    );
  }

  /// `Update nodes`
  String get xboardUpdateNodes {
    return Intl.message(
      'Update nodes',
      name: 'xboardUpdateNodes',
      desc: '',
      args: [],
    );
  }

  /// `Upload image`
  String get xboardUploadImage {
    return Intl.message(
      'Upload image',
      name: 'xboardUploadImage',
      desc: '',
      args: [],
    );
  }

  /// `Use balance`
  String get xboardUseBalance {
    return Intl.message(
      'Use balance',
      name: 'xboardUseBalance',
      desc: '',
      args: [],
    );
  }

  /// `Expired on {date}`
  String xboardExpiredOnDate(String date) {
    return Intl.message(
      'Expired on $date',
      name: 'xboardExpiredOnDate',
      desc: '',
      args: [date],
    );
  }

  /// `Expires on {date}, {days} days remaining`
  String xboardExpiresOnWithDays(String date, int days) {
    return Intl.message(
      'Expires on $date, $days days remaining',
      name: 'xboardExpiresOnWithDays',
      desc: '',
      args: [date, days],
    );
  }

  /// `Used traffic will reset in {days} days`
  String xboardResetTrafficInDays(int days) {
    return Intl.message(
      'Used traffic will reset in $days days',
      name: 'xboardResetTrafficInDays',
      desc: '',
      args: [days],
    );
  }

  /// `Used traffic has been reset today`
  String get xboardResetTrafficToday {
    return Intl.message(
      'Used traffic has been reset today',
      name: 'xboardResetTrafficToday',
      desc: 'Shown when traffic reset day is 0 (today)',
      args: [],
    );
  }

  /// `My services`
  String get xboardMyServices {
    return Intl.message(
      'My services',
      name: 'xboardMyServices',
      desc: '',
      args: [],
    );
  }

  /// `Software settings`
  String get xboardSoftwareSettings {
    return Intl.message(
      'Software settings',
      name: 'xboardSoftwareSettings',
      desc: '',
      args: [],
    );
  }

  /// `Mine`
  String get xboardMine {
    return Intl.message('Mine', name: 'xboardMine', desc: '', args: []);
  }

  /// `Valid until {date}`
  String xboardExpiresOnDate(String date) {
    return Intl.message(
      'Valid until $date',
      name: 'xboardExpiresOnDate',
      desc: '',
      args: [date],
    );
  }

  /// `Withdrawal method`
  String get withdrawMethod {
    return Intl.message(
      'Withdrawal method',
      name: 'withdrawMethod',
      desc: '',
      args: [],
    );
  }

  /// `Please select a withdrawal method`
  String get pleaseSelectWithdrawMethod {
    return Intl.message(
      'Please select a withdrawal method',
      name: 'pleaseSelectWithdrawMethod',
      desc: '',
      args: [],
    );
  }

  /// `Withdrawal account`
  String get withdrawAccount {
    return Intl.message(
      'Withdrawal account',
      name: 'withdrawAccount',
      desc: '',
      args: [],
    );
  }

  /// `Please enter withdrawal account`
  String get pleaseEnterWithdrawAccount {
    return Intl.message(
      'Please enter withdrawal account',
      name: 'pleaseEnterWithdrawAccount',
      desc: '',
      args: [],
    );
  }

  /// `The withdrawal request will be submitted through the ticket system. Please wait for admin review.`
  String get withdrawSubmissionNote {
    return Intl.message(
      'The withdrawal request will be submitted through the ticket system. Please wait for admin review.',
      name: 'withdrawSubmissionNote',
      desc: '',
      args: [],
    );
  }

  /// `Withdrawal request submitted`
  String get withdrawRequestSubmitted {
    return Intl.message(
      'Withdrawal request submitted',
      name: 'withdrawRequestSubmitted',
      desc: '',
      args: [],
    );
  }

  /// `Withdrawal request submitted, please wait for review`
  String get withdrawRequestSubmittedWaitReview {
    return Intl.message(
      'Withdrawal request submitted, please wait for review',
      name: 'withdrawRequestSubmittedWaitReview',
      desc: '',
      args: [],
    );
  }

  /// `Submission failed`
  String get withdrawSubmissionFailed {
    return Intl.message(
      'Submission failed',
      name: 'withdrawSubmissionFailed',
      desc: '',
      args: [],
    );
  }

  /// `Submission failed: {error}`
  String withdrawSubmissionFailedWithError(String error) {
    return Intl.message(
      'Submission failed: $error',
      name: 'withdrawSubmissionFailedWithError',
      desc: '',
      args: [error],
    );
  }

  /// `Incorrect email or password`
  String get backendErrorIncorrectEmailOrPassword {
    return Intl.message(
      'Incorrect email or password',
      name: 'backendErrorIncorrectEmailOrPassword',
      desc: '',
      args: [],
    );
  }

  /// `This account has been suspended`
  String get backendErrorAccountSuspended {
    return Intl.message(
      'This account has been suspended',
      name: 'backendErrorAccountSuspended',
      desc: '',
      args: [],
    );
  }

  /// `Email cannot be empty`
  String get backendErrorEmailEmpty {
    return Intl.message(
      'Email cannot be empty',
      name: 'backendErrorEmailEmpty',
      desc: '',
      args: [],
    );
  }

  /// `Email format is incorrect`
  String get backendErrorEmailFormatInvalid {
    return Intl.message(
      'Email format is incorrect',
      name: 'backendErrorEmailFormatInvalid',
      desc: '',
      args: [],
    );
  }

  /// `Password cannot be empty`
  String get backendErrorPasswordEmpty {
    return Intl.message(
      'Password cannot be empty',
      name: 'backendErrorPasswordEmpty',
      desc: '',
      args: [],
    );
  }

  /// `Password must be longer than 8 characters`
  String get backendErrorPasswordTooShort {
    return Intl.message(
      'Password must be longer than 8 characters',
      name: 'backendErrorPasswordTooShort',
      desc: '',
      args: [],
    );
  }

  /// `Verification code is incorrect`
  String get backendErrorVerificationCodeInvalid {
    return Intl.message(
      'Verification code is incorrect',
      name: 'backendErrorVerificationCodeInvalid',
      desc: '',
      args: [],
    );
  }

  /// `Invite code is invalid`
  String get backendErrorInviteCodeInvalid {
    return Intl.message(
      'Invite code is invalid',
      name: 'backendErrorInviteCodeInvalid',
      desc: '',
      args: [],
    );
  }

  /// `Invite code does not exist`
  String get backendErrorInviteCodeNotFound {
    return Intl.message(
      'Invite code does not exist',
      name: 'backendErrorInviteCodeNotFound',
      desc: '',
      args: [],
    );
  }

  /// `This email is already registered`
  String get backendErrorEmailExists {
    return Intl.message(
      'This email is already registered',
      name: 'backendErrorEmailExists',
      desc: '',
      args: [],
    );
  }

  /// `Gift card cannot be empty`
  String get backendErrorGiftCardEmpty {
    return Intl.message(
      'Gift card cannot be empty',
      name: 'backendErrorGiftCardEmpty',
      desc: '',
      args: [],
    );
  }

  /// `User does not exist`
  String get backendErrorUserNotFound {
    return Intl.message(
      'User does not exist',
      name: 'backendErrorUserNotFound',
      desc: '',
      args: [],
    );
  }

  /// `This gift card does not exist`
  String get backendErrorGiftCardNotFound {
    return Intl.message(
      'This gift card does not exist',
      name: 'backendErrorGiftCardNotFound',
      desc: '',
      args: [],
    );
  }

  /// `This gift card is not yet valid`
  String get backendErrorGiftCardNotYetValid {
    return Intl.message(
      'This gift card is not yet valid',
      name: 'backendErrorGiftCardNotYetValid',
      desc: '',
      args: [],
    );
  }

  /// `This gift card has expired`
  String get backendErrorGiftCardExpired {
    return Intl.message(
      'This gift card has expired',
      name: 'backendErrorGiftCardExpired',
      desc: '',
      args: [],
    );
  }

  /// `This gift card has reached its usage limit`
  String get backendErrorGiftCardLimitReached {
    return Intl.message(
      'This gift card has reached its usage limit',
      name: 'backendErrorGiftCardLimitReached',
      desc: '',
      args: [],
    );
  }

  /// `This gift card has already been used by this user`
  String get backendErrorGiftCardAlreadyUsedByUser {
    return Intl.message(
      'This gift card has already been used by this user',
      name: 'backendErrorGiftCardAlreadyUsedByUser',
      desc: '',
      args: [],
    );
  }

  /// `This gift card type is not applicable`
  String get backendErrorGiftCardTypeNotSuitable {
    return Intl.message(
      'This gift card type is not applicable',
      name: 'backendErrorGiftCardTypeNotSuitable',
      desc: '',
      args: [],
    );
  }

  /// `Unknown gift card type`
  String get backendErrorGiftCardTypeUnknown {
    return Intl.message(
      'Unknown gift card type',
      name: 'backendErrorGiftCardTypeUnknown',
      desc: '',
      args: [],
    );
  }

  /// `Save failed, please try again later`
  String get backendErrorSaveFailed {
    return Intl.message(
      'Save failed, please try again later',
      name: 'backendErrorSaveFailed',
      desc: '',
      args: [],
    );
  }

  /// `Withdrawal method cannot be empty`
  String get backendErrorWithdrawalMethodEmpty {
    return Intl.message(
      'Withdrawal method cannot be empty',
      name: 'backendErrorWithdrawalMethodEmpty',
      desc: '',
      args: [],
    );
  }

  /// `Withdrawal account cannot be empty`
  String get backendErrorWithdrawalAccountEmpty {
    return Intl.message(
      'Withdrawal account cannot be empty',
      name: 'backendErrorWithdrawalAccountEmpty',
      desc: '',
      args: [],
    );
  }

  /// `Withdrawal is currently not supported`
  String get backendErrorWithdrawNotSupported {
    return Intl.message(
      'Withdrawal is currently not supported',
      name: 'backendErrorWithdrawNotSupported',
      desc: '',
      args: [],
    );
  }

  /// `Unsupported withdrawal method`
  String get backendErrorWithdrawalMethodUnsupported {
    return Intl.message(
      'Unsupported withdrawal method',
      name: 'backendErrorWithdrawalMethodUnsupported',
      desc: '',
      args: [],
    );
  }

  /// `Failed to create withdrawal ticket`
  String get backendErrorFailedToOpenTicket {
    return Intl.message(
      'Failed to create withdrawal ticket',
      name: 'backendErrorFailedToOpenTicket',
      desc: '',
      args: [],
    );
  }

  /// `Insufficient commission balance`
  String get backendErrorInsufficientCommissionBalance {
    return Intl.message(
      'Insufficient commission balance',
      name: 'backendErrorInsufficientCommissionBalance',
      desc: '',
      args: [],
    );
  }

  /// `Transfer failed`
  String get backendErrorTransferFailed {
    return Intl.message(
      'Transfer failed',
      name: 'backendErrorTransferFailed',
      desc: '',
      args: [],
    );
  }

  /// `Transfer amount cannot be empty`
  String get backendErrorTransferAmountEmpty {
    return Intl.message(
      'Transfer amount cannot be empty',
      name: 'backendErrorTransferAmountEmpty',
      desc: '',
      args: [],
    );
  }

  /// `Transfer amount parameter is invalid`
  String get backendErrorTransferAmountInvalid {
    return Intl.message(
      'Transfer amount parameter is invalid',
      name: 'backendErrorTransferAmountInvalid',
      desc: '',
      args: [],
    );
  }

  /// `Coupon cannot be empty`
  String get backendErrorCouponEmpty {
    return Intl.message(
      'Coupon cannot be empty',
      name: 'backendErrorCouponEmpty',
      desc: '',
      args: [],
    );
  }

  /// `Coupon is invalid`
  String get backendErrorCouponInvalid {
    return Intl.message(
      'Coupon is invalid',
      name: 'backendErrorCouponInvalid',
      desc: '',
      args: [],
    );
  }

  /// `Coupon does not exist`
  String get backendErrorCouponNotFound {
    return Intl.message(
      'Coupon does not exist',
      name: 'backendErrorCouponNotFound',
      desc: '',
      args: [],
    );
  }

  /// `Coupon has expired`
  String get backendErrorCouponExpired {
    return Intl.message(
      'Coupon has expired',
      name: 'backendErrorCouponExpired',
      desc: '',
      args: [],
    );
  }

  /// `Coupon usage limit has been reached`
  String get backendErrorCouponLimitExceeded {
    return Intl.message(
      'Coupon usage limit has been reached',
      name: 'backendErrorCouponLimitExceeded',
      desc: '',
      args: [],
    );
  }

  /// `Order does not exist`
  String get backendErrorOrderNotFound {
    return Intl.message(
      'Order does not exist',
      name: 'backendErrorOrderNotFound',
      desc: '',
      args: [],
    );
  }

  /// `Plan does not exist`
  String get backendErrorPlanNotFound {
    return Intl.message(
      'Plan does not exist',
      name: 'backendErrorPlanNotFound',
      desc: '',
      args: [],
    );
  }

  /// `Ticket does not exist`
  String get backendErrorTicketNotFound {
    return Intl.message(
      'Ticket does not exist',
      name: 'backendErrorTicketNotFound',
      desc: '',
      args: [],
    );
  }

  /// `Ticket is closed`
  String get backendErrorTicketClosed {
    return Intl.message(
      'Ticket is closed',
      name: 'backendErrorTicketClosed',
      desc: '',
      args: [],
    );
  }

  /// `Old password is incorrect`
  String get backendErrorOldPasswordWrong {
    return Intl.message(
      'Old password is incorrect',
      name: 'backendErrorOldPasswordWrong',
      desc: '',
      args: [],
    );
  }

  /// `New password cannot be empty`
  String get backendErrorNewPasswordEmpty {
    return Intl.message(
      'New password cannot be empty',
      name: 'backendErrorNewPasswordEmpty',
      desc: '',
      args: [],
    );
  }

  /// `Reset failed, please try again later`
  String get backendErrorResetFailed {
    return Intl.message(
      'Reset failed, please try again later',
      name: 'backendErrorResetFailed',
      desc: '',
      args: [],
    );
  }

  /// `Too many password errors, please try again later`
  String get backendErrorTooManyPasswordErrorsGeneric {
    return Intl.message(
      'Too many password errors, please try again later',
      name: 'backendErrorTooManyPasswordErrorsGeneric',
      desc: '',
      args: [],
    );
  }

  /// `Too many password errors, please try again after {minute} minutes`
  String backendErrorTooManyPasswordErrors(String minute) {
    return Intl.message(
      'Too many password errors, please try again after $minute minutes',
      name: 'backendErrorTooManyPasswordErrors',
      desc: '',
      args: [minute],
    );
  }

  /// `Too many requests, please try again later`
  String get backendErrorTooManyRequests {
    return Intl.message(
      'Too many requests, please try again later',
      name: 'backendErrorTooManyRequests',
      desc: '',
      args: [],
    );
  }

  /// `The minimum withdrawal commission has not been reached`
  String get backendErrorMinimumWithdrawalCommissionGeneric {
    return Intl.message(
      'The minimum withdrawal commission has not been reached',
      name: 'backendErrorMinimumWithdrawalCommissionGeneric',
      desc: '',
      args: [],
    );
  }

  /// `The minimum withdrawal commission is {limit}`
  String backendErrorMinimumWithdrawalCommission(String limit) {
    return Intl.message(
      'The minimum withdrawal commission is $limit',
      name: 'backendErrorMinimumWithdrawalCommission',
      desc: '',
      args: [limit],
    );
  }

  /// `Login failed`
  String get backendFallbackLoginFailed {
    return Intl.message(
      'Login failed',
      name: 'backendFallbackLoginFailed',
      desc: '',
      args: [],
    );
  }

  /// `Register failed`
  String get backendFallbackRegisterFailed {
    return Intl.message(
      'Register failed',
      name: 'backendFallbackRegisterFailed',
      desc: '',
      args: [],
    );
  }

  /// `Failed to send verification code`
  String get backendFallbackEmailVerifyFailed {
    return Intl.message(
      'Failed to send verification code',
      name: 'backendFallbackEmailVerifyFailed',
      desc: '',
      args: [],
    );
  }

  /// `Transfer failed`
  String get backendFallbackTransferFailed {
    return Intl.message(
      'Transfer failed',
      name: 'backendFallbackTransferFailed',
      desc: '',
      args: [],
    );
  }

  /// `Password operation failed`
  String get backendFallbackPasswordFailed {
    return Intl.message(
      'Password operation failed',
      name: 'backendFallbackPasswordFailed',
      desc: '',
      args: [],
    );
  }

  /// `Coupon check failed`
  String get backendFallbackCouponFailed {
    return Intl.message(
      'Coupon check failed',
      name: 'backendFallbackCouponFailed',
      desc: '',
      args: [],
    );
  }

  /// `Order operation failed`
  String get backendFallbackOrderFailed {
    return Intl.message(
      'Order operation failed',
      name: 'backendFallbackOrderFailed',
      desc: '',
      args: [],
    );
  }

  /// `Ticket operation failed`
  String get backendFallbackTicketFailed {
    return Intl.message(
      'Ticket operation failed',
      name: 'backendFallbackTicketFailed',
      desc: '',
      args: [],
    );
  }

  /// `Operation failed`
  String get backendFallbackOperationFailed {
    return Intl.message(
      'Operation failed',
      name: 'backendFallbackOperationFailed',
      desc: '',
      args: [],
    );
  }

  /// `Device Management`
  String get xboardDeviceManagement {
    return Intl.message(
      'Device Management',
      name: 'xboardDeviceManagement',
      desc: '',
      args: [],
    );
  }

  /// `Join Group`
  String get xboardJoinGroup {
    return Intl.message(
      'Join Group',
      name: 'xboardJoinGroup',
      desc: '',
      args: [],
    );
  }

  /// `Tools Settings`
  String get xboardToolsSettings {
    return Intl.message(
      'Tools Settings',
      name: 'xboardToolsSettings',
      desc: '',
      args: [],
    );
  }

  /// `Contact Customer Service`
  String get xboardContactCustomerService {
    return Intl.message(
      'Contact Customer Service',
      name: 'xboardContactCustomerService',
      desc: '',
      args: [],
    );
  }

  /// `¥{amount}`
  String xboardBalanceWithAmount(Object amount) {
    return Intl.message(
      '¥$amount',
      name: 'xboardBalanceWithAmount',
      desc: '',
      args: [amount],
    );
  }

  /// `Group link not configured`
  String get xboardGroupLinkNotConfigured {
    return Intl.message(
      'Group link not configured',
      name: 'xboardGroupLinkNotConfigured',
      desc: '',
      args: [],
    );
  }

  /// `Failed to get group link`
  String get xboardGetGroupLinkFailed {
    return Intl.message(
      'Failed to get group link',
      name: 'xboardGetGroupLinkFailed',
      desc: '',
      args: [],
    );
  }

  /// `Gift Card Code`
  String get xboardGiftCardCodeLabel {
    return Intl.message(
      'Gift Card Code',
      name: 'xboardGiftCardCodeLabel',
      desc: '',
      args: [],
    );
  }

  /// `Enter gift card redemption code`
  String get xboardEnterGiftCardCodeHint {
    return Intl.message(
      'Enter gift card redemption code',
      name: 'xboardEnterGiftCardCodeHint',
      desc: '',
      args: [],
    );
  }

  /// `Please enter gift card code`
  String get xboardPleaseEnterGiftCardCode {
    return Intl.message(
      'Please enter gift card code',
      name: 'xboardPleaseEnterGiftCardCode',
      desc: '',
      args: [],
    );
  }

  /// `Redeem successful`
  String get xboardRedeemSuccess {
    return Intl.message(
      'Redeem successful',
      name: 'xboardRedeemSuccess',
      desc: '',
      args: [],
    );
  }

  /// `Redeem failed`
  String get xboardRedeemFailed {
    return Intl.message(
      'Redeem failed',
      name: 'xboardRedeemFailed',
      desc: '',
      args: [],
    );
  }

  /// `Redeem failed: {error}`
  String xboardRedeemFailedWithError(Object error) {
    return Intl.message(
      'Redeem failed: $error',
      name: 'xboardRedeemFailedWithError',
      desc: '',
      args: [error],
    );
  }

  /// `Redeem failed: this gift card has already been used by this user`
  String get xboardGiftCardAlreadyUsedByUser {
    return Intl.message(
      'Redeem failed: this gift card has already been used by this user',
      name: 'xboardGiftCardAlreadyUsedByUser',
      desc: '',
      args: [],
    );
  }

  /// `Redeem failed: this gift card does not exist`
  String get xboardGiftCardNotFound {
    return Intl.message(
      'Redeem failed: this gift card does not exist',
      name: 'xboardGiftCardNotFound',
      desc: '',
      args: [],
    );
  }

  /// `Redeem successful: user information has been refreshed automatically`
  String get xboardGiftCardRedeemSuccessRefreshed {
    return Intl.message(
      'Redeem successful: user information has been refreshed automatically',
      name: 'xboardGiftCardRedeemSuccessRefreshed',
      desc: '',
      args: [],
    );
  }

  /// `Copy Invite Code`
  String get xboardCopyInviteCode {
    return Intl.message(
      'Copy Invite Code',
      name: 'xboardCopyInviteCode',
      desc: '',
      args: [],
    );
  }

  /// `Copy Link`
  String get xboardCopyInviteLink {
    return Intl.message(
      'Copy Link',
      name: 'xboardCopyInviteLink',
      desc: '',
      args: [],
    );
  }

  /// `Gift Card Redeem`
  String get xboardGiftCardRedeemTitle {
    return Intl.message(
      'Gift Card Redeem',
      name: 'xboardGiftCardRedeemTitle',
      desc: '',
      args: [],
    );
  }

  /// `Device removed`
  String get xboardDeviceRemoved {
    return Intl.message(
      'Device removed',
      name: 'xboardDeviceRemoved',
      desc: '',
      args: [],
    );
  }

  /// `Online`
  String get xboardDeviceOnline {
    return Intl.message(
      'Online',
      name: 'xboardDeviceOnline',
      desc: '',
      args: [],
    );
  }

  /// `Offline`
  String get xboardDeviceOffline {
    return Intl.message(
      'Offline',
      name: 'xboardDeviceOffline',
      desc: '',
      args: [],
    );
  }

  /// `Removed`
  String get xboardDeviceRevoked {
    return Intl.message(
      'Removed',
      name: 'xboardDeviceRevoked',
      desc: '',
      args: [],
    );
  }

  /// `Expired`
  String get xboardDeviceExpired {
    return Intl.message(
      'Expired',
      name: 'xboardDeviceExpired',
      desc: '',
      args: [],
    );
  }

  /// `Unknown`
  String get xboardDeviceUnknown {
    return Intl.message(
      'Unknown',
      name: 'xboardDeviceUnknown',
      desc: '',
      args: [],
    );
  }

  /// `Current device`
  String get xboardDeviceCurrentDeviceLabel {
    return Intl.message(
      'Current device',
      name: 'xboardDeviceCurrentDeviceLabel',
      desc: '',
      args: [],
    );
  }

  /// `History`
  String get xboardDeviceHistory {
    return Intl.message(
      'History',
      name: 'xboardDeviceHistory',
      desc: '',
      args: [],
    );
  }

  /// `Only removal records within 90 days are kept. Older records will be automatically cleaned up.`
  String get xboardDeviceHistoryHint {
    return Intl.message(
      'Only removal records within 90 days are kept. Older records will be automatically cleaned up.',
      name: 'xboardDeviceHistoryHint',
      desc: '',
      args: [],
    );
  }

  /// `Devices offline for more than 30 days will be automatically removed.`
  String get xboardDeviceAutoOfflineHint {
    return Intl.message(
      'Devices offline for more than 30 days will be automatically removed.',
      name: 'xboardDeviceAutoOfflineHint',
      desc: '',
      args: [],
    );
  }

  /// `Unlimited`
  String get xboardDeviceUnlimited {
    return Intl.message(
      'Unlimited',
      name: 'xboardDeviceUnlimited',
      desc: '',
      args: [],
    );
  }

  /// `No device records`
  String get xboardDeviceNoRecords {
    return Intl.message(
      'No device records',
      name: 'xboardDeviceNoRecords',
      desc: '',
      args: [],
    );
  }

  /// `Devices you've signed in with will appear here for easy management.`
  String get xboardDeviceNoRecordsHint {
    return Intl.message(
      'Devices you\'ve signed in with will appear here for easy management.',
      name: 'xboardDeviceNoRecordsHint',
      desc: '',
      args: [],
    );
  }

  /// `Device ID`
  String get xboardDeviceLabelId {
    return Intl.message(
      'Device ID',
      name: 'xboardDeviceLabelId',
      desc: '',
      args: [],
    );
  }

  /// `OS Version`
  String get xboardDeviceLabelOsVersion {
    return Intl.message(
      'OS Version',
      name: 'xboardDeviceLabelOsVersion',
      desc: '',
      args: [],
    );
  }

  /// `Last IP`
  String get xboardDeviceLabelLastIp {
    return Intl.message(
      'Last IP',
      name: 'xboardDeviceLabelLastIp',
      desc: '',
      args: [],
    );
  }

  /// `Location`
  String get xboardDeviceLabelRegion {
    return Intl.message(
      'Location',
      name: 'xboardDeviceLabelRegion',
      desc: '',
      args: [],
    );
  }

  /// `Revoked at`
  String get xboardDeviceLabelRevokedAt {
    return Intl.message(
      'Revoked at',
      name: 'xboardDeviceLabelRevokedAt',
      desc: '',
      args: [],
    );
  }

  /// `Revoked by`
  String get xboardDeviceLabelRevokedBy {
    return Intl.message(
      'Revoked by',
      name: 'xboardDeviceLabelRevokedBy',
      desc: '',
      args: [],
    );
  }

  /// `Last online`
  String get xboardDeviceLabelLastOnline {
    return Intl.message(
      'Last online',
      name: 'xboardDeviceLabelLastOnline',
      desc: '',
      args: [],
    );
  }

  /// `Unknown version`
  String get xboardDeviceUnknownVersion {
    return Intl.message(
      'Unknown version',
      name: 'xboardDeviceUnknownVersion',
      desc: '',
      args: [],
    );
  }

  /// `Remove device`
  String get xboardDeviceRemoveTitle {
    return Intl.message(
      'Remove device',
      name: 'xboardDeviceRemoveTitle',
      desc: '',
      args: [],
    );
  }

  /// `This is your current device. Removing it will log you out immediately.`
  String get xboardDeviceRemoveCurrentConfirm {
    return Intl.message(
      'This is your current device. Removing it will log you out immediately.',
      name: 'xboardDeviceRemoveCurrentConfirm',
      desc: '',
      args: [],
    );
  }

  /// `{count} active · Limit {limit}`
  String xboardDeviceSummary(Object count, Object limit) {
    return Intl.message(
      '$count active · Limit $limit',
      name: 'xboardDeviceSummary',
      desc: '',
      args: [count, limit],
    );
  }

  /// `Connection Health`
  String get xboardConnectionHealth {
    return Intl.message(
      'Connection Health',
      name: 'xboardConnectionHealth',
      desc: '',
      args: [],
    );
  }

  /// `Check server, subscription, node, and device status`
  String get xboardConnectionHealthSubtitle {
    return Intl.message(
      'Check server, subscription, node, and device status',
      name: 'xboardConnectionHealthSubtitle',
      desc: '',
      args: [],
    );
  }

  /// `Server status`
  String get xboardServerStatus {
    return Intl.message(
      'Server status',
      name: 'xboardServerStatus',
      desc: '',
      args: [],
    );
  }

  /// `Gateway status`
  String get xboardGatewayStatus {
    return Intl.message(
      'Gateway status',
      name: 'xboardGatewayStatus',
      desc: '',
      args: [],
    );
  }

  /// `Subscription status`
  String get xboardSubscriptionHealth {
    return Intl.message(
      'Subscription status',
      name: 'xboardSubscriptionHealth',
      desc: '',
      args: [],
    );
  }

  /// `Node status`
  String get xboardNodeHealth {
    return Intl.message(
      'Node status',
      name: 'xboardNodeHealth',
      desc: '',
      args: [],
    );
  }

  /// `Device status`
  String get xboardDeviceHealth {
    return Intl.message(
      'Device status',
      name: 'xboardDeviceHealth',
      desc: '',
      args: [],
    );
  }

  /// `Healthy`
  String get xboardHealthy {
    return Intl.message('Healthy', name: 'xboardHealthy', desc: '', args: []);
  }

  /// `Needs attention`
  String get xboardNeedsAttention {
    return Intl.message(
      'Needs attention',
      name: 'xboardNeedsAttention',
      desc: '',
      args: [],
    );
  }

  /// `Current gateway`
  String get xboardCurrentGateway {
    return Intl.message(
      'Current gateway',
      name: 'xboardCurrentGateway',
      desc: '',
      args: [],
    );
  }

  /// `Current business API`
  String get xboardCurrentBusinessApi {
    return Intl.message(
      'Current business API',
      name: 'xboardCurrentBusinessApi',
      desc: '',
      args: [],
    );
  }

  /// `{count} candidates`
  String xboardGatewayCandidateCount(Object count) {
    return Intl.message(
      '$count candidates',
      name: 'xboardGatewayCandidateCount',
      desc: '',
      args: [count],
    );
  }

  /// `{healthy}/{total} available`
  String xboardServiceAvailableCount(Object healthy, Object total) {
    return Intl.message(
      '$healthy/$total available',
      name: 'xboardServiceAvailableCount',
      desc: '',
      args: [healthy, total],
    );
  }

  /// `Checking all endpoints`
  String get xboardServiceCheckingEndpoints {
    return Intl.message(
      'Checking all endpoints',
      name: 'xboardServiceCheckingEndpoints',
      desc: '',
      args: [],
    );
  }

  /// `Detailed status is temporarily unavailable`
  String get xboardServiceStatusUnavailable {
    return Intl.message(
      'Detailed status is temporarily unavailable',
      name: 'xboardServiceStatusUnavailable',
      desc: '',
      args: [],
    );
  }

  /// `This gateway version does not support detailed checks`
  String get xboardServiceStatusUnsupported {
    return Intl.message(
      'This gateway version does not support detailed checks',
      name: 'xboardServiceStatusUnsupported',
      desc: '',
      args: [],
    );
  }

  /// `In use`
  String get xboardServiceInUse {
    return Intl.message(
      'In use',
      name: 'xboardServiceInUse',
      desc: '',
      args: [],
    );
  }

  /// `Primary`
  String get xboardServicePrimary {
    return Intl.message(
      'Primary',
      name: 'xboardServicePrimary',
      desc: '',
      args: [],
    );
  }

  /// `Backup {index}`
  String xboardServiceBackup(Object index) {
    return Intl.message(
      'Backup $index',
      name: 'xboardServiceBackup',
      desc: '',
      args: [index],
    );
  }

  /// `Business API {index}`
  String xboardBusinessApiLabel(Object index) {
    return Intl.message(
      'Business API $index',
      name: 'xboardBusinessApiLabel',
      desc: '',
      args: [index],
    );
  }

  /// `Gateway API {index}`
  String xboardGatewayApiLabel(Object index) {
    return Intl.message(
      'Gateway API $index',
      name: 'xboardGatewayApiLabel',
      desc: '',
      args: [index],
    );
  }

  /// `Healthy`
  String get xboardServiceStateHealthy {
    return Intl.message(
      'Healthy',
      name: 'xboardServiceStateHealthy',
      desc: '',
      args: [],
    );
  }

  /// `Confirming recovery`
  String get xboardServiceStateRecovering {
    return Intl.message(
      'Confirming recovery',
      name: 'xboardServiceStateRecovering',
      desc: '',
      args: [],
    );
  }

  /// `Circuit open`
  String get xboardServiceStateCircuitOpen {
    return Intl.message(
      'Circuit open',
      name: 'xboardServiceStateCircuitOpen',
      desc: '',
      args: [],
    );
  }

  /// `Connection timed out`
  String get xboardServiceStateTimeout {
    return Intl.message(
      'Connection timed out',
      name: 'xboardServiceStateTimeout',
      desc: '',
      args: [],
    );
  }

  /// `Service error`
  String get xboardServiceStateServerError {
    return Intl.message(
      'Service error',
      name: 'xboardServiceStateServerError',
      desc: '',
      args: [],
    );
  }

  /// `Unreachable`
  String get xboardServiceStateUnreachable {
    return Intl.message(
      'Unreachable',
      name: 'xboardServiceStateUnreachable',
      desc: '',
      args: [],
    );
  }

  /// `Unavailable`
  String get xboardServiceStateUnavailable {
    return Intl.message(
      'Unavailable',
      name: 'xboardServiceStateUnavailable',
      desc: '',
      args: [],
    );
  }

  /// `Not checked`
  String get xboardServiceStateUnknown {
    return Intl.message(
      'Not checked',
      name: 'xboardServiceStateUnknown',
      desc: '',
      args: [],
    );
  }

  /// `{latency}ms`
  String xboardServiceLatency(Object latency) {
    return Intl.message(
      '${latency}ms',
      name: 'xboardServiceLatency',
      desc: '',
      args: [latency],
    );
  }

  /// `Recovery {current}/{required}`
  String xboardServiceRecoveryProgress(Object current, Object required) {
    return Intl.message(
      'Recovery $current/$required',
      name: 'xboardServiceRecoveryProgress',
      desc: '',
      args: [current, required],
    );
  }

  /// `Retry check in {seconds}s`
  String xboardServiceCircuitRemaining(Object seconds) {
    return Intl.message(
      'Retry check in ${seconds}s',
      name: 'xboardServiceCircuitRemaining',
      desc: '',
      args: [seconds],
    );
  }

  /// `Status source`
  String get xboardServiceStatusSource {
    return Intl.message(
      'Status source',
      name: 'xboardServiceStatusSource',
      desc: '',
      args: [],
    );
  }

  /// `Checked at`
  String get xboardServiceCheckedAt {
    return Intl.message(
      'Checked at',
      name: 'xboardServiceCheckedAt',
      desc: '',
      args: [],
    );
  }

  /// `No active gateway`
  String get xboardNoGatewayActive {
    return Intl.message(
      'No active gateway',
      name: 'xboardNoGatewayActive',
      desc: '',
      args: [],
    );
  }

  /// `Current domain`
  String get xboardCurrentDomain {
    return Intl.message(
      'Current domain',
      name: 'xboardCurrentDomain',
      desc: '',
      args: [],
    );
  }

  /// `{count} nodes`
  String xboardNodeCount(Object count) {
    return Intl.message(
      '$count nodes',
      name: 'xboardNodeCount',
      desc: '',
      args: [count],
    );
  }

  /// `Run check`
  String get xboardRunDiagnosis {
    return Intl.message(
      'Run check',
      name: 'xboardRunDiagnosis',
      desc: '',
      args: [],
    );
  }

  /// `Test current node`
  String get xboardTestCurrentNode {
    return Intl.message(
      'Test current node',
      name: 'xboardTestCurrentNode',
      desc: '',
      args: [],
    );
  }

  /// `Manage devices`
  String get xboardManageDevices {
    return Intl.message(
      'Manage devices',
      name: 'xboardManageDevices',
      desc: '',
      args: [],
    );
  }

  /// `View orders`
  String get xboardCheckOrders {
    return Intl.message(
      'View orders',
      name: 'xboardCheckOrders',
      desc: '',
      args: [],
    );
  }

  /// `Smart latency test started`
  String get xboardSmartLatencyStarted {
    return Intl.message(
      'Smart latency test started',
      name: 'xboardSmartLatencyStarted',
      desc: '',
      args: [],
    );
  }

  /// `If you paid but it has not arrived, refresh the order status.`
  String get xboardPendingOrdersHint {
    return Intl.message(
      'If you paid but it has not arrived, refresh the order status.',
      name: 'xboardPendingOrdersHint',
      desc: '',
      args: [],
    );
  }

  /// `Syncing account subscription...`
  String get xboardSyncingSubscription {
    return Intl.message(
      'Syncing account subscription...',
      name: 'xboardSyncingSubscription',
      desc: '',
      args: [],
    );
  }

  /// `Buy plan`
  String get xboardBuyPlan {
    return Intl.message('Buy plan', name: 'xboardBuyPlan', desc: '', args: []);
  }

  /// `Latest event`
  String get xboardHealthLastEvent {
    return Intl.message(
      'Latest event',
      name: 'xboardHealthLastEvent',
      desc: '',
      args: [],
    );
  }

  /// `Copy diagnostics`
  String get xboardCopyDiagnosticBundle {
    return Intl.message(
      'Copy diagnostics',
      name: 'xboardCopyDiagnosticBundle',
      desc: '',
      args: [],
    );
  }

  /// `Diagnostics copied`
  String get xboardDiagnosticBundleCopied {
    return Intl.message(
      'Diagnostics copied',
      name: 'xboardDiagnosticBundleCopied',
      desc: '',
      args: [],
    );
  }

  /// `Checking helper`
  String get xboardCoreStageCheckingHelper {
    return Intl.message(
      'Checking helper',
      name: 'xboardCoreStageCheckingHelper',
      desc: '',
      args: [],
    );
  }

  /// `Starting service`
  String get xboardCoreStageStartingService {
    return Intl.message(
      'Starting service',
      name: 'xboardCoreStageStartingService',
      desc: '',
      args: [],
    );
  }

  /// `Helper reused`
  String get xboardCoreStageHelperReady {
    return Intl.message(
      'Helper reused',
      name: 'xboardCoreStageHelperReady',
      desc: '',
      args: [],
    );
  }

  /// `Reconnecting core`
  String get xboardCoreStageCoreConnecting {
    return Intl.message(
      'Reconnecting core',
      name: 'xboardCoreStageCoreConnecting',
      desc: '',
      args: [],
    );
  }

  /// `Applying TUN`
  String get xboardCoreStageTunApplying {
    return Intl.message(
      'Applying TUN',
      name: 'xboardCoreStageTunApplying',
      desc: '',
      args: [],
    );
  }

  /// `Connected`
  String get xboardCoreStageConnected {
    return Intl.message(
      'Connected',
      name: 'xboardCoreStageConnected',
      desc: '',
      args: [],
    );
  }

  /// `Disconnecting`
  String get xboardCoreStageStopping {
    return Intl.message(
      'Disconnecting',
      name: 'xboardCoreStageStopping',
      desc: '',
      args: [],
    );
  }

  /// `Connection failed`
  String get xboardCoreStageFailed {
    return Intl.message(
      'Connection failed',
      name: 'xboardCoreStageFailed',
      desc: '',
      args: [],
    );
  }

  /// `Checking subscription`
  String get xboardCheckingSubscription {
    return Intl.message(
      'Checking subscription',
      name: 'xboardCheckingSubscription',
      desc: '',
      args: [],
    );
  }

  /// `Connecting`
  String get xboardConnecting {
    return Intl.message(
      'Connecting',
      name: 'xboardConnecting',
      desc: '',
      args: [],
    );
  }

  /// `Disconnecting`
  String get xboardDisconnecting {
    return Intl.message(
      'Disconnecting',
      name: 'xboardDisconnecting',
      desc: '',
      args: [],
    );
  }

  /// `Subscription import: {message}`
  String xboardHealthSubscriptionImport(String message) {
    return Intl.message(
      'Subscription import: $message',
      name: 'xboardHealthSubscriptionImport',
      desc: '',
      args: [message],
    );
  }

  /// `Running`
  String get xboardHealthCoreRunning {
    return Intl.message(
      'Running',
      name: 'xboardHealthCoreRunning',
      desc: '',
      args: [],
    );
  }

  /// `Applied`
  String get xboardHealthTunApplied {
    return Intl.message(
      'Applied',
      name: 'xboardHealthTunApplied',
      desc: '',
      args: [],
    );
  }

  /// `Waiting to apply`
  String get xboardHealthTunPending {
    return Intl.message(
      'Waiting to apply',
      name: 'xboardHealthTunPending',
      desc: '',
      args: [],
    );
  }

  /// `Enabled`
  String get xboardHealthEnabled {
    return Intl.message(
      'Enabled',
      name: 'xboardHealthEnabled',
      desc: '',
      args: [],
    );
  }

  /// `Disabled`
  String get xboardHealthDisabled {
    return Intl.message(
      'Disabled',
      name: 'xboardHealthDisabled',
      desc: '',
      args: [],
    );
  }

  /// `DNS`
  String get xboardHealthDns {
    return Intl.message('DNS', name: 'xboardHealthDns', desc: '', args: []);
  }

  /// `Using custom DNS`
  String get xboardHealthDnsCustom {
    return Intl.message(
      'Using custom DNS',
      name: 'xboardHealthDnsCustom',
      desc: '',
      args: [],
    );
  }

  /// `Using default DNS`
  String get xboardHealthDnsDefault {
    return Intl.message(
      'Using default DNS',
      name: 'xboardHealthDnsDefault',
      desc: '',
      args: [],
    );
  }

  /// `One-click repair`
  String get xboardOneClickRepair {
    return Intl.message(
      'One-click repair',
      name: 'xboardOneClickRepair',
      desc: '',
      args: [],
    );
  }

  /// `Repair completed`
  String get xboardRepairCompleted {
    return Intl.message(
      'Repair completed',
      name: 'xboardRepairCompleted',
      desc: '',
      args: [],
    );
  }

  /// `Helper`
  String get xboardHealthHelper {
    return Intl.message(
      'Helper',
      name: 'xboardHealthHelper',
      desc: '',
      args: [],
    );
  }

  /// `Windows helper is not required on this platform`
  String get xboardHealthHelperNotRequired {
    return Intl.message(
      'Windows helper is not required on this platform',
      name: 'xboardHealthHelperNotRequired',
      desc: '',
      args: [],
    );
  }

  /// `Available`
  String get xboardHealthHelperAvailable {
    return Intl.message(
      'Available',
      name: 'xboardHealthHelperAvailable',
      desc: '',
      args: [],
    );
  }

  /// `Unavailable`
  String get xboardHealthHelperUnavailable {
    return Intl.message(
      'Unavailable',
      name: 'xboardHealthHelperUnavailable',
      desc: '',
      args: [],
    );
  }

  /// `Helper HTTP is not responding`
  String get xboardHealthHelperNoResponse {
    return Intl.message(
      'Helper HTTP is not responding',
      name: 'xboardHealthHelperNoResponse',
      desc: '',
      args: [],
    );
  }

  /// `Checking`
  String get xboardHealthHelperChecking {
    return Intl.message(
      'Checking',
      name: 'xboardHealthHelperChecking',
      desc: '',
      args: [],
    );
  }

  /// `Check failed`
  String get xboardHealthHelperCheckFailed {
    return Intl.message(
      'Check failed',
      name: 'xboardHealthHelperCheckFailed',
      desc: '',
      args: [],
    );
  }

  /// `Release offline devices`
  String get xboardReleaseOfflineDevices {
    return Intl.message(
      'Release offline devices',
      name: 'xboardReleaseOfflineDevices',
      desc: '',
      args: [],
    );
  }

  /// `This will remove offline devices that still occupy your device limit. Your current device will not be affected. Continue?`
  String get xboardReleaseOfflineDevicesConfirm {
    return Intl.message(
      'This will remove offline devices that still occupy your device limit. Your current device will not be affected. Continue?',
      name: 'xboardReleaseOfflineDevicesConfirm',
      desc: '',
      args: [],
    );
  }

  /// `Offline, using slot`
  String get xboardOfflineButActive {
    return Intl.message(
      'Offline, using slot',
      name: 'xboardOfflineButActive',
      desc: '',
      args: [],
    );
  }

  /// `Reload nodes`
  String get xboardReloadNodes {
    return Intl.message(
      'Reload nodes',
      name: 'xboardReloadNodes',
      desc: '',
      args: [],
    );
  }

  /// `Got it`
  String get xboardGotIt {
    return Intl.message('Got it', name: 'xboardGotIt', desc: '', args: []);
  }

  /// `{count} devices`
  String xboardDeviceUnit(Object count) {
    return Intl.message(
      '$count devices',
      name: 'xboardDeviceUnit',
      desc: '',
      args: [count],
    );
  }

  /// `Service is temporarily unavailable, please try again later.`
  String get xboardLoginErrorNetwork {
    return Intl.message(
      'Service is temporarily unavailable, please try again later.',
      name: 'xboardLoginErrorNetwork',
      desc: '',
      args: [],
    );
  }

  /// `Configuration load failed, please try again later`
  String get xboardLoginErrorConfigLoad {
    return Intl.message(
      'Configuration load failed, please try again later',
      name: 'xboardLoginErrorConfigLoad',
      desc: '',
      args: [],
    );
  }

  /// `Invalid credentials, please check your account and password`
  String get xboardLoginErrorCredentials {
    return Intl.message(
      'Invalid credentials, please check your account and password',
      name: 'xboardLoginErrorCredentials',
      desc: '',
      args: [],
    );
  }

  /// `Too many login attempts. Please try again later.`
  String get xboardLoginErrorLimited {
    return Intl.message(
      'Too many login attempts. Please try again later.',
      name: 'xboardLoginErrorLimited',
      desc: '',
      args: [],
    );
  }

  /// `Device limit reached. Release an offline device first.`
  String get xboardLoginErrorDeviceLimit {
    return Intl.message(
      'Device limit reached. Release an offline device first.',
      name: 'xboardLoginErrorDeviceLimit',
      desc: '',
      args: [],
    );
  }

  /// `Subscription updated`
  String get subscriptionUpdateSuccess {
    return Intl.message(
      'Subscription updated',
      name: 'subscriptionUpdateSuccess',
      desc: '',
      args: [],
    );
  }

  /// `Subscription imported`
  String get subscriptionImportSuccess {
    return Intl.message(
      'Subscription imported',
      name: 'subscriptionImportSuccess',
      desc: '',
      args: [],
    );
  }

  /// `Invite code generated`
  String get inviteCodeGenerated {
    return Intl.message(
      'Invite code generated',
      name: 'inviteCodeGenerated',
      desc: '',
      args: [],
    );
  }

  /// `Maximum number of invites reached`
  String get backendErrorInviteLimitReached {
    return Intl.message(
      'Maximum number of invites reached',
      name: 'backendErrorInviteLimitReached',
      desc: '',
      args: [],
    );
  }

  /// `Subscription update failed`
  String get subscriptionUpdateFailed {
    return Intl.message(
      'Subscription update failed',
      name: 'subscriptionUpdateFailed',
      desc: '',
      args: [],
    );
  }

  /// `Subscription import failed`
  String get subscriptionImportFailed {
    return Intl.message(
      'Subscription import failed',
      name: 'subscriptionImportFailed',
      desc: '',
      args: [],
    );
  }

  /// `Subscription refresh failed, please refresh manually later`
  String get xboardRefreshFailedHint {
    return Intl.message(
      'Subscription refresh failed, please refresh manually later',
      name: 'xboardRefreshFailedHint',
      desc: '',
      args: [],
    );
  }

  /// `Customer service page is loading slowly, please wait...`
  String get customerServiceLoadingSlow {
    return Intl.message(
      'Customer service page is loading slowly, please wait...',
      name: 'customerServiceLoadingSlow',
      desc: '',
      args: [],
    );
  }

  /// `Customer service page failed to load, please try again later`
  String get customerServiceLoadFailed {
    return Intl.message(
      'Customer service page failed to load, please try again later',
      name: 'customerServiceLoadFailed',
      desc: '',
      args: [],
    );
  }

  /// `Clear cache and restart`
  String get clearCacheAndRestart {
    return Intl.message(
      'Clear cache and restart',
      name: 'clearCacheAndRestart',
      desc: '',
      args: [],
    );
  }

  /// `Diagnostics center`
  String get xboardDiagnosticsCenter {
    return Intl.message(
      'Diagnostics center',
      name: 'xboardDiagnosticsCenter',
      desc: '',
      args: [],
    );
  }

  /// `Check service status, proxy configuration, and network connectivity`
  String get xboardDiagnosticsCenterSubtitle {
    return Intl.message(
      'Check service status, proxy configuration, and network connectivity',
      name: 'xboardDiagnosticsCenterSubtitle',
      desc: '',
      args: [],
    );
  }

  /// `Service status`
  String get xboardDiagnosticServiceStatus {
    return Intl.message(
      'Service status',
      name: 'xboardDiagnosticServiceStatus',
      desc: '',
      args: [],
    );
  }

  /// `Network connectivity`
  String get xboardDiagnosticNetworkConnectivity {
    return Intl.message(
      'Network connectivity',
      name: 'xboardDiagnosticNetworkConnectivity',
      desc: '',
      args: [],
    );
  }

  /// `Business services`
  String get xboardDiagnosticBusinessServices {
    return Intl.message(
      'Business services',
      name: 'xboardDiagnosticBusinessServices',
      desc: '',
      args: [],
    );
  }

  /// `Proxy and system`
  String get xboardDiagnosticProxyAndSystem {
    return Intl.message(
      'Proxy and system',
      name: 'xboardDiagnosticProxyAndSystem',
      desc: '',
      args: [],
    );
  }

  /// `Network diagnostics`
  String get xboardNetworkDiagnostics {
    return Intl.message(
      'Network diagnostics',
      name: 'xboardNetworkDiagnostics',
      desc: '',
      args: [],
    );
  }

  /// `Check VPN status, DNS resolution, and HTTPS reachability`
  String get xboardNetworkDiagnosticsSubtitle {
    return Intl.message(
      'Check VPN status, DNS resolution, and HTTPS reachability',
      name: 'xboardNetworkDiagnosticsSubtitle',
      desc: '',
      args: [],
    );
  }

  /// `Test domain`
  String get xboardNetworkDiagnosticsTestDomain {
    return Intl.message(
      'Test domain',
      name: 'xboardNetworkDiagnosticsTestDomain',
      desc: '',
      args: [],
    );
  }

  /// `Start diagnostics`
  String get xboardNetworkDiagnosticsStart {
    return Intl.message(
      'Start diagnostics',
      name: 'xboardNetworkDiagnosticsStart',
      desc: '',
      args: [],
    );
  }

  /// `Diagnosing...`
  String get xboardNetworkDiagnosticsRunning {
    return Intl.message(
      'Diagnosing...',
      name: 'xboardNetworkDiagnosticsRunning',
      desc: '',
      args: [],
    );
  }

  /// `Copy report`
  String get xboardNetworkDiagnosticsCopyReport {
    return Intl.message(
      'Copy report',
      name: 'xboardNetworkDiagnosticsCopyReport',
      desc: '',
      args: [],
    );
  }

  /// `Connect the VPN before running network diagnostics.`
  String get xboardNetworkDiagnosticsConnectFirst {
    return Intl.message(
      'Connect the VPN before running network diagnostics.',
      name: 'xboardNetworkDiagnosticsConnectFirst',
      desc: '',
      args: [],
    );
  }

  /// `The VPN disconnected. Network diagnostics stopped and the current results were cleared.`
  String get xboardNetworkDiagnosticsDisconnectedInvalidated {
    return Intl.message(
      'The VPN disconnected. Network diagnostics stopped and the current results were cleared.',
      name: 'xboardNetworkDiagnosticsDisconnectedInvalidated',
      desc: '',
      args: [],
    );
  }

  /// `Xiaomi 204`
  String get xboardNetworkDiagnosticsTargetXiaomi204 {
    return Intl.message(
      'Xiaomi 204',
      name: 'xboardNetworkDiagnosticsTargetXiaomi204',
      desc: '',
      args: [],
    );
  }

  /// `vivo 204`
  String get xboardNetworkDiagnosticsTargetVivo204 {
    return Intl.message(
      'vivo 204',
      name: 'xboardNetworkDiagnosticsTargetVivo204',
      desc: '',
      args: [],
    );
  }

  /// `Huawei 204`
  String get xboardNetworkDiagnosticsTargetHuawei204 {
    return Intl.message(
      'Huawei 204',
      name: 'xboardNetworkDiagnosticsTargetHuawei204',
      desc: '',
      args: [],
    );
  }

  /// `VPN status`
  String get xboardNetworkDiagnosticsVpnStatus {
    return Intl.message(
      'VPN status',
      name: 'xboardNetworkDiagnosticsVpnStatus',
      desc: '',
      args: [],
    );
  }

  /// `Connected`
  String get xboardNetworkDiagnosticsConnected {
    return Intl.message(
      'Connected',
      name: 'xboardNetworkDiagnosticsConnected',
      desc: '',
      args: [],
    );
  }

  /// `Disconnected`
  String get xboardNetworkDiagnosticsDisconnected {
    return Intl.message(
      'Disconnected',
      name: 'xboardNetworkDiagnosticsDisconnected',
      desc: '',
      args: [],
    );
  }

  /// `Running time`
  String get xboardNetworkDiagnosticsRunningTime {
    return Intl.message(
      'Running time',
      name: 'xboardNetworkDiagnosticsRunningTime',
      desc: '',
      args: [],
    );
  }

  /// `DNS resolution`
  String get xboardNetworkDiagnosticsDns {
    return Intl.message(
      'DNS resolution',
      name: 'xboardNetworkDiagnosticsDns',
      desc: '',
      args: [],
    );
  }

  /// `HTTPS reachability`
  String get xboardNetworkDiagnosticsHttps {
    return Intl.message(
      'HTTPS reachability',
      name: 'xboardNetworkDiagnosticsHttps',
      desc: '',
      args: [],
    );
  }

  /// `Empty result`
  String get xboardNetworkDiagnosticsEmptyResult {
    return Intl.message(
      'Empty result',
      name: 'xboardNetworkDiagnosticsEmptyResult',
      desc: '',
      args: [],
    );
  }

  /// `Possible DNS pollution: private or reserved address`
  String get xboardNetworkDiagnosticsSuspiciousAddress {
    return Intl.message(
      'Possible DNS pollution: private or reserved address',
      name: 'xboardNetworkDiagnosticsSuspiciousAddress',
      desc: '',
      args: [],
    );
  }

  /// `Timed out`
  String get xboardNetworkDiagnosticsTimeout {
    return Intl.message(
      'Timed out',
      name: 'xboardNetworkDiagnosticsTimeout',
      desc: '',
      args: [],
    );
  }

  /// `FastCat network diagnostics report`
  String get xboardNetworkDiagnosticsReportTitle {
    return Intl.message(
      'FastCat network diagnostics report',
      name: 'xboardNetworkDiagnosticsReportTitle',
      desc: '',
      args: [],
    );
  }

  /// `Time`
  String get xboardNetworkDiagnosticsTime {
    return Intl.message(
      'Time',
      name: 'xboardNetworkDiagnosticsTime',
      desc: '',
      args: [],
    );
  }

  /// `Domain`
  String get xboardNetworkDiagnosticsDomain {
    return Intl.message(
      'Domain',
      name: 'xboardNetworkDiagnosticsDomain',
      desc: '',
      args: [],
    );
  }

  /// `Diagnostics report copied`
  String get xboardNetworkDiagnosticsCopied {
    return Intl.message(
      'Diagnostics report copied',
      name: 'xboardNetworkDiagnosticsCopied',
      desc: '',
      args: [],
    );
  }

  /// `DNS checks use the system resolver. Node diagnostics then check the actual endpoint DNS, TCP or UDP transport, proxy handshake, and HTTP reachability.`
  String get xboardNetworkDiagnosticsDescription {
    return Intl.message(
      'DNS checks use the system resolver. Node diagnostics then check the actual endpoint DNS, TCP or UDP transport, proxy handshake, and HTTP reachability.',
      name: 'xboardNetworkDiagnosticsDescription',
      desc: '',
      args: [],
    );
  }

  /// `Expected fake-IP result`
  String get xboardNetworkDiagnosticsExpectedFakeIp {
    return Intl.message(
      'Expected fake-IP result',
      name: 'xboardNetworkDiagnosticsExpectedFakeIp',
      desc: '',
      args: [],
    );
  }

  /// `Via current node`
  String get xboardNetworkDiagnosticsViaNode {
    return Intl.message(
      'Via current node',
      name: 'xboardNetworkDiagnosticsViaNode',
      desc: '',
      args: [],
    );
  }

  /// `Not available`
  String get xboardNetworkDiagnosticsUnavailable {
    return Intl.message(
      'Not available',
      name: 'xboardNetworkDiagnosticsUnavailable',
      desc: '',
      args: [],
    );
  }

  /// `Reachable`
  String get xboardNetworkDiagnosticsReachable {
    return Intl.message(
      'Reachable',
      name: 'xboardNetworkDiagnosticsReachable',
      desc: '',
      args: [],
    );
  }

  /// `Unreachable`
  String get xboardNetworkDiagnosticsUnreachable {
    return Intl.message(
      'Unreachable',
      name: 'xboardNetworkDiagnosticsUnreachable',
      desc: '',
      args: [],
    );
  }

  /// `Current node`
  String get xboardNetworkDiagnosticsNode {
    return Intl.message(
      'Current node',
      name: 'xboardNetworkDiagnosticsNode',
      desc: '',
      args: [],
    );
  }

  /// `Diagnostic conclusion`
  String get xboardNetworkDiagnosticsConclusion {
    return Intl.message(
      'Diagnostic conclusion',
      name: 'xboardNetworkDiagnosticsConclusion',
      desc: '',
      args: [],
    );
  }

  /// `IPv4 / IPv6 connectivity`
  String get xboardNetworkDiagnosticsIpConnectivity {
    return Intl.message(
      'IPv4 / IPv6 connectivity',
      name: 'xboardNetworkDiagnosticsIpConnectivity',
      desc: '',
      args: [],
    );
  }

  /// `Local direct HTTPS (domestic baseline)`
  String get xboardNetworkDiagnosticsDirectHttps {
    return Intl.message(
      'Local direct HTTPS (domestic baseline)',
      name: 'xboardNetworkDiagnosticsDirectHttps',
      desc: '',
      args: [],
    );
  }

  /// `Node proxy HTTPS (international reference)`
  String get xboardNetworkDiagnosticsProxyHttps {
    return Intl.message(
      'Node proxy HTTPS (international reference)',
      name: 'xboardNetworkDiagnosticsProxyHttps',
      desc: '',
      args: [],
    );
  }

  /// `DNS results are abnormal. Check DNS settings or the current network.`
  String get xboardNetworkDiagnosticsConclusionDns {
    return Intl.message(
      'DNS results are abnormal. Check DNS settings or the current network.',
      name: 'xboardNetworkDiagnosticsConclusionDns',
      desc: '',
      args: [],
    );
  }

  /// `The local network appears abnormal or unreachable.`
  String get xboardNetworkDiagnosticsConclusionNetwork {
    return Intl.message(
      'The local network appears abnormal or unreachable.',
      name: 'xboardNetworkDiagnosticsConclusionNetwork',
      desc: '',
      args: [],
    );
  }

  /// `VPN is connected, but the current node could not be identified.`
  String get xboardNetworkDiagnosticsConclusionNodeUnknown {
    return Intl.message(
      'VPN is connected, but the current node could not be identified.',
      name: 'xboardNetworkDiagnosticsConclusionNodeUnknown',
      desc: '',
      args: [],
    );
  }

  /// `The proxy node or proxy route is unavailable.`
  String get xboardNetworkDiagnosticsConclusionProxy {
    return Intl.message(
      'The proxy node or proxy route is unavailable.',
      name: 'xboardNetworkDiagnosticsConclusionProxy',
      desc: '',
      args: [],
    );
  }

  /// `The proxy route is working normally. Some direct targets are restricted on the current network, which does not affect proxy use.`
  String get xboardNetworkDiagnosticsConclusionProxyWorking {
    return Intl.message(
      'The proxy route is working normally. Some direct targets are restricted on the current network, which does not affect proxy use.',
      name: 'xboardNetworkDiagnosticsConclusionProxyWorking',
      desc: '',
      args: [],
    );
  }

  /// `DNS and network routes are working normally.`
  String get xboardNetworkDiagnosticsConclusionHealthy {
    return Intl.message(
      'DNS and network routes are working normally.',
      name: 'xboardNetworkDiagnosticsConclusionHealthy',
      desc: '',
      args: [],
    );
  }

  /// `This device has no usable network connection. The proxy core is running, but the local network or internet is unreachable. Check Wi-Fi, Ethernet, or system network settings.`
  String get xboardNetworkDiagnosticsConclusionNoNetwork {
    return Intl.message(
      'This device has no usable network connection. The proxy core is running, but the local network or internet is unreachable. Check Wi-Fi, Ethernet, or system network settings.',
      name: 'xboardNetworkDiagnosticsConclusionNoNetwork',
      desc: '',
      args: [],
    );
  }

  /// `Network type`
  String get xboardNetworkDiagnosticsNetworkType {
    return Intl.message(
      'Network type',
      name: 'xboardNetworkDiagnosticsNetworkType',
      desc: '',
      args: [],
    );
  }

  /// `Mobile network`
  String get xboardNetworkDiagnosticsNetworkMobile {
    return Intl.message(
      'Mobile network',
      name: 'xboardNetworkDiagnosticsNetworkMobile',
      desc: '',
      args: [],
    );
  }

  /// `Ethernet`
  String get xboardNetworkDiagnosticsNetworkEthernet {
    return Intl.message(
      'Ethernet',
      name: 'xboardNetworkDiagnosticsNetworkEthernet',
      desc: '',
      args: [],
    );
  }

  /// `Other network`
  String get xboardNetworkDiagnosticsNetworkOther {
    return Intl.message(
      'Other network',
      name: 'xboardNetworkDiagnosticsNetworkOther',
      desc: '',
      args: [],
    );
  }

  /// `No network`
  String get xboardNetworkDiagnosticsNetworkNone {
    return Intl.message(
      'No network',
      name: 'xboardNetworkDiagnosticsNetworkNone',
      desc: '',
      args: [],
    );
  }

  /// `Node connection layers`
  String get xboardNetworkDiagnosticsNodeLayers {
    return Intl.message(
      'Node connection layers',
      name: 'xboardNetworkDiagnosticsNodeLayers',
      desc: '',
      args: [],
    );
  }

  /// `Node endpoint`
  String get xboardNetworkDiagnosticsNodeEndpoint {
    return Intl.message(
      'Node endpoint',
      name: 'xboardNetworkDiagnosticsNodeEndpoint',
      desc: '',
      args: [],
    );
  }

  /// `Node DNS`
  String get xboardNetworkDiagnosticsNodeDns {
    return Intl.message(
      'Node DNS',
      name: 'xboardNetworkDiagnosticsNodeDns',
      desc: '',
      args: [],
    );
  }

  /// `TCP port`
  String get xboardNetworkDiagnosticsNodeTcp {
    return Intl.message(
      'TCP port',
      name: 'xboardNetworkDiagnosticsNodeTcp',
      desc: '',
      args: [],
    );
  }

  /// `TLS handshake`
  String get xboardNetworkDiagnosticsNodeTls {
    return Intl.message(
      'TLS handshake',
      name: 'xboardNetworkDiagnosticsNodeTls',
      desc: '',
      args: [],
    );
  }

  /// `TLS / proxy handshake / HTTP`
  String get xboardNetworkDiagnosticsNodeHandshake {
    return Intl.message(
      'TLS / proxy handshake / HTTP',
      name: 'xboardNetworkDiagnosticsNodeHandshake',
      desc: '',
      args: [],
    );
  }

  /// `Node domain resolved successfully`
  String get xboardNetworkDiagnosticsNodeDnsSuccess {
    return Intl.message(
      'Node domain resolved successfully',
      name: 'xboardNetworkDiagnosticsNodeDnsSuccess',
      desc: '',
      args: [],
    );
  }

  /// `Node domain resolution failed`
  String get xboardNetworkDiagnosticsNodeDnsFailed {
    return Intl.message(
      'Node domain resolution failed',
      name: 'xboardNetworkDiagnosticsNodeDnsFailed',
      desc: '',
      args: [],
    );
  }

  /// `TCP connection succeeded`
  String get xboardNetworkDiagnosticsTcpSuccess {
    return Intl.message(
      'TCP connection succeeded',
      name: 'xboardNetworkDiagnosticsTcpSuccess',
      desc: '',
      args: [],
    );
  }

  /// `TCP connection timed out; the endpoint may be unreachable or restricted by this network`
  String get xboardNetworkDiagnosticsTcpTimeout {
    return Intl.message(
      'TCP connection timed out; the endpoint may be unreachable or restricted by this network',
      name: 'xboardNetworkDiagnosticsTcpTimeout',
      desc: '',
      args: [],
    );
  }

  /// `TCP connection was refused; the server port may not be listening`
  String get xboardNetworkDiagnosticsTcpRefused {
    return Intl.message(
      'TCP connection was refused; the server port may not be listening',
      name: 'xboardNetworkDiagnosticsTcpRefused',
      desc: '',
      args: [],
    );
  }

  /// `No route to the node endpoint`
  String get xboardNetworkDiagnosticsTcpUnreachable {
    return Intl.message(
      'No route to the node endpoint',
      name: 'xboardNetworkDiagnosticsTcpUnreachable',
      desc: '',
      args: [],
    );
  }

  /// `UDP-based node; TCP port check is not applicable`
  String get xboardNetworkDiagnosticsTcpSkippedUdp {
    return Intl.message(
      'UDP-based node; TCP port check is not applicable',
      name: 'xboardNetworkDiagnosticsTcpSkippedUdp',
      desc: '',
      args: [],
    );
  }

  /// `TCP succeeded, but the TLS handshake failed`
  String get xboardNetworkDiagnosticsTlsFailed {
    return Intl.message(
      'TCP succeeded, but the TLS handshake failed',
      name: 'xboardNetworkDiagnosticsTlsFailed',
      desc: '',
      args: [],
    );
  }

  /// `The node endpoint is reachable, but the proxy protocol handshake failed`
  String get xboardNetworkDiagnosticsProtocolFailed {
    return Intl.message(
      'The node endpoint is reachable, but the proxy protocol handshake failed',
      name: 'xboardNetworkDiagnosticsProtocolFailed',
      desc: '',
      args: [],
    );
  }

  /// `The UDP node test timed out; UDP may be unavailable or restricted on this network`
  String get xboardNetworkDiagnosticsUdpFailed {
    return Intl.message(
      'The UDP node test timed out; UDP may be unavailable or restricted on this network',
      name: 'xboardNetworkDiagnosticsUdpFailed',
      desc: '',
      args: [],
    );
  }

  /// `The proxy connected, but the HTTP test failed`
  String get xboardNetworkDiagnosticsHttpFailed {
    return Intl.message(
      'The proxy connected, but the HTTP test failed',
      name: 'xboardNetworkDiagnosticsHttpFailed',
      desc: '',
      args: [],
    );
  }

  /// `Node handshake and HTTP test succeeded`
  String get xboardNetworkDiagnosticsNodeHttpSuccess {
    return Intl.message(
      'Node handshake and HTTP test succeeded',
      name: 'xboardNetworkDiagnosticsNodeHttpSuccess',
      desc: '',
      args: [],
    );
  }

  /// `Node endpoint information is unavailable`
  String get xboardNetworkDiagnosticsEndpointUnavailable {
    return Intl.message(
      'Node endpoint information is unavailable',
      name: 'xboardNetworkDiagnosticsEndpointUnavailable',
      desc: '',
      args: [],
    );
  }

  /// `Layered diagnostics are unavailable in the current core. Update or fully restart the client; the HTTPS results below remain valid.`
  String get xboardNetworkDiagnosticsCoreUnavailable {
    return Intl.message(
      'Layered diagnostics are unavailable in the current core. Update or fully restart the client; the HTTPS results below remain valid.',
      name: 'xboardNetworkDiagnosticsCoreUnavailable',
      desc: '',
      args: [],
    );
  }

  /// `VPN is not connected. Node DNS, port, TLS, and proxy-route diagnostics were skipped.`
  String get xboardNetworkDiagnosticsVpnRequired {
    return Intl.message(
      'VPN is not connected. Node DNS, port, TLS, and proxy-route diagnostics were skipped.',
      name: 'xboardNetworkDiagnosticsVpnRequired',
      desc: '',
      args: [],
    );
  }

  /// `VPN is not connected. The basic network is working normally; connect VPN to diagnose the node route.`
  String get xboardNetworkDiagnosticsConclusionDisconnectedHealthy {
    return Intl.message(
      'VPN is not connected. The basic network is working normally; connect VPN to diagnose the node route.',
      name: 'xboardNetworkDiagnosticsConclusionDisconnectedHealthy',
      desc: '',
      args: [],
    );
  }

  /// `VPN is not connected, and the basic network DNS result is abnormal. Fix the local network or DNS before diagnosing the node route.`
  String get xboardNetworkDiagnosticsConclusionDisconnectedDns {
    return Intl.message(
      'VPN is not connected, and the basic network DNS result is abnormal. Fix the local network or DNS before diagnosing the node route.',
      name: 'xboardNetworkDiagnosticsConclusionDisconnectedDns',
      desc: '',
      args: [],
    );
  }

  /// `VPN is not connected, and the basic network appears abnormal or unreachable.`
  String get xboardNetworkDiagnosticsConclusionDisconnectedNetwork {
    return Intl.message(
      'VPN is not connected, and the basic network appears abnormal or unreachable.',
      name: 'xboardNetworkDiagnosticsConclusionDisconnectedNetwork',
      desc: '',
      args: [],
    );
  }

  /// `The selected node domain could not be resolved on the current network.`
  String get xboardNetworkDiagnosticsConclusionNodeDns {
    return Intl.message(
      'The selected node domain could not be resolved on the current network.',
      name: 'xboardNetworkDiagnosticsConclusionNodeDns',
      desc: '',
      args: [],
    );
  }

  /// `Direct internet access works, but the selected node TCP endpoint timed out. The endpoint may be unreachable or restricted by the current network.`
  String get xboardNetworkDiagnosticsConclusionTcp {
    return Intl.message(
      'Direct internet access works, but the selected node TCP endpoint timed out. The endpoint may be unreachable or restricted by the current network.',
      name: 'xboardNetworkDiagnosticsConclusionTcp',
      desc: '',
      args: [],
    );
  }

  /// `The selected node endpoint refused the TCP connection. Check the server process and listening port.`
  String get xboardNetworkDiagnosticsConclusionTcpRefused {
    return Intl.message(
      'The selected node endpoint refused the TCP connection. Check the server process and listening port.',
      name: 'xboardNetworkDiagnosticsConclusionTcpRefused',
      desc: '',
      args: [],
    );
  }

  /// `TCP connectivity succeeded, but the node TLS handshake failed. Check SNI, certificates, or network TLS filtering.`
  String get xboardNetworkDiagnosticsConclusionTls {
    return Intl.message(
      'TCP connectivity succeeded, but the node TLS handshake failed. Check SNI, certificates, or network TLS filtering.',
      name: 'xboardNetworkDiagnosticsConclusionTls',
      desc: '',
      args: [],
    );
  }

  /// `The node endpoint is reachable, but the proxy protocol handshake failed. Check transport and authentication parameters.`
  String get xboardNetworkDiagnosticsConclusionProtocol {
    return Intl.message(
      'The node endpoint is reachable, but the proxy protocol handshake failed. Check transport and authentication parameters.',
      name: 'xboardNetworkDiagnosticsConclusionProtocol',
      desc: '',
      args: [],
    );
  }

  /// `The UDP-based node timed out while direct internet access works. UDP may be unavailable or restricted on the current network.`
  String get xboardNetworkDiagnosticsConclusionUdp {
    return Intl.message(
      'The UDP-based node timed out while direct internet access works. UDP may be unavailable or restricted on the current network.',
      name: 'xboardNetworkDiagnosticsConclusionUdp',
      desc: '',
      args: [],
    );
  }

  /// `FastCat diagnostic report`
  String get xboardDiagnosticSummaryTitle {
    return Intl.message(
      'FastCat diagnostic report',
      name: 'xboardDiagnosticSummaryTitle',
      desc: '',
      args: [],
    );
  }

  /// `Overall status`
  String get xboardDiagnosticOverall {
    return Intl.message(
      'Overall status',
      name: 'xboardDiagnosticOverall',
      desc: '',
      args: [],
    );
  }

  /// `Healthy`
  String get xboardDiagnosticOverallHealthy {
    return Intl.message(
      'Healthy',
      name: 'xboardDiagnosticOverallHealthy',
      desc: '',
      args: [],
    );
  }

  /// `Services and system proxy are healthy; network connectivity has not been verified`
  String get xboardDiagnosticOverallServiceHealthy {
    return Intl.message(
      'Services and system proxy are healthy; network connectivity has not been verified',
      name: 'xboardDiagnosticOverallServiceHealthy',
      desc: '',
      args: [],
    );
  }

  /// `Generally healthy, with items requiring attention`
  String get xboardDiagnosticOverallAttention {
    return Intl.message(
      'Generally healthy, with items requiring attention',
      name: 'xboardDiagnosticOverallAttention',
      desc: '',
      args: [],
    );
  }

  /// `Issues detected`
  String get xboardDiagnosticOverallAbnormal {
    return Intl.message(
      'Issues detected',
      name: 'xboardDiagnosticOverallAbnormal',
      desc: '',
      args: [],
    );
  }

  /// `Problems`
  String get xboardDiagnosticProblems {
    return Intl.message(
      'Problems',
      name: 'xboardDiagnosticProblems',
      desc: '',
      args: [],
    );
  }

  /// `Items requiring attention`
  String get xboardDiagnosticNotices {
    return Intl.message(
      'Items requiring attention',
      name: 'xboardDiagnosticNotices',
      desc: '',
      args: [],
    );
  }

  /// `Healthy items`
  String get xboardDiagnosticHealthyItems {
    return Intl.message(
      'Healthy items',
      name: 'xboardDiagnosticHealthyItems',
      desc: '',
      args: [],
    );
  }

  /// `Suggestion`
  String get xboardDiagnosticSuggestion {
    return Intl.message(
      'Suggestion',
      name: 'xboardDiagnosticSuggestion',
      desc: '',
      args: [],
    );
  }

  /// `Proxy core is not running`
  String get xboardDiagnosticIssueCore {
    return Intl.message(
      'Proxy core is not running',
      name: 'xboardDiagnosticIssueCore',
      desc: '',
      args: [],
    );
  }

  /// `No available business gateway`
  String get xboardDiagnosticIssueGateway {
    return Intl.message(
      'No available business gateway',
      name: 'xboardDiagnosticIssueGateway',
      desc: '',
      args: [],
    );
  }

  /// `No available proxy nodes`
  String get xboardDiagnosticIssueNodes {
    return Intl.message(
      'No available proxy nodes',
      name: 'xboardDiagnosticIssueNodes',
      desc: '',
      args: [],
    );
  }

  /// `System proxy is enabled but not running`
  String get xboardDiagnosticIssueProxy {
    return Intl.message(
      'System proxy is enabled but not running',
      name: 'xboardDiagnosticIssueProxy',
      desc: '',
      args: [],
    );
  }

  /// `TUN is configured but is not currently active; traffic is using another proxy mode`
  String get xboardDiagnosticNoticeTun {
    return Intl.message(
      'TUN is configured but is not currently active; traffic is using another proxy mode',
      name: 'xboardDiagnosticNoticeTun',
      desc: '',
      args: [],
    );
  }

  /// `Unverified backup gateways`
  String get xboardDiagnosticNoticeGateways {
    return Intl.message(
      'Unverified backup gateways',
      name: 'xboardDiagnosticNoticeGateways',
      desc: '',
      args: [],
    );
  }

  /// `Proxy core is running`
  String get xboardDiagnosticHealthyCore {
    return Intl.message(
      'Proxy core is running',
      name: 'xboardDiagnosticHealthyCore',
      desc: '',
      args: [],
    );
  }

  /// `Current business gateway is available`
  String get xboardDiagnosticHealthyGateway {
    return Intl.message(
      'Current business gateway is available',
      name: 'xboardDiagnosticHealthyGateway',
      desc: '',
      args: [],
    );
  }

  /// `Available proxy nodes`
  String get xboardDiagnosticHealthyNodes {
    return Intl.message(
      'Available proxy nodes',
      name: 'xboardDiagnosticHealthyNodes',
      desc: '',
      args: [],
    );
  }

  /// `System proxy is running on port`
  String get xboardDiagnosticHealthyProxy {
    return Intl.message(
      'System proxy is running on port',
      name: 'xboardDiagnosticHealthyProxy',
      desc: '',
      args: [],
    );
  }

  /// `Account and subscription are available`
  String get xboardDiagnosticHealthyAccount {
    return Intl.message(
      'Account and subscription are available',
      name: 'xboardDiagnosticHealthyAccount',
      desc: '',
      args: [],
    );
  }

  /// `Device heartbeat succeeded`
  String get xboardDiagnosticHealthyHeartbeat {
    return Intl.message(
      'Device heartbeat succeeded',
      name: 'xboardDiagnosticHealthyHeartbeat',
      desc: '',
      args: [],
    );
  }

  /// `Refresh status or use one-click repair, then rerun network diagnostics and copy the report.`
  String get xboardDiagnosticSuggestionRepair {
    return Intl.message(
      'Refresh status or use one-click repair, then rerun network diagnostics and copy the report.',
      name: 'xboardDiagnosticSuggestionRepair',
      desc: '',
      args: [],
    );
  }

  /// `The connection is usable. Enable TUN only if some apps cannot use the system proxy.`
  String get xboardDiagnosticSuggestionTun {
    return Intl.message(
      'The connection is usable. Enable TUN only if some apps cannot use the system proxy.',
      name: 'xboardDiagnosticSuggestionTun',
      desc: '',
      args: [],
    );
  }

  /// `The current connection is working normally; no action is required.`
  String get xboardDiagnosticSuggestionNone {
    return Intl.message(
      'The current connection is working normally; no action is required.',
      name: 'xboardDiagnosticSuggestionNone',
      desc: '',
      args: [],
    );
  }

  /// `Services and system proxy settings are healthy. Run network diagnostics to verify the node endpoint, TLS, and proxy route.`
  String get xboardDiagnosticSuggestionRunNetwork {
    return Intl.message(
      'Services and system proxy settings are healthy. Run network diagnostics to verify the node endpoint, TLS, and proxy route.',
      name: 'xboardDiagnosticSuggestionRunNetwork',
      desc: '',
      args: [],
    );
  }

  /// `Check Wi-Fi, Ethernet, or system network settings first, then rerun diagnostics after connectivity is restored.`
  String get xboardDiagnosticSuggestionNetwork {
    return Intl.message(
      'Check Wi-Fi, Ethernet, or system network settings first, then rerun diagnostics after connectivity is restored.',
      name: 'xboardDiagnosticSuggestionNetwork',
      desc: '',
      args: [],
    );
  }

  /// `The local network is available, but the current node route is unhealthy. Switch nodes and rerun diagnostics.`
  String get xboardDiagnosticSuggestionNode {
    return Intl.message(
      'The local network is available, but the current node route is unhealthy. Switch nodes and rerun diagnostics.',
      name: 'xboardDiagnosticSuggestionNode',
      desc: '',
      args: [],
    );
  }

  /// `Latest network connectivity check`
  String get xboardDiagnosticLatestNetwork {
    return Intl.message(
      'Latest network connectivity check',
      name: 'xboardDiagnosticLatestNetwork',
      desc: '',
      args: [],
    );
  }

  /// `Network connectivity diagnostics have not been run`
  String get xboardDiagnosticNetworkNotRun {
    return Intl.message(
      'Network connectivity diagnostics have not been run',
      name: 'xboardDiagnosticNetworkNotRun',
      desc: '',
      args: [],
    );
  }

  /// `Checked at`
  String get xboardDiagnosticNetworkSnapshotTime {
    return Intl.message(
      'Checked at',
      name: 'xboardDiagnosticNetworkSnapshotTime',
      desc: '',
      args: [],
    );
  }

  /// `Platform`
  String get xboardDiagnosticPlatform {
    return Intl.message(
      'Platform',
      name: 'xboardDiagnosticPlatform',
      desc: '',
      args: [],
    );
  }

  /// `Expected address`
  String get xboardProxyExpectedAddress {
    return Intl.message(
      'Expected address',
      name: 'xboardProxyExpectedAddress',
      desc: '',
      args: [],
    );
  }

  /// `System address`
  String get xboardProxyActualAddress {
    return Intl.message(
      'System address',
      name: 'xboardProxyActualAddress',
      desc: '',
      args: [],
    );
  }

  /// `Local port`
  String get xboardProxyLocalPort {
    return Intl.message(
      'Local port',
      name: 'xboardProxyLocalPort',
      desc: '',
      args: [],
    );
  }

  /// `Listening`
  String get xboardProxyListening {
    return Intl.message(
      'Listening',
      name: 'xboardProxyListening',
      desc: '',
      args: [],
    );
  }

  /// `Not listening`
  String get xboardProxyNotListening {
    return Intl.message(
      'Not listening',
      name: 'xboardProxyNotListening',
      desc: '',
      args: [],
    );
  }

  /// `Client setting`
  String get xboardProxyClientSetting {
    return Intl.message(
      'Client setting',
      name: 'xboardProxyClientSetting',
      desc: '',
      args: [],
    );
  }

  /// `System source`
  String get xboardProxyStatusSource {
    return Intl.message(
      'System source',
      name: 'xboardProxyStatusSource',
      desc: '',
      args: [],
    );
  }

  /// `TUN is active; system proxy is not required`
  String get xboardProxyStatusTunActive {
    return Intl.message(
      'TUN is active; system proxy is not required',
      name: 'xboardProxyStatusTunActive',
      desc: '',
      args: [],
    );
  }

  /// `The core is stopped, but a stale system proxy is still enabled`
  String get xboardProxyStatusStale {
    return Intl.message(
      'The core is stopped, but a stale system proxy is still enabled',
      name: 'xboardProxyStatusStale',
      desc: '',
      args: [],
    );
  }

  /// `The local proxy port is not listening`
  String get xboardProxyStatusPortUnavailable {
    return Intl.message(
      'The local proxy port is not listening',
      name: 'xboardProxyStatusPortUnavailable',
      desc: '',
      args: [],
    );
  }

  /// `Unable to read the system proxy status`
  String get xboardProxyStatusReadFailed {
    return Intl.message(
      'Unable to read the system proxy status',
      name: 'xboardProxyStatusReadFailed',
      desc: '',
      args: [],
    );
  }

  /// `The device system proxy is not enabled`
  String get xboardProxyStatusSystemDisabled {
    return Intl.message(
      'The device system proxy is not enabled',
      name: 'xboardProxyStatusSystemDisabled',
      desc: '',
      args: [],
    );
  }

  /// `The client system proxy setting is not enabled`
  String get xboardProxyStatusClientDisabled {
    return Intl.message(
      'The client system proxy setting is not enabled',
      name: 'xboardProxyStatusClientDisabled',
      desc: '',
      args: [],
    );
  }

  /// `The system proxy IP or port does not match the client`
  String get xboardProxyStatusMismatch {
    return Intl.message(
      'The system proxy IP or port does not match the client',
      name: 'xboardProxyStatusMismatch',
      desc: '',
      args: [],
    );
  }

  /// `The proxy core is not running. Connect first, then run one-click repair.`
  String get xboardProxyRepairCoreNotRunning {
    return Intl.message(
      'The proxy core is not running. Connect first, then run one-click repair.',
      name: 'xboardProxyRepairCoreNotRunning',
      desc: '',
      args: [],
    );
  }

  /// `The local proxy port is not listening; system proxy was not enabled.`
  String get xboardProxyRepairPortUnavailable {
    return Intl.message(
      'The local proxy port is not listening; system proxy was not enabled.',
      name: 'xboardProxyRepairPortUnavailable',
      desc: '',
      args: [],
    );
  }

  /// `Failed to write the device system proxy settings.`
  String get xboardProxyRepairWriteFailed {
    return Intl.message(
      'Failed to write the device system proxy settings.',
      name: 'xboardProxyRepairWriteFailed',
      desc: '',
      args: [],
    );
  }

  /// `System proxy verification failed after repair; the IP or port still does not match.`
  String get xboardProxyRepairVerifyFailed {
    return Intl.message(
      'System proxy verification failed after repair; the IP or port still does not match.',
      name: 'xboardProxyRepairVerifyFailed',
      desc: '',
      args: [],
    );
  }

  /// `Offline cache mode`
  String get xboardServiceOfflineCacheMode {
    return Intl.message(
      'Offline cache mode',
      name: 'xboardServiceOfflineCacheMode',
      desc: '',
      args: [],
    );
  }

  /// `Local network unavailable`
  String get xboardServiceNoNetwork {
    return Intl.message(
      'Local network unavailable',
      name: 'xboardServiceNoNetwork',
      desc: '',
      args: [],
    );
  }

  /// `Network access restricted`
  String get xboardServiceNetworkRestricted {
    return Intl.message(
      'Network access restricted',
      name: 'xboardServiceNetworkRestricted',
      desc: '',
      args: [],
    );
  }

  /// `Service connection unstable`
  String get xboardServiceConnectionDegraded {
    return Intl.message(
      'Service connection unstable',
      name: 'xboardServiceConnectionDegraded',
      desc: '',
      args: [],
    );
  }

  /// `Restoring connection`
  String get xboardServiceRecovering {
    return Intl.message(
      'Restoring connection',
      name: 'xboardServiceRecovering',
      desc: '',
      args: [],
    );
  }

  /// `Initializing`
  String get xboardInitializing {
    return Intl.message(
      'Initializing',
      name: 'xboardInitializing',
      desc: '',
      args: [],
    );
  }

  /// `The local internet connection is working, but the business service is temporarily unreachable. The proxy can continue using cached subscriptions and nodes, while login, plans, and payments may be unavailable. Offline cache mode ends automatically after recovery.`
  String get xboardServiceOfflineCacheTooltip {
    return Intl.message(
      'The local internet connection is working, but the business service is temporarily unreachable. The proxy can continue using cached subscriptions and nodes, while login, plans, and payments may be unavailable. Offline cache mode ends automatically after recovery.',
      name: 'xboardServiceOfflineCacheTooltip',
      desc: '',
      args: [],
    );
  }

  /// `This device has no usable network connection, so the proxy cannot work either. Check Wi-Fi, mobile data, or Ethernet.`
  String get xboardServiceNoNetworkTooltip {
    return Intl.message(
      'This device has no usable network connection, so the proxy cannot work either. Check Wi-Fi, mobile data, or Ethernet.',
      name: 'xboardServiceNoNetworkTooltip',
      desc: '',
      args: [],
    );
  }

  /// `A network interface is present, but both public internet checks and business gateways are unreachable. The proxy may not work. Check network restrictions or DNS, or run network diagnostics.`
  String get xboardServiceNetworkRestrictedTooltip {
    return Intl.message(
      'A network interface is present, but both public internet checks and business gateways are unreachable. The proxy may not work. Check network restrictions or DNS, or run network diagnostics.',
      name: 'xboardServiceNetworkRestrictedTooltip',
      desc: '',
      args: [],
    );
  }

  /// `A business request failed. The client is checking the local network and business gateways.`
  String get xboardServiceDegradedTooltip {
    return Intl.message(
      'A business request failed. The client is checking the local network and business gateways.',
      name: 'xboardServiceDegradedTooltip',
      desc: '',
      args: [],
    );
  }

  /// `The network has recovered. The client is confirming business gateway availability.`
  String get xboardServiceRecoveringTooltip {
    return Intl.message(
      'The network has recovered. The client is confirming business gateway availability.',
      name: 'xboardServiceRecoveringTooltip',
      desc: '',
      args: [],
    );
  }

  /// `Offline mode: checking cached subscription`
  String get xboardCheckingCachedSubscription {
    return Intl.message(
      'Offline mode: checking cached subscription',
      name: 'xboardCheckingCachedSubscription',
      desc: '',
      args: [],
    );
  }

  /// `Server response is slow; using cached data`
  String get xboardSubscriptionSlowUsingCache {
    return Intl.message(
      'Server response is slow; using cached data',
      name: 'xboardSubscriptionSlowUsingCache',
      desc: '',
      args: [],
    );
  }

  /// `Streaming & AI check`
  String get xboardStreamingCheck {
    return Intl.message(
      'Streaming & AI check',
      name: 'xboardStreamingCheck',
      desc: '',
      args: [],
    );
  }

  /// `Check common streaming and AI services through the current node`
  String get xboardStreamingCheckSubtitle {
    return Intl.message(
      'Check common streaming and AI services through the current node',
      name: 'xboardStreamingCheckSubtitle',
      desc: '',
      args: [],
    );
  }

  /// `Start check`
  String get xboardStreamingStart {
    return Intl.message(
      'Start check',
      name: 'xboardStreamingStart',
      desc: '',
      args: [],
    );
  }

  /// `Check again`
  String get xboardStreamingRetest {
    return Intl.message(
      'Check again',
      name: 'xboardStreamingRetest',
      desc: '',
      args: [],
    );
  }

  /// `Checking…`
  String get xboardStreamingChecking {
    return Intl.message(
      'Checking…',
      name: 'xboardStreamingChecking',
      desc: '',
      args: [],
    );
  }

  /// `Copy report`
  String get xboardStreamingCopyReport {
    return Intl.message(
      'Copy report',
      name: 'xboardStreamingCopyReport',
      desc: '',
      args: [],
    );
  }

  /// `Visit`
  String get xboardStreamingVisit {
    return Intl.message(
      'Visit',
      name: 'xboardStreamingVisit',
      desc: '',
      args: [],
    );
  }

  /// `VPN connected`
  String get xboardStreamingConnected {
    return Intl.message(
      'VPN connected',
      name: 'xboardStreamingConnected',
      desc: '',
      args: [],
    );
  }

  /// `VPN not connected`
  String get xboardStreamingNotConnected {
    return Intl.message(
      'VPN not connected',
      name: 'xboardStreamingNotConnected',
      desc: '',
      args: [],
    );
  }

  /// `Connect the VPN first. Streaming and AI checks must run through the current node.`
  String get xboardStreamingConnectFirst {
    return Intl.message(
      'Connect the VPN first. Streaming and AI checks must run through the current node.',
      name: 'xboardStreamingConnectFirst',
      desc: '',
      args: [],
    );
  }

  /// `The VPN disconnected. These results are no longer valid.`
  String get xboardStreamingDisconnected {
    return Intl.message(
      'The VPN disconnected. These results are no longer valid.',
      name: 'xboardStreamingDisconnected',
      desc: '',
      args: [],
    );
  }

  /// `The node changed during the check. Run the check again.`
  String get xboardStreamingNodeChanged {
    return Intl.message(
      'The node changed during the check. Run the check again.',
      name: 'xboardStreamingNodeChanged',
      desc: '',
      args: [],
    );
  }

  /// `The current node is temporarily unavailable. Try again shortly.`
  String get xboardStreamingNodeUnavailable {
    return Intl.message(
      'The current node is temporarily unavailable. Try again shortly.',
      name: 'xboardStreamingNodeUnavailable',
      desc: '',
      args: [],
    );
  }

  /// `Current node`
  String get xboardStreamingCurrentNode {
    return Intl.message(
      'Current node',
      name: 'xboardStreamingCurrentNode',
      desc: '',
      args: [],
    );
  }

  /// `Exit region`
  String get xboardStreamingExitRegion {
    return Intl.message(
      'Exit region',
      name: 'xboardStreamingExitRegion',
      desc: '',
      args: [],
    );
  }

  /// `Summary`
  String get xboardStreamingSummary {
    return Intl.message(
      'Summary',
      name: 'xboardStreamingSummary',
      desc: '',
      args: [],
    );
  }

  /// `Confirmed available`
  String get xboardStreamingSummaryAccessible {
    return Intl.message(
      'Confirmed available',
      name: 'xboardStreamingSummaryAccessible',
      desc: '',
      args: [],
    );
  }

  /// `Partially available`
  String get xboardStreamingSummaryPartial {
    return Intl.message(
      'Partially available',
      name: 'xboardStreamingSummaryPartial',
      desc: '',
      args: [],
    );
  }

  /// `Restricted/unavailable`
  String get xboardStreamingSummaryRestricted {
    return Intl.message(
      'Restricted/unavailable',
      name: 'xboardStreamingSummaryRestricted',
      desc: '',
      args: [],
    );
  }

  /// `Verification required`
  String get xboardStreamingSummaryVerification {
    return Intl.message(
      'Verification required',
      name: 'xboardStreamingSummaryVerification',
      desc: '',
      args: [],
    );
  }

  /// `Error/inconclusive`
  String get xboardStreamingSummaryInconclusive {
    return Intl.message(
      'Error/inconclusive',
      name: 'xboardStreamingSummaryInconclusive',
      desc: '',
      args: [],
    );
  }

  /// `Results`
  String get xboardStreamingResults {
    return Intl.message(
      'Results',
      name: 'xboardStreamingResults',
      desc: '',
      args: [],
    );
  }

  /// `Progress`
  String get xboardStreamingProgress {
    return Intl.message(
      'Progress',
      name: 'xboardStreamingProgress',
      desc: '',
      args: [],
    );
  }

  /// `Accessible services`
  String get xboardStreamingAccessibleCount {
    return Intl.message(
      'Accessible services',
      name: 'xboardStreamingAccessibleCount',
      desc: '',
      args: [],
    );
  }

  /// `Accessible`
  String get xboardStreamingAccessible {
    return Intl.message(
      'Accessible',
      name: 'xboardStreamingAccessible',
      desc: '',
      args: [],
    );
  }

  /// `Partially available`
  String get xboardStreamingPartiallyAccessible {
    return Intl.message(
      'Partially available',
      name: 'xboardStreamingPartiallyAccessible',
      desc: '',
      args: [],
    );
  }

  /// `Region restricted`
  String get xboardStreamingRestricted {
    return Intl.message(
      'Region restricted',
      name: 'xboardStreamingRestricted',
      desc: '',
      args: [],
    );
  }

  /// `IP blocked by service`
  String get xboardStreamingBlocked {
    return Intl.message(
      'IP blocked by service',
      name: 'xboardStreamingBlocked',
      desc: '',
      args: [],
    );
  }

  /// `Browser verification required`
  String get xboardStreamingVerificationRequired {
    return Intl.message(
      'Browser verification required',
      name: 'xboardStreamingVerificationRequired',
      desc: '',
      args: [],
    );
  }

  /// `Unable to confirm`
  String get xboardStreamingUncertain {
    return Intl.message(
      'Unable to confirm',
      name: 'xboardStreamingUncertain',
      desc: '',
      args: [],
    );
  }

  /// `Unavailable`
  String get xboardStreamingUnavailable {
    return Intl.message(
      'Unavailable',
      name: 'xboardStreamingUnavailable',
      desc: '',
      args: [],
    );
  }

  /// `Timed out`
  String get xboardStreamingTimeout {
    return Intl.message(
      'Timed out',
      name: 'xboardStreamingTimeout',
      desc: '',
      args: [],
    );
  }

  /// `Check failed`
  String get xboardStreamingError {
    return Intl.message(
      'Check failed',
      name: 'xboardStreamingError',
      desc: '',
      args: [],
    );
  }

  /// `Cancelled`
  String get xboardStreamingCancelled {
    return Intl.message(
      'Cancelled',
      name: 'xboardStreamingCancelled',
      desc: '',
      args: [],
    );
  }

  /// `Unknown`
  String get xboardStreamingUnknown {
    return Intl.message(
      'Unknown',
      name: 'xboardStreamingUnknown',
      desc: '',
      args: [],
    );
  }

  /// `FastCat Streaming & AI Check Report`
  String get xboardStreamingReportTitle {
    return Intl.message(
      'FastCat Streaming & AI Check Report',
      name: 'xboardStreamingReportTitle',
      desc: '',
      args: [],
    );
  }

  /// `Checked at`
  String get xboardStreamingReportTime {
    return Intl.message(
      'Checked at',
      name: 'xboardStreamingReportTime',
      desc: '',
      args: [],
    );
  }

  /// `Client version`
  String get xboardStreamingReportVersion {
    return Intl.message(
      'Client version',
      name: 'xboardStreamingReportVersion',
      desc: '',
      args: [],
    );
  }

  /// `System`
  String get xboardStreamingReportSystem {
    return Intl.message(
      'System',
      name: 'xboardStreamingReportSystem',
      desc: '',
      args: [],
    );
  }

  /// `Evidence`
  String get xboardStreamingReportDetail {
    return Intl.message(
      'Evidence',
      name: 'xboardStreamingReportDetail',
      desc: '',
      args: [],
    );
  }

  /// `Streaming and AI check report copied`
  String get xboardStreamingReportCopied {
    return Intl.message(
      'Streaming and AI check report copied',
      name: 'xboardStreamingReportCopied',
      desc: '',
      args: [],
    );
  }

  /// `Results are based on service-endpoint and public-page access through the current node and are for reference only. Service policies, account regions, sign-in status, and licensing restrictions may affect actual use.`
  String get xboardStreamingDisclaimer {
    return Intl.message(
      'Results are based on service-endpoint and public-page access through the current node and are for reference only. Service policies, account regions, sign-in status, and licensing restrictions may affect actual use.',
      name: 'xboardStreamingDisclaimer',
      desc: '',
      args: [],
    );
  }

  /// `Loading configuration...`
  String get xboardLoadingConfiguration {
    return Intl.message(
      'Loading configuration...',
      name: 'xboardLoadingConfiguration',
      desc: '',
      args: [],
    );
  }

  /// `Logging in...`
  String get xboardLoggingIn {
    return Intl.message(
      'Logging in...',
      name: 'xboardLoggingIn',
      desc: '',
      args: [],
    );
  }

  /// `Password changed successfully`
  String get xboardPasswordChanged {
    return Intl.message(
      'Password changed successfully',
      name: 'xboardPasswordChanged',
      desc: '',
      args: [],
    );
  }

  /// `Ticket details`
  String get xboardTicketDetails {
    return Intl.message(
      'Ticket details',
      name: 'xboardTicketDetails',
      desc: '',
      args: [],
    );
  }

  /// `Close ticket`
  String get xboardCloseTicket {
    return Intl.message(
      'Close ticket',
      name: 'xboardCloseTicket',
      desc: '',
      args: [],
    );
  }

  /// `Close this ticket? You will not be able to reply after it is closed.`
  String get xboardCloseTicketConfirm {
    return Intl.message(
      'Close this ticket? You will not be able to reply after it is closed.',
      name: 'xboardCloseTicketConfirm',
      desc: '',
      args: [],
    );
  }

  /// `Close`
  String get xboardConfirmClose {
    return Intl.message(
      'Close',
      name: 'xboardConfirmClose',
      desc: '',
      args: [],
    );
  }

  /// `Reply failed. Please try again later.`
  String get xboardReplyFailedRetry {
    return Intl.message(
      'Reply failed. Please try again later.',
      name: 'xboardReplyFailedRetry',
      desc: '',
      args: [],
    );
  }

  /// `No messages`
  String get xboardNoMessages {
    return Intl.message(
      'No messages',
      name: 'xboardNoMessages',
      desc: '',
      args: [],
    );
  }

  /// `Ticket closed`
  String get xboardTicketClosedMessage {
    return Intl.message(
      'Ticket closed',
      name: 'xboardTicketClosedMessage',
      desc: '',
      args: [],
    );
  }

  /// `Enter a reply...`
  String get xboardReplyHint {
    return Intl.message(
      'Enter a reply...',
      name: 'xboardReplyHint',
      desc: '',
      args: [],
    );
  }

  /// `Image upload is not configured. Contact support.`
  String get xboardImageUploadUnavailable {
    return Intl.message(
      'Image upload is not configured. Contact support.',
      name: 'xboardImageUploadUnavailable',
      desc: '',
      args: [],
    );
  }

  /// `Online support`
  String get xboardOnlineSupport {
    return Intl.message(
      'Online support',
      name: 'xboardOnlineSupport',
      desc: '',
      args: [],
    );
  }

  /// `Failed to load. Check your network.`
  String get xboardLoadFailedCheckNetwork {
    return Intl.message(
      'Failed to load. Check your network.',
      name: 'xboardLoadFailedCheckNetwork',
      desc: '',
      args: [],
    );
  }

  /// `TUN mode`
  String get xboardTunModeTitle {
    return Intl.message(
      'TUN mode',
      name: 'xboardTunModeTitle',
      desc: '',
      args: [],
    );
  }

  /// `TUN mode uses a virtual network interface to proxy application traffic more completely.`
  String get xboardTunModeDescription {
    return Intl.message(
      'TUN mode uses a virtual network interface to proxy application traffic more completely.',
      name: 'xboardTunModeDescription',
      desc: '',
      args: [],
    );
  }

  /// `All-traffic proxy`
  String get xboardTunAllTraffic {
    return Intl.message(
      'All-traffic proxy',
      name: 'xboardTunAllTraffic',
      desc: '',
      args: [],
    );
  }

  /// `Captures traffic from all apps without separate configuration.`
  String get xboardTunAllTrafficDescription {
    return Intl.message(
      'Captures traffic from all apps without separate configuration.',
      name: 'xboardTunAllTrafficDescription',
      desc: '',
      args: [],
    );
  }

  /// `Transparent proxy`
  String get xboardTunTransparentProxy {
    return Intl.message(
      'Transparent proxy',
      name: 'xboardTunTransparentProxy',
      desc: '',
      args: [],
    );
  }

  /// `Apps use the proxy without extra setup for better compatibility.`
  String get xboardTunTransparentProxyDescription {
    return Intl.message(
      'Apps use the proxy without extra setup for better compatibility.',
      name: 'xboardTunTransparentProxyDescription',
      desc: '',
      args: [],
    );
  }

  /// `Performance optimization`
  String get xboardTunPerformance {
    return Intl.message(
      'Performance optimization',
      name: 'xboardTunPerformance',
      desc: '',
      args: [],
    );
  }

  /// `Reduces proxy layers to improve network speed.`
  String get xboardTunPerformanceDescription {
    return Intl.message(
      'Reduces proxy layers to improve network speed.',
      name: 'xboardTunPerformanceDescription',
      desc: '',
      args: [],
    );
  }

  /// `Recommended usage`
  String get xboardTunRecommendedUsage {
    return Intl.message(
      'Recommended usage',
      name: 'xboardTunRecommendedUsage',
      desc: '',
      args: [],
    );
  }

  /// `Daily use: Rules + TUN for smart routing and best performance`
  String get xboardTunRuleRecommendation {
    return Intl.message(
      'Daily use: Rules + TUN for smart routing and best performance',
      name: 'xboardTunRuleRecommendation',
      desc: '',
      args: [],
    );
  }

  /// `Fallback: Global + TUN when rules mode does not work as expected`
  String get xboardTunGlobalRecommendation {
    return Intl.message(
      'Fallback: Global + TUN when rules mode does not work as expected',
      name: 'xboardTunGlobalRecommendation',
      desc: '',
      args: [],
    );
  }

  /// `Maybe later`
  String get xboardMaybeLater {
    return Intl.message(
      'Maybe later',
      name: 'xboardMaybeLater',
      desc: '',
      args: [],
    );
  }
}

class AppLocalizationDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationDelegate();

  List<Locale> get supportedLocales {
    return const <Locale>[
      Locale.fromSubtags(languageCode: 'en'),
      Locale.fromSubtags(languageCode: 'zh', countryCode: 'CN'),
    ];
  }

  @override
  bool isSupported(Locale locale) => _isSupported(locale);
  @override
  Future<AppLocalizations> load(Locale locale) => AppLocalizations.load(locale);
  @override
  bool shouldReload(AppLocalizationDelegate old) => false;

  bool _isSupported(Locale locale) {
    for (var supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == locale.languageCode) {
        return true;
      }
    }
    return false;
  }
}
