// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a zh_CN locale. All the
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
  String get localeName => 'zh_CN';

  static String m0(limit) => "当前最低提现佣金为 ${limit}";

  static String m1(minute) => "密码错误次数过多，请 ${minute} 分钟后再试";

  static String m2(rate) => "当前综合佣金返利比例：${rate}%";

  static String m3(label) => "确定删除选中的${label}吗？";

  static String m4(label) => "确定删除当前${label}吗？";

  static String m5(label) => "${label}不能为空";

  static String m6(label) => "${label}当前已存在";

  static String m7(error) => "退出失败：${error}";

  static String m8(amount) => "最大可划转: ¥${amount}";

  static String m9(label) => "暂无${label}";

  static String m10(label) => "${label}必须为数字";

  static String m11(statusCode) => "获取消息失败: ${statusCode}";

  static String m12(error) => "选择图片失败: ${error}";

  static String m13(method) => "不支持的HTTP方法: ${method}";

  static String m14(error) => "上传失败: ${error}";

  static String m15(amount) => "订单金额: ${amount}";

  static String m16(orderNo) => "订单: ${orderNo}";

  static String m17(page) => "第 ${page} 页";

  static String m18(label) => "${label} 必须在 1024 到 49151 之间";

  static String m19(e) => "注册失败: ${e}";

  static String m20(count) => "已选择 ${count} 项";

  static String m21(e) => "发送验证码失败: ${e}";

  static String m22(date) => "套餐已于 ${date} 过期，请续费后继续使用";

  static String m23(days) => "套餐将在 ${days} 天后过期，建议及时续费";

  static String m24(days) => "订阅将在 ${days} 天后过期";

  static String m25(count) => "共 ${count} 条记录";

  static String m26(amount) => "划转金额不能超过 ¥${amount}";

  static String m27(error) => "划转失败：${error}";

  static String m28(amount) => "划转成功！已划转 ¥${amount} 到钱包";

  static String m29(version) => "当前版本: ${version}";

  static String m30(version) => "强制更新: ${version}";

  static String m31(version) => "发现新版本: ${version}";

  static String m32(statusCode) => "服务器返回错误状态码 ${statusCode}";

  static String m33(label) => "${label}必须为URL";

  static String m34(email) => "验证码已发送到 ${email}，请查收并输入验证码和新密码";

  static String m35(error) => "提交失败：${error}";

  static String m36(amount) => "可提现金额: ${amount}";

  static String m37(amount) => "¥${amount}";

  static String m38(count, limit) => "活跃 ${count} 台 · 限额 ${limit}";

  static String m39(count) => "${count}台";

  static String m40(date) => "已于 ${date} 到期";

  static String m41(date) => "有效期至 ${date}";

  static String m42(date, days) => "于 ${date} 到期，距离到期还有 ${days} 天";

  static String m43(count) => "${count} 个候选";

  static String m44(message) => "订阅导入：${message}";

  static String m45(count) => "${count} 个节点";

  static String m46(error) => "兑换失败：${error}";

  static String m47(days) => "已用流量将在 ${days} 天后重置";

  static String m48(time) => "运行时间: ${time}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "about": MessageLookupByLibrary.simpleMessage("关于"),
    "accessControl": MessageLookupByLibrary.simpleMessage("访问控制"),
    "accessControlAllowDesc": MessageLookupByLibrary.simpleMessage(
      "只允许选中应用进入VPN",
    ),
    "accessControlDesc": MessageLookupByLibrary.simpleMessage("配置应用访问代理"),
    "accessControlNotAllowDesc": MessageLookupByLibrary.simpleMessage(
      "选中应用将会被排除在VPN之外",
    ),
    "account": MessageLookupByLibrary.simpleMessage("账号"),
    "action": MessageLookupByLibrary.simpleMessage("操作"),
    "action_mode": MessageLookupByLibrary.simpleMessage("切换模式"),
    "action_proxy": MessageLookupByLibrary.simpleMessage("系统代理"),
    "action_start": MessageLookupByLibrary.simpleMessage("启动/停止"),
    "action_tun": MessageLookupByLibrary.simpleMessage("虚拟网卡"),
    "action_view": MessageLookupByLibrary.simpleMessage("显示/隐藏"),
    "add": MessageLookupByLibrary.simpleMessage("添加"),
    "addRule": MessageLookupByLibrary.simpleMessage("添加规则"),
    "addedOriginRules": MessageLookupByLibrary.simpleMessage("附加到原始规则"),
    "address": MessageLookupByLibrary.simpleMessage("地址"),
    "addressHelp": MessageLookupByLibrary.simpleMessage("WebDAV服务器地址"),
    "addressTip": MessageLookupByLibrary.simpleMessage("请输入有效的WebDAV地址"),
    "adminAutoLaunch": MessageLookupByLibrary.simpleMessage("管理员自启动"),
    "adminAutoLaunchDesc": MessageLookupByLibrary.simpleMessage("使用管理员模式开机自启动"),
    "ago": MessageLookupByLibrary.simpleMessage("前"),
    "agree": MessageLookupByLibrary.simpleMessage("同意"),
    "allApps": MessageLookupByLibrary.simpleMessage("所有应用"),
    "allowBypass": MessageLookupByLibrary.simpleMessage("允许应用绕过VPN"),
    "allowBypassDesc": MessageLookupByLibrary.simpleMessage("开启后部分应用可绕过VPN"),
    "allowLan": MessageLookupByLibrary.simpleMessage("局域网代理"),
    "allowLanDesc": MessageLookupByLibrary.simpleMessage("允许通过局域网访问代理"),
    "alreadyHaveAccount": MessageLookupByLibrary.simpleMessage("已有账号？"),
    "app": MessageLookupByLibrary.simpleMessage("应用"),
    "appAccessControl": MessageLookupByLibrary.simpleMessage("应用访问控制"),
    "appDesc": MessageLookupByLibrary.simpleMessage("处理应用相关设置"),
    "application": MessageLookupByLibrary.simpleMessage("应用程序"),
    "applicationDesc": MessageLookupByLibrary.simpleMessage("修改应用程序相关设置"),
    "auto": MessageLookupByLibrary.simpleMessage("自动"),
    "autoCheckUpdate": MessageLookupByLibrary.simpleMessage("自动检查更新"),
    "autoCheckUpdateDesc": MessageLookupByLibrary.simpleMessage("应用启动时自动检查更新"),
    "autoCloseConnections": MessageLookupByLibrary.simpleMessage("自动关闭连接"),
    "autoCloseConnectionsDesc": MessageLookupByLibrary.simpleMessage(
      "切换节点后自动关闭连接",
    ),
    "autoLaunch": MessageLookupByLibrary.simpleMessage("开机启动"),
    "autoLaunchDesc": MessageLookupByLibrary.simpleMessage("跟随系统自启动"),
    "autoRun": MessageLookupByLibrary.simpleMessage("自动运行"),
    "autoRunDesc": MessageLookupByLibrary.simpleMessage("应用打开时自动运行"),
    "autoSetSystemDns": MessageLookupByLibrary.simpleMessage("自动设置系统DNS"),
    "autoUpdate": MessageLookupByLibrary.simpleMessage("自动更新"),
    "autoUpdateInterval": MessageLookupByLibrary.simpleMessage("自动更新间隔（分钟）"),
    "availableCommission": MessageLookupByLibrary.simpleMessage("佣金余额"),
    "backToLogin": MessageLookupByLibrary.simpleMessage("返回登录"),
    "backendErrorAccountSuspended": MessageLookupByLibrary.simpleMessage(
      "该账户已被停止使用",
    ),
    "backendErrorCouponEmpty": MessageLookupByLibrary.simpleMessage("优惠券不能为空"),
    "backendErrorCouponExpired": MessageLookupByLibrary.simpleMessage("优惠券已过期"),
    "backendErrorCouponInvalid": MessageLookupByLibrary.simpleMessage("优惠券无效"),
    "backendErrorCouponLimitExceeded": MessageLookupByLibrary.simpleMessage(
      "优惠券使用次数已达上限",
    ),
    "backendErrorCouponNotFound": MessageLookupByLibrary.simpleMessage(
      "优惠券不存在",
    ),
    "backendErrorEmailEmpty": MessageLookupByLibrary.simpleMessage("邮箱不能为空"),
    "backendErrorEmailExists": MessageLookupByLibrary.simpleMessage("该邮箱已注册"),
    "backendErrorEmailFormatInvalid": MessageLookupByLibrary.simpleMessage(
      "邮箱格式不正确",
    ),
    "backendErrorFailedToOpenTicket": MessageLookupByLibrary.simpleMessage(
      "提现工单创建失败",
    ),
    "backendErrorGiftCardAlreadyUsedByUser":
        MessageLookupByLibrary.simpleMessage("该礼品卡已被该用户使用"),
    "backendErrorGiftCardEmpty": MessageLookupByLibrary.simpleMessage(
      "礼品卡不能为空",
    ),
    "backendErrorGiftCardExpired": MessageLookupByLibrary.simpleMessage(
      "该礼品卡已过期",
    ),
    "backendErrorGiftCardLimitReached": MessageLookupByLibrary.simpleMessage(
      "该礼品卡使用次数已达上限",
    ),
    "backendErrorGiftCardNotFound": MessageLookupByLibrary.simpleMessage(
      "该礼品卡不存在",
    ),
    "backendErrorGiftCardNotYetValid": MessageLookupByLibrary.simpleMessage(
      "该礼品卡尚未生效",
    ),
    "backendErrorGiftCardTypeNotSuitable": MessageLookupByLibrary.simpleMessage(
      "该礼品卡类型不适用",
    ),
    "backendErrorGiftCardTypeUnknown": MessageLookupByLibrary.simpleMessage(
      "未知礼品卡类型",
    ),
    "backendErrorIncorrectEmailOrPassword":
        MessageLookupByLibrary.simpleMessage("邮箱或密码错误"),
    "backendErrorInsufficientCommissionBalance":
        MessageLookupByLibrary.simpleMessage("佣金余额不足"),
    "backendErrorInviteCodeInvalid": MessageLookupByLibrary.simpleMessage(
      "邀请码无效",
    ),
    "backendErrorInviteCodeNotFound": MessageLookupByLibrary.simpleMessage(
      "邀请码不存在",
    ),
    "backendErrorInviteLimitReached": MessageLookupByLibrary.simpleMessage(
      "已达到创建数量上限",
    ),
    "backendErrorMinimumWithdrawalCommission": m0,
    "backendErrorMinimumWithdrawalCommissionGeneric":
        MessageLookupByLibrary.simpleMessage("未达到最低提现佣金要求"),
    "backendErrorNewPasswordEmpty": MessageLookupByLibrary.simpleMessage(
      "新密码不能为空",
    ),
    "backendErrorOldPasswordWrong": MessageLookupByLibrary.simpleMessage(
      "旧密码错误",
    ),
    "backendErrorOrderNotFound": MessageLookupByLibrary.simpleMessage("订单不存在"),
    "backendErrorPasswordEmpty": MessageLookupByLibrary.simpleMessage("密码不能为空"),
    "backendErrorPasswordTooShort": MessageLookupByLibrary.simpleMessage(
      "密码必须大于 8 位",
    ),
    "backendErrorPlanNotFound": MessageLookupByLibrary.simpleMessage("套餐不存在"),
    "backendErrorResetFailed": MessageLookupByLibrary.simpleMessage(
      "重置失败，请稍后重试",
    ),
    "backendErrorSaveFailed": MessageLookupByLibrary.simpleMessage(
      "保存失败，请稍后重试",
    ),
    "backendErrorTicketClosed": MessageLookupByLibrary.simpleMessage("工单已关闭"),
    "backendErrorTicketNotFound": MessageLookupByLibrary.simpleMessage("工单不存在"),
    "backendErrorTooManyPasswordErrors": m1,
    "backendErrorTooManyPasswordErrorsGeneric":
        MessageLookupByLibrary.simpleMessage("密码错误次数过多，请稍后再试"),
    "backendErrorTooManyRequests": MessageLookupByLibrary.simpleMessage(
      "操作过于频繁，请稍后再试",
    ),
    "backendErrorTransferAmountEmpty": MessageLookupByLibrary.simpleMessage(
      "划转金额不能为空",
    ),
    "backendErrorTransferAmountInvalid": MessageLookupByLibrary.simpleMessage(
      "划转金额参数错误",
    ),
    "backendErrorTransferFailed": MessageLookupByLibrary.simpleMessage("划转失败"),
    "backendErrorUserNotFound": MessageLookupByLibrary.simpleMessage("用户不存在"),
    "backendErrorVerificationCodeInvalid": MessageLookupByLibrary.simpleMessage(
      "验证码不正确",
    ),
    "backendErrorWithdrawNotSupported": MessageLookupByLibrary.simpleMessage(
      "当前不支持提现",
    ),
    "backendErrorWithdrawalAccountEmpty": MessageLookupByLibrary.simpleMessage(
      "提现账号不能为空",
    ),
    "backendErrorWithdrawalMethodEmpty": MessageLookupByLibrary.simpleMessage(
      "提现方式不能为空",
    ),
    "backendErrorWithdrawalMethodUnsupported":
        MessageLookupByLibrary.simpleMessage("不支持该提现方式"),
    "backendFallbackCouponFailed": MessageLookupByLibrary.simpleMessage(
      "优惠券校验失败",
    ),
    "backendFallbackEmailVerifyFailed": MessageLookupByLibrary.simpleMessage(
      "验证码发送失败",
    ),
    "backendFallbackLoginFailed": MessageLookupByLibrary.simpleMessage("登录失败"),
    "backendFallbackOperationFailed": MessageLookupByLibrary.simpleMessage(
      "操作失败",
    ),
    "backendFallbackOrderFailed": MessageLookupByLibrary.simpleMessage(
      "订单操作失败",
    ),
    "backendFallbackPasswordFailed": MessageLookupByLibrary.simpleMessage(
      "密码操作失败",
    ),
    "backendFallbackRegisterFailed": MessageLookupByLibrary.simpleMessage(
      "注册失败",
    ),
    "backendFallbackTicketFailed": MessageLookupByLibrary.simpleMessage(
      "工单操作失败",
    ),
    "backendFallbackTransferFailed": MessageLookupByLibrary.simpleMessage(
      "划转失败",
    ),
    "backup": MessageLookupByLibrary.simpleMessage("备份"),
    "backupAndRecovery": MessageLookupByLibrary.simpleMessage("备份与恢复"),
    "backupAndRecoveryDesc": MessageLookupByLibrary.simpleMessage(
      "通过WebDAV或者文件同步数据",
    ),
    "backupSuccess": MessageLookupByLibrary.simpleMessage("备份成功"),
    "basicConfig": MessageLookupByLibrary.simpleMessage("基本配置"),
    "basicConfigDesc": MessageLookupByLibrary.simpleMessage("全局修改基本配置"),
    "bind": MessageLookupByLibrary.simpleMessage("绑定"),
    "blacklistMode": MessageLookupByLibrary.simpleMessage("黑名单模式"),
    "bypassDomain": MessageLookupByLibrary.simpleMessage("排除域名"),
    "bypassDomainDesc": MessageLookupByLibrary.simpleMessage("仅在系统代理启用时生效"),
    "cacheCorrupt": MessageLookupByLibrary.simpleMessage("缓存已损坏，是否清空？"),
    "cancel": MessageLookupByLibrary.simpleMessage("取消"),
    "cancelFilterSystemApp": MessageLookupByLibrary.simpleMessage("取消过滤系统应用"),
    "cancelSelectAll": MessageLookupByLibrary.simpleMessage("取消全选"),
    "cannotGetWebUrl": MessageLookupByLibrary.simpleMessage("无法获取网页地址，请联系客服"),
    "cannotOpenBrowser": MessageLookupByLibrary.simpleMessage(
      "无法打开浏览器，请手动访问网页版",
    ),
    "checkError": MessageLookupByLibrary.simpleMessage("检测失败"),
    "checkNetwork": MessageLookupByLibrary.simpleMessage("请检查网络连接后重试"),
    "checkUpdate": MessageLookupByLibrary.simpleMessage("检查更新"),
    "checkUpdateError": MessageLookupByLibrary.simpleMessage("当前应用已经是最新版了"),
    "checking": MessageLookupByLibrary.simpleMessage("检测中..."),
    "clearCacheAndRestart": MessageLookupByLibrary.simpleMessage("清除缓存并重启"),
    "clearData": MessageLookupByLibrary.simpleMessage("清除数据"),
    "clearLogs": MessageLookupByLibrary.simpleMessage("清空日志"),
    "clearLogsConfirm": MessageLookupByLibrary.simpleMessage(
      "确定要清空当前日志和请求记录吗？此操作无法撤销。",
    ),
    "clipboardExport": MessageLookupByLibrary.simpleMessage("导出剪贴板"),
    "clipboardImport": MessageLookupByLibrary.simpleMessage("剪贴板导入"),
    "close": MessageLookupByLibrary.simpleMessage("关闭"),
    "color": MessageLookupByLibrary.simpleMessage("颜色"),
    "colorSchemes": MessageLookupByLibrary.simpleMessage("配色方案"),
    "columns": MessageLookupByLibrary.simpleMessage("列数"),
    "commissionHistory": MessageLookupByLibrary.simpleMessage("佣金历史"),
    "commissionRate": MessageLookupByLibrary.simpleMessage("佣金比例"),
    "commissionSettled": MessageLookupByLibrary.simpleMessage(
      "佣金将在好友订阅成功后结算到账户",
    ),
    "compatible": MessageLookupByLibrary.simpleMessage("兼容模式"),
    "compatibleDesc": MessageLookupByLibrary.simpleMessage(
      "开启将失去部分应用能力，获得全量的Clash的支持",
    ),
    "complete": MessageLookupByLibrary.simpleMessage("完成"),
    "completeWithdrawal": MessageLookupByLibrary.simpleMessage(
      "网页版提供更完整的提现功能和支付方式选择",
    ),
    "configurationError": MessageLookupByLibrary.simpleMessage("应用配置异常，请联系客服"),
    "confirm": MessageLookupByLibrary.simpleMessage("确定"),
    "confirmLogout": MessageLookupByLibrary.simpleMessage("确认退出"),
    "confirmNewPassword": MessageLookupByLibrary.simpleMessage("确认新密码"),
    "confirmTransfer": MessageLookupByLibrary.simpleMessage("确认划转"),
    "connected": MessageLookupByLibrary.simpleMessage("已连接"),
    "connections": MessageLookupByLibrary.simpleMessage("连接"),
    "connectionsDesc": MessageLookupByLibrary.simpleMessage("查看当前连接数据"),
    "connectivity": MessageLookupByLibrary.simpleMessage("连通性："),
    "contactMe": MessageLookupByLibrary.simpleMessage("联系我"),
    "contactSupport": MessageLookupByLibrary.simpleMessage("客服"),
    "content": MessageLookupByLibrary.simpleMessage("内容"),
    "contentScheme": MessageLookupByLibrary.simpleMessage("内容主题"),
    "copiedToClipboard": MessageLookupByLibrary.simpleMessage("已复制到剪贴板"),
    "copy": MessageLookupByLibrary.simpleMessage("复制"),
    "copyEnvVar": MessageLookupByLibrary.simpleMessage("复制环境变量"),
    "copyInviteLink": MessageLookupByLibrary.simpleMessage("复制邀请链接"),
    "copyLink": MessageLookupByLibrary.simpleMessage("复制链接"),
    "copyLogs": MessageLookupByLibrary.simpleMessage("复制日志"),
    "copySuccess": MessageLookupByLibrary.simpleMessage("复制成功"),
    "core": MessageLookupByLibrary.simpleMessage("内核"),
    "coreInfo": MessageLookupByLibrary.simpleMessage("内核信息"),
    "country": MessageLookupByLibrary.simpleMessage("区域"),
    "crashTest": MessageLookupByLibrary.simpleMessage("崩溃测试"),
    "create": MessageLookupByLibrary.simpleMessage("创建"),
    "createAccount": MessageLookupByLibrary.simpleMessage("创建账号"),
    "credentialsSaved": MessageLookupByLibrary.simpleMessage("凭据已保存"),
    "currentCommissionRate": m2,
    "customerServiceLoadFailed": MessageLookupByLibrary.simpleMessage(
      "客服页面加载失败，请稍后重试",
    ),
    "customerServiceLoadingSlow": MessageLookupByLibrary.simpleMessage(
      "客服页面加载较慢，请耐心等待...",
    ),
    "cut": MessageLookupByLibrary.simpleMessage("剪切"),
    "dark": MessageLookupByLibrary.simpleMessage("深色"),
    "dashboard": MessageLookupByLibrary.simpleMessage("仪表盘"),
    "days": MessageLookupByLibrary.simpleMessage("天"),
    "defaultNameserver": MessageLookupByLibrary.simpleMessage("默认域名服务器"),
    "defaultNameserverDesc": MessageLookupByLibrary.simpleMessage("用于解析DNS服务器"),
    "defaultSort": MessageLookupByLibrary.simpleMessage("按默认排序"),
    "defaultText": MessageLookupByLibrary.simpleMessage("默认"),
    "delay": MessageLookupByLibrary.simpleMessage("延迟"),
    "delaySort": MessageLookupByLibrary.simpleMessage("按延迟排序"),
    "delete": MessageLookupByLibrary.simpleMessage("删除"),
    "deleteMultipTip": m3,
    "deleteTip": m4,
    "desc": MessageLookupByLibrary.simpleMessage("基于ClashMeta的多平台代理客户端"),
    "detectionTip": MessageLookupByLibrary.simpleMessage("依赖第三方api，仅供参考"),
    "developerMode": MessageLookupByLibrary.simpleMessage("开发者模式"),
    "developerModeEnableTip": MessageLookupByLibrary.simpleMessage("开发者模式已启用。"),
    "direct": MessageLookupByLibrary.simpleMessage("直连"),
    "disclaimer": MessageLookupByLibrary.simpleMessage("重要提示"),
    "disclaimerDesc": MessageLookupByLibrary.simpleMessage(
      "本软件目前在公测阶段，如果收到更新提醒，请前往更新。旧版本容易导致服务不稳定或无法使用。",
    ),
    "discoverNewVersion": MessageLookupByLibrary.simpleMessage("发现新版本"),
    "discovery": MessageLookupByLibrary.simpleMessage("发现新版本"),
    "dnsDesc": MessageLookupByLibrary.simpleMessage("更新DNS相关设置"),
    "dnsMode": MessageLookupByLibrary.simpleMessage("DNS模式"),
    "doYouWantToPass": MessageLookupByLibrary.simpleMessage("是否要通过"),
    "domain": MessageLookupByLibrary.simpleMessage("域名"),
    "domainStatusAvailable": MessageLookupByLibrary.simpleMessage("服务可用"),
    "domainStatusChecking": MessageLookupByLibrary.simpleMessage("检查中..."),
    "domainStatusUnavailable": MessageLookupByLibrary.simpleMessage("服务不可用"),
    "download": MessageLookupByLibrary.simpleMessage("下载"),
    "edit": MessageLookupByLibrary.simpleMessage("编辑"),
    "emailAddress": MessageLookupByLibrary.simpleMessage("邮箱地址"),
    "emailVerificationCode": MessageLookupByLibrary.simpleMessage("邮箱验证码"),
    "emptyTip": m5,
    "en": MessageLookupByLibrary.simpleMessage("英语"),
    "enableOverride": MessageLookupByLibrary.simpleMessage("启用覆写"),
    "enterEmailForReset": MessageLookupByLibrary.simpleMessage(
      "请输入您的邮箱地址，我们会发送验证码到您的邮箱",
    ),
    "enterTransferAmount": MessageLookupByLibrary.simpleMessage("请输入划转金额"),
    "enterTransferAmountError": MessageLookupByLibrary.simpleMessage("请输入划转金额"),
    "entries": MessageLookupByLibrary.simpleMessage("个条目"),
    "exclude": MessageLookupByLibrary.simpleMessage("从最近任务中隐藏"),
    "excludeDesc": MessageLookupByLibrary.simpleMessage("应用在后台时,从最近任务中隐藏应用"),
    "existsTip": m6,
    "exit": MessageLookupByLibrary.simpleMessage("退出"),
    "expand": MessageLookupByLibrary.simpleMessage("标准"),
    "expirationTime": MessageLookupByLibrary.simpleMessage("到期时间"),
    "exportFile": MessageLookupByLibrary.simpleMessage("导出文件"),
    "exportLogs": MessageLookupByLibrary.simpleMessage("导出日志"),
    "exportSuccess": MessageLookupByLibrary.simpleMessage("导出成功"),
    "expressiveScheme": MessageLookupByLibrary.simpleMessage("表现力"),
    "externalController": MessageLookupByLibrary.simpleMessage("外部控制器"),
    "externalControllerDesc": MessageLookupByLibrary.simpleMessage(
      "开启后将可以通过9090端口控制Clash内核",
    ),
    "externalLink": MessageLookupByLibrary.simpleMessage("外部链接"),
    "externalResources": MessageLookupByLibrary.simpleMessage("外部资源"),
    "fakeipFilter": MessageLookupByLibrary.simpleMessage("Fakeip过滤"),
    "fakeipRange": MessageLookupByLibrary.simpleMessage("Fakeip范围"),
    "fallback": MessageLookupByLibrary.simpleMessage("Fallback"),
    "fallbackDesc": MessageLookupByLibrary.simpleMessage("一般情况下使用境外DNS"),
    "fallbackFilter": MessageLookupByLibrary.simpleMessage("Fallback过滤"),
    "fidelityScheme": MessageLookupByLibrary.simpleMessage("高保真"),
    "file": MessageLookupByLibrary.simpleMessage("文件"),
    "fileDesc": MessageLookupByLibrary.simpleMessage("直接上传配置文件"),
    "fileIsUpdate": MessageLookupByLibrary.simpleMessage("文件有修改，是否保存修改"),
    "fillInfoToRegister": MessageLookupByLibrary.simpleMessage("请填写以下信息完成注册"),
    "filterSystemApp": MessageLookupByLibrary.simpleMessage("过滤系统应用"),
    "findProcessMode": MessageLookupByLibrary.simpleMessage("查找进程"),
    "findProcessModeDesc": MessageLookupByLibrary.simpleMessage("开启后会有一定性能损耗"),
    "fontFamily": MessageLookupByLibrary.simpleMessage("字体"),
    "forgotPassword": MessageLookupByLibrary.simpleMessage("忘记密码"),
    "fourColumns": MessageLookupByLibrary.simpleMessage("四列"),
    "friendInviteReward": MessageLookupByLibrary.simpleMessage(
      "好友邀请的人成功消费，您也能赚取佣金",
    ),
    "fruitSaladScheme": MessageLookupByLibrary.simpleMessage("果缤纷"),
    "general": MessageLookupByLibrary.simpleMessage("常规"),
    "generalDesc": MessageLookupByLibrary.simpleMessage("修改通用设置"),
    "generateInviteCode": MessageLookupByLibrary.simpleMessage("生成邀请码"),
    "generatingInviteCode": MessageLookupByLibrary.simpleMessage("正在生成邀请码..."),
    "geoData": MessageLookupByLibrary.simpleMessage("地理数据"),
    "geodataLoader": MessageLookupByLibrary.simpleMessage("Geo低内存模式"),
    "geodataLoaderDesc": MessageLookupByLibrary.simpleMessage("开启将使用Geo低内存加载器"),
    "geoipCode": MessageLookupByLibrary.simpleMessage("Geoip代码"),
    "getOriginRules": MessageLookupByLibrary.simpleMessage("获取原始规则"),
    "global": MessageLookupByLibrary.simpleMessage("全局代理"),
    "go": MessageLookupByLibrary.simpleMessage("前往"),
    "goDownload": MessageLookupByLibrary.simpleMessage("前往下载"),
    "goToWeb": MessageLookupByLibrary.simpleMessage("前往网页"),
    "hasCacheChange": MessageLookupByLibrary.simpleMessage("是否缓存修改"),
    "hostsDesc": MessageLookupByLibrary.simpleMessage("追加Hosts"),
    "hotkeyConflict": MessageLookupByLibrary.simpleMessage("快捷键冲突"),
    "hotkeyManagement": MessageLookupByLibrary.simpleMessage("快捷键管理"),
    "hotkeyManagementDesc": MessageLookupByLibrary.simpleMessage("使用键盘控制应用程序"),
    "hours": MessageLookupByLibrary.simpleMessage("小时"),
    "iUnderstand": MessageLookupByLibrary.simpleMessage("我知道了"),
    "icon": MessageLookupByLibrary.simpleMessage("图片"),
    "iconConfiguration": MessageLookupByLibrary.simpleMessage("图片配置"),
    "iconStyle": MessageLookupByLibrary.simpleMessage("图标样式"),
    "import": MessageLookupByLibrary.simpleMessage("导入"),
    "importFile": MessageLookupByLibrary.simpleMessage("通过文件导入"),
    "importFromURL": MessageLookupByLibrary.simpleMessage("从URL导入"),
    "importUrl": MessageLookupByLibrary.simpleMessage("通过URL导入"),
    "infiniteTime": MessageLookupByLibrary.simpleMessage("长期有效"),
    "init": MessageLookupByLibrary.simpleMessage("初始化"),
    "inputCorrectHotkey": MessageLookupByLibrary.simpleMessage("请输入正确的快捷键"),
    "intelligentSelected": MessageLookupByLibrary.simpleMessage("智能选择"),
    "internet": MessageLookupByLibrary.simpleMessage("互联网"),
    "interval": MessageLookupByLibrary.simpleMessage("间隔"),
    "intranetIP": MessageLookupByLibrary.simpleMessage("内网 IP"),
    "invalidTransferAmount": MessageLookupByLibrary.simpleMessage("请输入有效的划转金额"),
    "invite": MessageLookupByLibrary.simpleMessage("邀请"),
    "inviteCode": MessageLookupByLibrary.simpleMessage("邀请码"),
    "inviteCodeGenFailed": MessageLookupByLibrary.simpleMessage("邀请码生成失败"),
    "inviteCodeGenerated": MessageLookupByLibrary.simpleMessage("邀请码生成成功"),
    "inviteCodeOptional": MessageLookupByLibrary.simpleMessage("邀请码（可选）"),
    "inviteCodeRequired": MessageLookupByLibrary.simpleMessage("需要邀请码"),
    "inviteCodeRequiredMessage": MessageLookupByLibrary.simpleMessage(
      "注册需要邀请码，请联系已注册用户获取邀请码后再进行注册。",
    ),
    "inviteLinkCopied": MessageLookupByLibrary.simpleMessage("邀请链接已复制，可分享给好友"),
    "inviteRegisterReward": MessageLookupByLibrary.simpleMessage(
      "邀请好友注册并成功订阅，即可获得佣金奖励",
    ),
    "inviteRules": MessageLookupByLibrary.simpleMessage("邀请规则"),
    "inviteStats": MessageLookupByLibrary.simpleMessage("邀请统计"),
    "ipcidr": MessageLookupByLibrary.simpleMessage("IP/掩码"),
    "ipv6Desc": MessageLookupByLibrary.simpleMessage("开启后将可以接收IPv6流量"),
    "ipv6InboundDesc": MessageLookupByLibrary.simpleMessage("允许IPv6入站"),
    "just": MessageLookupByLibrary.simpleMessage("刚刚"),
    "keepAliveIntervalDesc": MessageLookupByLibrary.simpleMessage("TCP保持活动间隔"),
    "key": MessageLookupByLibrary.simpleMessage("键"),
    "language": MessageLookupByLibrary.simpleMessage("语言"),
    "layout": MessageLookupByLibrary.simpleMessage("布局"),
    "light": MessageLookupByLibrary.simpleMessage("浅色"),
    "list": MessageLookupByLibrary.simpleMessage("列表"),
    "listen": MessageLookupByLibrary.simpleMessage("监听"),
    "loadMore": MessageLookupByLibrary.simpleMessage("加载更多"),
    "loading": MessageLookupByLibrary.simpleMessage("加载中..."),
    "local": MessageLookupByLibrary.simpleMessage("本地"),
    "localBackupDesc": MessageLookupByLibrary.simpleMessage("备份数据到本地"),
    "localRecoveryDesc": MessageLookupByLibrary.simpleMessage("通过文件恢复数据"),
    "logLevel": MessageLookupByLibrary.simpleMessage("日志等级"),
    "logcat": MessageLookupByLibrary.simpleMessage("日志捕获"),
    "logcatDesc": MessageLookupByLibrary.simpleMessage("开启后日志将在根菜单中显示"),
    "loggedOutSuccess": MessageLookupByLibrary.simpleMessage("已退出登录"),
    "loginNow": MessageLookupByLibrary.simpleMessage("立即登录"),
    "logout": MessageLookupByLibrary.simpleMessage("退出登录"),
    "logoutConfirmMsg": MessageLookupByLibrary.simpleMessage(
      "确定要退出当前账户吗？退出后需要重新登录。",
    ),
    "logoutFailed": m7,
    "logs": MessageLookupByLibrary.simpleMessage("日志"),
    "logsCleared": MessageLookupByLibrary.simpleMessage("日志和请求记录已清空"),
    "logsDesc": MessageLookupByLibrary.simpleMessage("日志捕获记录"),
    "logsTest": MessageLookupByLibrary.simpleMessage("日志测试"),
    "loopback": MessageLookupByLibrary.simpleMessage("回环解锁工具"),
    "loopbackDesc": MessageLookupByLibrary.simpleMessage("用于UWP回环解锁"),
    "loose": MessageLookupByLibrary.simpleMessage("宽松"),
    "maxTransferable": m8,
    "memoryInfo": MessageLookupByLibrary.simpleMessage("内存信息"),
    "messageTest": MessageLookupByLibrary.simpleMessage("消息测试"),
    "messageTestTip": MessageLookupByLibrary.simpleMessage("这是一条消息。"),
    "min": MessageLookupByLibrary.simpleMessage("最小"),
    "minimizeOnExit": MessageLookupByLibrary.simpleMessage("退出时最小化"),
    "minimizeOnExitDesc": MessageLookupByLibrary.simpleMessage("修改系统默认退出事件"),
    "minutes": MessageLookupByLibrary.simpleMessage("分钟"),
    "mixedPort": MessageLookupByLibrary.simpleMessage("混合端口"),
    "mode": MessageLookupByLibrary.simpleMessage("模式"),
    "monochromeScheme": MessageLookupByLibrary.simpleMessage("单色"),
    "months": MessageLookupByLibrary.simpleMessage("月"),
    "more": MessageLookupByLibrary.simpleMessage("更多"),
    "myInviteQr": MessageLookupByLibrary.simpleMessage("我的邀请二维码"),
    "name": MessageLookupByLibrary.simpleMessage("名称"),
    "nameSort": MessageLookupByLibrary.simpleMessage("按名称排序"),
    "nameserver": MessageLookupByLibrary.simpleMessage("域名服务器"),
    "nameserverDesc": MessageLookupByLibrary.simpleMessage("用于解析域名"),
    "nameserverPolicy": MessageLookupByLibrary.simpleMessage("域名服务器策略"),
    "nameserverPolicyDesc": MessageLookupByLibrary.simpleMessage("指定对应域名服务器策略"),
    "network": MessageLookupByLibrary.simpleMessage("网络"),
    "networkDesc": MessageLookupByLibrary.simpleMessage("修改网络相关设置"),
    "networkDetection": MessageLookupByLibrary.simpleMessage("网络检测"),
    "networkSpeed": MessageLookupByLibrary.simpleMessage("网络速度"),
    "neutralScheme": MessageLookupByLibrary.simpleMessage("中性"),
    "newMessageFromSupport": MessageLookupByLibrary.simpleMessage("客服新消息"),
    "newPassword": MessageLookupByLibrary.simpleMessage("新密码"),
    "noCommissionRecord": MessageLookupByLibrary.simpleMessage("暂无佣金记录"),
    "noData": MessageLookupByLibrary.simpleMessage("暂无数据"),
    "noHotKey": MessageLookupByLibrary.simpleMessage("暂无快捷键"),
    "noIcon": MessageLookupByLibrary.simpleMessage("无图标"),
    "noInfo": MessageLookupByLibrary.simpleMessage("暂无信息"),
    "noInvitationData": MessageLookupByLibrary.simpleMessage("暂无邀请数据"),
    "noInviteCode": MessageLookupByLibrary.simpleMessage("暂无邀请码"),
    "noMoreInfoDesc": MessageLookupByLibrary.simpleMessage("暂无更多信息"),
    "noNetwork": MessageLookupByLibrary.simpleMessage("无网络"),
    "noNetworkApp": MessageLookupByLibrary.simpleMessage("无网络应用"),
    "noProxy": MessageLookupByLibrary.simpleMessage("暂无代理"),
    "noProxyDesc": MessageLookupByLibrary.simpleMessage("请创建配置文件或者添加有效配置文件"),
    "noResolve": MessageLookupByLibrary.simpleMessage("不解析IP"),
    "nodeSelection": MessageLookupByLibrary.simpleMessage("节点选择"),
    "none": MessageLookupByLibrary.simpleMessage("无"),
    "notConnected": MessageLookupByLibrary.simpleMessage("未连接"),
    "notSelectedTip": MessageLookupByLibrary.simpleMessage("当前代理组无法选中"),
    "nullProfileDesc": MessageLookupByLibrary.simpleMessage("没有配置文件,请先添加配置文件"),
    "nullTip": m9,
    "numberTip": m10,
    "officialWebsite": MessageLookupByLibrary.simpleMessage("官网"),
    "oneColumn": MessageLookupByLibrary.simpleMessage("一列"),
    "onlineSupport": MessageLookupByLibrary.simpleMessage("在线客服"),
    "onlineSupportAddMore": MessageLookupByLibrary.simpleMessage("添加更多"),
    "onlineSupportApiConfigNotFound": MessageLookupByLibrary.simpleMessage(
      "在线客服API配置未找到，请检查配置",
    ),
    "onlineSupportCancel": MessageLookupByLibrary.simpleMessage("取消"),
    "onlineSupportClearHistory": MessageLookupByLibrary.simpleMessage("清除历史记录"),
    "onlineSupportClearHistoryConfirm": MessageLookupByLibrary.simpleMessage(
      "确定要清除所有聊天历史记录吗？此操作不可恢复。",
    ),
    "onlineSupportClickToSelect": MessageLookupByLibrary.simpleMessage(
      "点击选择图片",
    ),
    "onlineSupportConfirm": MessageLookupByLibrary.simpleMessage("确定"),
    "onlineSupportConnected": MessageLookupByLibrary.simpleMessage("成功连接客服系统"),
    "onlineSupportConnecting": MessageLookupByLibrary.simpleMessage("连接中..."),
    "onlineSupportConnectionError": MessageLookupByLibrary.simpleMessage(
      "连接错误",
    ),
    "onlineSupportDisconnected": MessageLookupByLibrary.simpleMessage("已断开"),
    "onlineSupportGetMessagesFailed": m11,
    "onlineSupportInputHint": MessageLookupByLibrary.simpleMessage(
      "请输入您的问题...",
    ),
    "onlineSupportNoMessages": MessageLookupByLibrary.simpleMessage(
      "暂无消息，发送消息开始咨询",
    ),
    "onlineSupportSelectImages": MessageLookupByLibrary.simpleMessage("选择图片"),
    "onlineSupportSelectImagesFailed": m12,
    "onlineSupportSend": MessageLookupByLibrary.simpleMessage("发送"),
    "onlineSupportSendImage": MessageLookupByLibrary.simpleMessage("发送图片"),
    "onlineSupportSendMessageFailed": MessageLookupByLibrary.simpleMessage(
      "发送消息失败: 无法获取认证token",
    ),
    "onlineSupportSupportedFormats": MessageLookupByLibrary.simpleMessage(
      "支持 JPG, PNG, GIF, WebP, BMP\n最大 10MB",
    ),
    "onlineSupportTitle": MessageLookupByLibrary.simpleMessage("在线客服"),
    "onlineSupportTokenNotFound": MessageLookupByLibrary.simpleMessage(
      "未找到认证token",
    ),
    "onlineSupportUnsupportedHttpMethod": m13,
    "onlineSupportUploadFailed": m14,
    "onlineSupportWebSocketConfigNotFound":
        MessageLookupByLibrary.simpleMessage("在线客服WebSocket配置未找到，请检查配置"),
    "onlyIcon": MessageLookupByLibrary.simpleMessage("仅图标"),
    "onlyOtherApps": MessageLookupByLibrary.simpleMessage("仅第三方应用"),
    "onlyStatisticsProxy": MessageLookupByLibrary.simpleMessage("仅统计代理"),
    "onlyStatisticsProxyDesc": MessageLookupByLibrary.simpleMessage(
      "开启后，将只统计代理流量",
    ),
    "openWebFailed": MessageLookupByLibrary.simpleMessage("打开网页失败，请手动访问网页版"),
    "options": MessageLookupByLibrary.simpleMessage("选项"),
    "orderAmount": m15,
    "orderNumber": m16,
    "other": MessageLookupByLibrary.simpleMessage("其他"),
    "otherContributors": MessageLookupByLibrary.simpleMessage("其他贡献者"),
    "outboundMode": MessageLookupByLibrary.simpleMessage("出站模式"),
    "override": MessageLookupByLibrary.simpleMessage("覆写"),
    "overrideDesc": MessageLookupByLibrary.simpleMessage("覆写代理相关配置"),
    "overrideDns": MessageLookupByLibrary.simpleMessage("覆写DNS"),
    "overrideDnsDesc": MessageLookupByLibrary.simpleMessage("开启后将覆盖配置中的DNS选项"),
    "overrideInvalidTip": MessageLookupByLibrary.simpleMessage("在脚本模式下不生效"),
    "overrideOriginRules": MessageLookupByLibrary.simpleMessage("覆盖原始规则"),
    "pageNumber": m17,
    "palette": MessageLookupByLibrary.simpleMessage("调色板"),
    "password": MessageLookupByLibrary.simpleMessage("密码"),
    "passwordMin8Chars": MessageLookupByLibrary.simpleMessage("密码至少需要8位字符"),
    "passwordMinLength": MessageLookupByLibrary.simpleMessage("密码长度至少6位"),
    "passwordMismatch": MessageLookupByLibrary.simpleMessage("两次输入的密码不一致"),
    "passwordResetFailed": MessageLookupByLibrary.simpleMessage("密码重置失败"),
    "passwordResetSuccessful": MessageLookupByLibrary.simpleMessage(
      "密码重置成功！请使用新密码登录",
    ),
    "passwordsDoNotMatch": MessageLookupByLibrary.simpleMessage("两次输入的密码不一致"),
    "paste": MessageLookupByLibrary.simpleMessage("粘贴"),
    "pendingCommission": MessageLookupByLibrary.simpleMessage("待确认佣金"),
    "pendingCommissionTooltipCommissionBalance":
        MessageLookupByLibrary.simpleMessage("好友下单三天后会自动确认佣金并发放到佣金余额"),
    "pendingCommissionTooltipWalletBalance":
        MessageLookupByLibrary.simpleMessage("好友下单三天后会自动确认佣金并发放到钱包余额"),
    "plans": MessageLookupByLibrary.simpleMessage("套餐"),
    "pleaseBindWebDAV": MessageLookupByLibrary.simpleMessage("请绑定WebDAV"),
    "pleaseConfirmNewPassword": MessageLookupByLibrary.simpleMessage(
      "请再次输入新密码",
    ),
    "pleaseConfirmPassword": MessageLookupByLibrary.simpleMessage("请确认密码"),
    "pleaseEnterAtLeast8CharsPassword": MessageLookupByLibrary.simpleMessage(
      "请输入至少8位密码",
    ),
    "pleaseEnterEmail": MessageLookupByLibrary.simpleMessage("请输入邮箱地址"),
    "pleaseEnterEmailAddress": MessageLookupByLibrary.simpleMessage("请先输入邮箱地址"),
    "pleaseEnterEmailVerificationCode": MessageLookupByLibrary.simpleMessage(
      "请输入邮箱验证码",
    ),
    "pleaseEnterInviteCode": MessageLookupByLibrary.simpleMessage("请输入邀请码"),
    "pleaseEnterNewPassword": MessageLookupByLibrary.simpleMessage("请输入新密码"),
    "pleaseEnterPassword": MessageLookupByLibrary.simpleMessage("请输入密码"),
    "pleaseEnterScriptName": MessageLookupByLibrary.simpleMessage("请输入脚本名称"),
    "pleaseEnterValidEmail": MessageLookupByLibrary.simpleMessage("请输入有效的邮箱地址"),
    "pleaseEnterValidEmailAddress": MessageLookupByLibrary.simpleMessage(
      "请输入有效的邮箱地址",
    ),
    "pleaseEnterValidVerificationCode": MessageLookupByLibrary.simpleMessage(
      "请输入有效的验证码",
    ),
    "pleaseEnterVerificationCode": MessageLookupByLibrary.simpleMessage(
      "请输入邮箱验证码",
    ),
    "pleaseEnterWithdrawAccount": MessageLookupByLibrary.simpleMessage(
      "请输入提现账号",
    ),
    "pleaseEnterYourEmailAddress": MessageLookupByLibrary.simpleMessage(
      "请输入您的邮箱地址",
    ),
    "pleaseInputAdminPassword": MessageLookupByLibrary.simpleMessage(
      "请输入管理员密码",
    ),
    "pleaseReEnterPassword": MessageLookupByLibrary.simpleMessage("请再次输入密码"),
    "pleaseSelectWithdrawMethod": MessageLookupByLibrary.simpleMessage(
      "请选择提现方式",
    ),
    "pleaseUploadFile": MessageLookupByLibrary.simpleMessage("请上传文件"),
    "pleaseUploadValidQrcode": MessageLookupByLibrary.simpleMessage(
      "请上传有效的二维码",
    ),
    "port": MessageLookupByLibrary.simpleMessage("端口"),
    "portConflictTip": MessageLookupByLibrary.simpleMessage("请输入不同的端口"),
    "portTip": m18,
    "preferH3Desc": MessageLookupByLibrary.simpleMessage("优先使用DOH的http/3"),
    "pressKeyboard": MessageLookupByLibrary.simpleMessage("请按下按键"),
    "preview": MessageLookupByLibrary.simpleMessage("预览"),
    "profile": MessageLookupByLibrary.simpleMessage("配置"),
    "profileAutoUpdateIntervalInvalidValidationDesc":
        MessageLookupByLibrary.simpleMessage("请输入有效间隔时间格式"),
    "profileAutoUpdateIntervalNullValidationDesc":
        MessageLookupByLibrary.simpleMessage("请输入自动更新间隔时间"),
    "profileHasUpdate": MessageLookupByLibrary.simpleMessage(
      "配置文件已经修改,是否关闭自动更新 ",
    ),
    "profileNameNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "请输入配置名称",
    ),
    "profileParseErrorDesc": MessageLookupByLibrary.simpleMessage("配置文件解析错误"),
    "profileUrlInvalidValidationDesc": MessageLookupByLibrary.simpleMessage(
      "请输入有效配置URL",
    ),
    "profileUrlNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "请输入配置URL",
    ),
    "profiles": MessageLookupByLibrary.simpleMessage("配置"),
    "profilesSort": MessageLookupByLibrary.simpleMessage("配置排序"),
    "project": MessageLookupByLibrary.simpleMessage("项目"),
    "providers": MessageLookupByLibrary.simpleMessage("提供者"),
    "proxies": MessageLookupByLibrary.simpleMessage("代理"),
    "proxiesSetting": MessageLookupByLibrary.simpleMessage("代理设置"),
    "proxyGroup": MessageLookupByLibrary.simpleMessage("代理组"),
    "proxyNameserver": MessageLookupByLibrary.simpleMessage("代理域名服务器"),
    "proxyNameserverDesc": MessageLookupByLibrary.simpleMessage("用于解析代理节点的域名"),
    "proxyPort": MessageLookupByLibrary.simpleMessage("代理端口"),
    "proxyPortDesc": MessageLookupByLibrary.simpleMessage("设置Clash监听端口"),
    "proxyProviders": MessageLookupByLibrary.simpleMessage("代理提供者"),
    "pureBlackMode": MessageLookupByLibrary.simpleMessage("纯黑模式"),
    "qrcode": MessageLookupByLibrary.simpleMessage("二维码"),
    "qrcodeDesc": MessageLookupByLibrary.simpleMessage("扫描二维码获取配置文件"),
    "rainbowScheme": MessageLookupByLibrary.simpleMessage("彩虹"),
    "recovery": MessageLookupByLibrary.simpleMessage("恢复"),
    "recoveryAll": MessageLookupByLibrary.simpleMessage("恢复所有数据"),
    "recoveryProfiles": MessageLookupByLibrary.simpleMessage("仅恢复配置文件"),
    "recoveryStrategy": MessageLookupByLibrary.simpleMessage("恢复策略"),
    "recoveryStrategy_compatible": MessageLookupByLibrary.simpleMessage("兼容"),
    "recoveryStrategy_override": MessageLookupByLibrary.simpleMessage("覆盖"),
    "recoverySuccess": MessageLookupByLibrary.simpleMessage("恢复成功"),
    "redirPort": MessageLookupByLibrary.simpleMessage("Redir端口"),
    "redo": MessageLookupByLibrary.simpleMessage("重做"),
    "refresh": MessageLookupByLibrary.simpleMessage("刷新"),
    "regExp": MessageLookupByLibrary.simpleMessage("正则"),
    "registerAccount": MessageLookupByLibrary.simpleMessage("注册账号"),
    "registerSuccessSaveCredentials": MessageLookupByLibrary.simpleMessage(
      "注册成功 - 保存凭据:",
    ),
    "registrationFailed": m19,
    "rememberPassword": MessageLookupByLibrary.simpleMessage("记起密码了？"),
    "remote": MessageLookupByLibrary.simpleMessage("远程"),
    "remoteBackupDesc": MessageLookupByLibrary.simpleMessage("备份数据到WebDAV"),
    "remoteRecoveryDesc": MessageLookupByLibrary.simpleMessage("通过WebDAV恢复数据"),
    "remove": MessageLookupByLibrary.simpleMessage("移除"),
    "rename": MessageLookupByLibrary.simpleMessage("重命名"),
    "requests": MessageLookupByLibrary.simpleMessage("请求"),
    "requestsDesc": MessageLookupByLibrary.simpleMessage("查看最近请求记录"),
    "resendVerificationCode": MessageLookupByLibrary.simpleMessage("重新发送验证码"),
    "reset": MessageLookupByLibrary.simpleMessage("重置"),
    "resetPassword": MessageLookupByLibrary.simpleMessage("重置密码"),
    "resetTip": MessageLookupByLibrary.simpleMessage("确定要重置吗?"),
    "resources": MessageLookupByLibrary.simpleMessage("资源"),
    "resourcesDesc": MessageLookupByLibrary.simpleMessage("外部资源相关信息"),
    "respectRules": MessageLookupByLibrary.simpleMessage("遵守规则"),
    "respectRulesDesc": MessageLookupByLibrary.simpleMessage(
      "DNS连接跟随rules,需配置proxy-server-nameserver",
    ),
    "routeAddress": MessageLookupByLibrary.simpleMessage("路由地址"),
    "routeAddressDesc": MessageLookupByLibrary.simpleMessage("配置监听路由地址"),
    "routeMode": MessageLookupByLibrary.simpleMessage("路由模式"),
    "routeMode_bypassPrivate": MessageLookupByLibrary.simpleMessage("绕过私有路由地址"),
    "routeMode_config": MessageLookupByLibrary.simpleMessage("使用配置"),
    "rule": MessageLookupByLibrary.simpleMessage("智能分流"),
    "ruleName": MessageLookupByLibrary.simpleMessage("规则名称"),
    "ruleProviders": MessageLookupByLibrary.simpleMessage("规则提供者"),
    "ruleTarget": MessageLookupByLibrary.simpleMessage("规则目标"),
    "save": MessageLookupByLibrary.simpleMessage("保存"),
    "saveChanges": MessageLookupByLibrary.simpleMessage("是否保存更改？"),
    "saveQr": MessageLookupByLibrary.simpleMessage("保存二维码"),
    "saveQrCodeFeature": MessageLookupByLibrary.simpleMessage(
      "保存二维码功能开发中，敬请期待",
    ),
    "saveTip": MessageLookupByLibrary.simpleMessage("确定要保存吗？"),
    "script": MessageLookupByLibrary.simpleMessage("脚本"),
    "search": MessageLookupByLibrary.simpleMessage("搜索"),
    "seconds": MessageLookupByLibrary.simpleMessage("秒"),
    "selectAll": MessageLookupByLibrary.simpleMessage("全选"),
    "selectTheme": MessageLookupByLibrary.simpleMessage("选择主题"),
    "selected": MessageLookupByLibrary.simpleMessage("已选择"),
    "selectedCountTitle": m20,
    "sendCodeFailed": MessageLookupByLibrary.simpleMessage("发送验证码失败"),
    "sendVerificationCode": MessageLookupByLibrary.simpleMessage("发送验证码"),
    "sendVerificationCodeFailed": m21,
    "setNewPassword": MessageLookupByLibrary.simpleMessage("设置新密码"),
    "settings": MessageLookupByLibrary.simpleMessage("设置"),
    "show": MessageLookupByLibrary.simpleMessage("显示窗口"),
    "shrink": MessageLookupByLibrary.simpleMessage("紧凑"),
    "silentLaunch": MessageLookupByLibrary.simpleMessage("静默启动"),
    "silentLaunchDesc": MessageLookupByLibrary.simpleMessage("后台启动"),
    "size": MessageLookupByLibrary.simpleMessage("尺寸"),
    "socksPort": MessageLookupByLibrary.simpleMessage("Socks端口"),
    "sort": MessageLookupByLibrary.simpleMessage("排序"),
    "source": MessageLookupByLibrary.simpleMessage("来源"),
    "sourceIp": MessageLookupByLibrary.simpleMessage("源IP"),
    "stackMode": MessageLookupByLibrary.simpleMessage("栈模式"),
    "standard": MessageLookupByLibrary.simpleMessage("标准"),
    "start": MessageLookupByLibrary.simpleMessage("连接"),
    "startVpn": MessageLookupByLibrary.simpleMessage("正在启动VPN..."),
    "status": MessageLookupByLibrary.simpleMessage("状态"),
    "statusDesc": MessageLookupByLibrary.simpleMessage("关闭后将使用系统DNS"),
    "stop": MessageLookupByLibrary.simpleMessage("断开"),
    "stopVpn": MessageLookupByLibrary.simpleMessage("正在停止VPN..."),
    "style": MessageLookupByLibrary.simpleMessage("风格"),
    "subRule": MessageLookupByLibrary.simpleMessage("子规则"),
    "submit": MessageLookupByLibrary.simpleMessage("提交"),
    "subscriptionExpired": MessageLookupByLibrary.simpleMessage("订阅已过期"),
    "subscriptionExpiredDetail": m22,
    "subscriptionExpiresToday": MessageLookupByLibrary.simpleMessage("订阅今日过期"),
    "subscriptionExpiresTodayDetail": MessageLookupByLibrary.simpleMessage(
      "套餐将在今日过期，请立即续费以免影响使用",
    ),
    "subscriptionExpiringInDays": MessageLookupByLibrary.simpleMessage(
      "订阅即将过期",
    ),
    "subscriptionExpiringInDaysDetail": m23,
    "subscriptionImportFailed": MessageLookupByLibrary.simpleMessage("订阅导入失败"),
    "subscriptionImportSuccess": MessageLookupByLibrary.simpleMessage("订阅导入成功"),
    "subscriptionNoSubscription": MessageLookupByLibrary.simpleMessage("无订阅套餐"),
    "subscriptionNoSubscriptionDetail": MessageLookupByLibrary.simpleMessage(
      "当前账户暂无可用的订阅套餐，请购买套餐后使用",
    ),
    "subscriptionNotLoggedIn": MessageLookupByLibrary.simpleMessage("未登录"),
    "subscriptionNotLoggedInDetail": MessageLookupByLibrary.simpleMessage(
      "请先登录账户",
    ),
    "subscriptionTrafficExhausted": MessageLookupByLibrary.simpleMessage(
      "流量已用完",
    ),
    "subscriptionTrafficExhaustedDetail": MessageLookupByLibrary.simpleMessage(
      "套餐流量已用完，请重置流量或更换套餐",
    ),
    "subscriptionUpdateFailed": MessageLookupByLibrary.simpleMessage("订阅更新失败"),
    "subscriptionUpdateSuccess": MessageLookupByLibrary.simpleMessage("订阅更新成功"),
    "subscriptionValid": MessageLookupByLibrary.simpleMessage("订阅有效"),
    "subscriptionValidDetail": m24,
    "switchTheme": MessageLookupByLibrary.simpleMessage("切换主题"),
    "sync": MessageLookupByLibrary.simpleMessage("同步"),
    "system": MessageLookupByLibrary.simpleMessage("系统"),
    "systemApp": MessageLookupByLibrary.simpleMessage("系统应用"),
    "systemFont": MessageLookupByLibrary.simpleMessage("系统字体"),
    "systemProxy": MessageLookupByLibrary.simpleMessage("系统代理"),
    "systemProxyDesc": MessageLookupByLibrary.simpleMessage("设置系统代理"),
    "tab": MessageLookupByLibrary.simpleMessage("标签页"),
    "tapToConnect": MessageLookupByLibrary.simpleMessage("点击连接"),
    "tcpConcurrent": MessageLookupByLibrary.simpleMessage("TCP并发"),
    "tcpConcurrentDesc": MessageLookupByLibrary.simpleMessage("开启后允许TCP并发"),
    "testUrl": MessageLookupByLibrary.simpleMessage("测速链接"),
    "textScale": MessageLookupByLibrary.simpleMessage("文本缩放"),
    "theme": MessageLookupByLibrary.simpleMessage("主题"),
    "themeColor": MessageLookupByLibrary.simpleMessage("主题色彩"),
    "themeDesc": MessageLookupByLibrary.simpleMessage("设置深色模式，调整色彩"),
    "themeMode": MessageLookupByLibrary.simpleMessage("主题模式"),
    "threeColumns": MessageLookupByLibrary.simpleMessage("三列"),
    "ticketRecords": MessageLookupByLibrary.simpleMessage("工单"),
    "tight": MessageLookupByLibrary.simpleMessage("紧凑"),
    "time": MessageLookupByLibrary.simpleMessage("时间"),
    "tip": MessageLookupByLibrary.simpleMessage("提示"),
    "toggle": MessageLookupByLibrary.simpleMessage("切换"),
    "tonalSpotScheme": MessageLookupByLibrary.simpleMessage("调性点缀"),
    "tools": MessageLookupByLibrary.simpleMessage("工具"),
    "totalCommission": MessageLookupByLibrary.simpleMessage("累计佣金"),
    "totalInvites": MessageLookupByLibrary.simpleMessage("总邀请数"),
    "totalRecords": m25,
    "tproxyPort": MessageLookupByLibrary.simpleMessage("Tproxy端口"),
    "trafficUsage": MessageLookupByLibrary.simpleMessage("流量统计"),
    "transfer": MessageLookupByLibrary.simpleMessage("划转"),
    "transferAmount": MessageLookupByLibrary.simpleMessage("划转金额"),
    "transferAmountExceeded": m26,
    "transferFailed": m27,
    "transferNote": MessageLookupByLibrary.simpleMessage("划转到钱包的余额可以抵扣app内消费"),
    "transferSuccess": MessageLookupByLibrary.simpleMessage("划转成功！"),
    "transferSuccessMsg": m28,
    "transferToWallet": MessageLookupByLibrary.simpleMessage("划转到钱包"),
    "transferring": MessageLookupByLibrary.simpleMessage("正在划转..."),
    "trayDisconnect": MessageLookupByLibrary.simpleMessage("断开连接"),
    "trayStartConnection": MessageLookupByLibrary.simpleMessage("启动连接"),
    "tun": MessageLookupByLibrary.simpleMessage("虚拟网卡（TUN）"),
    "tunDesc": MessageLookupByLibrary.simpleMessage("仅在管理员模式生效"),
    "twoColumns": MessageLookupByLibrary.simpleMessage("两列"),
    "unableToUpdateCurrentProfileDesc": MessageLookupByLibrary.simpleMessage(
      "无法更新当前配置文件",
    ),
    "undo": MessageLookupByLibrary.simpleMessage("撤销"),
    "unifiedDelay": MessageLookupByLibrary.simpleMessage("统一延迟"),
    "unifiedDelayDesc": MessageLookupByLibrary.simpleMessage("去除握手等额外延迟"),
    "unknown": MessageLookupByLibrary.simpleMessage("未知"),
    "unnamed": MessageLookupByLibrary.simpleMessage("未命名"),
    "update": MessageLookupByLibrary.simpleMessage("更新"),
    "updateCheckAllServersUnavailable": MessageLookupByLibrary.simpleMessage(
      "所有配置的更新服务器都不可用",
    ),
    "updateCheckCurrentVersion": m29,
    "updateCheckForceUpdate": m30,
    "updateCheckMustUpdate": MessageLookupByLibrary.simpleMessage("必须更新"),
    "updateCheckNewVersionFound": m31,
    "updateCheckNoServerUrlsConfigured": MessageLookupByLibrary.simpleMessage(
      "未配置任何更新服务器URL，请检查配置",
    ),
    "updateCheckReleaseNotes": MessageLookupByLibrary.simpleMessage("更新内容："),
    "updateCheckServerError": m32,
    "updateCheckServerTemporarilyUnavailable":
        MessageLookupByLibrary.simpleMessage("服务器暂时不可用，请稍后重试"),
    "updateCheckServerUrlNotConfigured": MessageLookupByLibrary.simpleMessage(
      "未配置更新服务器URL，请检查配置",
    ),
    "updateCheckUpdateLater": MessageLookupByLibrary.simpleMessage("稍后更新"),
    "updateCheckUpdateNow": MessageLookupByLibrary.simpleMessage("立即更新"),
    "upload": MessageLookupByLibrary.simpleMessage("上传"),
    "url": MessageLookupByLibrary.simpleMessage("URL"),
    "urlDesc": MessageLookupByLibrary.simpleMessage("通过URL获取配置文件"),
    "urlTip": m33,
    "useHosts": MessageLookupByLibrary.simpleMessage("使用Hosts"),
    "useSystemHosts": MessageLookupByLibrary.simpleMessage("使用系统Hosts"),
    "userCenter": MessageLookupByLibrary.simpleMessage("个人中心"),
    "value": MessageLookupByLibrary.simpleMessage("值"),
    "verificationCode": MessageLookupByLibrary.simpleMessage("验证码"),
    "verificationCode6Digits": MessageLookupByLibrary.simpleMessage(
      "验证码应为6位数字",
    ),
    "verificationCodeSent": MessageLookupByLibrary.simpleMessage(
      "验证码已发送到您的邮箱，请查收",
    ),
    "verificationCodeSentCheckEmail": MessageLookupByLibrary.simpleMessage(
      "验证码已发送，请查收邮箱",
    ),
    "verificationCodeSentTo": m34,
    "vibrantScheme": MessageLookupByLibrary.simpleMessage("活力"),
    "view": MessageLookupByLibrary.simpleMessage("查看"),
    "viewHistory": MessageLookupByLibrary.simpleMessage("查看历史记录"),
    "visitWebVersion": MessageLookupByLibrary.simpleMessage("请前往网页版提交提现申请"),
    "vpnDesc": MessageLookupByLibrary.simpleMessage("修改VPN相关设置"),
    "vpnEnableDesc": MessageLookupByLibrary.simpleMessage(
      "通过VpnService自动路由系统所有流量",
    ),
    "vpnSystemProxyDesc": MessageLookupByLibrary.simpleMessage(
      "为VpnService附加HTTP代理",
    ),
    "vpnTip": MessageLookupByLibrary.simpleMessage("重启VPN后改变生效"),
    "walletBalance": MessageLookupByLibrary.simpleMessage("钱包余额"),
    "walletDetails": MessageLookupByLibrary.simpleMessage("钱包详情"),
    "webDAVConfiguration": MessageLookupByLibrary.simpleMessage("WebDAV配置"),
    "whitelistMode": MessageLookupByLibrary.simpleMessage("白名单模式"),
    "withdraw": MessageLookupByLibrary.simpleMessage("提现"),
    "withdrawAccount": MessageLookupByLibrary.simpleMessage("提现账号"),
    "withdrawCommission": MessageLookupByLibrary.simpleMessage("提现佣金"),
    "withdrawMethod": MessageLookupByLibrary.simpleMessage("提现方式"),
    "withdrawRequestSubmitted": MessageLookupByLibrary.simpleMessage("提现申请已提交"),
    "withdrawRequestSubmittedWaitReview": MessageLookupByLibrary.simpleMessage(
      "提现申请已提交，请等待审核",
    ),
    "withdrawSubmissionFailed": MessageLookupByLibrary.simpleMessage("提交失败"),
    "withdrawSubmissionFailedWithError": m35,
    "withdrawSubmissionNote": MessageLookupByLibrary.simpleMessage(
      "提现申请将通过工单系统提交，请等待管理员审核。",
    ),
    "withdrawableAmount": m36,
    "withdrawalAvailable": MessageLookupByLibrary.simpleMessage("可用佣金可申请提现"),
    "xboard": MessageLookupByLibrary.simpleMessage("首页"),
    "xboard24HourCustomerService": MessageLookupByLibrary.simpleMessage(
      "24小时客服支持",
    ),
    "xboardAccountBalance": MessageLookupByLibrary.simpleMessage("余额"),
    "xboardAccountBanned": MessageLookupByLibrary.simpleMessage("账号已封禁"),
    "xboardAccountBannedDetail": MessageLookupByLibrary.simpleMessage(
      "当前账号已被封禁，请联系客服处理。",
    ),
    "xboardAccountInfo": MessageLookupByLibrary.simpleMessage("我的账号"),
    "xboardAccountManagement": MessageLookupByLibrary.simpleMessage("账号管理"),
    "xboardActualPaidAmount": MessageLookupByLibrary.simpleMessage("应付金额"),
    "xboardAddLinkToConfig": MessageLookupByLibrary.simpleMessage(
      "在配置文件中添加此订阅链接",
    ),
    "xboardAddingToConfigList": MessageLookupByLibrary.simpleMessage("添加到配置列表"),
    "xboardAfterPurchasingPlan": MessageLookupByLibrary.simpleMessage(
      "购买套餐后您将享受：",
    ),
    "xboardApiUrlNotConfigured": MessageLookupByLibrary.simpleMessage(
      "API地址未配置",
    ),
    "xboardAutoCheckEvery5Seconds": MessageLookupByLibrary.simpleMessage(
      "系统每5秒自动检查一次，支付完成后会自动跳转",
    ),
    "xboardAutoDetectPaymentStatus": MessageLookupByLibrary.simpleMessage(
      "自动检测支付状态",
    ),
    "xboardAutoOpeningPaymentPage": MessageLookupByLibrary.simpleMessage(
      "正在自动打开支付页面，完成支付后请返回应用",
    ),
    "xboardAutoRenewal": MessageLookupByLibrary.simpleMessage("自动续费"),
    "xboardAutoRenewalDescription": MessageLookupByLibrary.simpleMessage(
      "套餐到期前将使用账户余额自动续费，请确保余额充足。",
    ),
    "xboardAutoRenewalDisabled": MessageLookupByLibrary.simpleMessage(
      "自动续费已关闭",
    ),
    "xboardAutoRenewalEnabled": MessageLookupByLibrary.simpleMessage("自动续费已开启"),
    "xboardAutoRenewalNoPlan": MessageLookupByLibrary.simpleMessage(
      "购买套餐后可开启自动续费。",
    ),
    "xboardAutoRenewalUpdateFailed": MessageLookupByLibrary.simpleMessage(
      "自动续费设置更新失败，请稍后重试",
    ),
    "xboardAutoRunDescription": MessageLookupByLibrary.simpleMessage(
      "应用打开自动连接代理",
    ),
    "xboardAutoTesting": MessageLookupByLibrary.simpleMessage("自动测试中"),
    "xboardBack": MessageLookupByLibrary.simpleMessage("返回"),
    "xboardBalancePay": MessageLookupByLibrary.simpleMessage("余额支付"),
    "xboardBalanceWithAmount": m37,
    "xboardBrowserNotOpenedTip": MessageLookupByLibrary.simpleMessage(
      "如果浏览器未自动打开，可以点击\\\"重新打开\\\"或复制链接手动打开",
    ),
    "xboardBuyMoreTrafficOrUpgrade": MessageLookupByLibrary.simpleMessage(
      "请购买更多流量或升级套餐",
    ),
    "xboardBuyNow": MessageLookupByLibrary.simpleMessage("立即购买"),
    "xboardBuyPlan": MessageLookupByLibrary.simpleMessage("购买套餐"),
    "xboardBuyoutPlan": MessageLookupByLibrary.simpleMessage("买断制"),
    "xboardCancel": MessageLookupByLibrary.simpleMessage("取消"),
    "xboardCancelOrder": MessageLookupByLibrary.simpleMessage("取消订单"),
    "xboardCancelPayment": MessageLookupByLibrary.simpleMessage("取消支付"),
    "xboardCanceling": MessageLookupByLibrary.simpleMessage("取消中..."),
    "xboardChangePassword": MessageLookupByLibrary.simpleMessage("修改密码"),
    "xboardCheckOrders": MessageLookupByLibrary.simpleMessage("查看订单"),
    "xboardCheckPaymentFailed": MessageLookupByLibrary.simpleMessage(
      "检查支付状态失败",
    ),
    "xboardCheckPaymentStatus": MessageLookupByLibrary.simpleMessage("检查支付状态"),
    "xboardCheckStatus": MessageLookupByLibrary.simpleMessage("检查状态"),
    "xboardChecking": MessageLookupByLibrary.simpleMessage("检查中"),
    "xboardCheckingCachedSubscription": MessageLookupByLibrary.simpleMessage(
      "离线模式，正在检查本地订阅",
    ),
    "xboardCheckingSubscription": MessageLookupByLibrary.simpleMessage("检查订阅"),
    "xboardCleaningOldConfig": MessageLookupByLibrary.simpleMessage("清理旧配置"),
    "xboardClearError": MessageLookupByLibrary.simpleMessage("清除错误"),
    "xboardClickToCopy": MessageLookupByLibrary.simpleMessage("点击复制"),
    "xboardClickToSetupNodes": MessageLookupByLibrary.simpleMessage("点击设置节点"),
    "xboardCloseTicket": MessageLookupByLibrary.simpleMessage("关闭工单"),
    "xboardCloseTicketConfirm": MessageLookupByLibrary.simpleMessage(
      "确定要关闭此工单吗？关闭后将无法继续回复。",
    ),
    "xboardCommissionConfirmed": MessageLookupByLibrary.simpleMessage("已确认"),
    "xboardCommissionIssuing": MessageLookupByLibrary.simpleMessage("发放中"),
    "xboardCommissionOffsetAmount": MessageLookupByLibrary.simpleMessage(
      "佣金折抵金额",
    ),
    "xboardCompletePaymentInBrowser": MessageLookupByLibrary.simpleMessage(
      "2. 请在浏览器中完成支付操作",
    ),
    "xboardConfigDownloadFailed": MessageLookupByLibrary.simpleMessage(
      "配置文件下载失败，请检查订阅链接",
    ),
    "xboardConfigFormatError": MessageLookupByLibrary.simpleMessage(
      "配置文件格式错误，请联系服务提供商",
    ),
    "xboardConfigSaveFailed": MessageLookupByLibrary.simpleMessage(
      "保存配置失败，请检查存储空间",
    ),
    "xboardConfigurationError": MessageLookupByLibrary.simpleMessage("配置错误"),
    "xboardConfirm": MessageLookupByLibrary.simpleMessage("确定"),
    "xboardConfirmAction": MessageLookupByLibrary.simpleMessage("确定"),
    "xboardConfirmChange": MessageLookupByLibrary.simpleMessage("确认修改"),
    "xboardConfirmClose": MessageLookupByLibrary.simpleMessage("确认关闭"),
    "xboardConfirmNewPeriod": MessageLookupByLibrary.simpleMessage(
      "确认开启下一个流量周期？",
    ),
    "xboardConfirmPassword": MessageLookupByLibrary.simpleMessage("确认密码"),
    "xboardConfirmPurchase": MessageLookupByLibrary.simpleMessage("确认购买"),
    "xboardConfirmRenewPlan": MessageLookupByLibrary.simpleMessage("确认续费套餐"),
    "xboardConfirmResetTraffic": MessageLookupByLibrary.simpleMessage("确认重置流量"),
    "xboardCongratulationsSubscriptionActivated":
        MessageLookupByLibrary.simpleMessage("恭喜！您的套餐已成功购买并生效"),
    "xboardConnectGlobalQualityNodes": MessageLookupByLibrary.simpleMessage(
      "连接全球优质节点",
    ),
    "xboardConnecting": MessageLookupByLibrary.simpleMessage("正在连接"),
    "xboardConnectionHealth": MessageLookupByLibrary.simpleMessage("连接健康"),
    "xboardConnectionHealthSubtitle": MessageLookupByLibrary.simpleMessage(
      "检查服务器、订阅、节点和设备状态",
    ),
    "xboardConnectionTimeout": MessageLookupByLibrary.simpleMessage(
      "连接超时，请检查网络连接",
    ),
    "xboardContactCustomerService": MessageLookupByLibrary.simpleMessage(
      "联系客服",
    ),
    "xboardCopyDiagnosticBundle": MessageLookupByLibrary.simpleMessage("复制诊断包"),
    "xboardCopyFailed": MessageLookupByLibrary.simpleMessage("复制失败"),
    "xboardCopyInviteCode": MessageLookupByLibrary.simpleMessage("复制邀请码"),
    "xboardCopyInviteLink": MessageLookupByLibrary.simpleMessage("复制链接"),
    "xboardCopyLink": MessageLookupByLibrary.simpleMessage("复制链接"),
    "xboardCopyPaymentLink": MessageLookupByLibrary.simpleMessage("复制链接"),
    "xboardCopySubscriptionLinkAbove": MessageLookupByLibrary.simpleMessage(
      "复制上方的订阅链接",
    ),
    "xboardCoreStageCheckingHelper": MessageLookupByLibrary.simpleMessage(
      "检查 helper",
    ),
    "xboardCoreStageConnected": MessageLookupByLibrary.simpleMessage("已连接"),
    "xboardCoreStageCoreConnecting": MessageLookupByLibrary.simpleMessage(
      "核心回连",
    ),
    "xboardCoreStageFailed": MessageLookupByLibrary.simpleMessage("连接失败"),
    "xboardCoreStageHelperReady": MessageLookupByLibrary.simpleMessage(
      "helper 已复用",
    ),
    "xboardCoreStageStartingService": MessageLookupByLibrary.simpleMessage(
      "启动服务",
    ),
    "xboardCoreStageStopping": MessageLookupByLibrary.simpleMessage("正在断开"),
    "xboardCoreStageTunApplying": MessageLookupByLibrary.simpleMessage(
      "应用 TUN",
    ),
    "xboardCouponExpired": MessageLookupByLibrary.simpleMessage("优惠券已过期"),
    "xboardCouponNotYetActive": MessageLookupByLibrary.simpleMessage("优惠券尚未生效"),
    "xboardCouponOptional": MessageLookupByLibrary.simpleMessage("优惠券（可选）"),
    "xboardCreateTicket": MessageLookupByLibrary.simpleMessage("创建工单"),
    "xboardCreateTicketHint": MessageLookupByLibrary.simpleMessage(
      "遇到问题可以创建工单联系客服。",
    ),
    "xboardCreatedAt": MessageLookupByLibrary.simpleMessage("创建时间"),
    "xboardCreatingOrder": MessageLookupByLibrary.simpleMessage("正在创建订单"),
    "xboardCreatingOrderPleaseWait": MessageLookupByLibrary.simpleMessage(
      "我们正在为您创建新订单，请稍候",
    ),
    "xboardCreditedAmount": MessageLookupByLibrary.simpleMessage("到账金额"),
    "xboardCurrentBalance": MessageLookupByLibrary.simpleMessage("当前余额"),
    "xboardCurrentBusinessApi": MessageLookupByLibrary.simpleMessage("当前业务API"),
    "xboardCurrentDomain": MessageLookupByLibrary.simpleMessage("当前域名"),
    "xboardCurrentGateway": MessageLookupByLibrary.simpleMessage("当前网关"),
    "xboardCurrentNode": MessageLookupByLibrary.simpleMessage("当前节点"),
    "xboardCurrentPassword": MessageLookupByLibrary.simpleMessage("当前密码"),
    "xboardCurrentPlanBased": MessageLookupByLibrary.simpleMessage("基于当前套餐"),
    "xboardCurrentVersion": MessageLookupByLibrary.simpleMessage("当前版本"),
    "xboardCustomRechargeAmount": MessageLookupByLibrary.simpleMessage(
      "自定义充值金额",
    ),
    "xboardDays": MessageLookupByLibrary.simpleMessage("天"),
    "xboardDeductedBalance": MessageLookupByLibrary.simpleMessage("已抵扣余额"),
    "xboardDeductibleBalance": MessageLookupByLibrary.simpleMessage("可使用余额"),
    "xboardDeductibleDuringPayment": MessageLookupByLibrary.simpleMessage(
      "支付时可抵扣",
    ),
    "xboardDeviceAutoOfflineHint": MessageLookupByLibrary.simpleMessage(
      "离线超过30天的设备会被自动移除",
    ),
    "xboardDeviceCurrentDeviceLabel": MessageLookupByLibrary.simpleMessage(
      "当前设备",
    ),
    "xboardDeviceExpired": MessageLookupByLibrary.simpleMessage("已过期"),
    "xboardDeviceHealth": MessageLookupByLibrary.simpleMessage("设备状态"),
    "xboardDeviceHistory": MessageLookupByLibrary.simpleMessage("历史设备"),
    "xboardDeviceHistoryHint": MessageLookupByLibrary.simpleMessage(
      "仅保留 90 天内的移除记录，超期设备将自动清理",
    ),
    "xboardDeviceKickedContent": MessageLookupByLibrary.simpleMessage(
      "当前账号已在其他设备登录，本设备已断开连接。请重新登录或前往设备管理处理。",
    ),
    "xboardDeviceKickedTitle": MessageLookupByLibrary.simpleMessage("本设备已下线"),
    "xboardDeviceLabelId": MessageLookupByLibrary.simpleMessage("设备标识"),
    "xboardDeviceLabelLastIp": MessageLookupByLibrary.simpleMessage("最近 IP"),
    "xboardDeviceLabelLastOnline": MessageLookupByLibrary.simpleMessage("最后在线"),
    "xboardDeviceLabelOsVersion": MessageLookupByLibrary.simpleMessage("系统版本"),
    "xboardDeviceLabelRegion": MessageLookupByLibrary.simpleMessage("归属地"),
    "xboardDeviceLabelRevokedAt": MessageLookupByLibrary.simpleMessage("移除时间"),
    "xboardDeviceLabelRevokedBy": MessageLookupByLibrary.simpleMessage("移除来源"),
    "xboardDeviceManagement": MessageLookupByLibrary.simpleMessage("设备管理"),
    "xboardDeviceNoRecords": MessageLookupByLibrary.simpleMessage("暂无设备记录"),
    "xboardDeviceNoRecordsHint": MessageLookupByLibrary.simpleMessage(
      "登录过的设备会显示在这里，方便你随时移除。",
    ),
    "xboardDeviceOffline": MessageLookupByLibrary.simpleMessage("离线"),
    "xboardDeviceOnline": MessageLookupByLibrary.simpleMessage("在线"),
    "xboardDeviceRemoveCurrentConfirm": MessageLookupByLibrary.simpleMessage(
      "这台设备是当前登录设备，移除后会立即退出登录。",
    ),
    "xboardDeviceRemoveTitle": MessageLookupByLibrary.simpleMessage("移除设备"),
    "xboardDeviceRemoved": MessageLookupByLibrary.simpleMessage("设备已移除"),
    "xboardDeviceRevoked": MessageLookupByLibrary.simpleMessage("已移除"),
    "xboardDeviceSessionRevokedContent": MessageLookupByLibrary.simpleMessage(
      "本设备的登录权限已被移除，连接已断开。请重新登录以继续使用。",
    ),
    "xboardDeviceSessionRevokedTitle": MessageLookupByLibrary.simpleMessage(
      "设备已被移除",
    ),
    "xboardDeviceSummary": m38,
    "xboardDeviceUnit": m39,
    "xboardDeviceUnknown": MessageLookupByLibrary.simpleMessage("未知"),
    "xboardDeviceUnknownVersion": MessageLookupByLibrary.simpleMessage("未知版本"),
    "xboardDeviceUnlimited": MessageLookupByLibrary.simpleMessage("无限制"),
    "xboardDiagnosticBundleCopied": MessageLookupByLibrary.simpleMessage(
      "诊断包已复制",
    ),
    "xboardDiagnosticBusinessServices": MessageLookupByLibrary.simpleMessage(
      "业务服务",
    ),
    "xboardDiagnosticHealthyAccount": MessageLookupByLibrary.simpleMessage(
      "账户与订阅可用",
    ),
    "xboardDiagnosticHealthyCore": MessageLookupByLibrary.simpleMessage(
      "代理核心运行正常",
    ),
    "xboardDiagnosticHealthyGateway": MessageLookupByLibrary.simpleMessage(
      "当前业务网关可用",
    ),
    "xboardDiagnosticHealthyHeartbeat": MessageLookupByLibrary.simpleMessage(
      "设备心跳成功",
    ),
    "xboardDiagnosticHealthyItems": MessageLookupByLibrary.simpleMessage(
      "正常项目",
    ),
    "xboardDiagnosticHealthyNodes": MessageLookupByLibrary.simpleMessage(
      "可用代理节点",
    ),
    "xboardDiagnosticHealthyProxy": MessageLookupByLibrary.simpleMessage(
      "系统代理运行端口",
    ),
    "xboardDiagnosticIssueCore": MessageLookupByLibrary.simpleMessage(
      "代理核心未运行",
    ),
    "xboardDiagnosticIssueGateway": MessageLookupByLibrary.simpleMessage(
      "没有可用的业务网关",
    ),
    "xboardDiagnosticIssueNodes": MessageLookupByLibrary.simpleMessage(
      "没有可用的代理节点",
    ),
    "xboardDiagnosticIssueProxy": MessageLookupByLibrary.simpleMessage(
      "系统代理已开启但没有运行",
    ),
    "xboardDiagnosticLatestNetwork": MessageLookupByLibrary.simpleMessage(
      "最近一次网络连通性检测",
    ),
    "xboardDiagnosticNetworkConnectivity": MessageLookupByLibrary.simpleMessage(
      "网络连通性",
    ),
    "xboardDiagnosticNetworkNotRun": MessageLookupByLibrary.simpleMessage(
      "尚未执行网络连通性检测",
    ),
    "xboardDiagnosticNetworkSnapshotTime": MessageLookupByLibrary.simpleMessage(
      "检测时间",
    ),
    "xboardDiagnosticNoticeGateways": MessageLookupByLibrary.simpleMessage(
      "尚未验证的备用网关",
    ),
    "xboardDiagnosticNoticeTun": MessageLookupByLibrary.simpleMessage(
      "TUN 已配置但当前未生效，流量正在使用其他代理模式",
    ),
    "xboardDiagnosticNotices": MessageLookupByLibrary.simpleMessage("注意项目"),
    "xboardDiagnosticOverall": MessageLookupByLibrary.simpleMessage("总体状态"),
    "xboardDiagnosticOverallAbnormal": MessageLookupByLibrary.simpleMessage(
      "发现异常",
    ),
    "xboardDiagnosticOverallAttention": MessageLookupByLibrary.simpleMessage(
      "基本正常，但有需要注意的项目",
    ),
    "xboardDiagnosticOverallHealthy": MessageLookupByLibrary.simpleMessage(
      "正常",
    ),
    "xboardDiagnosticOverallServiceHealthy":
        MessageLookupByLibrary.simpleMessage("服务与系统代理状态正常，网络连通性尚未验证"),
    "xboardDiagnosticPlatform": MessageLookupByLibrary.simpleMessage("平台"),
    "xboardDiagnosticProblems": MessageLookupByLibrary.simpleMessage("异常项目"),
    "xboardDiagnosticProxyAndSystem": MessageLookupByLibrary.simpleMessage(
      "代理与系统",
    ),
    "xboardDiagnosticServiceStatus": MessageLookupByLibrary.simpleMessage(
      "服务状态",
    ),
    "xboardDiagnosticSuggestion": MessageLookupByLibrary.simpleMessage("建议"),
    "xboardDiagnosticSuggestionNetwork": MessageLookupByLibrary.simpleMessage(
      "请先检查 Wi-Fi、网线或系统网络设置，恢复网络后重新检测。",
    ),
    "xboardDiagnosticSuggestionNode": MessageLookupByLibrary.simpleMessage(
      "本地网络可用，但当前节点链路异常；请切换节点后重新检测。",
    ),
    "xboardDiagnosticSuggestionNone": MessageLookupByLibrary.simpleMessage(
      "当前连接工作正常，无需处理。",
    ),
    "xboardDiagnosticSuggestionRepair": MessageLookupByLibrary.simpleMessage(
      "请先刷新状态或使用一键修复，然后重新检测网络并复制报告。",
    ),
    "xboardDiagnosticSuggestionRunNetwork":
        MessageLookupByLibrary.simpleMessage(
          "服务和系统代理配置正常；如需确认节点入口、TLS 和代理链路，请执行网络连通性检测。",
        ),
    "xboardDiagnosticSuggestionTun": MessageLookupByLibrary.simpleMessage(
      "当前连接可以使用；只有部分应用无法使用系统代理时才需要启用 TUN。",
    ),
    "xboardDiagnosticSummaryTitle": MessageLookupByLibrary.simpleMessage(
      "FastCat 诊断报告",
    ),
    "xboardDiagnosticsCenter": MessageLookupByLibrary.simpleMessage("诊断中心"),
    "xboardDiagnosticsCenterSubtitle": MessageLookupByLibrary.simpleMessage(
      "检查服务状态、代理配置和网络连通性",
    ),
    "xboardDisconnecting": MessageLookupByLibrary.simpleMessage("正在断开"),
    "xboardDiscountAmount": MessageLookupByLibrary.simpleMessage("优惠金额"),
    "xboardDiscounted": MessageLookupByLibrary.simpleMessage("已优惠"),
    "xboardDiscountedPrice": MessageLookupByLibrary.simpleMessage("优惠后价格"),
    "xboardDocsCenter": MessageLookupByLibrary.simpleMessage("使用文档"),
    "xboardDownloadingConfig": MessageLookupByLibrary.simpleMessage("下载配置文件"),
    "xboardEmail": MessageLookupByLibrary.simpleMessage("邮箱"),
    "xboardEmailUnavailable": MessageLookupByLibrary.simpleMessage("邮箱不可用"),
    "xboardEnableTun": MessageLookupByLibrary.simpleMessage("开启 TUN"),
    "xboardEnjoyFastNetworkExperience": MessageLookupByLibrary.simpleMessage(
      "享受极速网络体验",
    ),
    "xboardEnterAmount": MessageLookupByLibrary.simpleMessage("请输入金额"),
    "xboardEnterCouponCode": MessageLookupByLibrary.simpleMessage("请输入优惠券代码"),
    "xboardEnterGiftCardCode": MessageLookupByLibrary.simpleMessage(
      "请输入礼品卡兑换码",
    ),
    "xboardEnterGiftCardCodeHint": MessageLookupByLibrary.simpleMessage(
      "请输入礼品卡兑换码",
    ),
    "xboardExcellent": MessageLookupByLibrary.simpleMessage("优秀"),
    "xboardExpiredOnDate": m40,
    "xboardExpiresOnDate": m41,
    "xboardExpiresOnWithDays": m42,
    "xboardExpiryTime": MessageLookupByLibrary.simpleMessage("过期时间"),
    "xboardFailedToCheckPaymentStatus": MessageLookupByLibrary.simpleMessage(
      "检查支付状态失败",
    ),
    "xboardFailedToGetSubscriptionInfo": MessageLookupByLibrary.simpleMessage(
      "获取订阅信息失败",
    ),
    "xboardFailedToOpenPaymentLink": MessageLookupByLibrary.simpleMessage(
      "打开支付链接失败",
    ),
    "xboardFailedToOpenPaymentPage": MessageLookupByLibrary.simpleMessage(
      "打开支付页面失败",
    ),
    "xboardFair": MessageLookupByLibrary.simpleMessage("一般"),
    "xboardForceUpdate": MessageLookupByLibrary.simpleMessage("强制更新"),
    "xboardForgotPassword": MessageLookupByLibrary.simpleMessage("忘记密码"),
    "xboardGatewayCandidateCount": m43,
    "xboardGatewayStatus": MessageLookupByLibrary.simpleMessage("网关状态"),
    "xboardGetGroupLinkFailed": MessageLookupByLibrary.simpleMessage(
      "获取群组链接失败",
    ),
    "xboardGettingIP": MessageLookupByLibrary.simpleMessage("获取中..."),
    "xboardGiftCardAlreadyUsedByUser": MessageLookupByLibrary.simpleMessage(
      "兑换失败：该礼品卡已被该用户使用",
    ),
    "xboardGiftCardCode": MessageLookupByLibrary.simpleMessage("礼品卡兑换码"),
    "xboardGiftCardCodeLabel": MessageLookupByLibrary.simpleMessage("礼品卡码"),
    "xboardGiftCardNotFound": MessageLookupByLibrary.simpleMessage(
      "兑换失败：该礼品卡不存在",
    ),
    "xboardGiftCardRedeem": MessageLookupByLibrary.simpleMessage("礼品卡兑换"),
    "xboardGiftCardRedeemSuccessRefreshed":
        MessageLookupByLibrary.simpleMessage("兑换成功：已自动刷新用户信息"),
    "xboardGiftCardRedeemTitle": MessageLookupByLibrary.simpleMessage("礼品卡兑换"),
    "xboardGlobalNodes": MessageLookupByLibrary.simpleMessage("全球节点"),
    "xboardGlobalProxy": MessageLookupByLibrary.simpleMessage("全局代理"),
    "xboardGood": MessageLookupByLibrary.simpleMessage("良好"),
    "xboardGotIt": MessageLookupByLibrary.simpleMessage("知道了"),
    "xboardGroup": MessageLookupByLibrary.simpleMessage("所属组"),
    "xboardGroupLinkNotConfigured": MessageLookupByLibrary.simpleMessage(
      "未配置群组链接",
    ),
    "xboardHalfYearlyPayment": MessageLookupByLibrary.simpleMessage("半年付"),
    "xboardHandleLater": MessageLookupByLibrary.simpleMessage("稍后再说"),
    "xboardHandlingFee": MessageLookupByLibrary.simpleMessage("手续费"),
    "xboardHealthCoreRunning": MessageLookupByLibrary.simpleMessage("运行中"),
    "xboardHealthDisabled": MessageLookupByLibrary.simpleMessage("未开启"),
    "xboardHealthDns": MessageLookupByLibrary.simpleMessage("DNS"),
    "xboardHealthDnsCustom": MessageLookupByLibrary.simpleMessage("使用自定义 DNS"),
    "xboardHealthDnsDefault": MessageLookupByLibrary.simpleMessage("使用默认 DNS"),
    "xboardHealthEnabled": MessageLookupByLibrary.simpleMessage("已开启"),
    "xboardHealthHelper": MessageLookupByLibrary.simpleMessage("Helper"),
    "xboardHealthHelperAvailable": MessageLookupByLibrary.simpleMessage("可用"),
    "xboardHealthHelperCheckFailed": MessageLookupByLibrary.simpleMessage(
      "检查失败",
    ),
    "xboardHealthHelperChecking": MessageLookupByLibrary.simpleMessage("检查中"),
    "xboardHealthHelperNoResponse": MessageLookupByLibrary.simpleMessage(
      "helper HTTP 未响应",
    ),
    "xboardHealthHelperNotRequired": MessageLookupByLibrary.simpleMessage(
      "当前平台不需要 Windows helper",
    ),
    "xboardHealthHelperUnavailable": MessageLookupByLibrary.simpleMessage(
      "不可用",
    ),
    "xboardHealthLastEvent": MessageLookupByLibrary.simpleMessage("最近事件"),
    "xboardHealthSubscriptionImport": m44,
    "xboardHealthTunApplied": MessageLookupByLibrary.simpleMessage("已应用"),
    "xboardHealthTunPending": MessageLookupByLibrary.simpleMessage("等待应用"),
    "xboardHealthy": MessageLookupByLibrary.simpleMessage("正常"),
    "xboardHigh": MessageLookupByLibrary.simpleMessage("高"),
    "xboardHighSpeedNetwork": MessageLookupByLibrary.simpleMessage("高速网络"),
    "xboardHome": MessageLookupByLibrary.simpleMessage("首页"),
    "xboardImageUploadUnavailable": MessageLookupByLibrary.simpleMessage(
      "图片上传未配置，请联系管理员",
    ),
    "xboardImportFailed": MessageLookupByLibrary.simpleMessage("导入失败"),
    "xboardImportSuccess": MessageLookupByLibrary.simpleMessage("导入成功"),
    "xboardImportingSubscription": MessageLookupByLibrary.simpleMessage(
      "正在导入订阅",
    ),
    "xboardInitializing": MessageLookupByLibrary.simpleMessage("正在初始化"),
    "xboardInsufficientBalance": MessageLookupByLibrary.simpleMessage("余额不足"),
    "xboardInvalidCredentials": MessageLookupByLibrary.simpleMessage(
      "用户名或密码错误",
    ),
    "xboardInvalidOrExpiredCoupon": MessageLookupByLibrary.simpleMessage(
      "优惠券代码无效或已过期",
    ),
    "xboardInvalidResponseFormat": MessageLookupByLibrary.simpleMessage(
      "服务器返回数据格式错误",
    ),
    "xboardInviteCode": MessageLookupByLibrary.simpleMessage("邀请码"),
    "xboardJoinGroup": MessageLookupByLibrary.simpleMessage("加入群组"),
    "xboardKeepSubscriptionLinkSafe": MessageLookupByLibrary.simpleMessage(
      "请妥善保管您的订阅链接，不要分享给他人",
    ),
    "xboardLater": MessageLookupByLibrary.simpleMessage("稍后处理"),
    "xboardLoadFailedCheckNetwork": MessageLookupByLibrary.simpleMessage(
      "加载失败，请检查网络",
    ),
    "xboardLoadingConfiguration": MessageLookupByLibrary.simpleMessage(
      "正在加载配置...",
    ),
    "xboardLoadingFailed": MessageLookupByLibrary.simpleMessage("加载失败"),
    "xboardLoadingPaymentPage": MessageLookupByLibrary.simpleMessage(
      "正在加载支付页面",
    ),
    "xboardLocalIP": MessageLookupByLibrary.simpleMessage("本机IP"),
    "xboardLoggedIn": MessageLookupByLibrary.simpleMessage("已登录"),
    "xboardLoggingIn": MessageLookupByLibrary.simpleMessage("登录中..."),
    "xboardLogin": MessageLookupByLibrary.simpleMessage("登录"),
    "xboardLoginErrorConfigLoad": MessageLookupByLibrary.simpleMessage(
      "配置加载失败，请稍后再试",
    ),
    "xboardLoginErrorCredentials": MessageLookupByLibrary.simpleMessage(
      "账号或密码错误，请先检查账号密码",
    ),
    "xboardLoginErrorDeviceLimit": MessageLookupByLibrary.simpleMessage(
      "登录设备已达到上限，请先释放离线设备",
    ),
    "xboardLoginErrorLimited": MessageLookupByLibrary.simpleMessage(
      "登录尝试过于频繁，请稍后再试",
    ),
    "xboardLoginErrorNetwork": MessageLookupByLibrary.simpleMessage(
      "服务暂时不可用，请稍后重试",
    ),
    "xboardLoginExpired": MessageLookupByLibrary.simpleMessage("登录已过期，请重新登录"),
    "xboardLoginFailed": MessageLookupByLibrary.simpleMessage("登录失败"),
    "xboardLoginSuccess": MessageLookupByLibrary.simpleMessage("登录成功"),
    "xboardLoginToViewSubscription": MessageLookupByLibrary.simpleMessage(
      "请登录后查看套餐使用情况",
    ),
    "xboardLogout": MessageLookupByLibrary.simpleMessage("退出登录"),
    "xboardLogoutConfirmContent": MessageLookupByLibrary.simpleMessage(
      "确定要退出当前账户吗？退出后需要重新登录。",
    ),
    "xboardLogoutConfirmTitle": MessageLookupByLibrary.simpleMessage("确认退出"),
    "xboardLogoutFailed": MessageLookupByLibrary.simpleMessage("退出失败"),
    "xboardLogoutForceAction": MessageLookupByLibrary.simpleMessage("仍然退出"),
    "xboardLogoutForceConfirmContent": MessageLookupByLibrary.simpleMessage(
      "强制退出会清除本地登录状态和节点缓存，服务恢复前可能无法再次登录。确定继续吗？",
    ),
    "xboardLogoutForceConfirmTitle": MessageLookupByLibrary.simpleMessage(
      "确认强制退出",
    ),
    "xboardLogoutProtectedContent": MessageLookupByLibrary.simpleMessage(
      "当前服务连接异常，退出后可能暂时无法重新登录。建议保留当前登录状态，等待服务恢复。",
    ),
    "xboardLogoutProtectedTitle": MessageLookupByLibrary.simpleMessage(
      "登录保护已开启",
    ),
    "xboardLogoutSuccess": MessageLookupByLibrary.simpleMessage("已退出登录"),
    "xboardLow": MessageLookupByLibrary.simpleMessage("低"),
    "xboardManageDevices": MessageLookupByLibrary.simpleMessage("管理设备"),
    "xboardMaybeLater": MessageLookupByLibrary.simpleMessage("稍后再说"),
    "xboardMedium": MessageLookupByLibrary.simpleMessage("中"),
    "xboardMine": MessageLookupByLibrary.simpleMessage("我的"),
    "xboardMissingRequiredField": MessageLookupByLibrary.simpleMessage(
      "缺少必要字段",
    ),
    "xboardMonthlyPayment": MessageLookupByLibrary.simpleMessage("月付"),
    "xboardMonthlyRenewal": MessageLookupByLibrary.simpleMessage("每月续费"),
    "xboardMustUpdate": MessageLookupByLibrary.simpleMessage("必须更新"),
    "xboardMyServices": MessageLookupByLibrary.simpleMessage("我的服务"),
    "xboardMyTickets": MessageLookupByLibrary.simpleMessage("我的工单"),
    "xboardMyWallet": MessageLookupByLibrary.simpleMessage("我的钱包"),
    "xboardNeedsAttention": MessageLookupByLibrary.simpleMessage("需要处理"),
    "xboardNetworkConnectionFailed": MessageLookupByLibrary.simpleMessage(
      "网络连接失败，请检查网络设置",
    ),
    "xboardNetworkDiagnostics": MessageLookupByLibrary.simpleMessage("网络诊断"),
    "xboardNetworkDiagnosticsConclusion": MessageLookupByLibrary.simpleMessage(
      "诊断结论",
    ),
    "xboardNetworkDiagnosticsConclusionDisconnectedDns":
        MessageLookupByLibrary.simpleMessage(
          "VPN 尚未连接，且基础网络 DNS 结果异常；请先修复本地网络或 DNS，再诊断节点链路。",
        ),
    "xboardNetworkDiagnosticsConclusionDisconnectedHealthy":
        MessageLookupByLibrary.simpleMessage(
          "VPN 尚未连接；基础网络工作正常，连接 VPN 后可继续诊断节点链路。",
        ),
    "xboardNetworkDiagnosticsConclusionDisconnectedNetwork":
        MessageLookupByLibrary.simpleMessage("VPN 尚未连接，且基础网络可能异常或无法连接外网。"),
    "xboardNetworkDiagnosticsConclusionDns":
        MessageLookupByLibrary.simpleMessage("DNS 解析结果异常，请检查 DNS 设置或当前网络。"),
    "xboardNetworkDiagnosticsConclusionHealthy":
        MessageLookupByLibrary.simpleMessage("DNS 与网络链路工作正常。"),
    "xboardNetworkDiagnosticsConclusionNetwork":
        MessageLookupByLibrary.simpleMessage("本地网络可能异常或无法连接外网。"),
    "xboardNetworkDiagnosticsConclusionNoNetwork":
        MessageLookupByLibrary.simpleMessage(
          "当前设备没有可用网络连接。代理内核虽然正在运行，但无法访问本地网络或互联网；请检查 Wi-Fi、网线或系统网络设置。",
        ),
    "xboardNetworkDiagnosticsConclusionNodeDns":
        MessageLookupByLibrary.simpleMessage("当前网络无法解析所选节点的入口域名。"),
    "xboardNetworkDiagnosticsConclusionNodeUnknown":
        MessageLookupByLibrary.simpleMessage("VPN 已连接，但无法识别当前使用的节点。"),
    "xboardNetworkDiagnosticsConclusionProtocol":
        MessageLookupByLibrary.simpleMessage("节点入口可达，但代理协议握手失败，请检查传输方式和鉴权参数。"),
    "xboardNetworkDiagnosticsConclusionProxy":
        MessageLookupByLibrary.simpleMessage("当前代理节点或代理链路不可用。"),
    "xboardNetworkDiagnosticsConclusionProxyWorking":
        MessageLookupByLibrary.simpleMessage("代理链路正常，当前网络部分直连目标受限，不影响代理使用。"),
    "xboardNetworkDiagnosticsConclusionTcp":
        MessageLookupByLibrary.simpleMessage(
          "公网直连正常，但所选节点的 TCP 入口连接超时；该入口可能不可达或受到当前网络限制。",
        ),
    "xboardNetworkDiagnosticsConclusionTcpRefused":
        MessageLookupByLibrary.simpleMessage("所选节点拒绝 TCP 连接，请检查服务器进程和监听端口。"),
    "xboardNetworkDiagnosticsConclusionTls":
        MessageLookupByLibrary.simpleMessage(
          "TCP 连接成功，但节点 TLS 握手失败，请检查 SNI、证书或当前网络的 TLS 过滤。",
        ),
    "xboardNetworkDiagnosticsConclusionUdp":
        MessageLookupByLibrary.simpleMessage(
          "公网直连正常，但 UDP 节点测试超时；当前网络可能不支持或限制 UDP。",
        ),
    "xboardNetworkDiagnosticsConnectFirst":
        MessageLookupByLibrary.simpleMessage("请先连接 VPN，再进行网络连通性诊断。"),
    "xboardNetworkDiagnosticsConnected": MessageLookupByLibrary.simpleMessage(
      "已连接",
    ),
    "xboardNetworkDiagnosticsCopied": MessageLookupByLibrary.simpleMessage(
      "诊断报告已复制",
    ),
    "xboardNetworkDiagnosticsCopyReport": MessageLookupByLibrary.simpleMessage(
      "复制报告",
    ),
    "xboardNetworkDiagnosticsCoreUnavailable":
        MessageLookupByLibrary.simpleMessage(
          "当前核心不支持分层诊断，请更新或完全重启客户端；下方 HTTPS 检测结果仍然有效。",
        ),
    "xboardNetworkDiagnosticsDescription": MessageLookupByLibrary.simpleMessage(
      "DNS 检测使用系统解析器；节点诊断会继续检测实际入口 DNS、TCP 或 UDP 传输、代理握手及 HTTP 连通性。",
    ),
    "xboardNetworkDiagnosticsDirectHttps": MessageLookupByLibrary.simpleMessage(
      "本地直连 HTTPS（国内基准）",
    ),
    "xboardNetworkDiagnosticsDisconnected":
        MessageLookupByLibrary.simpleMessage("未连接"),
    "xboardNetworkDiagnosticsDisconnectedInvalidated":
        MessageLookupByLibrary.simpleMessage("VPN 已断开，网络诊断已停止，当前结果已清除。"),
    "xboardNetworkDiagnosticsDns": MessageLookupByLibrary.simpleMessage(
      "DNS 解析",
    ),
    "xboardNetworkDiagnosticsDomain": MessageLookupByLibrary.simpleMessage(
      "域名",
    ),
    "xboardNetworkDiagnosticsEmptyResult": MessageLookupByLibrary.simpleMessage(
      "返回结果为空",
    ),
    "xboardNetworkDiagnosticsEndpointUnavailable":
        MessageLookupByLibrary.simpleMessage("无法获取节点入口信息"),
    "xboardNetworkDiagnosticsExpectedFakeIp":
        MessageLookupByLibrary.simpleMessage("当前 fake-ip 模式的正常结果"),
    "xboardNetworkDiagnosticsHttpFailed": MessageLookupByLibrary.simpleMessage(
      "代理已连接，但 HTTP 测试失败",
    ),
    "xboardNetworkDiagnosticsHttps": MessageLookupByLibrary.simpleMessage(
      "HTTPS 连通性",
    ),
    "xboardNetworkDiagnosticsIpConnectivity":
        MessageLookupByLibrary.simpleMessage("IPv4 / IPv6 连通性"),
    "xboardNetworkDiagnosticsNetworkEthernet":
        MessageLookupByLibrary.simpleMessage("有线网络"),
    "xboardNetworkDiagnosticsNetworkMobile":
        MessageLookupByLibrary.simpleMessage("移动网络"),
    "xboardNetworkDiagnosticsNetworkNone": MessageLookupByLibrary.simpleMessage(
      "无网络连接",
    ),
    "xboardNetworkDiagnosticsNetworkOther":
        MessageLookupByLibrary.simpleMessage("其他网络"),
    "xboardNetworkDiagnosticsNetworkType": MessageLookupByLibrary.simpleMessage(
      "网络类型",
    ),
    "xboardNetworkDiagnosticsNode": MessageLookupByLibrary.simpleMessage(
      "当前节点",
    ),
    "xboardNetworkDiagnosticsNodeDns": MessageLookupByLibrary.simpleMessage(
      "节点 DNS",
    ),
    "xboardNetworkDiagnosticsNodeDnsFailed":
        MessageLookupByLibrary.simpleMessage("节点域名解析失败"),
    "xboardNetworkDiagnosticsNodeDnsSuccess":
        MessageLookupByLibrary.simpleMessage("节点域名解析成功"),
    "xboardNetworkDiagnosticsNodeEndpoint":
        MessageLookupByLibrary.simpleMessage("节点入口"),
    "xboardNetworkDiagnosticsNodeHandshake":
        MessageLookupByLibrary.simpleMessage("TLS / 代理握手 / HTTP"),
    "xboardNetworkDiagnosticsNodeHttpSuccess":
        MessageLookupByLibrary.simpleMessage("节点握手与 HTTP 测试成功"),
    "xboardNetworkDiagnosticsNodeLayers": MessageLookupByLibrary.simpleMessage(
      "节点分层检测",
    ),
    "xboardNetworkDiagnosticsNodeTcp": MessageLookupByLibrary.simpleMessage(
      "TCP 端口",
    ),
    "xboardNetworkDiagnosticsNodeTls": MessageLookupByLibrary.simpleMessage(
      "TLS 握手",
    ),
    "xboardNetworkDiagnosticsProtocolFailed":
        MessageLookupByLibrary.simpleMessage("节点入口可达，但代理协议握手失败"),
    "xboardNetworkDiagnosticsProxyHttps": MessageLookupByLibrary.simpleMessage(
      "节点代理 HTTPS（境外参考）",
    ),
    "xboardNetworkDiagnosticsReachable": MessageLookupByLibrary.simpleMessage(
      "可连接",
    ),
    "xboardNetworkDiagnosticsReportTitle": MessageLookupByLibrary.simpleMessage(
      "FastCat 网络诊断报告",
    ),
    "xboardNetworkDiagnosticsRunning": MessageLookupByLibrary.simpleMessage(
      "诊断中…",
    ),
    "xboardNetworkDiagnosticsRunningTime": MessageLookupByLibrary.simpleMessage(
      "运行时间",
    ),
    "xboardNetworkDiagnosticsStart": MessageLookupByLibrary.simpleMessage(
      "开始诊断",
    ),
    "xboardNetworkDiagnosticsSubtitle": MessageLookupByLibrary.simpleMessage(
      "检查 VPN 状态、DNS 解析和 HTTPS 连通性",
    ),
    "xboardNetworkDiagnosticsSuspiciousAddress":
        MessageLookupByLibrary.simpleMessage("疑似 DNS 污染：私网或保留地址"),
    "xboardNetworkDiagnosticsTargetHuawei204":
        MessageLookupByLibrary.simpleMessage("华为 204"),
    "xboardNetworkDiagnosticsTargetVivo204":
        MessageLookupByLibrary.simpleMessage("vivo 204"),
    "xboardNetworkDiagnosticsTargetXiaomi204":
        MessageLookupByLibrary.simpleMessage("小米 204"),
    "xboardNetworkDiagnosticsTcpRefused": MessageLookupByLibrary.simpleMessage(
      "TCP 连接被拒绝，服务器端口可能未监听",
    ),
    "xboardNetworkDiagnosticsTcpSkippedUdp":
        MessageLookupByLibrary.simpleMessage("当前节点基于 UDP，不适用 TCP 端口检测"),
    "xboardNetworkDiagnosticsTcpSuccess": MessageLookupByLibrary.simpleMessage(
      "TCP 连接成功",
    ),
    "xboardNetworkDiagnosticsTcpTimeout": MessageLookupByLibrary.simpleMessage(
      "TCP 连接超时，节点入口可能不可达或受到当前网络限制",
    ),
    "xboardNetworkDiagnosticsTcpUnreachable":
        MessageLookupByLibrary.simpleMessage("没有到节点入口的可用路由"),
    "xboardNetworkDiagnosticsTestDomain": MessageLookupByLibrary.simpleMessage(
      "测试域名",
    ),
    "xboardNetworkDiagnosticsTime": MessageLookupByLibrary.simpleMessage("时间"),
    "xboardNetworkDiagnosticsTimeout": MessageLookupByLibrary.simpleMessage(
      "请求超时",
    ),
    "xboardNetworkDiagnosticsTlsFailed": MessageLookupByLibrary.simpleMessage(
      "TCP 已连接，但 TLS 握手失败",
    ),
    "xboardNetworkDiagnosticsUdpFailed": MessageLookupByLibrary.simpleMessage(
      "UDP 节点测试超时，当前网络可能不支持或限制 UDP",
    ),
    "xboardNetworkDiagnosticsUnavailable": MessageLookupByLibrary.simpleMessage(
      "不可用",
    ),
    "xboardNetworkDiagnosticsUnreachable": MessageLookupByLibrary.simpleMessage(
      "无法连接",
    ),
    "xboardNetworkDiagnosticsViaNode": MessageLookupByLibrary.simpleMessage(
      "经当前节点",
    ),
    "xboardNetworkDiagnosticsVpnRequired": MessageLookupByLibrary.simpleMessage(
      "VPN 尚未连接，已跳过节点 DNS、端口、TLS 和代理链路检测。",
    ),
    "xboardNetworkDiagnosticsVpnStatus": MessageLookupByLibrary.simpleMessage(
      "VPN 状态",
    ),
    "xboardNewPeriodCheckingResult": MessageLookupByLibrary.simpleMessage(
      "正在检查操作结果",
    ),
    "xboardNewPeriodConfirmContent": MessageLookupByLibrary.simpleMessage(
      "开启后将重置已使用流量，并扣除当前流量周期剩余的套餐时长。此操作无法撤销，是否继续？",
    ),
    "xboardNewPeriodFailed": MessageLookupByLibrary.simpleMessage(
      "开启新的流量周期失败，请稍后重试",
    ),
    "xboardNewPeriodInsufficientDuration": MessageLookupByLibrary.simpleMessage(
      "套餐剩余时长不足，无法开启新周期",
    ),
    "xboardNewPeriodNotAllowed": MessageLookupByLibrary.simpleMessage(
      "当前套餐不支持开启新周期",
    ),
    "xboardNewPeriodResultUncertainContent":
        MessageLookupByLibrary.simpleMessage(
          "网络响应异常，暂时无法确认新的流量周期是否已开启。请检查结果，不要重复提交。",
        ),
    "xboardNewPeriodResultUncertainTitle": MessageLookupByLibrary.simpleMessage(
      "暂时无法确认操作结果",
    ),
    "xboardNewPeriodStarting": MessageLookupByLibrary.simpleMessage(
      "正在开启新的流量周期",
    ),
    "xboardNewPeriodSuccess": MessageLookupByLibrary.simpleMessage("新的流量周期已开启"),
    "xboardNewPeriodTrafficExhaustedDetail":
        MessageLookupByLibrary.simpleMessage("套餐流量已用完，可以提前开启下一个流量周期。"),
    "xboardNewVersionFound": MessageLookupByLibrary.simpleMessage("发现新版本"),
    "xboardNext": MessageLookupByLibrary.simpleMessage("下一条"),
    "xboardNoAvailableNodes": MessageLookupByLibrary.simpleMessage("暂无可用节点"),
    "xboardNoAvailablePlan": MessageLookupByLibrary.simpleMessage("无可用套餐"),
    "xboardNoAvailableSubscription": MessageLookupByLibrary.simpleMessage(
      "无可用套餐",
    ),
    "xboardNoDocuments": MessageLookupByLibrary.simpleMessage("暂无文档"),
    "xboardNoGatewayActive": MessageLookupByLibrary.simpleMessage("暂无可用网关"),
    "xboardNoInternetConnection": MessageLookupByLibrary.simpleMessage(
      "无网络连接，请检查网络设置",
    ),
    "xboardNoMessages": MessageLookupByLibrary.simpleMessage("暂无消息"),
    "xboardNoOrderRecords": MessageLookupByLibrary.simpleMessage("暂无订单记录"),
    "xboardNoPaymentMethods": MessageLookupByLibrary.simpleMessage("暂无可用支付方式"),
    "xboardNoPlansAvailable": MessageLookupByLibrary.simpleMessage("暂无套餐信息"),
    "xboardNoSubscriptionInfo": MessageLookupByLibrary.simpleMessage("暂无套餐信息"),
    "xboardNoSubscriptionPlans": MessageLookupByLibrary.simpleMessage("暂无套餐信息"),
    "xboardNoTicketRecords": MessageLookupByLibrary.simpleMessage("暂无工单记录"),
    "xboardNoTrafficRecords": MessageLookupByLibrary.simpleMessage("暂无流量记录"),
    "xboardNodeCount": m45,
    "xboardNodeHealth": MessageLookupByLibrary.simpleMessage("节点状态"),
    "xboardNodeName": MessageLookupByLibrary.simpleMessage("节点名称"),
    "xboardNodeSelection": MessageLookupByLibrary.simpleMessage("节点选择"),
    "xboardNone": MessageLookupByLibrary.simpleMessage("无"),
    "xboardNormal": MessageLookupByLibrary.simpleMessage("普通"),
    "xboardNotLoggedIn": MessageLookupByLibrary.simpleMessage("未登录"),
    "xboardOfflineButActive": MessageLookupByLibrary.simpleMessage("离线占用"),
    "xboardOneClickRepair": MessageLookupByLibrary.simpleMessage("一键修复"),
    "xboardOneTimePayment": MessageLookupByLibrary.simpleMessage("一次性"),
    "xboardOnlineSupport": MessageLookupByLibrary.simpleMessage("在线客服"),
    "xboardOpenPaymentFailed": MessageLookupByLibrary.simpleMessage("打开支付页面失败"),
    "xboardOpenPaymentLinkFailed": MessageLookupByLibrary.simpleMessage(
      "打开支付链接失败",
    ),
    "xboardOperationFailed": MessageLookupByLibrary.simpleMessage("操作失败"),
    "xboardOperationTips": MessageLookupByLibrary.simpleMessage("操作提示"),
    "xboardOrderAmount": MessageLookupByLibrary.simpleMessage("订单金额"),
    "xboardOrderCreationFailed": MessageLookupByLibrary.simpleMessage("创建订单失败"),
    "xboardOrderInfo": MessageLookupByLibrary.simpleMessage("订单信息"),
    "xboardOrderLoadingFailed": MessageLookupByLibrary.simpleMessage("订单加载失败"),
    "xboardOrderNotFound": MessageLookupByLibrary.simpleMessage("订单不存在"),
    "xboardOrderNumber": MessageLookupByLibrary.simpleMessage("订单号"),
    "xboardOrderRecords": MessageLookupByLibrary.simpleMessage("订单记录"),
    "xboardOrderStatus": MessageLookupByLibrary.simpleMessage("订单状态"),
    "xboardOrderStatusCancelled": MessageLookupByLibrary.simpleMessage("已取消"),
    "xboardOrderStatusCompleted": MessageLookupByLibrary.simpleMessage("已完成"),
    "xboardOrderStatusOffset": MessageLookupByLibrary.simpleMessage("已抵扣"),
    "xboardOrderStatusOpening": MessageLookupByLibrary.simpleMessage("开通中"),
    "xboardOrderStatusPending": MessageLookupByLibrary.simpleMessage("待支付"),
    "xboardOriginalPrice": MessageLookupByLibrary.simpleMessage("原价"),
    "xboardPackageAmount": MessageLookupByLibrary.simpleMessage("套餐金额"),
    "xboardPassword": MessageLookupByLibrary.simpleMessage("密码"),
    "xboardPasswordChanged": MessageLookupByLibrary.simpleMessage("密码修改成功"),
    "xboardPayNow": MessageLookupByLibrary.simpleMessage("立即支付"),
    "xboardPayableAmount": MessageLookupByLibrary.simpleMessage("应付金额"),
    "xboardPaymentCancelled": MessageLookupByLibrary.simpleMessage("支付已取消"),
    "xboardPaymentComplete": MessageLookupByLibrary.simpleMessage("支付完成"),
    "xboardPaymentCompleted": MessageLookupByLibrary.simpleMessage("支付完成！"),
    "xboardPaymentFailed": MessageLookupByLibrary.simpleMessage("支付失败"),
    "xboardPaymentGateway": MessageLookupByLibrary.simpleMessage("支付网关"),
    "xboardPaymentInfo": MessageLookupByLibrary.simpleMessage("支付信息"),
    "xboardPaymentInstructions1": MessageLookupByLibrary.simpleMessage(
      "1. 系统已自动为您打开支付页面",
    ),
    "xboardPaymentInstructions2": MessageLookupByLibrary.simpleMessage(
      "2. 请在浏览器中完成支付操作",
    ),
    "xboardPaymentInstructions3": MessageLookupByLibrary.simpleMessage(
      "3. 支付完成后返回应用，系统将自动检测",
    ),
    "xboardPaymentLink": MessageLookupByLibrary.simpleMessage("支付链接"),
    "xboardPaymentLinkCopied": MessageLookupByLibrary.simpleMessage(
      "支付链接已复制到剪贴板",
    ),
    "xboardPaymentMethodVerified": MessageLookupByLibrary.simpleMessage(
      "支付方式验证通过",
    ),
    "xboardPaymentMethodVerifiedPreparing":
        MessageLookupByLibrary.simpleMessage("支付方式已验证，准备跳转到支付页面"),
    "xboardPaymentMethods": MessageLookupByLibrary.simpleMessage("支付方式"),
    "xboardPaymentPageAutoOpened": MessageLookupByLibrary.simpleMessage(
      "1. 系统已自动为您打开支付页面",
    ),
    "xboardPaymentPageOpenedCompleteAndReturn":
        MessageLookupByLibrary.simpleMessage("支付页面已打开，请完成支付并返回应用"),
    "xboardPaymentPageOpenedInBrowser": MessageLookupByLibrary.simpleMessage(
      "已在浏览器中打开支付页面，完成支付后请返回应用",
    ),
    "xboardPaymentSuccess": MessageLookupByLibrary.simpleMessage("支付成功"),
    "xboardPaymentSuccessful": MessageLookupByLibrary.simpleMessage("🎉 支付成功！"),
    "xboardPendingOrdersHint": MessageLookupByLibrary.simpleMessage(
      "如已支付未到账，可在订单页刷新状态",
    ),
    "xboardPeriod": MessageLookupByLibrary.simpleMessage("周期"),
    "xboardPlanBased": MessageLookupByLibrary.simpleMessage("基于套餐"),
    "xboardPlanExpiryReminder": MessageLookupByLibrary.simpleMessage(
      "套餐到期邮件提醒",
    ),
    "xboardPlanInfo": MessageLookupByLibrary.simpleMessage("购买订阅"),
    "xboardPlanName": MessageLookupByLibrary.simpleMessage("套餐名称"),
    "xboardPlanNotFound": MessageLookupByLibrary.simpleMessage("套餐不存在"),
    "xboardPlans": MessageLookupByLibrary.simpleMessage("商店"),
    "xboardPleaseEnterGiftCardCode": MessageLookupByLibrary.simpleMessage(
      "请输入礼品卡码",
    ),
    "xboardPleaseSelectPaymentPeriod": MessageLookupByLibrary.simpleMessage(
      "请选择购买周期",
    ),
    "xboardPleaseWait": MessageLookupByLibrary.simpleMessage("请稍候"),
    "xboardPoor": MessageLookupByLibrary.simpleMessage("较差"),
    "xboardPreparingImport": MessageLookupByLibrary.simpleMessage("准备导入"),
    "xboardPreparingPaymentPage": MessageLookupByLibrary.simpleMessage(
      "正在准备支付页面，即将跳转",
    ),
    "xboardPrevious": MessageLookupByLibrary.simpleMessage("上一条"),
    "xboardPriority": MessageLookupByLibrary.simpleMessage("优先级"),
    "xboardProcessing": MessageLookupByLibrary.simpleMessage("处理中..."),
    "xboardProductInfo": MessageLookupByLibrary.simpleMessage("商品信息"),
    "xboardProfessionalSupport": MessageLookupByLibrary.simpleMessage("专业客服"),
    "xboardProfile": MessageLookupByLibrary.simpleMessage("配置文件"),
    "xboardProtectNetworkPrivacy": MessageLookupByLibrary.simpleMessage(
      "保护您的网络隐私",
    ),
    "xboardProxy": MessageLookupByLibrary.simpleMessage("代理"),
    "xboardProxyActualAddress": MessageLookupByLibrary.simpleMessage("系统实际地址"),
    "xboardProxyClientSetting": MessageLookupByLibrary.simpleMessage("客户端设置"),
    "xboardProxyExpectedAddress": MessageLookupByLibrary.simpleMessage("期望地址"),
    "xboardProxyListening": MessageLookupByLibrary.simpleMessage("监听正常"),
    "xboardProxyLocalPort": MessageLookupByLibrary.simpleMessage("本地端口"),
    "xboardProxyMode": MessageLookupByLibrary.simpleMessage("代理模式"),
    "xboardProxyModeDirectDescription": MessageLookupByLibrary.simpleMessage(
      "所有流量都直接连接，不使用代理",
    ),
    "xboardProxyModeGlobalDescription": MessageLookupByLibrary.simpleMessage(
      "全球网络均通过代理进行访问（建议特殊网址无法访问时使用）",
    ),
    "xboardProxyModeRuleDescription": MessageLookupByLibrary.simpleMessage(
      "智能区分目标网络地区实现加速（推荐使用）",
    ),
    "xboardProxyNotListening": MessageLookupByLibrary.simpleMessage("未监听"),
    "xboardProxyRepairCoreNotRunning": MessageLookupByLibrary.simpleMessage(
      "代理核心未运行，请先连接后再执行一键修复。",
    ),
    "xboardProxyRepairPortUnavailable": MessageLookupByLibrary.simpleMessage(
      "本地代理端口未监听，未开启系统代理。",
    ),
    "xboardProxyRepairVerifyFailed": MessageLookupByLibrary.simpleMessage(
      "修复后回读验证失败，系统代理 IP 或端口仍不匹配。",
    ),
    "xboardProxyRepairWriteFailed": MessageLookupByLibrary.simpleMessage(
      "写入设备系统代理设置失败。",
    ),
    "xboardProxyStatusClientDisabled": MessageLookupByLibrary.simpleMessage(
      "客户端系统代理设置未开启",
    ),
    "xboardProxyStatusMismatch": MessageLookupByLibrary.simpleMessage(
      "系统代理 IP 或端口与客户端不一致",
    ),
    "xboardProxyStatusPortUnavailable": MessageLookupByLibrary.simpleMessage(
      "本地代理端口未监听",
    ),
    "xboardProxyStatusReadFailed": MessageLookupByLibrary.simpleMessage(
      "无法读取系统代理状态",
    ),
    "xboardProxyStatusSource": MessageLookupByLibrary.simpleMessage("系统来源"),
    "xboardProxyStatusStale": MessageLookupByLibrary.simpleMessage(
      "代理核心已停止，但系统仍残留代理设置",
    ),
    "xboardProxyStatusSystemDisabled": MessageLookupByLibrary.simpleMessage(
      "设备系统代理未开启",
    ),
    "xboardProxyStatusTunActive": MessageLookupByLibrary.simpleMessage(
      "TUN 已生效，无需开启系统代理",
    ),
    "xboardPurchasePlan": MessageLookupByLibrary.simpleMessage("购买套餐"),
    "xboardPurchaseSubscription": MessageLookupByLibrary.simpleMessage("购买套餐"),
    "xboardPurchaseSubscriptionToUse": MessageLookupByLibrary.simpleMessage(
      "请购买套餐后使用",
    ),
    "xboardPurchaseTraffic": MessageLookupByLibrary.simpleMessage("购买流量"),
    "xboardQuarterlyPayment": MessageLookupByLibrary.simpleMessage("季付"),
    "xboardRecharge": MessageLookupByLibrary.simpleMessage("充值"),
    "xboardRechargeAmount": MessageLookupByLibrary.simpleMessage("充值金额"),
    "xboardRechargeBalance": MessageLookupByLibrary.simpleMessage("余额充值"),
    "xboardRechargeBalanceTip": MessageLookupByLibrary.simpleMessage(
      "充值金额将进入账户余额，可用于购买套餐或支付订单。",
    ),
    "xboardRechargeBonus": MessageLookupByLibrary.simpleMessage("充值奖励"),
    "xboardRechargeNow": MessageLookupByLibrary.simpleMessage("立即充值"),
    "xboardRedeemFailed": MessageLookupByLibrary.simpleMessage("兑换失败"),
    "xboardRedeemFailedWithError": m46,
    "xboardRedeemNow": MessageLookupByLibrary.simpleMessage("立即兑换"),
    "xboardRedeemSuccess": MessageLookupByLibrary.simpleMessage("兑换成功"),
    "xboardRefresh": MessageLookupByLibrary.simpleMessage("刷新"),
    "xboardRefreshFailedHint": MessageLookupByLibrary.simpleMessage(
      "订阅配置刷新失败，请稍后手动刷新",
    ),
    "xboardRefreshStatus": MessageLookupByLibrary.simpleMessage("刷新状态"),
    "xboardRefundAmount": MessageLookupByLibrary.simpleMessage("退回钱包金额"),
    "xboardRegister": MessageLookupByLibrary.simpleMessage("注册"),
    "xboardRegisterFailed": MessageLookupByLibrary.simpleMessage("注册失败"),
    "xboardRegisterSuccess": MessageLookupByLibrary.simpleMessage(
      "注册成功！正在跳转到登录页面...",
    ),
    "xboardReleaseOfflineDevices": MessageLookupByLibrary.simpleMessage(
      "释放离线设备",
    ),
    "xboardReleaseOfflineDevicesConfirm": MessageLookupByLibrary.simpleMessage(
      "将移除离线但仍占用名额的设备，不会影响当前设备。继续吗？",
    ),
    "xboardReload": MessageLookupByLibrary.simpleMessage("重新获取"),
    "xboardReloadNodes": MessageLookupByLibrary.simpleMessage("重新加载节点"),
    "xboardRelogin": MessageLookupByLibrary.simpleMessage("重新登录"),
    "xboardRemainingBalance": MessageLookupByLibrary.simpleMessage("剩余"),
    "xboardRememberPassword": MessageLookupByLibrary.simpleMessage("记住密码"),
    "xboardRenewPlan": MessageLookupByLibrary.simpleMessage("续费套餐"),
    "xboardRenewToContinue": MessageLookupByLibrary.simpleMessage("请续费后继续使用"),
    "xboardReopen": MessageLookupByLibrary.simpleMessage("重新打开"),
    "xboardReopenPayment": MessageLookupByLibrary.simpleMessage("重新打开"),
    "xboardReopenPaymentPageTip": MessageLookupByLibrary.simpleMessage(
      "如需重新打开，可点击下方\\\"重新打开\\\"按钮",
    ),
    "xboardRepairCompleted": MessageLookupByLibrary.simpleMessage("修复完成"),
    "xboardReplyFailedRetry": MessageLookupByLibrary.simpleMessage(
      "回复失败，请稍后重试",
    ),
    "xboardReplyHint": MessageLookupByLibrary.simpleMessage("输入回复内容..."),
    "xboardResetCurrentPlanTraffic": MessageLookupByLibrary.simpleMessage(
      "重置当前套餐流量",
    ),
    "xboardResetTraffic": MessageLookupByLibrary.simpleMessage("重置流量"),
    "xboardResetTrafficByPlanCycle": MessageLookupByLibrary.simpleMessage(
      "按套餐周期重置流量",
    ),
    "xboardResetTrafficConfirmContent": MessageLookupByLibrary.simpleMessage(
      "此操作将重置已使用的流量，但不会增加套餐时长，是否继续？",
    ),
    "xboardResetTrafficInDays": m47,
    "xboardResetTrafficToday": MessageLookupByLibrary.simpleMessage(
      "已用流量已在今天重置",
    ),
    "xboardRetry": MessageLookupByLibrary.simpleMessage("重试"),
    "xboardRetryGet": MessageLookupByLibrary.simpleMessage("重新获取"),
    "xboardReturn": MessageLookupByLibrary.simpleMessage("返回"),
    "xboardReturnAfterPaymentAutoDetect": MessageLookupByLibrary.simpleMessage(
      "3. 支付完成后返回应用，系统将自动检测",
    ),
    "xboardRunDiagnosis": MessageLookupByLibrary.simpleMessage("运行自检"),
    "xboardRunningTime": m48,
    "xboardSecureEncryption": MessageLookupByLibrary.simpleMessage("安全加密"),
    "xboardSelectPaymentMethod": MessageLookupByLibrary.simpleMessage("选择支付方式"),
    "xboardSelectPaymentPeriod": MessageLookupByLibrary.simpleMessage("选择购买周期"),
    "xboardSelectPeriod": MessageLookupByLibrary.simpleMessage("请选择购买周期"),
    "xboardSelectRechargeAmount": MessageLookupByLibrary.simpleMessage(
      "选择充值金额",
    ),
    "xboardSendVerificationCode": MessageLookupByLibrary.simpleMessage("发送验证码"),
    "xboardServerError": MessageLookupByLibrary.simpleMessage("服务器错误"),
    "xboardServerStatus": MessageLookupByLibrary.simpleMessage("服务器状态"),
    "xboardServiceConnectionDegraded": MessageLookupByLibrary.simpleMessage(
      "服务连接不稳定",
    ),
    "xboardServiceDegradedTooltip": MessageLookupByLibrary.simpleMessage(
      "业务请求出现异常，客户端正在确认本地网络和业务网关状态。",
    ),
    "xboardServiceNetworkRestricted": MessageLookupByLibrary.simpleMessage(
      "网络连接受限",
    ),
    "xboardServiceNetworkRestrictedTooltip":
        MessageLookupByLibrary.simpleMessage(
          "检测到网络接口，但公网基准和业务网关均不可达，当前代理可能无法使用。请检查网络限制、DNS 或运行网络诊断。",
        ),
    "xboardServiceNoNetwork": MessageLookupByLibrary.simpleMessage("本地网络不可用"),
    "xboardServiceNoNetworkTooltip": MessageLookupByLibrary.simpleMessage(
      "当前设备没有可用的网络连接，代理也无法正常使用。请检查 Wi-Fi、移动数据或有线网络。",
    ),
    "xboardServiceOfflineCacheMode": MessageLookupByLibrary.simpleMessage(
      "离线缓存模式",
    ),
    "xboardServiceOfflineCacheTooltip": MessageLookupByLibrary.simpleMessage(
      "本地网络正常，但暂时无法连接业务服务器。当前代理可继续使用已缓存的订阅和节点，登录、套餐、支付等功能可能暂不可用。网络或网关恢复后会自动退出离线缓存模式。",
    ),
    "xboardServiceRecovering": MessageLookupByLibrary.simpleMessage("正在恢复连接"),
    "xboardServiceRecoveringTooltip": MessageLookupByLibrary.simpleMessage(
      "网络已恢复，客户端正在重新确认业务网关状态。",
    ),
    "xboardSetup": MessageLookupByLibrary.simpleMessage("设置"),
    "xboardSixMonthCycle": MessageLookupByLibrary.simpleMessage("6个月周期"),
    "xboardSmartLatencyStarted": MessageLookupByLibrary.simpleMessage(
      "已开始智能测速",
    ),
    "xboardSmartRouting": MessageLookupByLibrary.simpleMessage("智能分流"),
    "xboardSoftwareSettings": MessageLookupByLibrary.simpleMessage("软件设置"),
    "xboardSpeedLimit": MessageLookupByLibrary.simpleMessage("限速"),
    "xboardStartNewPeriod": MessageLookupByLibrary.simpleMessage("开启新周期"),
    "xboardStartProxy": MessageLookupByLibrary.simpleMessage("启动代理"),
    "xboardStartup": MessageLookupByLibrary.simpleMessage("自启动"),
    "xboardStartupDescription": MessageLookupByLibrary.simpleMessage(
      "开启启动与自动连接代理",
    ),
    "xboardStop": MessageLookupByLibrary.simpleMessage("停止"),
    "xboardStopProxy": MessageLookupByLibrary.simpleMessage("停止代理"),
    "xboardStreamingAccessible": MessageLookupByLibrary.simpleMessage("可访问"),
    "xboardStreamingAccessibleCount": MessageLookupByLibrary.simpleMessage(
      "可访问服务",
    ),
    "xboardStreamingBlocked": MessageLookupByLibrary.simpleMessage("IP 被平台限制"),
    "xboardStreamingCancelled": MessageLookupByLibrary.simpleMessage("已取消"),
    "xboardStreamingCheck": MessageLookupByLibrary.simpleMessage("流媒体与 AI 检测"),
    "xboardStreamingCheckSubtitle": MessageLookupByLibrary.simpleMessage(
      "检测当前节点对常用流媒体与 AI 服务的访问状态",
    ),
    "xboardStreamingChecking": MessageLookupByLibrary.simpleMessage("检测中…"),
    "xboardStreamingConnectFirst": MessageLookupByLibrary.simpleMessage(
      "请先连接 VPN，流媒体与 AI 检测必须通过当前节点进行。",
    ),
    "xboardStreamingConnected": MessageLookupByLibrary.simpleMessage("VPN 已连接"),
    "xboardStreamingCopyReport": MessageLookupByLibrary.simpleMessage("复制报告"),
    "xboardStreamingCurrentNode": MessageLookupByLibrary.simpleMessage("当前节点"),
    "xboardStreamingDisclaimer": MessageLookupByLibrary.simpleMessage(
      "检测结果基于当前节点对服务接口和公开页面的访问情况，仅供参考；服务策略、账号地区、登录状态和版权限制都可能影响实际使用。",
    ),
    "xboardStreamingDisconnected": MessageLookupByLibrary.simpleMessage(
      "VPN 已断开，当前检测结果已失效。",
    ),
    "xboardStreamingError": MessageLookupByLibrary.simpleMessage("检测失败"),
    "xboardStreamingExitRegion": MessageLookupByLibrary.simpleMessage("出口地区"),
    "xboardStreamingNodeChanged": MessageLookupByLibrary.simpleMessage(
      "检测期间节点发生变化，当前结果已失效，请重新检测。",
    ),
    "xboardStreamingNodeUnavailable": MessageLookupByLibrary.simpleMessage(
      "暂时无法获取当前节点，请稍后重试。",
    ),
    "xboardStreamingNotConnected": MessageLookupByLibrary.simpleMessage(
      "VPN 未连接",
    ),
    "xboardStreamingPartiallyAccessible": MessageLookupByLibrary.simpleMessage(
      "部分可用",
    ),
    "xboardStreamingProgress": MessageLookupByLibrary.simpleMessage("检测进度"),
    "xboardStreamingReportCopied": MessageLookupByLibrary.simpleMessage(
      "流媒体与 AI 检测报告已复制",
    ),
    "xboardStreamingReportDetail": MessageLookupByLibrary.simpleMessage("判定依据"),
    "xboardStreamingReportSystem": MessageLookupByLibrary.simpleMessage("系统"),
    "xboardStreamingReportTime": MessageLookupByLibrary.simpleMessage("检测时间"),
    "xboardStreamingReportTitle": MessageLookupByLibrary.simpleMessage(
      "FastCat 流媒体与 AI 检测报告",
    ),
    "xboardStreamingReportVersion": MessageLookupByLibrary.simpleMessage(
      "客户端版本",
    ),
    "xboardStreamingRestricted": MessageLookupByLibrary.simpleMessage("地区受限"),
    "xboardStreamingResults": MessageLookupByLibrary.simpleMessage("检测结果"),
    "xboardStreamingRetest": MessageLookupByLibrary.simpleMessage("重新检测"),
    "xboardStreamingStart": MessageLookupByLibrary.simpleMessage("开始检测"),
    "xboardStreamingSummary": MessageLookupByLibrary.simpleMessage("检测汇总"),
    "xboardStreamingSummaryAccessible": MessageLookupByLibrary.simpleMessage(
      "确认可用",
    ),
    "xboardStreamingSummaryInconclusive": MessageLookupByLibrary.simpleMessage(
      "异常/无法确认",
    ),
    "xboardStreamingSummaryPartial": MessageLookupByLibrary.simpleMessage(
      "部分可用",
    ),
    "xboardStreamingSummaryRestricted": MessageLookupByLibrary.simpleMessage(
      "明确受限/不可用",
    ),
    "xboardStreamingSummaryVerification": MessageLookupByLibrary.simpleMessage(
      "需要验证",
    ),
    "xboardStreamingTimeout": MessageLookupByLibrary.simpleMessage("检测超时"),
    "xboardStreamingUnavailable": MessageLookupByLibrary.simpleMessage("不可访问"),
    "xboardStreamingUncertain": MessageLookupByLibrary.simpleMessage("无法确认"),
    "xboardStreamingUnknown": MessageLookupByLibrary.simpleMessage("未知"),
    "xboardStreamingVerificationRequired": MessageLookupByLibrary.simpleMessage(
      "需要浏览器验证",
    ),
    "xboardStreamingVisit": MessageLookupByLibrary.simpleMessage("访问"),
    "xboardSubmitOrder": MessageLookupByLibrary.simpleMessage("提交订单"),
    "xboardSubmitTicket": MessageLookupByLibrary.simpleMessage("提交工单"),
    "xboardSubmitting": MessageLookupByLibrary.simpleMessage("提交中..."),
    "xboardSubscription": MessageLookupByLibrary.simpleMessage("订阅"),
    "xboardSubscriptionCopied": MessageLookupByLibrary.simpleMessage(
      "订阅链接已复制到剪贴板",
    ),
    "xboardSubscriptionExpired": MessageLookupByLibrary.simpleMessage("订阅已过期"),
    "xboardSubscriptionHasExpired": MessageLookupByLibrary.simpleMessage(
      "订阅已过期",
    ),
    "xboardSubscriptionHealth": MessageLookupByLibrary.simpleMessage("订阅状态"),
    "xboardSubscriptionInfo": MessageLookupByLibrary.simpleMessage("订阅信息"),
    "xboardSubscriptionLink": MessageLookupByLibrary.simpleMessage("订阅链接"),
    "xboardSubscriptionLinkCopied": MessageLookupByLibrary.simpleMessage(
      "订阅链接已复制到剪贴板",
    ),
    "xboardSubscriptionPurchase": MessageLookupByLibrary.simpleMessage("订阅购买"),
    "xboardSubscriptionSlowUsingCache": MessageLookupByLibrary.simpleMessage(
      "后端响应较慢，正在使用缓存",
    ),
    "xboardSubscriptionStatus": MessageLookupByLibrary.simpleMessage("订阅状态"),
    "xboardSurplusAmount": MessageLookupByLibrary.simpleMessage("旧套餐折抵金额"),
    "xboardSwitch": MessageLookupByLibrary.simpleMessage("切换"),
    "xboardSyncingSubscription": MessageLookupByLibrary.simpleMessage(
      "正在同步账号订阅信息...",
    ),
    "xboardTestCurrentNode": MessageLookupByLibrary.simpleMessage("测试当前节点"),
    "xboardTestLatency": MessageLookupByLibrary.simpleMessage("测试延迟"),
    "xboardTesting": MessageLookupByLibrary.simpleMessage("测试中"),
    "xboardThirtySixMonthCycle": MessageLookupByLibrary.simpleMessage("36个月周期"),
    "xboardThreeMonthCycle": MessageLookupByLibrary.simpleMessage("3个月周期"),
    "xboardThreeYearPayment": MessageLookupByLibrary.simpleMessage("三年付"),
    "xboardTicketClosed": MessageLookupByLibrary.simpleMessage("已关闭"),
    "xboardTicketClosedMessage": MessageLookupByLibrary.simpleMessage("工单已关闭"),
    "xboardTicketDescription": MessageLookupByLibrary.simpleMessage("问题描述"),
    "xboardTicketDescriptionHint": MessageLookupByLibrary.simpleMessage(
      "请详细描述你遇到的问题",
    ),
    "xboardTicketDetails": MessageLookupByLibrary.simpleMessage("工单详情"),
    "xboardTicketPendingReply": MessageLookupByLibrary.simpleMessage("待回复"),
    "xboardTicketReplied": MessageLookupByLibrary.simpleMessage("已回复"),
    "xboardTicketTitle": MessageLookupByLibrary.simpleMessage("工单标题"),
    "xboardTicketTitleHint": MessageLookupByLibrary.simpleMessage("请输入工单标题"),
    "xboardTimeout": MessageLookupByLibrary.simpleMessage("超时"),
    "xboardTokenExpiredContent": MessageLookupByLibrary.simpleMessage(
      "您的登录状态已过期，请重新登录以继续使用。",
    ),
    "xboardTokenExpiredTitle": MessageLookupByLibrary.simpleMessage("登录已过期"),
    "xboardToolsSettings": MessageLookupByLibrary.simpleMessage("工具设置"),
    "xboardTotal": MessageLookupByLibrary.simpleMessage("总计"),
    "xboardTotalTraffic": MessageLookupByLibrary.simpleMessage("总计"),
    "xboardTraffic": MessageLookupByLibrary.simpleMessage("流量"),
    "xboardTrafficDetails": MessageLookupByLibrary.simpleMessage("流量明细"),
    "xboardTrafficExhausted": MessageLookupByLibrary.simpleMessage("流量已用完"),
    "xboardTrafficExhaustedRenewConfirmContent":
        MessageLookupByLibrary.simpleMessage(
          "续费套餐不会立即重置流量，如需立即使用可以重置流量或更换套餐，是否继续？",
        ),
    "xboardTrafficLogHint": MessageLookupByLibrary.simpleMessage(
      "仅显示近一个月的流量明细",
    ),
    "xboardTrafficReminder": MessageLookupByLibrary.simpleMessage("流量使用邮件提醒"),
    "xboardTrafficUsedUp": MessageLookupByLibrary.simpleMessage("流量已用完"),
    "xboardTunAllTraffic": MessageLookupByLibrary.simpleMessage("全流量代理"),
    "xboardTunAllTrafficDescription": MessageLookupByLibrary.simpleMessage(
      "捕获所有应用的网络流量，无需单独配置。",
    ),
    "xboardTunEnabled": MessageLookupByLibrary.simpleMessage("TUN已启用"),
    "xboardTunGlobalRecommendation": MessageLookupByLibrary.simpleMessage(
      "备用方案：全局 + TUN，规则模式异常时使用",
    ),
    "xboardTunModeDescription": MessageLookupByLibrary.simpleMessage(
      "TUN 模式通过虚拟网络接口实现更完整的应用流量代理。",
    ),
    "xboardTunModeTitle": MessageLookupByLibrary.simpleMessage("TUN 模式"),
    "xboardTunPerformance": MessageLookupByLibrary.simpleMessage("性能优化"),
    "xboardTunPerformanceDescription": MessageLookupByLibrary.simpleMessage(
      "减少代理层级，提升网络访问速度。",
    ),
    "xboardTunRecommendedUsage": MessageLookupByLibrary.simpleMessage("推荐使用方式"),
    "xboardTunRuleRecommendation": MessageLookupByLibrary.simpleMessage(
      "日常使用：规则 + TUN，智能分流且性能最佳",
    ),
    "xboardTunTransparentProxy": MessageLookupByLibrary.simpleMessage("透明代理"),
    "xboardTunTransparentProxyDescription":
        MessageLookupByLibrary.simpleMessage("应用无需额外设置即可使用代理，兼容性更好。"),
    "xboardTwelveMonthCycle": MessageLookupByLibrary.simpleMessage("12个月周期"),
    "xboardTwentyFourMonthCycle": MessageLookupByLibrary.simpleMessage(
      "24个月周期",
    ),
    "xboardTwoYearPayment": MessageLookupByLibrary.simpleMessage("两年付"),
    "xboardUnauthorizedAccess": MessageLookupByLibrary.simpleMessage(
      "未授权访问，请先登录",
    ),
    "xboardUnknownErrorRetry": MessageLookupByLibrary.simpleMessage("未知错误，请重试"),
    "xboardUnknownPeriod": MessageLookupByLibrary.simpleMessage("未知周期"),
    "xboardUnknownPlan": MessageLookupByLibrary.simpleMessage("未知套餐"),
    "xboardUnknownUser": MessageLookupByLibrary.simpleMessage("未知用户"),
    "xboardUnlimited": MessageLookupByLibrary.simpleMessage("不限速"),
    "xboardUnlimitedSpeed": MessageLookupByLibrary.simpleMessage("不限速"),
    "xboardUnselected": MessageLookupByLibrary.simpleMessage("未选择"),
    "xboardUnsupportedCouponType": MessageLookupByLibrary.simpleMessage(
      "不支持的优惠券类型",
    ),
    "xboardUpdateContent": MessageLookupByLibrary.simpleMessage("更新内容："),
    "xboardUpdateLater": MessageLookupByLibrary.simpleMessage("稍后更新"),
    "xboardUpdateNodes": MessageLookupByLibrary.simpleMessage("更新节点"),
    "xboardUpdateNow": MessageLookupByLibrary.simpleMessage("立即更新"),
    "xboardUpdateSubscriptionRegularly": MessageLookupByLibrary.simpleMessage(
      "定期更新订阅获取最新节点",
    ),
    "xboardUploadImage": MessageLookupByLibrary.simpleMessage("上传图片"),
    "xboardUsageInstructions": MessageLookupByLibrary.simpleMessage("使用说明"),
    "xboardUseBalance": MessageLookupByLibrary.simpleMessage("使用余额"),
    "xboardUsed": MessageLookupByLibrary.simpleMessage("已用"),
    "xboardUsedTraffic": MessageLookupByLibrary.simpleMessage("已用"),
    "xboardValidatingConfigFormat": MessageLookupByLibrary.simpleMessage(
      "验证配置格式",
    ),
    "xboardValidationFailed": MessageLookupByLibrary.simpleMessage("验证失败"),
    "xboardValidityPeriod": MessageLookupByLibrary.simpleMessage("有效期"),
    "xboardVerify": MessageLookupByLibrary.simpleMessage("核验"),
    "xboardVeryPoor": MessageLookupByLibrary.simpleMessage("很差"),
    "xboardWaitingForPayment": MessageLookupByLibrary.simpleMessage("正在等待支付"),
    "xboardWaitingPaymentCompletion": MessageLookupByLibrary.simpleMessage(
      "等待支付完成",
    ),
    "xboardWalletBalance": MessageLookupByLibrary.simpleMessage("钱包余额"),
    "xboardYearlyPayment": MessageLookupByLibrary.simpleMessage("年付"),
    "years": MessageLookupByLibrary.simpleMessage("年"),
    "zh_CN": MessageLookupByLibrary.simpleMessage("中文简体"),
    "zoom": MessageLookupByLibrary.simpleMessage("缩放"),
  };
}
