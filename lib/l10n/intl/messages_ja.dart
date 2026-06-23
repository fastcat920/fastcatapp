// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a ja locale. All the
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
  String get localeName => 'ja';

  static String m0(limit) => "現在の最低出金コミッションは ${limit} です";

  static String m1(minute) => "パスワードの入力ミスが多すぎます。${minute}分後に再試行してください";

  static String m2(rate) => "現在のコミッション率: ${rate}%";

  static String m3(label) => "選択された${label}を削除してもよろしいですか？";

  static String m4(label) => "現在の${label}を削除してもよろしいですか？";

  static String m5(label) => "${label}は空欄にできません";

  static String m6(label) => "現在の${label}は既に存在しています";

  static String m7(error) => "ログアウト失敗：${error}";

  static String m8(amount) => "最大振替可能額: ¥${amount}";

  static String m9(label) => "現在${label}はありません";

  static String m10(label) => "${label}は数字でなければなりません";

  static String m11(statusCode) => "メッセージの取得に失敗しました: ${statusCode}";

  static String m12(error) => "画像の選択に失敗しました: ${error}";

  static String m13(method) => "サポートされていないHTTPメソッド: ${method}";

  static String m14(error) => "アップロードに失敗しました: ${error}";

  static String m15(amount) => "注文金額: ${amount}";

  static String m16(orderNo) => "注文: ${orderNo}";

  static String m17(page) => "${page} ページ";

  static String m18(label) => "${label} は 1024 から 49151 の間でなければなりません";

  static String m19(e) => "登録に失敗しました: ${e}";

  static String m20(count) => "${count} 項目が選択されています";

  static String m21(e) => "確認コードの送信に失敗しました: ${e}";

  static String m22(date) => "プランは${date}に期限切れになりました。継続利用には更新してください";

  static String m23(days) => "プランは${days}日後に期限切れになります。タイムリーに更新してください";

  static String m24(days) => "サブスクリプションは${days}日後に期限切れになります";

  static String m25(count) => "全 ${count} 件";

  static String m26(amount) => "振替金額は ¥${amount} を超えられません";

  static String m27(error) => "振替に失敗しました: ${error}";

  static String m28(amount) => "振替成功！¥${amount} をウォレットへ移動しました";

  static String m29(version) => "現在のバージョン: ${version}";

  static String m30(version) => "強制アップデート: ${version}";

  static String m31(version) => "新しいバージョンが見つかりました: ${version}";

  static String m32(statusCode) => "サーバーがエラーステータスコード ${statusCode} を返しました";

  static String m33(label) => "${label}はURLである必要があります";

  static String m34(email) => "確認コードを ${email} に送信しました。確認コードと新しいパスワードを入力してください";

  static String m35(error) => "送信に失敗しました: ${error}";

  static String m36(amount) => "出金可能額: ${amount}";

  static String m37(amount) => "¥${amount}";

  static String m38(count, limit) => "${count} 台アクティブ · 上限 ${limit}";

  static String m39(date) => "${date} に期限切れ";

  static String m40(date) => "有効期限 ${date}";

  static String m41(date, days) => "${date} に期限切れ、残り ${days} 日";

  static String m42(count) => "${count} 件の候補";

  static String m43(message) => "サブスクリプションインポート: ${message}";

  static String m44(count) => "${count} 件のノード";

  static String m45(error) => "交換失敗: ${error}";

  static String m46(days) => "利用済み通信量は ${days} 日後にリセットされます";

  static String m47(time) => "実行時間: ${time}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "about": MessageLookupByLibrary.simpleMessage("約"),
    "accessControl": MessageLookupByLibrary.simpleMessage("アクセス制御"),
    "accessControlAllowDesc": MessageLookupByLibrary.simpleMessage(
      "選択したアプリのみVPNを許可",
    ),
    "accessControlDesc": MessageLookupByLibrary.simpleMessage(
      "アプリケーションのプロキシアクセスを設定",
    ),
    "accessControlNotAllowDesc": MessageLookupByLibrary.simpleMessage(
      "選択したアプリをVPNから除外",
    ),
    "account": MessageLookupByLibrary.simpleMessage("アカウント"),
    "action": MessageLookupByLibrary.simpleMessage("アクション"),
    "action_mode": MessageLookupByLibrary.simpleMessage("モード切替"),
    "action_proxy": MessageLookupByLibrary.simpleMessage("システムプロキシ"),
    "action_start": MessageLookupByLibrary.simpleMessage("開始/停止"),
    "action_tun": MessageLookupByLibrary.simpleMessage("TUN"),
    "action_view": MessageLookupByLibrary.simpleMessage("表示/非表示"),
    "add": MessageLookupByLibrary.simpleMessage("追加"),
    "addRule": MessageLookupByLibrary.simpleMessage("ルールを追加"),
    "addedOriginRules": MessageLookupByLibrary.simpleMessage("元のルールに追加"),
    "address": MessageLookupByLibrary.simpleMessage("アドレス"),
    "addressHelp": MessageLookupByLibrary.simpleMessage("WebDAVサーバーアドレス"),
    "addressTip": MessageLookupByLibrary.simpleMessage("有効なWebDAVアドレスを入力"),
    "adminAutoLaunch": MessageLookupByLibrary.simpleMessage("管理者自動起動"),
    "adminAutoLaunchDesc": MessageLookupByLibrary.simpleMessage("管理者モードで起動"),
    "ago": MessageLookupByLibrary.simpleMessage("前"),
    "agree": MessageLookupByLibrary.simpleMessage("同意"),
    "allApps": MessageLookupByLibrary.simpleMessage("全アプリ"),
    "allowBypass": MessageLookupByLibrary.simpleMessage("アプリがVPNをバイパスすることを許可"),
    "allowBypassDesc": MessageLookupByLibrary.simpleMessage(
      "有効化すると一部アプリがVPNをバイパス",
    ),
    "allowLan": MessageLookupByLibrary.simpleMessage("LANを許可"),
    "allowLanDesc": MessageLookupByLibrary.simpleMessage("LAN経由でのプロキシアクセスを許可"),
    "alreadyHaveAccount": MessageLookupByLibrary.simpleMessage(
      "すでにアカウントをお持ちですか？",
    ),
    "app": MessageLookupByLibrary.simpleMessage("アプリ"),
    "appAccessControl": MessageLookupByLibrary.simpleMessage("アプリアクセス制御"),
    "appDesc": MessageLookupByLibrary.simpleMessage("アプリ関連設定の処理"),
    "application": MessageLookupByLibrary.simpleMessage("アプリケーション"),
    "applicationDesc": MessageLookupByLibrary.simpleMessage("アプリ関連設定を変更"),
    "auto": MessageLookupByLibrary.simpleMessage("自動"),
    "autoCheckUpdate": MessageLookupByLibrary.simpleMessage("自動更新チェック"),
    "autoCheckUpdateDesc": MessageLookupByLibrary.simpleMessage(
      "起動時に更新を自動チェック",
    ),
    "autoCloseConnections": MessageLookupByLibrary.simpleMessage("接続を自動閉じる"),
    "autoCloseConnectionsDesc": MessageLookupByLibrary.simpleMessage(
      "ノード変更後に接続を自動閉じる",
    ),
    "autoLaunch": MessageLookupByLibrary.simpleMessage("起動時に開始"),
    "autoLaunchDesc": MessageLookupByLibrary.simpleMessage("システムの自動起動に従う"),
    "autoRun": MessageLookupByLibrary.simpleMessage("自動実行"),
    "autoRunDesc": MessageLookupByLibrary.simpleMessage("アプリ起動時に自動実行"),
    "autoSetSystemDns": MessageLookupByLibrary.simpleMessage("オートセットシステムDNS"),
    "autoUpdate": MessageLookupByLibrary.simpleMessage("自動更新"),
    "autoUpdateInterval": MessageLookupByLibrary.simpleMessage("自動更新間隔（分）"),
    "availableCommission": MessageLookupByLibrary.simpleMessage("利用可能"),
    "backToLogin": MessageLookupByLibrary.simpleMessage("ログインに戻る"),
    "backendErrorAccountSuspended": MessageLookupByLibrary.simpleMessage(
      "このアカウントは停止されています",
    ),
    "backendErrorCouponEmpty": MessageLookupByLibrary.simpleMessage(
      "クーポンを入力してください",
    ),
    "backendErrorCouponExpired": MessageLookupByLibrary.simpleMessage(
      "クーポンは期限切れです",
    ),
    "backendErrorCouponInvalid": MessageLookupByLibrary.simpleMessage(
      "クーポンが無効です",
    ),
    "backendErrorCouponLimitExceeded": MessageLookupByLibrary.simpleMessage(
      "クーポンの使用上限に達しています",
    ),
    "backendErrorCouponNotFound": MessageLookupByLibrary.simpleMessage(
      "クーポンが存在しません",
    ),
    "backendErrorEmailEmpty": MessageLookupByLibrary.simpleMessage(
      "メールアドレスを入力してください",
    ),
    "backendErrorEmailExists": MessageLookupByLibrary.simpleMessage(
      "このメールアドレスは既に登録されています",
    ),
    "backendErrorEmailFormatInvalid": MessageLookupByLibrary.simpleMessage(
      "メールアドレスの形式が正しくありません",
    ),
    "backendErrorFailedToOpenTicket": MessageLookupByLibrary.simpleMessage(
      "出金チケットの作成に失敗しました",
    ),
    "backendErrorGiftCardAlreadyUsedByUser":
        MessageLookupByLibrary.simpleMessage("このギフトカードはこのユーザーによって既に使用されています"),
    "backendErrorGiftCardEmpty": MessageLookupByLibrary.simpleMessage(
      "ギフトカードを入力してください",
    ),
    "backendErrorGiftCardExpired": MessageLookupByLibrary.simpleMessage(
      "このギフトカードは期限切れです",
    ),
    "backendErrorGiftCardLimitReached": MessageLookupByLibrary.simpleMessage(
      "このギフトカードは使用上限に達しています",
    ),
    "backendErrorGiftCardNotFound": MessageLookupByLibrary.simpleMessage(
      "このギフトカードは存在しません",
    ),
    "backendErrorGiftCardNotYetValid": MessageLookupByLibrary.simpleMessage(
      "このギフトカードはまだ有効ではありません",
    ),
    "backendErrorGiftCardTypeNotSuitable": MessageLookupByLibrary.simpleMessage(
      "このギフトカードタイプは適用できません",
    ),
    "backendErrorGiftCardTypeUnknown": MessageLookupByLibrary.simpleMessage(
      "不明なギフトカードタイプです",
    ),
    "backendErrorIncorrectEmailOrPassword":
        MessageLookupByLibrary.simpleMessage("メールアドレスまたはパスワードが正しくありません"),
    "backendErrorInsufficientCommissionBalance":
        MessageLookupByLibrary.simpleMessage("コミッション残高が不足しています"),
    "backendErrorInviteCodeInvalid": MessageLookupByLibrary.simpleMessage(
      "招待コードが無効です",
    ),
    "backendErrorInviteCodeNotFound": MessageLookupByLibrary.simpleMessage(
      "招待コードが存在しません",
    ),
    "backendErrorInviteLimitReached": MessageLookupByLibrary.simpleMessage("作成数の上限に達しました"),
    "subscriptionUpdateFailed": MessageLookupByLibrary.simpleMessage("サブスクリプションの更新に失敗しました"),
    "subscriptionImportFailed": MessageLookupByLibrary.simpleMessage("サブスクリプションのインポートに失敗しました"),
    "backendErrorMinimumWithdrawalCommission": m0,
    "backendErrorMinimumWithdrawalCommissionGeneric":
        MessageLookupByLibrary.simpleMessage("最低出金コミッションに達していません"),
    "backendErrorNewPasswordEmpty": MessageLookupByLibrary.simpleMessage(
      "新しいパスワードを入力してください",
    ),
    "backendErrorOldPasswordWrong": MessageLookupByLibrary.simpleMessage(
      "現在のパスワードが正しくありません",
    ),
    "backendErrorOrderNotFound": MessageLookupByLibrary.simpleMessage(
      "注文が存在しません",
    ),
    "backendErrorPasswordEmpty": MessageLookupByLibrary.simpleMessage(
      "パスワードを入力してください",
    ),
    "backendErrorPasswordTooShort": MessageLookupByLibrary.simpleMessage(
      "パスワードは8文字より長くしてください",
    ),
    "backendErrorPlanNotFound": MessageLookupByLibrary.simpleMessage(
      "プランが存在しません",
    ),
    "backendErrorResetFailed": MessageLookupByLibrary.simpleMessage(
      "リセットに失敗しました。しばらくしてから再試行してください",
    ),
    "backendErrorSaveFailed": MessageLookupByLibrary.simpleMessage(
      "保存に失敗しました。しばらくしてから再試行してください",
    ),
    "backendErrorTicketClosed": MessageLookupByLibrary.simpleMessage(
      "チケットは閉じられています",
    ),
    "backendErrorTicketNotFound": MessageLookupByLibrary.simpleMessage(
      "チケットが存在しません",
    ),
    "backendErrorTooManyPasswordErrors": m1,
    "backendErrorTooManyPasswordErrorsGeneric":
        MessageLookupByLibrary.simpleMessage(
          "パスワードの入力ミスが多すぎます。しばらくしてから再試行してください",
        ),
    "backendErrorTooManyRequests": MessageLookupByLibrary.simpleMessage(
      "操作が多すぎます。しばらくしてから再試行してください",
    ),
    "backendErrorTransferAmountEmpty": MessageLookupByLibrary.simpleMessage(
      "振替金額を入力してください",
    ),
    "backendErrorTransferAmountInvalid": MessageLookupByLibrary.simpleMessage(
      "振替金額のパラメータが正しくありません",
    ),
    "backendErrorTransferFailed": MessageLookupByLibrary.simpleMessage(
      "振替に失敗しました",
    ),
    "backendErrorUserNotFound": MessageLookupByLibrary.simpleMessage(
      "ユーザーが存在しません",
    ),
    "backendErrorVerificationCodeInvalid": MessageLookupByLibrary.simpleMessage(
      "認証コードが正しくありません",
    ),
    "backendErrorWithdrawNotSupported": MessageLookupByLibrary.simpleMessage(
      "現在、出金はサポートされていません",
    ),
    "backendErrorWithdrawalAccountEmpty": MessageLookupByLibrary.simpleMessage(
      "出金口座を入力してください",
    ),
    "backendErrorWithdrawalMethodEmpty": MessageLookupByLibrary.simpleMessage(
      "出金方法を入力してください",
    ),
    "backendErrorWithdrawalMethodUnsupported":
        MessageLookupByLibrary.simpleMessage("この出金方法はサポートされていません"),
    "backendFallbackCouponFailed": MessageLookupByLibrary.simpleMessage(
      "クーポン確認に失敗しました",
    ),
    "backendFallbackEmailVerifyFailed": MessageLookupByLibrary.simpleMessage(
      "認証コードの送信に失敗しました",
    ),
    "backendFallbackLoginFailed": MessageLookupByLibrary.simpleMessage(
      "ログインに失敗しました",
    ),
    "backendFallbackOperationFailed": MessageLookupByLibrary.simpleMessage(
      "操作に失敗しました",
    ),
    "backendFallbackOrderFailed": MessageLookupByLibrary.simpleMessage(
      "注文操作に失敗しました",
    ),
    "backendFallbackPasswordFailed": MessageLookupByLibrary.simpleMessage(
      "パスワード操作に失敗しました",
    ),
    "backendFallbackRegisterFailed": MessageLookupByLibrary.simpleMessage(
      "登録に失敗しました",
    ),
    "backendFallbackTicketFailed": MessageLookupByLibrary.simpleMessage(
      "チケット操作に失敗しました",
    ),
    "backendFallbackTransferFailed": MessageLookupByLibrary.simpleMessage(
      "振替に失敗しました",
    ),
    "backup": MessageLookupByLibrary.simpleMessage("バックアップ"),
    "backupAndRecovery": MessageLookupByLibrary.simpleMessage("バックアップと復元"),
    "backupAndRecoveryDesc": MessageLookupByLibrary.simpleMessage(
      "WebDAVまたはファイルでデータを同期",
    ),
    "backupSuccess": MessageLookupByLibrary.simpleMessage("バックアップ成功"),
    "basicConfig": MessageLookupByLibrary.simpleMessage("基本設定"),
    "basicConfigDesc": MessageLookupByLibrary.simpleMessage("基本設定をグローバルに変更"),
    "bind": MessageLookupByLibrary.simpleMessage("バインド"),
    "blacklistMode": MessageLookupByLibrary.simpleMessage("ブラックリストモード"),
    "bypassDomain": MessageLookupByLibrary.simpleMessage("バイパスドメイン"),
    "bypassDomainDesc": MessageLookupByLibrary.simpleMessage("システムプロキシ有効時のみ適用"),
    "cacheCorrupt": MessageLookupByLibrary.simpleMessage(
      "キャッシュが破損しています。クリアしますか？",
    ),
    "cancel": MessageLookupByLibrary.simpleMessage("キャンセル"),
    "cancelFilterSystemApp": MessageLookupByLibrary.simpleMessage(
      "システムアプリの除外を解除",
    ),
    "cancelSelectAll": MessageLookupByLibrary.simpleMessage("全選択解除"),
    "cannotGetWebUrl": MessageLookupByLibrary.simpleMessage(
      "Web URLを取得できません。サポートにお問い合わせください",
    ),
    "cannotOpenBrowser": MessageLookupByLibrary.simpleMessage(
      "ブラウザを開けません。手動でWebにアクセスしてください",
    ),
    "checkError": MessageLookupByLibrary.simpleMessage("確認エラー"),
    "checkNetwork": MessageLookupByLibrary.simpleMessage(
      "ネットワークを確認して再試行してください",
    ),
    "checkUpdate": MessageLookupByLibrary.simpleMessage("更新を確認"),
    "checkUpdateError": MessageLookupByLibrary.simpleMessage("アプリは最新版です"),
    "checking": MessageLookupByLibrary.simpleMessage("確認中..."),
    "clearData": MessageLookupByLibrary.simpleMessage("データを消去"),
    "clipboardExport": MessageLookupByLibrary.simpleMessage("クリップボードにエクスポート"),
    "clipboardImport": MessageLookupByLibrary.simpleMessage("クリップボードからインポート"),
    "close": MessageLookupByLibrary.simpleMessage("閉じる"),
    "color": MessageLookupByLibrary.simpleMessage("カラー"),
    "colorSchemes": MessageLookupByLibrary.simpleMessage("カラースキーム"),
    "columns": MessageLookupByLibrary.simpleMessage("列"),
    "commissionHistory": MessageLookupByLibrary.simpleMessage("コミッション履歴"),
    "commissionRate": MessageLookupByLibrary.simpleMessage("率"),
    "commissionSettled": MessageLookupByLibrary.simpleMessage(
      "友だちの購読後にコミッションが確定します",
    ),
    "compatible": MessageLookupByLibrary.simpleMessage("互換モード"),
    "compatibleDesc": MessageLookupByLibrary.simpleMessage(
      "有効化すると一部機能を失いますが、Clashの完全サポートを獲得",
    ),
    "complete": MessageLookupByLibrary.simpleMessage("完了"),
    "completeWithdrawal": MessageLookupByLibrary.simpleMessage(
      "Web版で完全な出金機能を利用できます",
    ),
    "configurationError": MessageLookupByLibrary.simpleMessage(
      "アプリケーション設定エラー、サポートにお問い合わせください",
    ),
    "confirm": MessageLookupByLibrary.simpleMessage("確認"),
    "confirmLogout": MessageLookupByLibrary.simpleMessage("終了確認"),
    "confirmNewPassword": MessageLookupByLibrary.simpleMessage("新しいパスワードを確認"),
    "confirmTransfer": MessageLookupByLibrary.simpleMessage("振替を確認"),
    "connected": MessageLookupByLibrary.simpleMessage("接続済み"),
    "connections": MessageLookupByLibrary.simpleMessage("接続"),
    "connectionsDesc": MessageLookupByLibrary.simpleMessage("現在の接続データを表示"),
    "connectivity": MessageLookupByLibrary.simpleMessage("接続性："),
    "contactMe": MessageLookupByLibrary.simpleMessage("連絡する"),
    "contactSupport": MessageLookupByLibrary.simpleMessage("サポート"),
    "content": MessageLookupByLibrary.simpleMessage("内容"),
    "contentScheme": MessageLookupByLibrary.simpleMessage("コンテンツテーマ"),
    "copiedToClipboard": MessageLookupByLibrary.simpleMessage(
      "クリップボードにコピーしました",
    ),
    "copy": MessageLookupByLibrary.simpleMessage("コピー"),
    "copyEnvVar": MessageLookupByLibrary.simpleMessage("環境変数をコピー"),
    "copyInviteLink": MessageLookupByLibrary.simpleMessage("リンクをコピー"),
    "copyLink": MessageLookupByLibrary.simpleMessage("リンクをコピー"),
    "copySuccess": MessageLookupByLibrary.simpleMessage("コピー成功"),
    "core": MessageLookupByLibrary.simpleMessage("コア"),
    "coreInfo": MessageLookupByLibrary.simpleMessage("コア情報"),
    "country": MessageLookupByLibrary.simpleMessage("国"),
    "crashTest": MessageLookupByLibrary.simpleMessage("クラッシュテスト"),
    "create": MessageLookupByLibrary.simpleMessage("作成"),
    "createAccount": MessageLookupByLibrary.simpleMessage("アカウントを作成"),
    "credentialsSaved": MessageLookupByLibrary.simpleMessage("認証情報を保存しました"),
    "currentCommissionRate": m2,
    "cut": MessageLookupByLibrary.simpleMessage("切り取り"),
    "dark": MessageLookupByLibrary.simpleMessage("ダーク"),
    "dashboard": MessageLookupByLibrary.simpleMessage("ダッシュボード"),
    "days": MessageLookupByLibrary.simpleMessage("日"),
    "defaultNameserver": MessageLookupByLibrary.simpleMessage("デフォルトネームサーバー"),
    "defaultNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "DNSサーバーの解決用",
    ),
    "defaultSort": MessageLookupByLibrary.simpleMessage("デフォルト順"),
    "defaultText": MessageLookupByLibrary.simpleMessage("デフォルト"),
    "delay": MessageLookupByLibrary.simpleMessage("遅延"),
    "delaySort": MessageLookupByLibrary.simpleMessage("遅延順"),
    "delete": MessageLookupByLibrary.simpleMessage("削除"),
    "deleteMultipTip": m3,
    "deleteTip": m4,
    "desc": MessageLookupByLibrary.simpleMessage(
      "ClashMetaベースのマルチプラットフォームプロキシクライアント",
    ),
    "detectionTip": MessageLookupByLibrary.simpleMessage("サードパーティAPIに依存（参考値）"),
    "developerMode": MessageLookupByLibrary.simpleMessage("デベロッパーモード"),
    "developerModeEnableTip": MessageLookupByLibrary.simpleMessage(
      "デベロッパーモードが有効になりました。",
    ),
    "direct": MessageLookupByLibrary.simpleMessage("ダイレクト"),
    "disclaimer": MessageLookupByLibrary.simpleMessage("重要なお知らせ"),
    "disclaimerDesc": MessageLookupByLibrary.simpleMessage(
      "このソフトウェアは現在公開ベータ段階です。更新の通知を受け取った場合は、速やかに更新してください。古いバージョンではサービスが不安定になったり、使用できなくなる場合があります。",
    ),
    "discoverNewVersion": MessageLookupByLibrary.simpleMessage("新バージョンを発見"),
    "discovery": MessageLookupByLibrary.simpleMessage("新しいバージョンを発見"),
    "dnsDesc": MessageLookupByLibrary.simpleMessage("DNS関連設定の更新"),
    "dnsMode": MessageLookupByLibrary.simpleMessage("DNSモード"),
    "doYouWantToPass": MessageLookupByLibrary.simpleMessage("通過させますか？"),
    "domain": MessageLookupByLibrary.simpleMessage("ドメイン"),
    "domainStatusAvailable": MessageLookupByLibrary.simpleMessage("サービス利用可能"),
    "domainStatusChecking": MessageLookupByLibrary.simpleMessage("確認中..."),
    "domainStatusUnavailable": MessageLookupByLibrary.simpleMessage("サービス利用不可"),
    "download": MessageLookupByLibrary.simpleMessage("ダウンロード"),
    "edit": MessageLookupByLibrary.simpleMessage("編集"),
    "emailAddress": MessageLookupByLibrary.simpleMessage("メールアドレス"),
    "emailVerificationCode": MessageLookupByLibrary.simpleMessage("メール確認コード"),
    "emptyTip": m5,
    "en": MessageLookupByLibrary.simpleMessage("英語"),
    "enableOverride": MessageLookupByLibrary.simpleMessage("上書きを有効化"),
    "enterEmailForReset": MessageLookupByLibrary.simpleMessage(
      "メールアドレスを入力してください。確認コードを送信します",
    ),
    "enterTransferAmount": MessageLookupByLibrary.simpleMessage("振替金額を入力"),
    "enterTransferAmountError": MessageLookupByLibrary.simpleMessage(
      "振替金額を入力してください",
    ),
    "entries": MessageLookupByLibrary.simpleMessage(" エントリ"),
    "exclude": MessageLookupByLibrary.simpleMessage("最近のタスクから非表示"),
    "excludeDesc": MessageLookupByLibrary.simpleMessage(
      "アプリがバックグラウンド時に最近のタスクから非表示",
    ),
    "existsTip": m6,
    "exit": MessageLookupByLibrary.simpleMessage("終了"),
    "expand": MessageLookupByLibrary.simpleMessage("標準"),
    "expirationTime": MessageLookupByLibrary.simpleMessage("有効期限"),
    "exportFile": MessageLookupByLibrary.simpleMessage("ファイルをエクスポート"),
    "exportLogs": MessageLookupByLibrary.simpleMessage("ログをエクスポート"),
    "exportSuccess": MessageLookupByLibrary.simpleMessage("エクスポート成功"),
    "expressiveScheme": MessageLookupByLibrary.simpleMessage("エクスプレッシブ"),
    "externalController": MessageLookupByLibrary.simpleMessage("外部コントローラー"),
    "externalControllerDesc": MessageLookupByLibrary.simpleMessage(
      "有効化するとClashコアをポート9090で制御可能",
    ),
    "externalLink": MessageLookupByLibrary.simpleMessage("外部リンク"),
    "externalResources": MessageLookupByLibrary.simpleMessage("外部リソース"),
    "fakeipFilter": MessageLookupByLibrary.simpleMessage("Fakeipフィルター"),
    "fakeipRange": MessageLookupByLibrary.simpleMessage("Fakeip範囲"),
    "fallback": MessageLookupByLibrary.simpleMessage("フォールバック"),
    "fallbackDesc": MessageLookupByLibrary.simpleMessage("通常はオフショアDNSを使用"),
    "fallbackFilter": MessageLookupByLibrary.simpleMessage("フォールバックフィルター"),
    "fidelityScheme": MessageLookupByLibrary.simpleMessage("ハイファイデリティー"),
    "file": MessageLookupByLibrary.simpleMessage("ファイル"),
    "fileDesc": MessageLookupByLibrary.simpleMessage("プロファイルを直接アップロード"),
    "fileIsUpdate": MessageLookupByLibrary.simpleMessage(
      "ファイルが変更されました。保存しますか？",
    ),
    "fillInfoToRegister": MessageLookupByLibrary.simpleMessage(
      "以下の情報を入力して登録を完了してください",
    ),
    "filterSystemApp": MessageLookupByLibrary.simpleMessage("システムアプリを除外"),
    "findProcessMode": MessageLookupByLibrary.simpleMessage("プロセス検出"),
    "findProcessModeDesc": MessageLookupByLibrary.simpleMessage(
      "有効化するとパフォーマンスが若干低下します",
    ),
    "fontFamily": MessageLookupByLibrary.simpleMessage("フォントファミリー"),
    "forgotPassword": MessageLookupByLibrary.simpleMessage("パスワードをお忘れですか"),
    "fourColumns": MessageLookupByLibrary.simpleMessage("4列"),
    "friendInviteReward": MessageLookupByLibrary.simpleMessage(
      "招待した友だちが支払うとコミッションを獲得できます",
    ),
    "fruitSaladScheme": MessageLookupByLibrary.simpleMessage("フルーツサラダ"),
    "general": MessageLookupByLibrary.simpleMessage("一般"),
    "generalDesc": MessageLookupByLibrary.simpleMessage("一般設定を変更"),
    "generateInviteCode": MessageLookupByLibrary.simpleMessage("招待コードを生成"),
    "generatingInviteCode": MessageLookupByLibrary.simpleMessage(
      "招待コードを生成中...",
    ),
    "geoData": MessageLookupByLibrary.simpleMessage("地域データ"),
    "geodataLoader": MessageLookupByLibrary.simpleMessage("Geo低メモリモード"),
    "geodataLoaderDesc": MessageLookupByLibrary.simpleMessage(
      "有効化するとGeo低メモリローダーを使用",
    ),
    "geoipCode": MessageLookupByLibrary.simpleMessage("GeoIPコード"),
    "getOriginRules": MessageLookupByLibrary.simpleMessage("元のルールを取得"),
    "global": MessageLookupByLibrary.simpleMessage("グローバルプロキシ"),
    "go": MessageLookupByLibrary.simpleMessage("移動"),
    "goDownload": MessageLookupByLibrary.simpleMessage("ダウンロードへ"),
    "goToWeb": MessageLookupByLibrary.simpleMessage("Webへ移動"),
    "hasCacheChange": MessageLookupByLibrary.simpleMessage("変更をキャッシュしますか？"),
    "hostsDesc": MessageLookupByLibrary.simpleMessage("ホストを追加"),
    "hotkeyConflict": MessageLookupByLibrary.simpleMessage("ホットキー競合"),
    "hotkeyManagement": MessageLookupByLibrary.simpleMessage("ホットキー管理"),
    "hotkeyManagementDesc": MessageLookupByLibrary.simpleMessage(
      "キーボードでアプリを制御",
    ),
    "hours": MessageLookupByLibrary.simpleMessage("時間"),
    "iUnderstand": MessageLookupByLibrary.simpleMessage("了解しました"),
    "icon": MessageLookupByLibrary.simpleMessage("アイコン"),
    "iconConfiguration": MessageLookupByLibrary.simpleMessage("アイコン設定"),
    "iconStyle": MessageLookupByLibrary.simpleMessage("アイコンスタイル"),
    "import": MessageLookupByLibrary.simpleMessage("インポート"),
    "importFile": MessageLookupByLibrary.simpleMessage("ファイルからインポート"),
    "importFromURL": MessageLookupByLibrary.simpleMessage("URLからインポート"),
    "importUrl": MessageLookupByLibrary.simpleMessage("URLからインポート"),
    "infiniteTime": MessageLookupByLibrary.simpleMessage("長期有効"),
    "init": MessageLookupByLibrary.simpleMessage("初期化"),
    "inputCorrectHotkey": MessageLookupByLibrary.simpleMessage("正しいホットキーを入力"),
    "intelligentSelected": MessageLookupByLibrary.simpleMessage("インテリジェント選択"),
    "internet": MessageLookupByLibrary.simpleMessage("インターネット"),
    "interval": MessageLookupByLibrary.simpleMessage("インターバル"),
    "intranetIP": MessageLookupByLibrary.simpleMessage("イントラネットIP"),
    "invalidTransferAmount": MessageLookupByLibrary.simpleMessage(
      "有効な振替金額を入力してください",
    ),
    "invite": MessageLookupByLibrary.simpleMessage("招待"),
    "inviteCode": MessageLookupByLibrary.simpleMessage("招待コード"),
    "inviteCodeGenFailed": MessageLookupByLibrary.simpleMessage(
      "招待コードの生成に失敗しました",
    ),
    "subscriptionUpdateSuccess": MessageLookupByLibrary.simpleMessage("サブスクリプションを更新しました"),
    "subscriptionImportSuccess": MessageLookupByLibrary.simpleMessage("サブスクリプションをインポートしました"),
    "inviteCodeGenerated": MessageLookupByLibrary.simpleMessage("招待コードを生成しました"),
    "inviteCodeOptional": MessageLookupByLibrary.simpleMessage("招待コード（任意）"),
    "inviteCodeRequired": MessageLookupByLibrary.simpleMessage("招待コードが必要です"),
    "inviteCodeRequiredMessage": MessageLookupByLibrary.simpleMessage(
      "登録には招待コードが必要です。登録済みユーザーに連絡して招待コードを取得してから登録してください。",
    ),
    "inviteLinkCopied": MessageLookupByLibrary.simpleMessage(
      "招待リンクをコピーしました。友だちに共有してください",
    ),
    "inviteRegisterReward": MessageLookupByLibrary.simpleMessage(
      "友だちを招待して登録・購読してもらうとコミッションを獲得できます",
    ),
    "inviteRules": MessageLookupByLibrary.simpleMessage("招待ルール"),
    "inviteStats": MessageLookupByLibrary.simpleMessage("招待統計"),
    "ipcidr": MessageLookupByLibrary.simpleMessage("IPCIDR"),
    "ipv6Desc": MessageLookupByLibrary.simpleMessage("有効化するとIPv6トラフィックを受信可能"),
    "ipv6InboundDesc": MessageLookupByLibrary.simpleMessage("IPv6インバウンドを許可"),
    "ja": MessageLookupByLibrary.simpleMessage("日本語"),
    "just": MessageLookupByLibrary.simpleMessage("たった今"),
    "keepAliveIntervalDesc": MessageLookupByLibrary.simpleMessage(
      "TCPキープアライブ間隔",
    ),
    "key": MessageLookupByLibrary.simpleMessage("キー"),
    "ko": MessageLookupByLibrary.simpleMessage("韓国語"),
    "language": MessageLookupByLibrary.simpleMessage("言語"),
    "layout": MessageLookupByLibrary.simpleMessage("レイアウト"),
    "light": MessageLookupByLibrary.simpleMessage("ライト"),
    "list": MessageLookupByLibrary.simpleMessage("リスト"),
    "listen": MessageLookupByLibrary.simpleMessage("リスン"),
    "loadMore": MessageLookupByLibrary.simpleMessage("さらに読み込む"),
    "loading": MessageLookupByLibrary.simpleMessage("読み込み中..."),
    "local": MessageLookupByLibrary.simpleMessage("ローカル"),
    "localBackupDesc": MessageLookupByLibrary.simpleMessage("ローカルにデータをバックアップ"),
    "localRecoveryDesc": MessageLookupByLibrary.simpleMessage("ファイルからデータを復元"),
    "logLevel": MessageLookupByLibrary.simpleMessage("ログレベル"),
    "logcat": MessageLookupByLibrary.simpleMessage("ログキャット"),
    "logcatDesc": MessageLookupByLibrary.simpleMessage("無効化するとログエントリを非表示"),
    "loggedOutSuccess": MessageLookupByLibrary.simpleMessage("ログアウトしました"),
    "loginNow": MessageLookupByLibrary.simpleMessage("今すぐログイン"),
    "logout": MessageLookupByLibrary.simpleMessage("ログアウト"),
    "logoutConfirmMsg": MessageLookupByLibrary.simpleMessage(
      "現在のアカウントから退出しますか？再度ログインが必要です。",
    ),
    "logoutFailed": m7,
    "logs": MessageLookupByLibrary.simpleMessage("ログ"),
    "logsDesc": MessageLookupByLibrary.simpleMessage("ログキャプチャ記録"),
    "logsTest": MessageLookupByLibrary.simpleMessage("ログテスト"),
    "loopback": MessageLookupByLibrary.simpleMessage("ループバック解除ツール"),
    "loopbackDesc": MessageLookupByLibrary.simpleMessage("UWPループバック解除用"),
    "loose": MessageLookupByLibrary.simpleMessage("疎"),
    "maxTransferable": m8,
    "memoryInfo": MessageLookupByLibrary.simpleMessage("メモリ情報"),
    "messageTest": MessageLookupByLibrary.simpleMessage("メッセージテスト"),
    "messageTestTip": MessageLookupByLibrary.simpleMessage("これはメッセージです。"),
    "min": MessageLookupByLibrary.simpleMessage("最小化"),
    "minimizeOnExit": MessageLookupByLibrary.simpleMessage("終了時に最小化"),
    "minimizeOnExitDesc": MessageLookupByLibrary.simpleMessage(
      "システムの終了イベントを変更",
    ),
    "minutes": MessageLookupByLibrary.simpleMessage("分"),
    "mixedPort": MessageLookupByLibrary.simpleMessage("混合ポート"),
    "mode": MessageLookupByLibrary.simpleMessage("モード"),
    "monochromeScheme": MessageLookupByLibrary.simpleMessage("モノクローム"),
    "months": MessageLookupByLibrary.simpleMessage("月"),
    "more": MessageLookupByLibrary.simpleMessage("詳細"),
    "myInviteQr": MessageLookupByLibrary.simpleMessage("マイ招待QR"),
    "name": MessageLookupByLibrary.simpleMessage("名前"),
    "nameSort": MessageLookupByLibrary.simpleMessage("名前順"),
    "nameserver": MessageLookupByLibrary.simpleMessage("ネームサーバー"),
    "nameserverDesc": MessageLookupByLibrary.simpleMessage("ドメイン解決用"),
    "nameserverPolicy": MessageLookupByLibrary.simpleMessage("ネームサーバーポリシー"),
    "nameserverPolicyDesc": MessageLookupByLibrary.simpleMessage(
      "対応するネームサーバーポリシーを指定",
    ),
    "network": MessageLookupByLibrary.simpleMessage("ネットワーク"),
    "networkDesc": MessageLookupByLibrary.simpleMessage("ネットワーク関連設定の変更"),
    "networkDetection": MessageLookupByLibrary.simpleMessage("ネットワーク検出"),
    "networkSpeed": MessageLookupByLibrary.simpleMessage("ネットワーク速度"),
    "neutralScheme": MessageLookupByLibrary.simpleMessage("ニュートラル"),
    "newMessageFromSupport": MessageLookupByLibrary.simpleMessage(
      "サポートから新しいメッセージがあります",
    ),
    "newPassword": MessageLookupByLibrary.simpleMessage("新しいパスワード"),
    "noCommissionRecord": MessageLookupByLibrary.simpleMessage("コミッション記録なし"),
    "noData": MessageLookupByLibrary.simpleMessage("データなし"),
    "noHotKey": MessageLookupByLibrary.simpleMessage("ホットキーなし"),
    "noIcon": MessageLookupByLibrary.simpleMessage("なし"),
    "noInfo": MessageLookupByLibrary.simpleMessage("情報なし"),
    "noInvitationData": MessageLookupByLibrary.simpleMessage("招待データなし"),
    "noInviteCode": MessageLookupByLibrary.simpleMessage("招待コードはありません"),
    "noMoreInfoDesc": MessageLookupByLibrary.simpleMessage("追加情報なし"),
    "noNetwork": MessageLookupByLibrary.simpleMessage("ネットワークなし"),
    "noNetworkApp": MessageLookupByLibrary.simpleMessage("ネットワークなしアプリ"),
    "noProxy": MessageLookupByLibrary.simpleMessage("プロキシなし"),
    "noProxyDesc": MessageLookupByLibrary.simpleMessage(
      "プロファイルを作成するか、有効なプロファイルを追加してください",
    ),
    "noResolve": MessageLookupByLibrary.simpleMessage("IPを解決しない"),
    "none": MessageLookupByLibrary.simpleMessage("なし"),
    "notConnected": MessageLookupByLibrary.simpleMessage("未接続"),
    "notSelectedTip": MessageLookupByLibrary.simpleMessage(
      "現在のプロキシグループは選択できません",
    ),
    "nullProfileDesc": MessageLookupByLibrary.simpleMessage(
      "プロファイルがありません。追加してください",
    ),
    "nullTip": m9,
    "numberTip": m10,
    "officialWebsite": MessageLookupByLibrary.simpleMessage("公式サイト"),
    "oneColumn": MessageLookupByLibrary.simpleMessage("1列"),
    "onlineSupport": MessageLookupByLibrary.simpleMessage("オンラインサポート"),
    "onlineSupportAddMore": MessageLookupByLibrary.simpleMessage("さらに追加"),
    "onlineSupportApiConfigNotFound": MessageLookupByLibrary.simpleMessage(
      "オンラインサポートAPI設定が見つかりません。設定を確認してください",
    ),
    "onlineSupportCancel": MessageLookupByLibrary.simpleMessage("キャンセル"),
    "onlineSupportClearHistory": MessageLookupByLibrary.simpleMessage("履歴をクリア"),
    "onlineSupportClearHistoryConfirm": MessageLookupByLibrary.simpleMessage(
      "すべてのチャット履歴をクリアしてもよろしいですか？この操作は元に戻せません。",
    ),
    "onlineSupportClickToSelect": MessageLookupByLibrary.simpleMessage(
      "クリックして画像を選択",
    ),
    "onlineSupportConfirm": MessageLookupByLibrary.simpleMessage("確認"),
    "onlineSupportConnected": MessageLookupByLibrary.simpleMessage(
      "サポートシステムに正常に接続しました",
    ),
    "onlineSupportConnecting": MessageLookupByLibrary.simpleMessage("接続中..."),
    "onlineSupportConnectionError": MessageLookupByLibrary.simpleMessage(
      "接続エラー",
    ),
    "onlineSupportDisconnected": MessageLookupByLibrary.simpleMessage(
      "切断されました",
    ),
    "onlineSupportGetMessagesFailed": m11,
    "onlineSupportInputHint": MessageLookupByLibrary.simpleMessage(
      "ご質問を入力してください...",
    ),
    "onlineSupportNoMessages": MessageLookupByLibrary.simpleMessage(
      "メッセージがありません。メッセージを送信して相談を開始してください",
    ),
    "onlineSupportSelectImages": MessageLookupByLibrary.simpleMessage("画像を選択"),
    "onlineSupportSelectImagesFailed": m12,
    "onlineSupportSend": MessageLookupByLibrary.simpleMessage("送信"),
    "onlineSupportSendImage": MessageLookupByLibrary.simpleMessage("画像を送信"),
    "onlineSupportSendMessageFailed": MessageLookupByLibrary.simpleMessage(
      "メッセージの送信に失敗しました: 認証トークンを取得できません",
    ),
    "onlineSupportSupportedFormats": MessageLookupByLibrary.simpleMessage(
      "JPG、PNG、GIF、WebP、BMP対応\n最大10MB",
    ),
    "onlineSupportTitle": MessageLookupByLibrary.simpleMessage("オンラインサポート"),
    "onlineSupportTokenNotFound": MessageLookupByLibrary.simpleMessage(
      "認証トークンが見つかりません",
    ),
    "onlineSupportUnsupportedHttpMethod": m13,
    "onlineSupportUploadFailed": m14,
    "onlineSupportWebSocketConfigNotFound":
        MessageLookupByLibrary.simpleMessage(
          "オンラインサポートWebSocket設定が見つかりません。設定を確認してください",
        ),
    "onlyIcon": MessageLookupByLibrary.simpleMessage("アイコンのみ"),
    "onlyOtherApps": MessageLookupByLibrary.simpleMessage("サードパーティアプリのみ"),
    "onlyStatisticsProxy": MessageLookupByLibrary.simpleMessage("プロキシのみ統計"),
    "onlyStatisticsProxyDesc": MessageLookupByLibrary.simpleMessage(
      "有効化するとプロキシトラフィックのみ統計",
    ),
    "openWebFailed": MessageLookupByLibrary.simpleMessage(
      "Webを開けませんでした。手動でアクセスしてください",
    ),
    "options": MessageLookupByLibrary.simpleMessage("オプション"),
    "orderAmount": m15,
    "orderNumber": m16,
    "other": MessageLookupByLibrary.simpleMessage("その他"),
    "otherContributors": MessageLookupByLibrary.simpleMessage("その他の貢献者"),
    "outboundMode": MessageLookupByLibrary.simpleMessage("アウトバウンドモード"),
    "override": MessageLookupByLibrary.simpleMessage("上書き"),
    "overrideDesc": MessageLookupByLibrary.simpleMessage("プロキシ関連設定を上書き"),
    "overrideDns": MessageLookupByLibrary.simpleMessage("DNS上書き"),
    "overrideDnsDesc": MessageLookupByLibrary.simpleMessage(
      "有効化するとプロファイルのDNS設定を上書き",
    ),
    "overrideInvalidTip": MessageLookupByLibrary.simpleMessage(
      "スクリプトモードでは有効になりません",
    ),
    "overrideOriginRules": MessageLookupByLibrary.simpleMessage("元のルールを上書き"),
    "pageNumber": m17,
    "palette": MessageLookupByLibrary.simpleMessage("パレット"),
    "password": MessageLookupByLibrary.simpleMessage("パスワード"),
    "passwordMin8Chars": MessageLookupByLibrary.simpleMessage(
      "パスワードは8文字以上である必要があります",
    ),
    "passwordMinLength": MessageLookupByLibrary.simpleMessage(
      "パスワードは6文字以上である必要があります",
    ),
    "passwordMismatch": MessageLookupByLibrary.simpleMessage("パスワードが一致しません"),
    "passwordResetFailed": MessageLookupByLibrary.simpleMessage(
      "パスワードのリセットに失敗しました",
    ),
    "passwordResetSuccessful": MessageLookupByLibrary.simpleMessage(
      "パスワードをリセットしました。新しいパスワードでログインしてください",
    ),
    "passwordsDoNotMatch": MessageLookupByLibrary.simpleMessage("パスワードが一致しません"),
    "paste": MessageLookupByLibrary.simpleMessage("貼り付け"),
    "pendingCommission": MessageLookupByLibrary.simpleMessage("保留中"),
    "plans": MessageLookupByLibrary.simpleMessage("プラン"),
    "pleaseBindWebDAV": MessageLookupByLibrary.simpleMessage(
      "WebDAVをバインドしてください",
    ),
    "pleaseConfirmNewPassword": MessageLookupByLibrary.simpleMessage(
      "新しいパスワードを再入力してください",
    ),
    "pleaseConfirmPassword": MessageLookupByLibrary.simpleMessage(
      "パスワードを確認してください",
    ),
    "pleaseEnterAtLeast8CharsPassword": MessageLookupByLibrary.simpleMessage(
      "8文字以上のパスワードを入力してください",
    ),
    "pleaseEnterEmail": MessageLookupByLibrary.simpleMessage(
      "メールアドレスを入力してください",
    ),
    "pleaseEnterEmailAddress": MessageLookupByLibrary.simpleMessage(
      "メールアドレスを入力してください",
    ),
    "pleaseEnterEmailVerificationCode": MessageLookupByLibrary.simpleMessage(
      "メール確認コードを入力してください",
    ),
    "pleaseEnterInviteCode": MessageLookupByLibrary.simpleMessage(
      "招待コードを入力してください",
    ),
    "pleaseEnterNewPassword": MessageLookupByLibrary.simpleMessage(
      "新しいパスワードを入力してください",
    ),
    "pleaseEnterPassword": MessageLookupByLibrary.simpleMessage(
      "パスワードを入力してください",
    ),
    "pleaseEnterScriptName": MessageLookupByLibrary.simpleMessage(
      "スクリプト名を入力してください",
    ),
    "pleaseEnterValidEmail": MessageLookupByLibrary.simpleMessage(
      "有効なメールアドレスを入力してください",
    ),
    "pleaseEnterValidEmailAddress": MessageLookupByLibrary.simpleMessage(
      "有効なメールアドレスを入力してください",
    ),
    "pleaseEnterValidVerificationCode": MessageLookupByLibrary.simpleMessage(
      "有効な確認コードを入力してください",
    ),
    "pleaseEnterVerificationCode": MessageLookupByLibrary.simpleMessage(
      "メール確認コードを入力してください",
    ),
    "pleaseEnterWithdrawAccount": MessageLookupByLibrary.simpleMessage(
      "出金口座を入力してください",
    ),
    "pleaseEnterYourEmailAddress": MessageLookupByLibrary.simpleMessage(
      "メールアドレスを入力してください",
    ),
    "pleaseInputAdminPassword": MessageLookupByLibrary.simpleMessage(
      "管理者パスワードを入力",
    ),
    "pleaseReEnterPassword": MessageLookupByLibrary.simpleMessage(
      "パスワードを再入力してください",
    ),
    "pleaseSelectWithdrawMethod": MessageLookupByLibrary.simpleMessage(
      "出金方法を選択してください",
    ),
    "pleaseUploadFile": MessageLookupByLibrary.simpleMessage(
      "ファイルをアップロードしてください",
    ),
    "pleaseUploadValidQrcode": MessageLookupByLibrary.simpleMessage(
      "有効なQRコードをアップロードしてください",
    ),
    "port": MessageLookupByLibrary.simpleMessage("ポート"),
    "portConflictTip": MessageLookupByLibrary.simpleMessage("別のポートを入力してください"),
    "portTip": m18,
    "preferH3Desc": MessageLookupByLibrary.simpleMessage("DOHのHTTP/3を優先使用"),
    "pressKeyboard": MessageLookupByLibrary.simpleMessage("キーボードを押してください"),
    "preview": MessageLookupByLibrary.simpleMessage("プレビュー"),
    "profile": MessageLookupByLibrary.simpleMessage("プロファイル"),
    "profileAutoUpdateIntervalInvalidValidationDesc":
        MessageLookupByLibrary.simpleMessage("有効な間隔形式を入力してください"),
    "profileAutoUpdateIntervalNullValidationDesc":
        MessageLookupByLibrary.simpleMessage("自動更新間隔を入力してください"),
    "profileHasUpdate": MessageLookupByLibrary.simpleMessage(
      "プロファイルが変更されました。自動更新を無効化しますか？",
    ),
    "profileNameNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "プロファイル名を入力してください",
    ),
    "profileParseErrorDesc": MessageLookupByLibrary.simpleMessage(
      "プロファイル解析エラー",
    ),
    "profileUrlInvalidValidationDesc": MessageLookupByLibrary.simpleMessage(
      "有効なプロファイルURLを入力してください",
    ),
    "profileUrlNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "プロファイルURLを入力してください",
    ),
    "profiles": MessageLookupByLibrary.simpleMessage("プロファイル一覧"),
    "profilesSort": MessageLookupByLibrary.simpleMessage("プロファイルの並び替え"),
    "project": MessageLookupByLibrary.simpleMessage("プロジェクト"),
    "providers": MessageLookupByLibrary.simpleMessage("プロバイダー"),
    "proxies": MessageLookupByLibrary.simpleMessage("プロキシ"),
    "proxiesSetting": MessageLookupByLibrary.simpleMessage("プロキシ設定"),
    "proxyGroup": MessageLookupByLibrary.simpleMessage("プロキシグループ"),
    "proxyNameserver": MessageLookupByLibrary.simpleMessage("プロキシネームサーバー"),
    "proxyNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "プロキシノード解決用ドメイン",
    ),
    "proxyPort": MessageLookupByLibrary.simpleMessage("プロキシポート"),
    "proxyPortDesc": MessageLookupByLibrary.simpleMessage("Clashのリスニングポートを設定"),
    "proxyProviders": MessageLookupByLibrary.simpleMessage("プロキシプロバイダー"),
    "pureBlackMode": MessageLookupByLibrary.simpleMessage("純黒モード"),
    "qrcode": MessageLookupByLibrary.simpleMessage("QRコード"),
    "qrcodeDesc": MessageLookupByLibrary.simpleMessage("QRコードをスキャンしてプロファイルを取得"),
    "rainbowScheme": MessageLookupByLibrary.simpleMessage("レインボー"),
    "recovery": MessageLookupByLibrary.simpleMessage("復元"),
    "recoveryAll": MessageLookupByLibrary.simpleMessage("全データ復元"),
    "recoveryProfiles": MessageLookupByLibrary.simpleMessage("プロファイルのみ復元"),
    "recoveryStrategy": MessageLookupByLibrary.simpleMessage("リカバリー戦略"),
    "recoveryStrategy_compatible": MessageLookupByLibrary.simpleMessage("互換性"),
    "recoveryStrategy_override": MessageLookupByLibrary.simpleMessage(
      "オーバーライド",
    ),
    "recoverySuccess": MessageLookupByLibrary.simpleMessage("復元成功"),
    "redirPort": MessageLookupByLibrary.simpleMessage("Redirポート"),
    "redo": MessageLookupByLibrary.simpleMessage("やり直す"),
    "refresh": MessageLookupByLibrary.simpleMessage("更新"),
    "regExp": MessageLookupByLibrary.simpleMessage("正規表現"),
    "registerAccount": MessageLookupByLibrary.simpleMessage("アカウント登録"),
    "registerSuccessSaveCredentials": MessageLookupByLibrary.simpleMessage(
      "登録成功 - 認証情報を保存中:",
    ),
    "registrationFailed": m19,
    "rememberPassword": MessageLookupByLibrary.simpleMessage("パスワードを覚えていますか？"),
    "remote": MessageLookupByLibrary.simpleMessage("リモート"),
    "remoteBackupDesc": MessageLookupByLibrary.simpleMessage(
      "WebDAVにデータをバックアップ",
    ),
    "remoteRecoveryDesc": MessageLookupByLibrary.simpleMessage(
      "WebDAVからデータを復元",
    ),
    "remove": MessageLookupByLibrary.simpleMessage("削除"),
    "rename": MessageLookupByLibrary.simpleMessage("リネーム"),
    "requests": MessageLookupByLibrary.simpleMessage("リクエスト"),
    "requestsDesc": MessageLookupByLibrary.simpleMessage("最近のリクエスト記録を表示"),
    "resendVerificationCode": MessageLookupByLibrary.simpleMessage("確認コードを再送信"),
    "reset": MessageLookupByLibrary.simpleMessage("リセット"),
    "resetPassword": MessageLookupByLibrary.simpleMessage("パスワードをリセット"),
    "resetTip": MessageLookupByLibrary.simpleMessage("リセットを確定"),
    "resources": MessageLookupByLibrary.simpleMessage("リソース"),
    "resourcesDesc": MessageLookupByLibrary.simpleMessage("外部リソース関連情報"),
    "respectRules": MessageLookupByLibrary.simpleMessage("ルール尊重"),
    "respectRulesDesc": MessageLookupByLibrary.simpleMessage(
      "DNS接続がルールに従う（proxy-server-nameserverの設定が必要）",
    ),
    "routeAddress": MessageLookupByLibrary.simpleMessage("ルートアドレス"),
    "routeAddressDesc": MessageLookupByLibrary.simpleMessage("ルートアドレスを設定"),
    "routeMode": MessageLookupByLibrary.simpleMessage("ルートモード"),
    "routeMode_bypassPrivate": MessageLookupByLibrary.simpleMessage(
      "プライベートルートをバイパス",
    ),
    "routeMode_config": MessageLookupByLibrary.simpleMessage("設定を使用"),
    "rule": MessageLookupByLibrary.simpleMessage("スマートルーティング"),
    "ruleName": MessageLookupByLibrary.simpleMessage("ルール名"),
    "ruleProviders": MessageLookupByLibrary.simpleMessage("ルールプロバイダー"),
    "ruleTarget": MessageLookupByLibrary.simpleMessage("ルール対象"),
    "save": MessageLookupByLibrary.simpleMessage("保存"),
    "saveChanges": MessageLookupByLibrary.simpleMessage("変更を保存しますか？"),
    "saveQr": MessageLookupByLibrary.simpleMessage("QRを保存"),
    "saveQrCodeFeature": MessageLookupByLibrary.simpleMessage(
      "QR保存機能は近日対応予定です",
    ),
    "saveTip": MessageLookupByLibrary.simpleMessage("保存してもよろしいですか？"),
    "script": MessageLookupByLibrary.simpleMessage("スクリプト"),
    "search": MessageLookupByLibrary.simpleMessage("検索"),
    "seconds": MessageLookupByLibrary.simpleMessage("秒"),
    "selectAll": MessageLookupByLibrary.simpleMessage("すべて選択"),
    "selectTheme": MessageLookupByLibrary.simpleMessage("テーマを選択"),
    "selected": MessageLookupByLibrary.simpleMessage("選択済み"),
    "selectedCountTitle": m20,
    "sendCodeFailed": MessageLookupByLibrary.simpleMessage("確認コードの送信に失敗しました"),
    "sendVerificationCode": MessageLookupByLibrary.simpleMessage("確認コードを送信"),
    "sendVerificationCodeFailed": m21,
    "setNewPassword": MessageLookupByLibrary.simpleMessage("新しいパスワードを設定"),
    "settings": MessageLookupByLibrary.simpleMessage("設定"),
    "show": MessageLookupByLibrary.simpleMessage("ウィンドウを表示"),
    "shrink": MessageLookupByLibrary.simpleMessage("縮小"),
    "silentLaunch": MessageLookupByLibrary.simpleMessage("バックグラウンド起動"),
    "silentLaunchDesc": MessageLookupByLibrary.simpleMessage("バックグラウンドで起動"),
    "size": MessageLookupByLibrary.simpleMessage("サイズ"),
    "socksPort": MessageLookupByLibrary.simpleMessage("Socksポート"),
    "sort": MessageLookupByLibrary.simpleMessage("並び替え"),
    "source": MessageLookupByLibrary.simpleMessage("ソース"),
    "sourceIp": MessageLookupByLibrary.simpleMessage("送信元IP"),
    "stackMode": MessageLookupByLibrary.simpleMessage("スタックモード"),
    "standard": MessageLookupByLibrary.simpleMessage("標準"),
    "start": MessageLookupByLibrary.simpleMessage("接続"),
    "startVpn": MessageLookupByLibrary.simpleMessage("VPNを開始中..."),
    "status": MessageLookupByLibrary.simpleMessage("ステータス"),
    "statusDesc": MessageLookupByLibrary.simpleMessage("無効時はシステムDNSを使用"),
    "stop": MessageLookupByLibrary.simpleMessage("切断"),
    "stopVpn": MessageLookupByLibrary.simpleMessage("VPNを停止中..."),
    "style": MessageLookupByLibrary.simpleMessage("スタイル"),
    "subRule": MessageLookupByLibrary.simpleMessage("サブルール"),
    "submit": MessageLookupByLibrary.simpleMessage("送信"),
    "subscriptionExpired": MessageLookupByLibrary.simpleMessage(
      "サブスクリプションが期限切れです",
    ),
    "subscriptionExpiredDetail": m22,
    "subscriptionExpiresToday": MessageLookupByLibrary.simpleMessage(
      "サブスクリプションが本日期限切れ",
    ),
    "subscriptionExpiresTodayDetail": MessageLookupByLibrary.simpleMessage(
      "プランが本日期限切れになります。サービス中断を避けるため即座に更新してください",
    ),
    "subscriptionExpiringInDays": MessageLookupByLibrary.simpleMessage(
      "サブスクリプションがまもなく期限切れ",
    ),
    "subscriptionExpiringInDaysDetail": m23,
    "subscriptionNoSubscription": MessageLookupByLibrary.simpleMessage(
      "サブスクリプションがありません",
    ),
    "subscriptionNoSubscriptionDetail": MessageLookupByLibrary.simpleMessage(
      "利用可能なサブスクリプションプランが見つかりません。ご利用にはプランをご購入ください",
    ),
    "subscriptionNotLoggedIn": MessageLookupByLibrary.simpleMessage("未ログイン"),
    "subscriptionNotLoggedInDetail": MessageLookupByLibrary.simpleMessage(
      "まずログインしてください",
    ),
    "subscriptionTrafficExhausted": MessageLookupByLibrary.simpleMessage(
      "トラフィックを使い切りました",
    ),
    "subscriptionTrafficExhaustedDetail": MessageLookupByLibrary.simpleMessage(
      "プランのトラフィックを使い切りました。より多くのトラフィックを購入するかプランをアップグレードしてください",
    ),
    "subscriptionValid": MessageLookupByLibrary.simpleMessage("サブスクリプション有効"),
    "subscriptionValidDetail": m24,
    "switchTheme": MessageLookupByLibrary.simpleMessage("テーマを切り替え"),
    "sync": MessageLookupByLibrary.simpleMessage("同期"),
    "system": MessageLookupByLibrary.simpleMessage("システム"),
    "systemApp": MessageLookupByLibrary.simpleMessage("システムアプリ"),
    "systemFont": MessageLookupByLibrary.simpleMessage("システムフォント"),
    "systemProxy": MessageLookupByLibrary.simpleMessage("システムプロキシ"),
    "systemProxyDesc": MessageLookupByLibrary.simpleMessage(
      "HTTPプロキシをVpnServiceに接続",
    ),
    "tab": MessageLookupByLibrary.simpleMessage("タブ"),
    "tabAnimation": MessageLookupByLibrary.simpleMessage("タブアニメーション"),
    "tabAnimationDesc": MessageLookupByLibrary.simpleMessage("モバイル表示でのみ有効"),
    "tapToConnect": MessageLookupByLibrary.simpleMessage("タップして接続"),
    "tcpConcurrent": MessageLookupByLibrary.simpleMessage("TCP並列処理"),
    "tcpConcurrentDesc": MessageLookupByLibrary.simpleMessage("TCP並列処理を許可"),
    "testUrl": MessageLookupByLibrary.simpleMessage("URLテスト"),
    "textScale": MessageLookupByLibrary.simpleMessage("テキストスケーリング"),
    "theme": MessageLookupByLibrary.simpleMessage("テーマ"),
    "themeColor": MessageLookupByLibrary.simpleMessage("テーマカラー"),
    "themeDesc": MessageLookupByLibrary.simpleMessage("ダークモードの設定、色の調整"),
    "themeMode": MessageLookupByLibrary.simpleMessage("テーマモード"),
    "threeColumns": MessageLookupByLibrary.simpleMessage("3列"),
    "ticketRecords": MessageLookupByLibrary.simpleMessage("チケット"),
    "tight": MessageLookupByLibrary.simpleMessage("密"),
    "time": MessageLookupByLibrary.simpleMessage("時間"),
    "tip": MessageLookupByLibrary.simpleMessage("ヒント"),
    "toggle": MessageLookupByLibrary.simpleMessage("トグル"),
    "tonalSpotScheme": MessageLookupByLibrary.simpleMessage("トーンスポット"),
    "tools": MessageLookupByLibrary.simpleMessage("ツール"),
    "totalCommission": MessageLookupByLibrary.simpleMessage("収益"),
    "totalInvites": MessageLookupByLibrary.simpleMessage("招待数"),
    "totalRecords": m25,
    "tproxyPort": MessageLookupByLibrary.simpleMessage("Tproxyポート"),
    "trafficUsage": MessageLookupByLibrary.simpleMessage("トラフィック使用量"),
    "transfer": MessageLookupByLibrary.simpleMessage("振替"),
    "transferAmount": MessageLookupByLibrary.simpleMessage("振替金額"),
    "transferAmountExceeded": m26,
    "transferFailed": m27,
    "transferNote": MessageLookupByLibrary.simpleMessage(
      "振替後の残高はアプリ内購入に使用できます",
    ),
    "transferSuccess": MessageLookupByLibrary.simpleMessage("振替成功！"),
    "transferSuccessMsg": m28,
    "transferToWallet": MessageLookupByLibrary.simpleMessage("ウォレットへ振替"),
    "transferring": MessageLookupByLibrary.simpleMessage("振替中..."),
    "trayDisconnect": MessageLookupByLibrary.simpleMessage("接続を切断"),
    "trayStartConnection": MessageLookupByLibrary.simpleMessage("接続を開始"),
    "tun": MessageLookupByLibrary.simpleMessage("仮想ネットワークアダプタ（TUN）"),
    "tunDesc": MessageLookupByLibrary.simpleMessage("管理者モードでのみ有効"),
    "twoColumns": MessageLookupByLibrary.simpleMessage("2列"),
    "unableToUpdateCurrentProfileDesc": MessageLookupByLibrary.simpleMessage(
      "現在のプロファイルを更新できません",
    ),
    "undo": MessageLookupByLibrary.simpleMessage("元に戻す"),
    "unifiedDelay": MessageLookupByLibrary.simpleMessage("統一遅延"),
    "unifiedDelayDesc": MessageLookupByLibrary.simpleMessage(
      "ハンドシェイクなどの余分な遅延を削除",
    ),
    "unknown": MessageLookupByLibrary.simpleMessage("不明"),
    "unnamed": MessageLookupByLibrary.simpleMessage("無題"),
    "update": MessageLookupByLibrary.simpleMessage("更新"),
    "updateCheckAllServersUnavailable": MessageLookupByLibrary.simpleMessage(
      "設定されたすべてのアップデートサーバーが利用できません",
    ),
    "updateCheckCurrentVersion": m29,
    "updateCheckForceUpdate": m30,
    "updateCheckMustUpdate": MessageLookupByLibrary.simpleMessage("アップデート必須"),
    "updateCheckNewVersionFound": m31,
    "updateCheckNoServerUrlsConfigured": MessageLookupByLibrary.simpleMessage(
      "アップデートサーバーURLが設定されていません。設定を確認してください",
    ),
    "updateCheckReleaseNotes": MessageLookupByLibrary.simpleMessage("リリースノート："),
    "updateCheckServerError": m32,
    "updateCheckServerTemporarilyUnavailable":
        MessageLookupByLibrary.simpleMessage(
          "サーバーが一時的に利用できません。しばらくしてから再試行してください",
        ),
    "updateCheckServerUrlNotConfigured": MessageLookupByLibrary.simpleMessage(
      "アップデートサーバーURLが設定されていません。設定を確認してください",
    ),
    "updateCheckUpdateLater": MessageLookupByLibrary.simpleMessage("後でアップデート"),
    "updateCheckUpdateNow": MessageLookupByLibrary.simpleMessage("今すぐアップデート"),
    "upload": MessageLookupByLibrary.simpleMessage("アップロード"),
    "url": MessageLookupByLibrary.simpleMessage("URL"),
    "urlDesc": MessageLookupByLibrary.simpleMessage("URL経由でプロファイルを取得"),
    "urlTip": m33,
    "useHosts": MessageLookupByLibrary.simpleMessage("ホストを使用"),
    "useSystemHosts": MessageLookupByLibrary.simpleMessage("システムホストを使用"),
    "userCenter": MessageLookupByLibrary.simpleMessage("ユーザーセンター"),
    "value": MessageLookupByLibrary.simpleMessage("値"),
    "verificationCode": MessageLookupByLibrary.simpleMessage("確認コード"),
    "verificationCode6Digits": MessageLookupByLibrary.simpleMessage(
      "確認コードは6桁である必要があります",
    ),
    "verificationCodeSent": MessageLookupByLibrary.simpleMessage(
      "確認コードをメールに送信しました。ご確認ください",
    ),
    "verificationCodeSentCheckEmail": MessageLookupByLibrary.simpleMessage(
      "確認コードを送信しました。メールをご確認ください",
    ),
    "verificationCodeSentTo": m34,
    "vibrantScheme": MessageLookupByLibrary.simpleMessage("ビブラント"),
    "view": MessageLookupByLibrary.simpleMessage("表示"),
    "viewHistory": MessageLookupByLibrary.simpleMessage("履歴を表示"),
    "visitWebVersion": MessageLookupByLibrary.simpleMessage(
      "出金するにはWeb版をご利用ください",
    ),
    "vpnDesc": MessageLookupByLibrary.simpleMessage("VPN関連設定の変更"),
    "vpnEnableDesc": MessageLookupByLibrary.simpleMessage(
      "VpnService経由で全システムトラフィックをルーティング",
    ),
    "vpnSystemProxyDesc": MessageLookupByLibrary.simpleMessage(
      "HTTPプロキシをVpnServiceに接続",
    ),
    "vpnTip": MessageLookupByLibrary.simpleMessage("変更はVPN再起動後に有効"),
    "walletBalance": MessageLookupByLibrary.simpleMessage("残高"),
    "walletDetails": MessageLookupByLibrary.simpleMessage("ウォレット詳細"),
    "webDAVConfiguration": MessageLookupByLibrary.simpleMessage("WebDAV設定"),
    "whitelistMode": MessageLookupByLibrary.simpleMessage("ホワイトリストモード"),
    "withdraw": MessageLookupByLibrary.simpleMessage("出金"),
    "withdrawAccount": MessageLookupByLibrary.simpleMessage("出金口座"),
    "withdrawCommission": MessageLookupByLibrary.simpleMessage("コミッションを出金"),
    "withdrawMethod": MessageLookupByLibrary.simpleMessage("出金方法"),
    "withdrawRequestSubmitted": MessageLookupByLibrary.simpleMessage(
      "出金申請を送信しました",
    ),
    "withdrawRequestSubmittedWaitReview": MessageLookupByLibrary.simpleMessage(
      "出金申請を送信しました。確認をお待ちください",
    ),
    "withdrawSubmissionFailed": MessageLookupByLibrary.simpleMessage(
      "送信に失敗しました",
    ),
    "withdrawSubmissionFailedWithError": m35,
    "withdrawSubmissionNote": MessageLookupByLibrary.simpleMessage(
      "出金申請はチケットシステム経由で送信されます。管理者の確認をお待ちください。",
    ),
    "withdrawableAmount": m36,
    "withdrawalAvailable": MessageLookupByLibrary.simpleMessage(
      "利用可能なコミッションは出金できます",
    ),
    "xboard": MessageLookupByLibrary.simpleMessage("ホーム"),
    "xboard24HourCustomerService": MessageLookupByLibrary.simpleMessage(
      "24時間カスタマーサービスサポート",
    ),
    "xboardAccountBalance": MessageLookupByLibrary.simpleMessage("残高"),
    "xboardAccountBanned": MessageLookupByLibrary.simpleMessage("アカウント停止中"),
    "xboardAccountBannedDetail": MessageLookupByLibrary.simpleMessage(
      "このアカウントは停止されています。サポートにお問い合わせください。",
    ),
    "xboardAccountInfo": MessageLookupByLibrary.simpleMessage("マイアカウント"),
    "xboardAccountManagement": MessageLookupByLibrary.simpleMessage("アカウント管理"),
    "xboardActualPaidAmount": MessageLookupByLibrary.simpleMessage("支払金額"),
    "xboardAddLinkToConfig": MessageLookupByLibrary.simpleMessage(
      "設定にこのサブスクリプションリンクを追加",
    ),
    "xboardAddingToConfigList": MessageLookupByLibrary.simpleMessage(
      "設定リストに追加中",
    ),
    "xboardAfterPurchasingPlan": MessageLookupByLibrary.simpleMessage(
      "プラン購入後、あなたは以下を享受できます：",
    ),
    "xboardApiUrlNotConfigured": MessageLookupByLibrary.simpleMessage(
      "API URLが設定されていません",
    ),
    "xboardAutoCheckEvery5Seconds": MessageLookupByLibrary.simpleMessage(
      "システムが5秒ごとに自動チェックし、支払い完了後に自動リダイレクトします",
    ),
    "xboardAutoDetectPaymentStatus": MessageLookupByLibrary.simpleMessage(
      "支払い状況を自動検出",
    ),
    "xboardAutoOpeningPaymentPage": MessageLookupByLibrary.simpleMessage(
      "支払いページを自動的に開いています。支払い完了後はアプリに戻ってください",
    ),
    "xboardAutoTesting": MessageLookupByLibrary.simpleMessage("自動テスト中"),
    "xboardBack": MessageLookupByLibrary.simpleMessage("戻る"),
    "xboardBalancePay": MessageLookupByLibrary.simpleMessage("残高で支払う"),
    "xboardBalanceWithAmount": m37,
    "xboardBrowserNotOpenedTip": MessageLookupByLibrary.simpleMessage(
      "ブラウザが自動的に開かない場合は、\\\"再開\\\"をクリックするかリンクを手動でコピーしてください",
    ),
    "xboardBuyMoreTrafficOrUpgrade": MessageLookupByLibrary.simpleMessage(
      "より多くのトラフィックを購入するかプランをアップグレードしてください",
    ),
    "xboardBuyNow": MessageLookupByLibrary.simpleMessage("今すぐ購入"),
    "xboardBuyPlan": MessageLookupByLibrary.simpleMessage("プランを購入"),
    "xboardBuyoutPlan": MessageLookupByLibrary.simpleMessage("買い切りプラン"),
    "xboardCancel": MessageLookupByLibrary.simpleMessage("キャンセル"),
    "xboardCancelOrder": MessageLookupByLibrary.simpleMessage("注文をキャンセル"),
    "xboardCancelPayment": MessageLookupByLibrary.simpleMessage("支払いキャンセル"),
    "xboardCanceling": MessageLookupByLibrary.simpleMessage("キャンセル中..."),
    "xboardChangePassword": MessageLookupByLibrary.simpleMessage("パスワード変更"),
    "xboardCheckOrders": MessageLookupByLibrary.simpleMessage("注文を確認"),
    "xboardCheckPaymentFailed": MessageLookupByLibrary.simpleMessage(
      "支払い状況の確認に失敗しました",
    ),
    "xboardCheckPaymentStatus": MessageLookupByLibrary.simpleMessage(
      "支払い状況を確認",
    ),
    "xboardCheckStatus": MessageLookupByLibrary.simpleMessage("ステータス確認"),
    "xboardChecking": MessageLookupByLibrary.simpleMessage("確認中"),
    "xboardCheckingSubscription": MessageLookupByLibrary.simpleMessage(
      "サブスクリプションを確認中",
    ),
    "xboardCleaningOldConfig": MessageLookupByLibrary.simpleMessage(
      "古い設定をクリーン中",
    ),
    "xboardClearError": MessageLookupByLibrary.simpleMessage("エラーをクリア"),
    "xboardClickToCopy": MessageLookupByLibrary.simpleMessage("クリックしてコピー"),
    "xboardClickToSetupNodes": MessageLookupByLibrary.simpleMessage(
      "クリックしてノードを設定",
    ),
    "xboardCommissionConfirmed": MessageLookupByLibrary.simpleMessage("確認済み"),
    "xboardCommissionIssuing": MessageLookupByLibrary.simpleMessage("発行中"),
    "xboardCommissionOffsetAmount": MessageLookupByLibrary.simpleMessage(
      "コミッション充当額",
    ),
    "xboardCompletePaymentInBrowser": MessageLookupByLibrary.simpleMessage(
      "2. ブラウザで支払いを完了してください",
    ),
    "xboardConfigDownloadFailed": MessageLookupByLibrary.simpleMessage(
      "設定のダウンロードに失敗しました、サブスクリプションリンクを確認してください",
    ),
    "xboardConfigFormatError": MessageLookupByLibrary.simpleMessage(
      "設定形式エラー、サービスプロバイダーにお問い合わせください",
    ),
    "xboardConfigSaveFailed": MessageLookupByLibrary.simpleMessage(
      "設定の保存に失敗しました、ストレージ容量を確認してください",
    ),
    "xboardConfigurationError": MessageLookupByLibrary.simpleMessage("設定エラー"),
    "xboardConfirm": MessageLookupByLibrary.simpleMessage("確認"),
    "xboardConfirmAction": MessageLookupByLibrary.simpleMessage("確認"),
    "xboardConfirmChange": MessageLookupByLibrary.simpleMessage("変更を確認"),
    "xboardConfirmPassword": MessageLookupByLibrary.simpleMessage("パスワード確認"),
    "xboardConfirmPurchase": MessageLookupByLibrary.simpleMessage("購入を確認"),
    "xboardConfirmRenewPlan": MessageLookupByLibrary.simpleMessage("更新を確認"),
    "xboardConfirmResetTraffic": MessageLookupByLibrary.simpleMessage(
      "通信量リセットを確認",
    ),
    "xboardCongratulationsSubscriptionActivated":
        MessageLookupByLibrary.simpleMessage(
          "おめでとうございます！サブスクリプションが正常に購入され、有効化されました",
        ),
    "xboardConnectGlobalQualityNodes": MessageLookupByLibrary.simpleMessage(
      "グローバル品質ノードに接続",
    ),
    "xboardConnecting": MessageLookupByLibrary.simpleMessage("接続中"),
    "xboardConnectionHealth": MessageLookupByLibrary.simpleMessage("接続ヘルス"),
    "xboardConnectionHealthSubtitle": MessageLookupByLibrary.simpleMessage(
      "サーバー、サブスクリプション、ノード、デバイスの状態を確認",
    ),
    "xboardConnectionTimeout": MessageLookupByLibrary.simpleMessage(
      "接続タイムアウト、ネットワーク接続を確認してください",
    ),
    "xboardContactCustomerService": MessageLookupByLibrary.simpleMessage(
      "カスタマーサービス",
    ),
    "xboardCopyDiagnosticBundle": MessageLookupByLibrary.simpleMessage(
      "診断パックをコピー",
    ),
    "xboardCopyFailed": MessageLookupByLibrary.simpleMessage("コピーに失敗しました"),
    "xboardCopyInviteCode": MessageLookupByLibrary.simpleMessage("招待コードをコピー"),
    "xboardCopyInviteLink": MessageLookupByLibrary.simpleMessage("リンクをコピー"),
    "xboardCopyLink": MessageLookupByLibrary.simpleMessage("リンクをコピー"),
    "xboardCopyPaymentLink": MessageLookupByLibrary.simpleMessage("リンクをコピー"),
    "xboardCopySubscriptionLinkAbove": MessageLookupByLibrary.simpleMessage(
      "上記のサブスクリプションリンクをコピー",
    ),
    "xboardCoreStageCheckingHelper": MessageLookupByLibrary.simpleMessage(
      "helper を確認中",
    ),
    "xboardCoreStageConnected": MessageLookupByLibrary.simpleMessage("接続済み"),
    "xboardCoreStageCoreConnecting": MessageLookupByLibrary.simpleMessage(
      "Core に再接続中",
    ),
    "xboardCoreStageFailed": MessageLookupByLibrary.simpleMessage("接続に失敗しました"),
    "xboardCoreStageHelperReady": MessageLookupByLibrary.simpleMessage(
      "helper を再利用済み",
    ),
    "xboardCoreStageStartingService": MessageLookupByLibrary.simpleMessage(
      "サービスを起動中",
    ),
    "xboardCoreStageStopping": MessageLookupByLibrary.simpleMessage("切断中"),
    "xboardCoreStageTunApplying": MessageLookupByLibrary.simpleMessage(
      "TUN を適用中",
    ),
    "xboardCouponExpired": MessageLookupByLibrary.simpleMessage("クーポンが期限切れです"),
    "xboardCouponNotYetActive": MessageLookupByLibrary.simpleMessage(
      "クーポンはまだ有効ではありません",
    ),
    "xboardCouponOptional": MessageLookupByLibrary.simpleMessage("クーポン（オプション）"),
    "xboardCreateTicket": MessageLookupByLibrary.simpleMessage("チケットを作成"),
    "xboardCreateTicketHint": MessageLookupByLibrary.simpleMessage(
      "サポートに連絡するためのチケットを作成します。",
    ),
    "xboardCreatedAt": MessageLookupByLibrary.simpleMessage("作成日時"),
    "xboardCreatingOrder": MessageLookupByLibrary.simpleMessage("注文を作成中"),
    "xboardCreatingOrderPleaseWait": MessageLookupByLibrary.simpleMessage(
      "新しい注文を作成しています。お待ちください",
    ),
    "xboardCurrentBalance": MessageLookupByLibrary.simpleMessage("現在の残高"),
    "xboardCurrentBusinessApi": MessageLookupByLibrary.simpleMessage(
      "現在の業務API",
    ),
    "xboardCurrentDomain": MessageLookupByLibrary.simpleMessage("現在のドメイン"),
    "xboardCurrentGateway": MessageLookupByLibrary.simpleMessage("現在のゲートウェイ"),
    "xboardCurrentNode": MessageLookupByLibrary.simpleMessage("現在のノード"),
    "xboardCurrentPassword": MessageLookupByLibrary.simpleMessage("現在のパスワード"),
    "xboardCurrentPlanBased": MessageLookupByLibrary.simpleMessage("現在のプラン基準"),
    "xboardCurrentVersion": MessageLookupByLibrary.simpleMessage("現在のバージョン"),
    "xboardCustomRechargeAmount": MessageLookupByLibrary.simpleMessage(
      "任意のチャージ金額",
    ),
    "xboardDays": MessageLookupByLibrary.simpleMessage("日"),
    "xboardDeductedBalance": MessageLookupByLibrary.simpleMessage("差し引き残高"),
    "xboardDeductibleBalance": MessageLookupByLibrary.simpleMessage("使用可能残高"),
    "xboardDeductibleDuringPayment": MessageLookupByLibrary.simpleMessage(
      "支払い時に控除可能",
    ),
    "xboardDeviceAutoOfflineHint": MessageLookupByLibrary.simpleMessage(
      "30日以上オフラインのデバイスは自動的に削除されます。",
    ),
    "xboardDeviceCurrentDeviceLabel": MessageLookupByLibrary.simpleMessage(
      "現在のデバイス",
    ),
    "xboardDeviceExpired": MessageLookupByLibrary.simpleMessage("期限切れ"),
    "xboardDeviceHealth": MessageLookupByLibrary.simpleMessage("デバイス状態"),
    "xboardDeviceHistory": MessageLookupByLibrary.simpleMessage("履歴"),
    "xboardDeviceHistoryHint": MessageLookupByLibrary.simpleMessage(
      "90日以内の削除記録のみ保持され、それ以前の記録は自動的に削除されます。",
    ),
    "xboardDeviceLabelId": MessageLookupByLibrary.simpleMessage("デバイスID"),
    "xboardDeviceLabelLastIp": MessageLookupByLibrary.simpleMessage("最終IP"),
    "xboardDeviceLabelLastOnline": MessageLookupByLibrary.simpleMessage(
      "最終オンライン",
    ),
    "xboardDeviceLabelOsVersion": MessageLookupByLibrary.simpleMessage(
      "OSバージョン",
    ),
    "xboardDeviceLabelRegion": MessageLookupByLibrary.simpleMessage("所在地"),
    "xboardDeviceLabelRevokedAt": MessageLookupByLibrary.simpleMessage("削除日時"),
    "xboardDeviceLabelRevokedBy": MessageLookupByLibrary.simpleMessage("削除元"),
    "xboardDeviceManagement": MessageLookupByLibrary.simpleMessage("デバイス管理"),
    "xboardDeviceNoRecords": MessageLookupByLibrary.simpleMessage("デバイス記録なし"),
    "xboardDeviceNoRecordsHint": MessageLookupByLibrary.simpleMessage(
      "ログインしたデバイスがここに表示されます。",
    ),
    "xboardDeviceOffline": MessageLookupByLibrary.simpleMessage("オフライン"),
    "xboardDeviceOnline": MessageLookupByLibrary.simpleMessage("オンライン"),
    "xboardDeviceRemoveCurrentConfirm": MessageLookupByLibrary.simpleMessage(
      "このデバイスは現在ログイン中のデバイスです。削除するとすぐにログアウトされます。",
    ),
    "xboardDeviceRemoveTitle": MessageLookupByLibrary.simpleMessage("デバイスを削除"),
    "xboardDeviceRemoved": MessageLookupByLibrary.simpleMessage("デバイスが削除されました"),
    "xboardDeviceRevoked": MessageLookupByLibrary.simpleMessage("削除済み"),
    "xboardDeviceSummary": m38,
    "xboardDeviceUnknown": MessageLookupByLibrary.simpleMessage("不明"),
    "xboardDeviceUnknownVersion": MessageLookupByLibrary.simpleMessage(
      "不明なバージョン",
    ),
    "xboardDeviceUnlimited": MessageLookupByLibrary.simpleMessage("無制限"),
    "xboardDiagnosticBundleCopied": MessageLookupByLibrary.simpleMessage(
      "診断パックをコピーしました",
    ),
    "xboardDisconnecting": MessageLookupByLibrary.simpleMessage("切断中"),
    "xboardDiscountAmount": MessageLookupByLibrary.simpleMessage("割引額"),
    "xboardDiscounted": MessageLookupByLibrary.simpleMessage("割引済み"),
    "xboardDiscountedPrice": MessageLookupByLibrary.simpleMessage("割引後価格"),
    "xboardDocsCenter": MessageLookupByLibrary.simpleMessage("ドキュメントセンター"),
    "xboardNoDocuments": MessageLookupByLibrary.simpleMessage(
      "ドキュメントはありません"
    ),
    "xboardDownloadingConfig": MessageLookupByLibrary.simpleMessage(
      "設定ファイルをダウンロード中",
    ),
    "xboardEmail": MessageLookupByLibrary.simpleMessage("メール"),
    "xboardEmailUnavailable": MessageLookupByLibrary.simpleMessage(
      "メールアドレスは使用できません",
    ),
    "xboardEnableTun": MessageLookupByLibrary.simpleMessage("TUNを有効化"),
    "xboardEnjoyFastNetworkExperience": MessageLookupByLibrary.simpleMessage(
      "高速ネットワーク体験をお楽しみください",
    ),
    "xboardEnterAmount": MessageLookupByLibrary.simpleMessage("金額を入力"),
    "xboardEnterCouponCode": MessageLookupByLibrary.simpleMessage("クーポンコードを入力"),
    "xboardEnterGiftCardCode": MessageLookupByLibrary.simpleMessage(
      "ギフトカードコードを入力",
    ),
    "xboardEnterGiftCardCodeHint": MessageLookupByLibrary.simpleMessage(
      "ギフトカード引換コードを入力",
    ),
    "xboardExcellent": MessageLookupByLibrary.simpleMessage("優秀"),
    "xboardExpiredOnDate": m39,
    "xboardExpiresOnDate": m40,
    "xboardExpiresOnWithDays": m41,
    "xboardExpiryTime": MessageLookupByLibrary.simpleMessage("有効期限"),
    "xboardFailedToCheckPaymentStatus": MessageLookupByLibrary.simpleMessage(
      "支払い状況の確認に失敗しました",
    ),
    "xboardFailedToGetSubscriptionInfo": MessageLookupByLibrary.simpleMessage(
      "サブスクリプション情報の取得に失敗しました",
    ),
    "xboardFailedToOpenPaymentLink": MessageLookupByLibrary.simpleMessage(
      "支払いリンクを開けませんでした",
    ),
    "xboardFailedToOpenPaymentPage": MessageLookupByLibrary.simpleMessage(
      "支払いページを開けませんでした",
    ),
    "xboardFair": MessageLookupByLibrary.simpleMessage("普通"),
    "xboardForceUpdate": MessageLookupByLibrary.simpleMessage("強制更新"),
    "xboardForgotPassword": MessageLookupByLibrary.simpleMessage("パスワードを忘れた"),
    "xboardGatewayCandidateCount": m42,
    "xboardGatewayStatus": MessageLookupByLibrary.simpleMessage("ゲートウェイ状態"),
    "xboardGetGroupLinkFailed": MessageLookupByLibrary.simpleMessage(
      "グループリンク取得失敗",
    ),
    "xboardGettingIP": MessageLookupByLibrary.simpleMessage("取得中..."),
    "xboardGiftCardAlreadyUsedByUser": MessageLookupByLibrary.simpleMessage(
      "交換失敗：このギフトカードはこのユーザーによって既に使用されています",
    ),
    "xboardGiftCardCode": MessageLookupByLibrary.simpleMessage("ギフトカードコード"),
    "xboardGiftCardCodeLabel": MessageLookupByLibrary.simpleMessage(
      "ギフトカードコード",
    ),
    "xboardGiftCardNotFound": MessageLookupByLibrary.simpleMessage(
      "交換失敗：このギフトカードは存在しません",
    ),
    "xboardGiftCardRedeem": MessageLookupByLibrary.simpleMessage("ギフトカード交換"),
    "xboardGiftCardRedeemSuccessRefreshed":
        MessageLookupByLibrary.simpleMessage("交換成功：ユーザー情報を自動更新しました"),
    "xboardGiftCardRedeemTitle": MessageLookupByLibrary.simpleMessage(
      "ギフトカード交換",
    ),
    "xboardGlobalNodes": MessageLookupByLibrary.simpleMessage("グローバルノード"),
    "xboardGlobalProxy": MessageLookupByLibrary.simpleMessage("グローバルプロキシ"),
    "xboardGood": MessageLookupByLibrary.simpleMessage("良好"),
    "xboardGotIt": MessageLookupByLibrary.simpleMessage("了解"),
    "xboardGroup": MessageLookupByLibrary.simpleMessage("グループ"),
    "xboardGroupLinkNotConfigured": MessageLookupByLibrary.simpleMessage(
      "グループリンク未設定",
    ),
    "xboardHalfYearlyPayment": MessageLookupByLibrary.simpleMessage("半年払い"),
    "xboardHandleLater": MessageLookupByLibrary.simpleMessage("後で処理"),
    "xboardHandlingFee": MessageLookupByLibrary.simpleMessage("手数料"),
    "xboardHealthCoreRunning": MessageLookupByLibrary.simpleMessage("実行中"),
    "xboardHealthDisabled": MessageLookupByLibrary.simpleMessage("無効"),
    "xboardHealthDns": MessageLookupByLibrary.simpleMessage("DNS"),
    "xboardHealthDnsCustom": MessageLookupByLibrary.simpleMessage(
      "カスタム DNS を使用",
    ),
    "xboardHealthDnsDefault": MessageLookupByLibrary.simpleMessage(
      "デフォルト DNS を使用",
    ),
    "xboardHealthEnabled": MessageLookupByLibrary.simpleMessage("有効"),
    "xboardHealthHelper": MessageLookupByLibrary.simpleMessage("Helper"),
    "xboardHealthHelperAvailable": MessageLookupByLibrary.simpleMessage("利用可能"),
    "xboardHealthHelperCheckFailed": MessageLookupByLibrary.simpleMessage(
      "確認に失敗しました",
    ),
    "xboardHealthHelperChecking": MessageLookupByLibrary.simpleMessage("確認中"),
    "xboardHealthHelperNoResponse": MessageLookupByLibrary.simpleMessage(
      "helper HTTP が応答していません",
    ),
    "xboardHealthHelperNotRequired": MessageLookupByLibrary.simpleMessage(
      "このプラットフォームでは Windows helper は不要です",
    ),
    "xboardHealthHelperUnavailable": MessageLookupByLibrary.simpleMessage(
      "利用不可",
    ),
    "xboardHealthLastEvent": MessageLookupByLibrary.simpleMessage("最新イベント"),
    "xboardHealthSubscriptionImport": m43,
    "xboardHealthTunApplied": MessageLookupByLibrary.simpleMessage("適用済み"),
    "xboardHealthTunPending": MessageLookupByLibrary.simpleMessage("適用待ち"),
    "xboardHealthy": MessageLookupByLibrary.simpleMessage("正常"),
    "xboardHigh": MessageLookupByLibrary.simpleMessage("高"),
    "xboardHighSpeedNetwork": MessageLookupByLibrary.simpleMessage("高速ネットワーク"),
    "xboardHome": MessageLookupByLibrary.simpleMessage("ホーム"),
    "xboardImportFailed": MessageLookupByLibrary.simpleMessage("インポート失敗"),
    "xboardImportSuccess": MessageLookupByLibrary.simpleMessage("インポート成功"),
    "xboardImportingSubscription": MessageLookupByLibrary.simpleMessage(
      "サブスクリプションをインポート中",
    ),
    "xboardInsufficientBalance": MessageLookupByLibrary.simpleMessage("残高不足"),
    "xboardInvalidCredentials": MessageLookupByLibrary.simpleMessage(
      "無効なユーザー名またはパスワード",
    ),
    "xboardInvalidOrExpiredCoupon": MessageLookupByLibrary.simpleMessage(
      "無効または期限切れのクーポンコード",
    ),
    "xboardInvalidResponseFormat": MessageLookupByLibrary.simpleMessage(
      "サーバーからの無効なレスポンス形式",
    ),
    "xboardInviteCode": MessageLookupByLibrary.simpleMessage("招待コード"),
    "xboardJoinGroup": MessageLookupByLibrary.simpleMessage("グループ参加"),
    "xboardKeepSubscriptionLinkSafe": MessageLookupByLibrary.simpleMessage(
      "サブスクリプションリンクを安全に保管し、他人と共有しないでください",
    ),
    "xboardLater": MessageLookupByLibrary.simpleMessage("後で"),
    "xboardLoadingFailed": MessageLookupByLibrary.simpleMessage("読み込みに失敗しました"),
    "xboardLoadingPaymentPage": MessageLookupByLibrary.simpleMessage(
      "支払いページを読み込み中",
    ),
    "xboardLocalIP": MessageLookupByLibrary.simpleMessage("ローカルIP"),
    "xboardLoggedIn": MessageLookupByLibrary.simpleMessage("ログイン済み"),
    "xboardLogin": MessageLookupByLibrary.simpleMessage("ログイン"),
    "xboardLoginErrorConfigLoad": MessageLookupByLibrary.simpleMessage(
      "設定の読み込みに失敗しました。しばらくしてから再試行してください",
    ),
    "xboardLoginErrorCredentials": MessageLookupByLibrary.simpleMessage(
      "アカウントまたはパスワードが間違っています。確認してください",
    ),
    "xboardLoginErrorDeviceLimit": MessageLookupByLibrary.simpleMessage(
      "デバイス上限に達しました。先にオフラインデバイスを解放してください。",
    ),
    "xboardLoginErrorLimited": MessageLookupByLibrary.simpleMessage(
      "ログイン試行が多すぎます。しばらくしてから再試行してください。",
    ),
    "xboardLoginErrorNetwork": MessageLookupByLibrary.simpleMessage(
      "ネットワークエラー、ローカルネットワークを確認してください",
    ),
    "xboardLoginExpired": MessageLookupByLibrary.simpleMessage(
      "ログインが期限切れです、再度ログインしてください",
    ),
    "xboardLoginFailed": MessageLookupByLibrary.simpleMessage("ログイン失敗"),
    "xboardLoginSuccess": MessageLookupByLibrary.simpleMessage("ログイン成功"),
    "xboardLoginToViewSubscription": MessageLookupByLibrary.simpleMessage(
      "サブスクリプション使用状況を確認するにはログインしてください",
    ),
    "xboardLogout": MessageLookupByLibrary.simpleMessage("ログアウト"),
    "xboardLogoutConfirmContent": MessageLookupByLibrary.simpleMessage(
      "現在のアカウントから退出しますか？再度ログインが必要です。",
    ),
    "xboardLogoutConfirmTitle": MessageLookupByLibrary.simpleMessage("終了確認"),
    "xboardLogoutFailed": MessageLookupByLibrary.simpleMessage("ログアウト失敗"),
    "xboardLogoutSuccess": MessageLookupByLibrary.simpleMessage("ログアウトしました"),
    "xboardLow": MessageLookupByLibrary.simpleMessage("低"),
    "xboardManageDevices": MessageLookupByLibrary.simpleMessage("デバイスを管理"),
    "xboardMedium": MessageLookupByLibrary.simpleMessage("中"),
    "xboardMine": MessageLookupByLibrary.simpleMessage("マイページ"),
    "xboardMissingRequiredField": MessageLookupByLibrary.simpleMessage(
      "必須フィールドが不足しています",
    ),
    "xboardMonthlyPayment": MessageLookupByLibrary.simpleMessage("月払い"),
    "xboardMonthlyRenewal": MessageLookupByLibrary.simpleMessage("毎月更新"),
    "xboardMustUpdate": MessageLookupByLibrary.simpleMessage("更新必須"),
    "xboardMyServices": MessageLookupByLibrary.simpleMessage("マイサービス"),
    "xboardMyTickets": MessageLookupByLibrary.simpleMessage("マイチケット"),
    "xboardMyWallet": MessageLookupByLibrary.simpleMessage("マイウォレット"),
    "xboardNeedsAttention": MessageLookupByLibrary.simpleMessage("確認が必要"),
    "xboardNetworkConnectionFailed": MessageLookupByLibrary.simpleMessage(
      "ネットワーク接続に失敗しました、ネットワーク設定を確認してください",
    ),
    "xboardNewVersionFound": MessageLookupByLibrary.simpleMessage(
      "新しいバージョンが見つかりました",
    ),
    "xboardNext": MessageLookupByLibrary.simpleMessage("次へ"),
    "xboardNoAvailableNodes": MessageLookupByLibrary.simpleMessage(
      "利用可能なノードがありません",
    ),
    "xboardNoAvailablePlan": MessageLookupByLibrary.simpleMessage(
      "利用可能なプランがありません",
    ),
    "xboardNoAvailableSubscription": MessageLookupByLibrary.simpleMessage(
      "利用可能なサブスクリプションがありません",
    ),
    "xboardNoGatewayActive": MessageLookupByLibrary.simpleMessage(
      "有効なゲートウェイがありません",
    ),
    "xboardNoInternetConnection": MessageLookupByLibrary.simpleMessage(
      "インターネット接続がありません、ネットワーク設定を確認してください",
    ),
    "xboardNoOrderRecords": MessageLookupByLibrary.simpleMessage("注文記録なし"),
    "xboardNoPaymentMethods": MessageLookupByLibrary.simpleMessage("支払い方法なし"),
    "xboardNoSubscriptionInfo": MessageLookupByLibrary.simpleMessage(
      "サブスクリプション情報がありません",
    ),
    "xboardNoSubscriptionPlans": MessageLookupByLibrary.simpleMessage(
      "サブスクリプションプランがありません",
    ),
    "xboardNoTicketRecords": MessageLookupByLibrary.simpleMessage("チケット記録なし"),
    "xboardNoTrafficRecords": MessageLookupByLibrary.simpleMessage("通信量記録なし"),
    "xboardNodeCount": m44,
    "xboardNodeHealth": MessageLookupByLibrary.simpleMessage("ノード状態"),
    "xboardNodeName": MessageLookupByLibrary.simpleMessage("ノード名"),
    "xboardNodeSelection": MessageLookupByLibrary.simpleMessage("ノード選択"),
    "xboardNone": MessageLookupByLibrary.simpleMessage("なし"),
    "xboardNormal": MessageLookupByLibrary.simpleMessage("通常"),
    "xboardNotLoggedIn": MessageLookupByLibrary.simpleMessage("未ログイン"),
    "xboardOfflineButActive": MessageLookupByLibrary.simpleMessage(
      "オフライン・枠使用中",
    ),
    "xboardOneClickRepair": MessageLookupByLibrary.simpleMessage("ワンクリック修復"),
    "xboardOneTimePayment": MessageLookupByLibrary.simpleMessage("一回払い"),
    "xboardOpenPaymentFailed": MessageLookupByLibrary.simpleMessage(
      "支払いページを開けませんでした",
    ),
    "xboardOpenPaymentLinkFailed": MessageLookupByLibrary.simpleMessage(
      "支払いリンクを開けませんでした",
    ),
    "xboardOperationFailed": MessageLookupByLibrary.simpleMessage("操作に失敗しました"),
    "xboardOperationTips": MessageLookupByLibrary.simpleMessage("操作のヒント"),
    "xboardOrderAmount": MessageLookupByLibrary.simpleMessage("注文金額"),
    "xboardOrderCreationFailed": MessageLookupByLibrary.simpleMessage(
      "注文作成に失敗しました",
    ),
    "xboardOrderInfo": MessageLookupByLibrary.simpleMessage("注文情報"),
    "xboardOrderLoadingFailed": MessageLookupByLibrary.simpleMessage(
      "注文の読み込みに失敗しました",
    ),
    "xboardOrderNotFound": MessageLookupByLibrary.simpleMessage("注文が見つかりません"),
    "xboardOrderNumber": MessageLookupByLibrary.simpleMessage("注文番号"),
    "xboardOrderRecords": MessageLookupByLibrary.simpleMessage("注文履歴"),
    "xboardOrderStatus": MessageLookupByLibrary.simpleMessage("注文状態"),
    "xboardOrderStatusCancelled": MessageLookupByLibrary.simpleMessage(
      "キャンセル済み",
    ),
    "xboardOrderStatusCompleted": MessageLookupByLibrary.simpleMessage("完了"),
    "xboardOrderStatusOffset": MessageLookupByLibrary.simpleMessage("相殺"),
    "xboardOrderStatusOpening": MessageLookupByLibrary.simpleMessage("有効化中"),
    "xboardOrderStatusPending": MessageLookupByLibrary.simpleMessage("支払い待ち"),
    "xboardOriginalPrice": MessageLookupByLibrary.simpleMessage("元の価格"),
    "xboardPackageAmount": MessageLookupByLibrary.simpleMessage("パッケージ金額"),
    "xboardPassword": MessageLookupByLibrary.simpleMessage("パスワード"),
    "xboardPayNow": MessageLookupByLibrary.simpleMessage("今すぐ支払う"),
    "xboardPayableAmount": MessageLookupByLibrary.simpleMessage("支払金額"),
    "xboardPaymentCancelled": MessageLookupByLibrary.simpleMessage(
      "支払いがキャンセルされました",
    ),
    "xboardPaymentComplete": MessageLookupByLibrary.simpleMessage("支払い完了"),
    "xboardPaymentCompleted": MessageLookupByLibrary.simpleMessage("支払い完了！"),
    "xboardPaymentFailed": MessageLookupByLibrary.simpleMessage("支払いに失敗しました"),
    "xboardPaymentGateway": MessageLookupByLibrary.simpleMessage("支払いゲートウェイ"),
    "xboardPaymentInfo": MessageLookupByLibrary.simpleMessage("支払い情報"),
    "xboardPaymentInstructions1": MessageLookupByLibrary.simpleMessage(
      "1. 支払いページが自動的に開かれました",
    ),
    "xboardPaymentInstructions2": MessageLookupByLibrary.simpleMessage(
      "2. ブラウザで支払いを完了してください",
    ),
    "xboardPaymentInstructions3": MessageLookupByLibrary.simpleMessage(
      "3. 支払い後にアプリに戻ると、システムが自動検出します",
    ),
    "xboardPaymentLink": MessageLookupByLibrary.simpleMessage("支払いリンク"),
    "xboardPaymentLinkCopied": MessageLookupByLibrary.simpleMessage(
      "支払いリンクをクリップボードにコピーしました",
    ),
    "xboardPaymentMethodVerified": MessageLookupByLibrary.simpleMessage(
      "支払い方法が確認されました",
    ),
    "xboardPaymentMethodVerifiedPreparing":
        MessageLookupByLibrary.simpleMessage(
          "支払い方法が確認されました。支払いページにリダイレクトする準備中です",
        ),
    "xboardPaymentMethods": MessageLookupByLibrary.simpleMessage("支払い方法"),
    "xboardPaymentPageAutoOpened": MessageLookupByLibrary.simpleMessage(
      "1. 支払いページが自動的に開かれました",
    ),
    "xboardPaymentPageOpenedCompleteAndReturn":
        MessageLookupByLibrary.simpleMessage(
          "支払いページが開かれました。支払いを完了してアプリに戻ってください",
        ),
    "xboardPaymentPageOpenedInBrowser": MessageLookupByLibrary.simpleMessage(
      "ブラウザで支払いページが開かれました。支払い完了後はアプリに戻ってください",
    ),
    "xboardPaymentSuccess": MessageLookupByLibrary.simpleMessage("支払い成功"),
    "xboardPaymentSuccessful": MessageLookupByLibrary.simpleMessage(
      "🎉 支払い成功！",
    ),
    "xboardPendingOrdersHint": MessageLookupByLibrary.simpleMessage(
      "支払い済みで反映されない場合は、注文状態を更新してください。",
    ),
    "xboardPeriod": MessageLookupByLibrary.simpleMessage("期間"),
    "xboardPlanBased": MessageLookupByLibrary.simpleMessage("プラン基準"),
    "xboardPlanExpiryReminder": MessageLookupByLibrary.simpleMessage(
      "プラン期限切れメール通知",
    ),
    "xboardPlanInfo": MessageLookupByLibrary.simpleMessage("プラン情報"),
    "xboardPlanName": MessageLookupByLibrary.simpleMessage("プラン名"),
    "xboardPlanNotFound": MessageLookupByLibrary.simpleMessage("プランが見つかりません"),
    "xboardPlans": MessageLookupByLibrary.simpleMessage("ストア"),
    "xboardPleaseEnterGiftCardCode": MessageLookupByLibrary.simpleMessage(
      "ギフトカードコードを入力してください",
    ),
    "xboardPleaseSelectPaymentPeriod": MessageLookupByLibrary.simpleMessage(
      "支払い期間を選択してください",
    ),
    "xboardPleaseWait": MessageLookupByLibrary.simpleMessage("しばらくお待ちください"),
    "xboardPoor": MessageLookupByLibrary.simpleMessage("悪い"),
    "xboardPreparingImport": MessageLookupByLibrary.simpleMessage("インポートを準備中"),
    "xboardPreparingPaymentPage": MessageLookupByLibrary.simpleMessage(
      "支払いページを準備中、まもなくリダイレクトします",
    ),
    "xboardPrevious": MessageLookupByLibrary.simpleMessage("前へ"),
    "xboardPriority": MessageLookupByLibrary.simpleMessage("優先度"),
    "xboardProcessing": MessageLookupByLibrary.simpleMessage("処理中..."),
    "xboardProductInfo": MessageLookupByLibrary.simpleMessage("商品情報"),
    "xboardProfessionalSupport": MessageLookupByLibrary.simpleMessage(
      "プロフェッショナルサポート",
    ),
    "xboardProfile": MessageLookupByLibrary.simpleMessage("プロファイル"),
    "xboardProtectNetworkPrivacy": MessageLookupByLibrary.simpleMessage(
      "ネットワークプライバシーを保護",
    ),
    "xboardProxy": MessageLookupByLibrary.simpleMessage("プロキシ"),
    "xboardProxyMode": MessageLookupByLibrary.simpleMessage("プロキシモード"),
    "xboardProxyModeDirectDescription": MessageLookupByLibrary.simpleMessage(
      "すべてのトラフィックがプロキシなしで直接接続",
    ),
    "xboardProxyModeGlobalDescription": MessageLookupByLibrary.simpleMessage(
      "すべてのトラフィックがプロキシサーバーを通過",
    ),
    "xboardProxyModeRuleDescription": MessageLookupByLibrary.simpleMessage(
      "ルールに基づいて直接またはプロキシを自動選択",
    ),
    "xboardPurchasePlan": MessageLookupByLibrary.simpleMessage("プランを購入"),
    "xboardPurchaseSubscription": MessageLookupByLibrary.simpleMessage(
      "サブスクリプション購入",
    ),
    "xboardPurchaseSubscriptionToUse": MessageLookupByLibrary.simpleMessage(
      "使用するにはサブスクリプションを購入してください",
    ),
    "xboardPurchaseTraffic": MessageLookupByLibrary.simpleMessage("トラフィックを購入"),
    "xboardQuarterlyPayment": MessageLookupByLibrary.simpleMessage("四半期払い"),
    "xboardRecharge": MessageLookupByLibrary.simpleMessage("チャージ"),
    "xboardRechargeAmount": MessageLookupByLibrary.simpleMessage("チャージ金額"),
    "xboardRechargeBalance": MessageLookupByLibrary.simpleMessage("残高をチャージ"),
    "xboardRechargeBalanceTip": MessageLookupByLibrary.simpleMessage(
      "チャージ金額はアカウント残高に追加されます。",
    ),
    "xboardRechargeNow": MessageLookupByLibrary.simpleMessage("今すぐチャージ"),
    "xboardRedeemFailed": MessageLookupByLibrary.simpleMessage("交換失敗"),
    "xboardRedeemFailedWithError": m45,
    "xboardRedeemNow": MessageLookupByLibrary.simpleMessage("今すぐ交換"),
    "xboardRedeemSuccess": MessageLookupByLibrary.simpleMessage("交換成功"),
    "xboardRefresh": MessageLookupByLibrary.simpleMessage("更新"),
    "xboardRefreshStatus": MessageLookupByLibrary.simpleMessage("状態を更新"),
    "xboardRefundAmount": MessageLookupByLibrary.simpleMessage("ウォレット返金"),
    "xboardRegister": MessageLookupByLibrary.simpleMessage("登録"),
    "xboardRegisterFailed": MessageLookupByLibrary.simpleMessage("登録失敗"),
    "xboardRegisterSuccess": MessageLookupByLibrary.simpleMessage(
      "登録成功！ログインページにリダイレクトしています...",
    ),
    "xboardReleaseOfflineDevices": MessageLookupByLibrary.simpleMessage(
      "オフラインデバイスを解放",
    ),
    "xboardReleaseOfflineDevicesConfirm": MessageLookupByLibrary.simpleMessage(
      "オフラインのままデバイス枠を使用しているデバイスを削除します。現在のデバイスには影響しません。続行しますか？",
    ),
    "xboardReload": MessageLookupByLibrary.simpleMessage("再読み込み"),
    "xboardReloadNodes": MessageLookupByLibrary.simpleMessage("ノードを再読み込み"),
    "xboardRelogin": MessageLookupByLibrary.simpleMessage("再ログイン"),
    "xboardRemainingBalance": MessageLookupByLibrary.simpleMessage("残り"),
    "xboardRememberPassword": MessageLookupByLibrary.simpleMessage("パスワードを記憶"),
    "xboardRenewPlan": MessageLookupByLibrary.simpleMessage("プランを更新"),
    "xboardRenewToContinue": MessageLookupByLibrary.simpleMessage(
      "引き続き使用するには更新してください",
    ),
    "xboardReopen": MessageLookupByLibrary.simpleMessage("再開"),
    "xboardReopenPayment": MessageLookupByLibrary.simpleMessage("支払いを再開"),
    "xboardReopenPaymentPageTip": MessageLookupByLibrary.simpleMessage(
      "再度開くには、下の\\\"再開\\\"ボタンをクリックしてください",
    ),
    "xboardRepairCompleted": MessageLookupByLibrary.simpleMessage("修復完了"),
    "xboardResetCurrentPlanTraffic": MessageLookupByLibrary.simpleMessage(
      "現在のプラン通信量をリセット",
    ),
    "xboardResetTraffic": MessageLookupByLibrary.simpleMessage("トラフィックをリセット"),
    "xboardResetTrafficByPlanCycle": MessageLookupByLibrary.simpleMessage(
      "プラン周期で通信量をリセット",
    ),
    "xboardResetTrafficConfirmContent": MessageLookupByLibrary.simpleMessage(
      "この操作により使用済みトラフィックがリセットされますが、プラン期間は延長されません。続行しますか？",
    ),
    "xboardResetTrafficInDays": m46,
    "xboardResetTrafficToday": MessageLookupByLibrary.simpleMessage(
      "利用済み通信量は本日リセットされました",
    ),
    "xboardRetry": MessageLookupByLibrary.simpleMessage("再試行"),
    "xboardRetryGet": MessageLookupByLibrary.simpleMessage("再試行"),
    "xboardReturn": MessageLookupByLibrary.simpleMessage("戻る"),
    "xboardReturnAfterPaymentAutoDetect": MessageLookupByLibrary.simpleMessage(
      "3. 支払い後にアプリに戻ると、システムが自動検出します",
    ),
    "xboardRunDiagnosis": MessageLookupByLibrary.simpleMessage("チェックを実行"),
    "xboardRunningTime": m47,
    "xboardSecureEncryption": MessageLookupByLibrary.simpleMessage("セキュア暗号化"),
    "xboardSelectPaymentMethod": MessageLookupByLibrary.simpleMessage(
      "支払い方法を選択",
    ),
    "xboardSelectPaymentPeriod": MessageLookupByLibrary.simpleMessage(
      "支払い期間を選択",
    ),
    "xboardSelectPeriod": MessageLookupByLibrary.simpleMessage("購入期間を選択してください"),
    "xboardSelectRechargeAmount": MessageLookupByLibrary.simpleMessage(
      "チャージ金額を選択",
    ),
    "xboardSendVerificationCode": MessageLookupByLibrary.simpleMessage(
      "認証コードを送信",
    ),
    "xboardServerError": MessageLookupByLibrary.simpleMessage("サーバーエラー"),
    "xboardServerStatus": MessageLookupByLibrary.simpleMessage("サーバー状態"),
    "xboardSetup": MessageLookupByLibrary.simpleMessage("設定"),
    "xboardSixMonthCycle": MessageLookupByLibrary.simpleMessage("6ヶ月サイクル"),
    "xboardSmartLatencyStarted": MessageLookupByLibrary.simpleMessage(
      "スマート遅延テストを開始しました",
    ),
    "xboardSmartRouting": MessageLookupByLibrary.simpleMessage("スマートルーティング"),
    "xboardSoftwareSettings": MessageLookupByLibrary.simpleMessage("ソフトウェア設定"),
    "xboardSpeedLimit": MessageLookupByLibrary.simpleMessage("速度制限"),
    "xboardStartProxy": MessageLookupByLibrary.simpleMessage("プロキシ開始"),
    "xboardStop": MessageLookupByLibrary.simpleMessage("停止"),
    "xboardStopProxy": MessageLookupByLibrary.simpleMessage("プロキシ停止"),
    "xboardSubmitTicket": MessageLookupByLibrary.simpleMessage("チケットを送信"),
    "xboardSubmitting": MessageLookupByLibrary.simpleMessage("送信中..."),
    "xboardSubscription": MessageLookupByLibrary.simpleMessage("サブスクリプション"),
    "xboardSubscriptionCopied": MessageLookupByLibrary.simpleMessage(
      "サブスクリプションリンクをクリップボードにコピーしました",
    ),
    "xboardSubscriptionExpired": MessageLookupByLibrary.simpleMessage(
      "サブスクリプションが期限切れです",
    ),
    "xboardSubscriptionHasExpired": MessageLookupByLibrary.simpleMessage(
      "サブスクリプションが期限切れです",
    ),
    "xboardSubscriptionHealth": MessageLookupByLibrary.simpleMessage(
      "サブスクリプション状態",
    ),
    "xboardSubscriptionInfo": MessageLookupByLibrary.simpleMessage(
      "サブスクリプション情報",
    ),
    "xboardSubscriptionLink": MessageLookupByLibrary.simpleMessage(
      "サブスクリプションリンク",
    ),
    "xboardSubscriptionLinkCopied": MessageLookupByLibrary.simpleMessage(
      "サブスクリプションリンクをクリップボードにコピーしました",
    ),
    "xboardSubscriptionPurchase": MessageLookupByLibrary.simpleMessage(
      "サブスクリプション購入",
    ),
    "xboardSubscriptionStatus": MessageLookupByLibrary.simpleMessage(
      "サブスクリプションステータス",
    ),
    "xboardSurplusAmount": MessageLookupByLibrary.simpleMessage("旧プラン充当額"),
    "xboardSwitch": MessageLookupByLibrary.simpleMessage("切り替え"),
    "xboardSyncingSubscription": MessageLookupByLibrary.simpleMessage(
      "アカウントのサブスクリプションを同期中...",
    ),
    "xboardTestCurrentNode": MessageLookupByLibrary.simpleMessage("現在のノードをテスト"),
    "xboardTestLatency": MessageLookupByLibrary.simpleMessage("遅延をテスト"),
    "xboardTesting": MessageLookupByLibrary.simpleMessage("テスト中"),
    "xboardThirtySixMonthCycle": MessageLookupByLibrary.simpleMessage(
      "36ヶ月サイクル",
    ),
    "xboardThreeMonthCycle": MessageLookupByLibrary.simpleMessage("3ヶ月サイクル"),
    "xboardThreeYearPayment": MessageLookupByLibrary.simpleMessage("3年払い"),
    "xboardTicketClosed": MessageLookupByLibrary.simpleMessage("クローズ済み"),
    "xboardTicketDescription": MessageLookupByLibrary.simpleMessage("説明"),
    "xboardTicketDescriptionHint": MessageLookupByLibrary.simpleMessage(
      "問題を詳しく説明してください",
    ),
    "xboardTicketPendingReply": MessageLookupByLibrary.simpleMessage("返信待ち"),
    "xboardTicketReplied": MessageLookupByLibrary.simpleMessage("返信済み"),
    "xboardTicketTitle": MessageLookupByLibrary.simpleMessage("チケットタイトル"),
    "xboardTicketTitleHint": MessageLookupByLibrary.simpleMessage(
      "チケットタイトルを入力",
    ),
    "xboardTimeout": MessageLookupByLibrary.simpleMessage("タイムアウト"),
    "xboardTokenExpiredContent": MessageLookupByLibrary.simpleMessage(
      "ログインセッションが期限切れです。続行するには再度ログインしてください。",
    ),
    "xboardTokenExpiredTitle": MessageLookupByLibrary.simpleMessage("ログイン期限切れ"),
    "xboardToolsSettings": MessageLookupByLibrary.simpleMessage("ツール設定"),
    "xboardTotal": MessageLookupByLibrary.simpleMessage("合計"),
    "xboardTotalTraffic": MessageLookupByLibrary.simpleMessage("合計"),
    "xboardTraffic": MessageLookupByLibrary.simpleMessage("トラフィック"),
    "xboardTrafficDetails": MessageLookupByLibrary.simpleMessage("通信量詳細"),
    "xboardTrafficExhausted": MessageLookupByLibrary.simpleMessage(
      "トラフィックを使い切りました",
    ),
    "xboardTrafficExhaustedRenewConfirmContent":
        MessageLookupByLibrary.simpleMessage(
          "プランを更新しても通信量はすぐにはリセットされません。すぐに利用するには、通信量をリセットするかプランを変更してください。続行しますか？",
        ),
    "xboardTrafficLogHint": MessageLookupByLibrary.simpleMessage(
      "過去1か月分のトラフィックのみ表示",
    ),
    "xboardTrafficReminder": MessageLookupByLibrary.simpleMessage(
      "トラフィック使用量メール通知",
    ),
    "xboardTrafficUsedUp": MessageLookupByLibrary.simpleMessage(
      "トラフィックを使い切りました",
    ),
    "xboardTunEnabled": MessageLookupByLibrary.simpleMessage("TUNが有効"),
    "xboardTwelveMonthCycle": MessageLookupByLibrary.simpleMessage("12ヶ月サイクル"),
    "xboardTwentyFourMonthCycle": MessageLookupByLibrary.simpleMessage(
      "24ヶ月サイクル",
    ),
    "xboardTwoYearPayment": MessageLookupByLibrary.simpleMessage("2年払い"),
    "xboardUnauthorizedAccess": MessageLookupByLibrary.simpleMessage(
      "認証されていないアクセス、まずログインしてください",
    ),
    "xboardUnknownErrorRetry": MessageLookupByLibrary.simpleMessage(
      "不明なエラー、再試行してください",
    ),
    "xboardUnknownPeriod": MessageLookupByLibrary.simpleMessage("不明な期間"),
    "xboardUnknownPlan": MessageLookupByLibrary.simpleMessage("不明なプラン"),
    "xboardUnknownUser": MessageLookupByLibrary.simpleMessage("不明なユーザー"),
    "xboardUnlimited": MessageLookupByLibrary.simpleMessage("無制限"),
    "xboardUnlimitedSpeed": MessageLookupByLibrary.simpleMessage("速度無制限"),
    "xboardUnselected": MessageLookupByLibrary.simpleMessage("未選択"),
    "xboardUnsupportedCouponType": MessageLookupByLibrary.simpleMessage(
      "サポートされていないクーポンタイプ",
    ),
    "xboardUpdateContent": MessageLookupByLibrary.simpleMessage("更新内容："),
    "xboardUpdateLater": MessageLookupByLibrary.simpleMessage("後で更新"),
    "xboardUpdateNodes": MessageLookupByLibrary.simpleMessage("ノードを更新"),
    "xboardUpdateNow": MessageLookupByLibrary.simpleMessage("今すぐ更新"),
    "xboardUpdateSubscriptionRegularly": MessageLookupByLibrary.simpleMessage(
      "定期的にサブスクリプションを更新して最新のノードを取得",
    ),
    "xboardUploadImage": MessageLookupByLibrary.simpleMessage("画像をアップロード"),
    "xboardUsageInstructions": MessageLookupByLibrary.simpleMessage("使用方法"),
    "xboardUseBalance": MessageLookupByLibrary.simpleMessage("残高を使用"),
    "xboardUsed": MessageLookupByLibrary.simpleMessage("使用済み"),
    "xboardUsedTraffic": MessageLookupByLibrary.simpleMessage("使用済み"),
    "xboardValidatingConfigFormat": MessageLookupByLibrary.simpleMessage(
      "設定形式を検証中",
    ),
    "xboardValidationFailed": MessageLookupByLibrary.simpleMessage("検証に失敗しました"),
    "xboardValidityPeriod": MessageLookupByLibrary.simpleMessage("有効期間"),
    "xboardVerify": MessageLookupByLibrary.simpleMessage("検証"),
    "xboardVeryPoor": MessageLookupByLibrary.simpleMessage("非常に悪い"),
    "xboardWaitingForPayment": MessageLookupByLibrary.simpleMessage(
      "支払いを待っています",
    ),
    "xboardWaitingPaymentCompletion": MessageLookupByLibrary.simpleMessage(
      "支払い完了を待機中",
    ),
    "xboardWalletBalance": MessageLookupByLibrary.simpleMessage("ウォレット残高"),
    "xboardYearlyPayment": MessageLookupByLibrary.simpleMessage("年払い"),
    "years": MessageLookupByLibrary.simpleMessage("年"),
    "zh_CN": MessageLookupByLibrary.simpleMessage("簡体字中国語"),
      "xboardDeviceUnit": xboardDeviceUnit,
};

  static String xboardDeviceUnit(num count) => "${count}台";
}
