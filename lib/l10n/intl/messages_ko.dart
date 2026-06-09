// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a ko locale. All the
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
  String get localeName => 'ko';

  static String m0(rate) => "현재 커미션 rate: ${rate}";

  static String m1(label) => "삭제 multip 안내: ${label}";

  static String m2(label) => "삭제 안내: ${label}";

  static String m3(label) => "비어 있음 안내: ${label}";

  static String m4(label) => "exists 안내: ${label}";

  static String m5(error) => "로그아웃 실패: ${error}";

  static String m6(amount) => "MAX transferable: ${amount}";

  static String m7(label) => "없음 안내: ${label}";

  static String m8(label) => "number 안내: ${label}";

  static String m9(statusCode) => "메시지 가져오기 실패: ${statusCode}";

  static String m10(error) => "지원 선택 이미지 실패: ${error}";

  static String m11(method) => "지원하지 않는 HTTP 메서드: ${method}";

  static String m12(error) => "지원 업로드 실패: ${error}";

  static String m13(amount) => "주문 금액: ${amount}";

  static String m14(orderNo) => "주문 number: ${orderNo}";

  static String m15(page) => "page number: ${page}";

  static String m16(label) => "포트 안내: ${label}";

  static String m17(e) => "registration 실패: ${e}";

  static String m18(count) => "선택됨 count 제목: ${count}";

  static String m19(e) => "보내기 인증 코드 실패: ${e}";

  static String m20(date) => "구독 만료됨 상세: ${date}";

  static String m21(days) => "구독 expiring IN 일 상세: ${days}";

  static String m22(days) => "구독 유효 상세: ${days}";

  static String m23(count) => "전체 기록: ${count}";

  static String m24(amount) => "이체 금액 exceeded: ${amount}";

  static String m25(error) => "이체 실패: ${error}";

  static String m26(amount) => "이체 성공 MSG: ${amount}";

  static String m27(version) => "업데이트 확인 현재 버전: ${version}";

  static String m28(version) => "업데이트 확인 force 업데이트: ${version}";

  static String m29(version) => "업데이트 확인 새 버전 found: ${version}";

  static String m30(statusCode) => "업데이트 확인 서버 오류: ${statusCode}";

  static String m31(label) => "URL 안내: ${label}";

  static String m32(email) => "인증 코드 sent TO: ${email}";

  static String m33(error) => "출금 submission 실패 with 오류: ${error}";

  static String m34(amount) => "withdrawable 금액: ${amount}";

  static String m35(amount) => "잔액 with 금액: ${amount}";

  static String m36(count, limit) => "기기 summary: ${count}: ${limit}";

  static String m37(date) => "만료됨 ON date: ${date}";

  static String m38(date) => "만료 ON date: ${date}";

  static String m39(date, days) => "만료 ON with 일: ${date}: ${days}";

  static String m40(error) => "redeem 실패 with 오류: ${error}";

  static String m41(days) => "초기화 트래픽 IN 일: ${days}";

  static String m42(time) => "실행 중 time: ${time}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "about": MessageLookupByLibrary.simpleMessage("정보"),
    "accessControl": MessageLookupByLibrary.simpleMessage("access control"),
    "accessControlAllowDesc": MessageLookupByLibrary.simpleMessage(
      "access control 허용 설명",
    ),
    "accessControlDesc": MessageLookupByLibrary.simpleMessage(
      "access control 설명",
    ),
    "accessControlNotAllowDesc": MessageLookupByLibrary.simpleMessage(
      "access control NOT 허용 설명",
    ),
    "account": MessageLookupByLibrary.simpleMessage("계정"),
    "action": MessageLookupByLibrary.simpleMessage("action"),
    "action_mode": MessageLookupByLibrary.simpleMessage("action 모드"),
    "action_proxy": MessageLookupByLibrary.simpleMessage("action 프록시"),
    "action_start": MessageLookupByLibrary.simpleMessage("action 시작"),
    "action_tun": MessageLookupByLibrary.simpleMessage("action TUN"),
    "action_view": MessageLookupByLibrary.simpleMessage("action 보기"),
    "add": MessageLookupByLibrary.simpleMessage("추가"),
    "addRule": MessageLookupByLibrary.simpleMessage("추가 규칙"),
    "addedOriginRules": MessageLookupByLibrary.simpleMessage(
      "added origin rules",
    ),
    "address": MessageLookupByLibrary.simpleMessage("주소"),
    "addressHelp": MessageLookupByLibrary.simpleMessage("주소 help"),
    "addressTip": MessageLookupByLibrary.simpleMessage("주소 안내"),
    "adminAutoLaunch": MessageLookupByLibrary.simpleMessage("관리자 자동 실행"),
    "adminAutoLaunchDesc": MessageLookupByLibrary.simpleMessage("관리자 자동 실행 설명"),
    "ago": MessageLookupByLibrary.simpleMessage("AGO"),
    "agree": MessageLookupByLibrary.simpleMessage("agree"),
    "allApps": MessageLookupByLibrary.simpleMessage("ALL apps"),
    "allowBypass": MessageLookupByLibrary.simpleMessage("허용 bypass"),
    "allowBypassDesc": MessageLookupByLibrary.simpleMessage("허용 bypass 설명"),
    "allowLan": MessageLookupByLibrary.simpleMessage("허용 LAN"),
    "allowLanDesc": MessageLookupByLibrary.simpleMessage("허용 LAN 설명"),
    "alreadyHaveAccount": MessageLookupByLibrary.simpleMessage(
      "already have 계정",
    ),
    "app": MessageLookupByLibrary.simpleMessage("앱"),
    "appAccessControl": MessageLookupByLibrary.simpleMessage(
      "앱 access control",
    ),
    "appDesc": MessageLookupByLibrary.simpleMessage("앱 설명"),
    "application": MessageLookupByLibrary.simpleMessage("application"),
    "applicationDesc": MessageLookupByLibrary.simpleMessage("application 설명"),
    "auto": MessageLookupByLibrary.simpleMessage("자동"),
    "autoCheckUpdate": MessageLookupByLibrary.simpleMessage("자동 확인 업데이트"),
    "autoCheckUpdateDesc": MessageLookupByLibrary.simpleMessage(
      "자동 확인 업데이트 설명",
    ),
    "autoCloseConnections": MessageLookupByLibrary.simpleMessage(
      "자동 닫기 connections",
    ),
    "autoCloseConnectionsDesc": MessageLookupByLibrary.simpleMessage(
      "자동 닫기 connections 설명",
    ),
    "autoLaunch": MessageLookupByLibrary.simpleMessage("부팅 시 시작"),
    "autoLaunchDesc": MessageLookupByLibrary.simpleMessage("자동 실행 설명"),
    "autoRun": MessageLookupByLibrary.simpleMessage("자동 RUN"),
    "autoRunDesc": MessageLookupByLibrary.simpleMessage("자동 RUN 설명"),
    "autoSetSystemDns": MessageLookupByLibrary.simpleMessage("자동 SET 시스템 DNS"),
    "autoUpdate": MessageLookupByLibrary.simpleMessage("자동 업데이트"),
    "autoUpdateInterval": MessageLookupByLibrary.simpleMessage(
      "자동 업데이트 interval",
    ),
    "availableCommission": MessageLookupByLibrary.simpleMessage("사용 가능 커미션"),
    "backToLogin": MessageLookupByLibrary.simpleMessage("back TO 로그인"),
    "backup": MessageLookupByLibrary.simpleMessage("백업"),
    "backupAndRecovery": MessageLookupByLibrary.simpleMessage(
      "백업 AND recovery",
    ),
    "backupAndRecoveryDesc": MessageLookupByLibrary.simpleMessage(
      "백업 AND recovery 설명",
    ),
    "backupSuccess": MessageLookupByLibrary.simpleMessage("백업 성공"),
    "basicConfig": MessageLookupByLibrary.simpleMessage("basic 설정"),
    "basicConfigDesc": MessageLookupByLibrary.simpleMessage("basic 설정 설명"),
    "bind": MessageLookupByLibrary.simpleMessage("bind"),
    "blacklistMode": MessageLookupByLibrary.simpleMessage("blacklist 모드"),
    "bypassDomain": MessageLookupByLibrary.simpleMessage("bypass 도메인"),
    "bypassDomainDesc": MessageLookupByLibrary.simpleMessage("bypass 도메인 설명"),
    "cacheCorrupt": MessageLookupByLibrary.simpleMessage("캐시 corrupt"),
    "cancel": MessageLookupByLibrary.simpleMessage("취소"),
    "cancelFilterSystemApp": MessageLookupByLibrary.simpleMessage(
      "취소 filter 시스템 앱",
    ),
    "cancelSelectAll": MessageLookupByLibrary.simpleMessage("취소 선택 ALL"),
    "cannotGetWebUrl": MessageLookupByLibrary.simpleMessage(
      "웹 주소를 가져올 수 없습니다. 고객지원에 문의하세요",
    ),
    "cannotOpenBrowser": MessageLookupByLibrary.simpleMessage("cannot 열기 브라우저"),
    "checkError": MessageLookupByLibrary.simpleMessage("확인 오류"),
    "checkNetwork": MessageLookupByLibrary.simpleMessage("확인 네트워크"),
    "checkUpdate": MessageLookupByLibrary.simpleMessage("확인 업데이트"),
    "checkUpdateError": MessageLookupByLibrary.simpleMessage("확인 업데이트 오류"),
    "checking": MessageLookupByLibrary.simpleMessage("확인 중"),
    "clearData": MessageLookupByLibrary.simpleMessage("지우기 data"),
    "clipboardExport": MessageLookupByLibrary.simpleMessage("클립보드 내보내기"),
    "clipboardImport": MessageLookupByLibrary.simpleMessage("클립보드 가져오기"),
    "close": MessageLookupByLibrary.simpleMessage("닫기"),
    "color": MessageLookupByLibrary.simpleMessage("color"),
    "colorSchemes": MessageLookupByLibrary.simpleMessage("color schemes"),
    "columns": MessageLookupByLibrary.simpleMessage("columns"),
    "commissionHistory": MessageLookupByLibrary.simpleMessage("커미션 기록"),
    "commissionRate": MessageLookupByLibrary.simpleMessage("커미션 rate"),
    "commissionSettled": MessageLookupByLibrary.simpleMessage("커미션 settled"),
    "compatible": MessageLookupByLibrary.simpleMessage("compatible"),
    "compatibleDesc": MessageLookupByLibrary.simpleMessage("compatible 설명"),
    "complete": MessageLookupByLibrary.simpleMessage("complete"),
    "completeWithdrawal": MessageLookupByLibrary.simpleMessage(
      "complete withdrawal",
    ),
    "configurationError": MessageLookupByLibrary.simpleMessage(
      "앱 설정 오류입니다. 고객지원에 문의하세요",
    ),
    "confirm": MessageLookupByLibrary.simpleMessage("확인"),
    "confirmLogout": MessageLookupByLibrary.simpleMessage("확인 로그아웃"),
    "confirmNewPassword": MessageLookupByLibrary.simpleMessage("확인 새 비밀번호"),
    "confirmTransfer": MessageLookupByLibrary.simpleMessage("확인 이체"),
    "connected": MessageLookupByLibrary.simpleMessage("연결됨"),
    "connections": MessageLookupByLibrary.simpleMessage("connections"),
    "connectionsDesc": MessageLookupByLibrary.simpleMessage("connections 설명"),
    "connectivity": MessageLookupByLibrary.simpleMessage("connectivity"),
    "contactMe": MessageLookupByLibrary.simpleMessage("문의 ME"),
    "contactSupport": MessageLookupByLibrary.simpleMessage("고객지원"),
    "content": MessageLookupByLibrary.simpleMessage("내용"),
    "contentScheme": MessageLookupByLibrary.simpleMessage("내용 scheme"),
    "copiedToClipboard": MessageLookupByLibrary.simpleMessage("복사됨 TO 클립보드"),
    "copy": MessageLookupByLibrary.simpleMessage("복사"),
    "copyEnvVar": MessageLookupByLibrary.simpleMessage("복사 ENV VAR"),
    "copyInviteLink": MessageLookupByLibrary.simpleMessage("복사 초대 링크"),
    "copyLink": MessageLookupByLibrary.simpleMessage("복사 링크"),
    "copySuccess": MessageLookupByLibrary.simpleMessage("복사 성공"),
    "core": MessageLookupByLibrary.simpleMessage("코어"),
    "coreInfo": MessageLookupByLibrary.simpleMessage("코어 정보"),
    "country": MessageLookupByLibrary.simpleMessage("국가"),
    "crashTest": MessageLookupByLibrary.simpleMessage("crash 테스트"),
    "create": MessageLookupByLibrary.simpleMessage("create"),
    "createAccount": MessageLookupByLibrary.simpleMessage("create 계정"),
    "credentialsSaved": MessageLookupByLibrary.simpleMessage(
      "credentials saved",
    ),
    "currentCommissionRate": m0,
    "cut": MessageLookupByLibrary.simpleMessage("CUT"),
    "dark": MessageLookupByLibrary.simpleMessage("dark"),
    "dashboard": MessageLookupByLibrary.simpleMessage("대시보드"),
    "days": MessageLookupByLibrary.simpleMessage("일"),
    "defaultNameserver": MessageLookupByLibrary.simpleMessage("기본값 nameserver"),
    "defaultNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "기본값 nameserver 설명",
    ),
    "defaultSort": MessageLookupByLibrary.simpleMessage("기본값 정렬"),
    "defaultText": MessageLookupByLibrary.simpleMessage("기본값 텍스트"),
    "delay": MessageLookupByLibrary.simpleMessage("지연"),
    "delaySort": MessageLookupByLibrary.simpleMessage("지연 정렬"),
    "delete": MessageLookupByLibrary.simpleMessage("삭제"),
    "deleteMultipTip": m1,
    "deleteTip": m2,
    "desc": MessageLookupByLibrary.simpleMessage("설명"),
    "detectionTip": MessageLookupByLibrary.simpleMessage("감지 안내"),
    "developerMode": MessageLookupByLibrary.simpleMessage("developer 모드"),
    "developerModeEnableTip": MessageLookupByLibrary.simpleMessage(
      "developer 모드 활성화 안내",
    ),
    "direct": MessageLookupByLibrary.simpleMessage("직접 연결"),
    "disclaimer": MessageLookupByLibrary.simpleMessage("disclaimer"),
    "disclaimerDesc": MessageLookupByLibrary.simpleMessage("disclaimer 설명"),
    "discoverNewVersion": MessageLookupByLibrary.simpleMessage("discover 새 버전"),
    "discovery": MessageLookupByLibrary.simpleMessage("discovery"),
    "dnsDesc": MessageLookupByLibrary.simpleMessage("DNS 설명"),
    "dnsMode": MessageLookupByLibrary.simpleMessage("DNS 모드"),
    "doYouWantToPass": MessageLookupByLibrary.simpleMessage(
      "DO YOU want TO pass",
    ),
    "domain": MessageLookupByLibrary.simpleMessage("도메인"),
    "domainStatusAvailable": MessageLookupByLibrary.simpleMessage(
      "도메인 상태 사용 가능",
    ),
    "domainStatusChecking": MessageLookupByLibrary.simpleMessage("도메인 상태 확인 중"),
    "domainStatusUnavailable": MessageLookupByLibrary.simpleMessage(
      "도메인 상태 사용 불가",
    ),
    "download": MessageLookupByLibrary.simpleMessage("다운로드"),
    "edit": MessageLookupByLibrary.simpleMessage("편집"),
    "emailAddress": MessageLookupByLibrary.simpleMessage("이메일 주소"),
    "emailVerificationCode": MessageLookupByLibrary.simpleMessage("이메일 인증 코드"),
    "emptyTip": m3,
    "en": MessageLookupByLibrary.simpleMessage("영어"),
    "enableOverride": MessageLookupByLibrary.simpleMessage("활성화 오버라이드"),
    "enterEmailForReset": MessageLookupByLibrary.simpleMessage(
      "enter 이메일 FOR 초기화",
    ),
    "enterTransferAmount": MessageLookupByLibrary.simpleMessage("enter 이체 금액"),
    "enterTransferAmountError": MessageLookupByLibrary.simpleMessage(
      "enter 이체 금액 오류",
    ),
    "entries": MessageLookupByLibrary.simpleMessage("entries"),
    "exclude": MessageLookupByLibrary.simpleMessage("exclude"),
    "excludeDesc": MessageLookupByLibrary.simpleMessage("exclude 설명"),
    "existsTip": m4,
    "exit": MessageLookupByLibrary.simpleMessage("종료"),
    "expand": MessageLookupByLibrary.simpleMessage("expand"),
    "expirationTime": MessageLookupByLibrary.simpleMessage("expiration time"),
    "exportFile": MessageLookupByLibrary.simpleMessage("내보내기 파일"),
    "exportLogs": MessageLookupByLibrary.simpleMessage("내보내기 로그"),
    "exportSuccess": MessageLookupByLibrary.simpleMessage("내보내기 성공"),
    "expressiveScheme": MessageLookupByLibrary.simpleMessage(
      "expressive scheme",
    ),
    "externalController": MessageLookupByLibrary.simpleMessage("외부 controller"),
    "externalControllerDesc": MessageLookupByLibrary.simpleMessage(
      "외부 controller 설명",
    ),
    "externalLink": MessageLookupByLibrary.simpleMessage("외부 링크"),
    "externalResources": MessageLookupByLibrary.simpleMessage("외부 리소스"),
    "fakeipFilter": MessageLookupByLibrary.simpleMessage("fakeip filter"),
    "fakeipRange": MessageLookupByLibrary.simpleMessage("fakeip range"),
    "fallback": MessageLookupByLibrary.simpleMessage("대체"),
    "fallbackDesc": MessageLookupByLibrary.simpleMessage("대체 설명"),
    "fallbackFilter": MessageLookupByLibrary.simpleMessage("대체 filter"),
    "fidelityScheme": MessageLookupByLibrary.simpleMessage("fidelity scheme"),
    "file": MessageLookupByLibrary.simpleMessage("파일"),
    "fileDesc": MessageLookupByLibrary.simpleMessage("파일 설명"),
    "fileIsUpdate": MessageLookupByLibrary.simpleMessage("파일 IS 업데이트"),
    "fillInfoToRegister": MessageLookupByLibrary.simpleMessage("fill 정보 TO 가입"),
    "filterSystemApp": MessageLookupByLibrary.simpleMessage("filter 시스템 앱"),
    "findProcessMode": MessageLookupByLibrary.simpleMessage("find process 모드"),
    "findProcessModeDesc": MessageLookupByLibrary.simpleMessage(
      "find process 모드 설명",
    ),
    "fontFamily": MessageLookupByLibrary.simpleMessage("font family"),
    "forgotPassword": MessageLookupByLibrary.simpleMessage("잊음 비밀번호"),
    "fourColumns": MessageLookupByLibrary.simpleMessage("four columns"),
    "friendInviteReward": MessageLookupByLibrary.simpleMessage(
      "friend 초대 reward",
    ),
    "fruitSaladScheme": MessageLookupByLibrary.simpleMessage(
      "fruit salad scheme",
    ),
    "general": MessageLookupByLibrary.simpleMessage("general"),
    "generalDesc": MessageLookupByLibrary.simpleMessage("general 설명"),
    "generateInviteCode": MessageLookupByLibrary.simpleMessage("생성 초대 코드"),
    "generatingInviteCode": MessageLookupByLibrary.simpleMessage("생성 중 초대 코드"),
    "geoData": MessageLookupByLibrary.simpleMessage("GEO data"),
    "geodataLoader": MessageLookupByLibrary.simpleMessage("geodata loader"),
    "geodataLoaderDesc": MessageLookupByLibrary.simpleMessage(
      "geodata loader 설명",
    ),
    "geoipCode": MessageLookupByLibrary.simpleMessage("geoip 코드"),
    "getOriginRules": MessageLookupByLibrary.simpleMessage("GET origin rules"),
    "global": MessageLookupByLibrary.simpleMessage("전역 프록시"),
    "go": MessageLookupByLibrary.simpleMessage("GO"),
    "goDownload": MessageLookupByLibrary.simpleMessage("GO 다운로드"),
    "goToWeb": MessageLookupByLibrary.simpleMessage("GO TO 웹"),
    "hasCacheChange": MessageLookupByLibrary.simpleMessage("HAS 캐시 변경"),
    "hostsDesc": MessageLookupByLibrary.simpleMessage("hosts 설명"),
    "hotkeyConflict": MessageLookupByLibrary.simpleMessage("hotkey conflict"),
    "hotkeyManagement": MessageLookupByLibrary.simpleMessage("hotkey 관리"),
    "hotkeyManagementDesc": MessageLookupByLibrary.simpleMessage(
      "hotkey 관리 설명",
    ),
    "hours": MessageLookupByLibrary.simpleMessage("시간"),
    "iUnderstand": MessageLookupByLibrary.simpleMessage("I understand"),
    "icon": MessageLookupByLibrary.simpleMessage("icon"),
    "iconConfiguration": MessageLookupByLibrary.simpleMessage("icon 설정"),
    "iconStyle": MessageLookupByLibrary.simpleMessage("icon style"),
    "import": MessageLookupByLibrary.simpleMessage("가져오기"),
    "importFile": MessageLookupByLibrary.simpleMessage("가져오기 파일"),
    "importFromURL": MessageLookupByLibrary.simpleMessage("가져오기 from URL"),
    "importUrl": MessageLookupByLibrary.simpleMessage("가져오기 URL"),
    "infiniteTime": MessageLookupByLibrary.simpleMessage("infinite time"),
    "init": MessageLookupByLibrary.simpleMessage("init"),
    "inputCorrectHotkey": MessageLookupByLibrary.simpleMessage(
      "입력 correct hotkey",
    ),
    "intelligentSelected": MessageLookupByLibrary.simpleMessage(
      "intelligent 선택됨",
    ),
    "internet": MessageLookupByLibrary.simpleMessage("internet"),
    "interval": MessageLookupByLibrary.simpleMessage("interval"),
    "intranetIP": MessageLookupByLibrary.simpleMessage("intranet IP"),
    "invalidTransferAmount": MessageLookupByLibrary.simpleMessage(
      "유효하지 않음 이체 금액",
    ),
    "invite": MessageLookupByLibrary.simpleMessage("초대"),
    "inviteCode": MessageLookupByLibrary.simpleMessage("초대 코드"),
    "inviteCodeGenFailed": MessageLookupByLibrary.simpleMessage("초대 코드 GEN 실패"),
    "inviteCodeIncorrect": MessageLookupByLibrary.simpleMessage(
      "초대 코드 incorrect",
    ),
    "inviteCodeOptional": MessageLookupByLibrary.simpleMessage(
      "초대 코드 optional",
    ),
    "inviteCodeRequired": MessageLookupByLibrary.simpleMessage("초대 코드 필수"),
    "inviteCodeRequiredMessage": MessageLookupByLibrary.simpleMessage(
      "초대 코드 필수 메시지",
    ),
    "inviteLinkCopied": MessageLookupByLibrary.simpleMessage("초대 링크 복사됨"),
    "inviteRegisterReward": MessageLookupByLibrary.simpleMessage(
      "초대 가입 reward",
    ),
    "inviteRules": MessageLookupByLibrary.simpleMessage("초대 rules"),
    "inviteStats": MessageLookupByLibrary.simpleMessage("초대 stats"),
    "ipcidr": MessageLookupByLibrary.simpleMessage("ipcidr"),
    "ipv6Desc": MessageLookupByLibrary.simpleMessage("IPV 6 설명"),
    "ipv6InboundDesc": MessageLookupByLibrary.simpleMessage("IPV 6 inbound 설명"),
    "ja": MessageLookupByLibrary.simpleMessage("일본어"),
    "just": MessageLookupByLibrary.simpleMessage("just"),
    "keepAliveIntervalDesc": MessageLookupByLibrary.simpleMessage(
      "keep alive interval 설명",
    ),
    "key": MessageLookupByLibrary.simpleMessage("KEY"),
    "ko": MessageLookupByLibrary.simpleMessage("한국어"),
    "language": MessageLookupByLibrary.simpleMessage("언어"),
    "layout": MessageLookupByLibrary.simpleMessage("layout"),
    "light": MessageLookupByLibrary.simpleMessage("light"),
    "list": MessageLookupByLibrary.simpleMessage("목록"),
    "listen": MessageLookupByLibrary.simpleMessage("listen"),
    "loadMore": MessageLookupByLibrary.simpleMessage("load 더보기"),
    "loading": MessageLookupByLibrary.simpleMessage("불러오는 중"),
    "local": MessageLookupByLibrary.simpleMessage("로컬"),
    "localBackupDesc": MessageLookupByLibrary.simpleMessage("로컬 백업 설명"),
    "localRecoveryDesc": MessageLookupByLibrary.simpleMessage("로컬 recovery 설명"),
    "logLevel": MessageLookupByLibrary.simpleMessage("LOG 레벨"),
    "logcat": MessageLookupByLibrary.simpleMessage("logcat"),
    "logcatDesc": MessageLookupByLibrary.simpleMessage("logcat 설명"),
    "loggedOutSuccess": MessageLookupByLibrary.simpleMessage("logged OUT 성공"),
    "loginNow": MessageLookupByLibrary.simpleMessage("로그인 NOW"),
    "logout": MessageLookupByLibrary.simpleMessage("로그아웃"),
    "logoutConfirmMsg": MessageLookupByLibrary.simpleMessage("로그아웃 확인 MSG"),
    "logoutFailed": m5,
    "logs": MessageLookupByLibrary.simpleMessage("로그"),
    "logsDesc": MessageLookupByLibrary.simpleMessage("로그 설명"),
    "logsTest": MessageLookupByLibrary.simpleMessage("로그 테스트"),
    "loopback": MessageLookupByLibrary.simpleMessage("loopback"),
    "loopbackDesc": MessageLookupByLibrary.simpleMessage("loopback 설명"),
    "loose": MessageLookupByLibrary.simpleMessage("loose"),
    "maxTransferable": m6,
    "memoryInfo": MessageLookupByLibrary.simpleMessage("memory 정보"),
    "messageTest": MessageLookupByLibrary.simpleMessage("메시지 테스트"),
    "messageTestTip": MessageLookupByLibrary.simpleMessage("메시지 테스트 안내"),
    "min": MessageLookupByLibrary.simpleMessage("MIN"),
    "minimizeOnExit": MessageLookupByLibrary.simpleMessage("최소화 ON 종료"),
    "minimizeOnExitDesc": MessageLookupByLibrary.simpleMessage("최소화 ON 종료 설명"),
    "minutes": MessageLookupByLibrary.simpleMessage("분"),
    "mixedPort": MessageLookupByLibrary.simpleMessage("mixed 포트"),
    "mode": MessageLookupByLibrary.simpleMessage("모드"),
    "monochromeScheme": MessageLookupByLibrary.simpleMessage(
      "monochrome scheme",
    ),
    "months": MessageLookupByLibrary.simpleMessage("months"),
    "more": MessageLookupByLibrary.simpleMessage("더보기"),
    "myInviteQr": MessageLookupByLibrary.simpleMessage("MY 초대 QR"),
    "name": MessageLookupByLibrary.simpleMessage("이름"),
    "nameSort": MessageLookupByLibrary.simpleMessage("이름 정렬"),
    "nameserver": MessageLookupByLibrary.simpleMessage("nameserver"),
    "nameserverDesc": MessageLookupByLibrary.simpleMessage("nameserver 설명"),
    "nameserverPolicy": MessageLookupByLibrary.simpleMessage("nameserver 정책"),
    "nameserverPolicyDesc": MessageLookupByLibrary.simpleMessage(
      "nameserver 정책 설명",
    ),
    "network": MessageLookupByLibrary.simpleMessage("네트워크"),
    "networkDesc": MessageLookupByLibrary.simpleMessage("네트워크 설명"),
    "networkDetection": MessageLookupByLibrary.simpleMessage("네트워크 감지"),
    "networkSpeed": MessageLookupByLibrary.simpleMessage("네트워크 속도"),
    "neutralScheme": MessageLookupByLibrary.simpleMessage("neutral scheme"),
    "newMessageFromSupport": MessageLookupByLibrary.simpleMessage("새 지원 메시지"),
    "newPassword": MessageLookupByLibrary.simpleMessage("새 비밀번호"),
    "noCommissionRecord": MessageLookupByLibrary.simpleMessage("없음 커미션 기록"),
    "noData": MessageLookupByLibrary.simpleMessage("없음 data"),
    "noHotKey": MessageLookupByLibrary.simpleMessage("없음 HOT KEY"),
    "noIcon": MessageLookupByLibrary.simpleMessage("없음 icon"),
    "noInfo": MessageLookupByLibrary.simpleMessage("없음 정보"),
    "noInvitationData": MessageLookupByLibrary.simpleMessage("없음 초대 data"),
    "noInviteCode": MessageLookupByLibrary.simpleMessage("없음 초대 코드"),
    "noMoreInfoDesc": MessageLookupByLibrary.simpleMessage("없음 더보기 정보 설명"),
    "noNetwork": MessageLookupByLibrary.simpleMessage("없음 네트워크"),
    "noNetworkApp": MessageLookupByLibrary.simpleMessage("없음 네트워크 앱"),
    "noProxy": MessageLookupByLibrary.simpleMessage("없음 프록시"),
    "noProxyDesc": MessageLookupByLibrary.simpleMessage("없음 프록시 설명"),
    "noResolve": MessageLookupByLibrary.simpleMessage("없음 resolve"),
    "none": MessageLookupByLibrary.simpleMessage("없음"),
    "notConnected": MessageLookupByLibrary.simpleMessage("연결되지 않음"),
    "notSelectedTip": MessageLookupByLibrary.simpleMessage("NOT 선택됨 안내"),
    "nullProfileDesc": MessageLookupByLibrary.simpleMessage("없음 프로필 설명"),
    "nullTip": m7,
    "numberTip": m8,
    "officialWebsite": MessageLookupByLibrary.simpleMessage("웹사이트"),
    "oneColumn": MessageLookupByLibrary.simpleMessage("ONE column"),
    "onlineSupport": MessageLookupByLibrary.simpleMessage("온라인 지원"),
    "onlineSupportAddMore": MessageLookupByLibrary.simpleMessage("더 추가"),
    "onlineSupportApiConfigNotFound": MessageLookupByLibrary.simpleMessage(
      "온라인 지원 API 설정을 찾을 수 없습니다. 설정을 확인하세요",
    ),
    "onlineSupportCancel": MessageLookupByLibrary.simpleMessage("취소"),
    "onlineSupportClearHistory": MessageLookupByLibrary.simpleMessage("기록 지우기"),
    "onlineSupportClearHistoryConfirm": MessageLookupByLibrary.simpleMessage(
      "모든 채팅 기록을 지우시겠습니까? 이 작업은 되돌릴 수 없습니다.",
    ),
    "onlineSupportClickToSelect": MessageLookupByLibrary.simpleMessage(
      "클릭하여 이미지 선택",
    ),
    "onlineSupportConfirm": MessageLookupByLibrary.simpleMessage("확인"),
    "onlineSupportConnected": MessageLookupByLibrary.simpleMessage(
      "지원 시스템에 연결되었습니다",
    ),
    "onlineSupportConnecting": MessageLookupByLibrary.simpleMessage("연결 중..."),
    "onlineSupportConnectionError": MessageLookupByLibrary.simpleMessage(
      "연결 오류",
    ),
    "onlineSupportDisconnected": MessageLookupByLibrary.simpleMessage("연결 해제됨"),
    "onlineSupportGetMessagesFailed": m9,
    "onlineSupportInputHint": MessageLookupByLibrary.simpleMessage(
      "질문을 입력하세요...",
    ),
    "onlineSupportNoMessages": MessageLookupByLibrary.simpleMessage(
      "아직 메시지가 없습니다. 메시지를 보내 상담을 시작하세요",
    ),
    "onlineSupportSelectImages": MessageLookupByLibrary.simpleMessage("이미지 선택"),
    "onlineSupportSelectImagesFailed": m10,
    "onlineSupportSend": MessageLookupByLibrary.simpleMessage("보내기"),
    "onlineSupportSendImage": MessageLookupByLibrary.simpleMessage("이미지 보내기"),
    "onlineSupportSendMessageFailed": MessageLookupByLibrary.simpleMessage(
      "메시지 전송 실패: 인증 토큰을 가져올 수 없습니다",
    ),
    "onlineSupportSupportedFormats": MessageLookupByLibrary.simpleMessage(
      "JPG, PNG, GIF, WebP, BMP 지원\n최대 10MB",
    ),
    "onlineSupportTitle": MessageLookupByLibrary.simpleMessage("온라인 지원"),
    "onlineSupportTokenNotFound": MessageLookupByLibrary.simpleMessage(
      "인증 토큰을 찾을 수 없습니다",
    ),
    "onlineSupportUnsupportedHttpMethod": m11,
    "onlineSupportUploadFailed": m12,
    "onlineSupportWebSocketConfigNotFound":
        MessageLookupByLibrary.simpleMessage(
          "온라인 지원 WebSocket 설정을 찾을 수 없습니다. 설정을 확인하세요",
        ),
    "onlyIcon": MessageLookupByLibrary.simpleMessage("만 icon"),
    "onlyOtherApps": MessageLookupByLibrary.simpleMessage("만 기타 apps"),
    "onlyStatisticsProxy": MessageLookupByLibrary.simpleMessage("만 통계 프록시"),
    "onlyStatisticsProxyDesc": MessageLookupByLibrary.simpleMessage(
      "만 통계 프록시 설명",
    ),
    "openWebFailed": MessageLookupByLibrary.simpleMessage("열기 웹 실패"),
    "options": MessageLookupByLibrary.simpleMessage("options"),
    "orderAmount": m13,
    "orderNumber": m14,
    "other": MessageLookupByLibrary.simpleMessage("기타"),
    "otherContributors": MessageLookupByLibrary.simpleMessage(
      "기타 contributors",
    ),
    "outboundMode": MessageLookupByLibrary.simpleMessage("아웃바운드 모드"),
    "override": MessageLookupByLibrary.simpleMessage("오버라이드"),
    "overrideDesc": MessageLookupByLibrary.simpleMessage("오버라이드 설명"),
    "overrideDns": MessageLookupByLibrary.simpleMessage("오버라이드 DNS"),
    "overrideDnsDesc": MessageLookupByLibrary.simpleMessage("오버라이드 DNS 설명"),
    "overrideInvalidTip": MessageLookupByLibrary.simpleMessage(
      "오버라이드 유효하지 않음 안내",
    ),
    "overrideOriginRules": MessageLookupByLibrary.simpleMessage(
      "오버라이드 origin rules",
    ),
    "pageNumber": m15,
    "palette": MessageLookupByLibrary.simpleMessage("palette"),
    "password": MessageLookupByLibrary.simpleMessage("비밀번호"),
    "passwordMin8Chars": MessageLookupByLibrary.simpleMessage(
      "비밀번호 MIN 8 chars",
    ),
    "passwordMinLength": MessageLookupByLibrary.simpleMessage(
      "비밀번호 MIN length",
    ),
    "passwordMismatch": MessageLookupByLibrary.simpleMessage("비밀번호 mismatch"),
    "passwordResetFailed": MessageLookupByLibrary.simpleMessage("비밀번호 초기화 실패"),
    "passwordResetSuccessful": MessageLookupByLibrary.simpleMessage(
      "비밀번호 초기화 성공",
    ),
    "passwordsDoNotMatch": MessageLookupByLibrary.simpleMessage(
      "passwords DO NOT match",
    ),
    "paste": MessageLookupByLibrary.simpleMessage("붙여넣기"),
    "pendingCommission": MessageLookupByLibrary.simpleMessage("pending 커미션"),
    "plans": MessageLookupByLibrary.simpleMessage("요금제"),
    "pleaseBindWebDAV": MessageLookupByLibrary.simpleMessage(
      "please bind 웹 DAV",
    ),
    "pleaseConfirmNewPassword": MessageLookupByLibrary.simpleMessage(
      "please 확인 새 비밀번호",
    ),
    "pleaseConfirmPassword": MessageLookupByLibrary.simpleMessage(
      "please 확인 비밀번호",
    ),
    "pleaseEnterAtLeast8CharsPassword": MessageLookupByLibrary.simpleMessage(
      "please enter AT least 8 chars 비밀번호",
    ),
    "pleaseEnterEmail": MessageLookupByLibrary.simpleMessage(
      "please enter 이메일",
    ),
    "pleaseEnterEmailAddress": MessageLookupByLibrary.simpleMessage(
      "please enter 이메일 주소",
    ),
    "pleaseEnterEmailVerificationCode": MessageLookupByLibrary.simpleMessage(
      "please enter 이메일 인증 코드",
    ),
    "pleaseEnterInviteCode": MessageLookupByLibrary.simpleMessage(
      "please enter 초대 코드",
    ),
    "pleaseEnterNewPassword": MessageLookupByLibrary.simpleMessage(
      "please enter 새 비밀번호",
    ),
    "pleaseEnterPassword": MessageLookupByLibrary.simpleMessage(
      "please enter 비밀번호",
    ),
    "pleaseEnterScriptName": MessageLookupByLibrary.simpleMessage(
      "please enter 스크립트 이름",
    ),
    "pleaseEnterValidEmail": MessageLookupByLibrary.simpleMessage(
      "please enter 유효 이메일",
    ),
    "pleaseEnterValidEmailAddress": MessageLookupByLibrary.simpleMessage(
      "please enter 유효 이메일 주소",
    ),
    "pleaseEnterValidVerificationCode": MessageLookupByLibrary.simpleMessage(
      "please enter 유효 인증 코드",
    ),
    "pleaseEnterVerificationCode": MessageLookupByLibrary.simpleMessage(
      "please enter 인증 코드",
    ),
    "pleaseEnterWithdrawAccount": MessageLookupByLibrary.simpleMessage(
      "please enter 출금 계정",
    ),
    "pleaseEnterYourEmailAddress": MessageLookupByLibrary.simpleMessage(
      "please enter your 이메일 주소",
    ),
    "pleaseInputAdminPassword": MessageLookupByLibrary.simpleMessage(
      "please 입력 관리자 비밀번호",
    ),
    "pleaseReEnterPassword": MessageLookupByLibrary.simpleMessage(
      "please RE enter 비밀번호",
    ),
    "pleaseSelectWithdrawMethod": MessageLookupByLibrary.simpleMessage(
      "please 선택 출금 방식",
    ),
    "pleaseUploadFile": MessageLookupByLibrary.simpleMessage("please 업로드 파일"),
    "pleaseUploadValidQrcode": MessageLookupByLibrary.simpleMessage(
      "please 업로드 유효 QR 코드",
    ),
    "port": MessageLookupByLibrary.simpleMessage("포트"),
    "portConflictTip": MessageLookupByLibrary.simpleMessage("포트 conflict 안내"),
    "portTip": m16,
    "preferH3Desc": MessageLookupByLibrary.simpleMessage("prefer H 3 설명"),
    "pressKeyboard": MessageLookupByLibrary.simpleMessage("press keyboard"),
    "preview": MessageLookupByLibrary.simpleMessage("preview"),
    "profile": MessageLookupByLibrary.simpleMessage("프로필"),
    "profileAutoUpdateIntervalInvalidValidationDesc":
        MessageLookupByLibrary.simpleMessage(
          "프로필 자동 업데이트 interval 유효하지 않음 validation 설명",
        ),
    "profileAutoUpdateIntervalNullValidationDesc":
        MessageLookupByLibrary.simpleMessage(
          "프로필 자동 업데이트 interval 없음 validation 설명",
        ),
    "profileHasUpdate": MessageLookupByLibrary.simpleMessage("프로필 HAS 업데이트"),
    "profileNameNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "프로필 이름 없음 validation 설명",
    ),
    "profileParseErrorDesc": MessageLookupByLibrary.simpleMessage(
      "프로필 parse 오류 설명",
    ),
    "profileUrlInvalidValidationDesc": MessageLookupByLibrary.simpleMessage(
      "프로필 URL 유효하지 않음 validation 설명",
    ),
    "profileUrlNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "프로필 URL 없음 validation 설명",
    ),
    "profiles": MessageLookupByLibrary.simpleMessage("프로필"),
    "profilesSort": MessageLookupByLibrary.simpleMessage("프로필 정렬"),
    "project": MessageLookupByLibrary.simpleMessage("project"),
    "providers": MessageLookupByLibrary.simpleMessage("제공자"),
    "proxies": MessageLookupByLibrary.simpleMessage("프록시"),
    "proxiesSetting": MessageLookupByLibrary.simpleMessage("프록시 setting"),
    "proxyGroup": MessageLookupByLibrary.simpleMessage("프록시 그룹"),
    "proxyNameserver": MessageLookupByLibrary.simpleMessage("프록시 nameserver"),
    "proxyNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "프록시 nameserver 설명",
    ),
    "proxyPort": MessageLookupByLibrary.simpleMessage("프록시 포트"),
    "proxyPortDesc": MessageLookupByLibrary.simpleMessage("프록시 포트 설명"),
    "proxyProviders": MessageLookupByLibrary.simpleMessage("프록시 제공자"),
    "pureBlackMode": MessageLookupByLibrary.simpleMessage("pure black 모드"),
    "qrcode": MessageLookupByLibrary.simpleMessage("QR 코드"),
    "qrcodeDesc": MessageLookupByLibrary.simpleMessage("QR 코드 설명"),
    "rainbowScheme": MessageLookupByLibrary.simpleMessage("rainbow scheme"),
    "recovery": MessageLookupByLibrary.simpleMessage("recovery"),
    "recoveryAll": MessageLookupByLibrary.simpleMessage("recovery ALL"),
    "recoveryProfiles": MessageLookupByLibrary.simpleMessage("recovery 프로필"),
    "recoveryStrategy": MessageLookupByLibrary.simpleMessage(
      "recovery strategy",
    ),
    "recoveryStrategy_compatible": MessageLookupByLibrary.simpleMessage(
      "recovery strategy compatible",
    ),
    "recoveryStrategy_override": MessageLookupByLibrary.simpleMessage(
      "recovery strategy 오버라이드",
    ),
    "recoverySuccess": MessageLookupByLibrary.simpleMessage("recovery 성공"),
    "redirPort": MessageLookupByLibrary.simpleMessage("redir 포트"),
    "redo": MessageLookupByLibrary.simpleMessage("다시 실행"),
    "refresh": MessageLookupByLibrary.simpleMessage("새로고침"),
    "regExp": MessageLookupByLibrary.simpleMessage("REG EXP"),
    "registerAccount": MessageLookupByLibrary.simpleMessage("가입 계정"),
    "registerSuccessSaveCredentials": MessageLookupByLibrary.simpleMessage(
      "가입 성공 저장 credentials",
    ),
    "registrationFailed": m17,
    "rememberPassword": MessageLookupByLibrary.simpleMessage("remember 비밀번호"),
    "remote": MessageLookupByLibrary.simpleMessage("원격"),
    "remoteBackupDesc": MessageLookupByLibrary.simpleMessage("원격 백업 설명"),
    "remoteRecoveryDesc": MessageLookupByLibrary.simpleMessage(
      "원격 recovery 설명",
    ),
    "remove": MessageLookupByLibrary.simpleMessage("삭제"),
    "rename": MessageLookupByLibrary.simpleMessage("rename"),
    "requests": MessageLookupByLibrary.simpleMessage("requests"),
    "requestsDesc": MessageLookupByLibrary.simpleMessage("requests 설명"),
    "resendVerificationCode": MessageLookupByLibrary.simpleMessage(
      "resend 인증 코드",
    ),
    "reset": MessageLookupByLibrary.simpleMessage("초기화"),
    "resetPassword": MessageLookupByLibrary.simpleMessage("초기화 비밀번호"),
    "resetTip": MessageLookupByLibrary.simpleMessage("초기화 안내"),
    "resources": MessageLookupByLibrary.simpleMessage("리소스"),
    "resourcesDesc": MessageLookupByLibrary.simpleMessage("리소스 설명"),
    "respectRules": MessageLookupByLibrary.simpleMessage("respect rules"),
    "respectRulesDesc": MessageLookupByLibrary.simpleMessage(
      "respect rules 설명",
    ),
    "routeAddress": MessageLookupByLibrary.simpleMessage("라우팅 주소"),
    "routeAddressDesc": MessageLookupByLibrary.simpleMessage("라우팅 주소 설명"),
    "routeMode": MessageLookupByLibrary.simpleMessage("라우팅 모드"),
    "routeMode_bypassPrivate": MessageLookupByLibrary.simpleMessage(
      "라우팅 모드 bypass private",
    ),
    "routeMode_config": MessageLookupByLibrary.simpleMessage("라우팅 모드 설정"),
    "rule": MessageLookupByLibrary.simpleMessage("스마트 라우팅"),
    "ruleName": MessageLookupByLibrary.simpleMessage("규칙 이름"),
    "ruleProviders": MessageLookupByLibrary.simpleMessage("규칙 제공자"),
    "ruleTarget": MessageLookupByLibrary.simpleMessage("규칙 target"),
    "save": MessageLookupByLibrary.simpleMessage("저장"),
    "saveChanges": MessageLookupByLibrary.simpleMessage("저장 changes"),
    "saveQr": MessageLookupByLibrary.simpleMessage("저장 QR"),
    "saveQrCodeFeature": MessageLookupByLibrary.simpleMessage(
      "저장 QR 코드 feature",
    ),
    "saveTip": MessageLookupByLibrary.simpleMessage("저장 안내"),
    "script": MessageLookupByLibrary.simpleMessage("스크립트"),
    "search": MessageLookupByLibrary.simpleMessage("search"),
    "seconds": MessageLookupByLibrary.simpleMessage("초"),
    "selectAll": MessageLookupByLibrary.simpleMessage("선택 ALL"),
    "selectTheme": MessageLookupByLibrary.simpleMessage("선택 테마"),
    "selected": MessageLookupByLibrary.simpleMessage("선택됨"),
    "selectedCountTitle": m18,
    "sendCodeFailed": MessageLookupByLibrary.simpleMessage("보내기 코드 실패"),
    "sendVerificationCode": MessageLookupByLibrary.simpleMessage("보내기 인증 코드"),
    "sendVerificationCodeFailed": m19,
    "setNewPassword": MessageLookupByLibrary.simpleMessage("SET 새 비밀번호"),
    "settings": MessageLookupByLibrary.simpleMessage("설정"),
    "show": MessageLookupByLibrary.simpleMessage("창 표시"),
    "shrink": MessageLookupByLibrary.simpleMessage("shrink"),
    "silentLaunch": MessageLookupByLibrary.simpleMessage("조용히 실행"),
    "silentLaunchDesc": MessageLookupByLibrary.simpleMessage("조용히 실행 설명"),
    "size": MessageLookupByLibrary.simpleMessage("size"),
    "socksPort": MessageLookupByLibrary.simpleMessage("socks 포트"),
    "sort": MessageLookupByLibrary.simpleMessage("정렬"),
    "source": MessageLookupByLibrary.simpleMessage("소스"),
    "sourceIp": MessageLookupByLibrary.simpleMessage("소스 IP"),
    "stackMode": MessageLookupByLibrary.simpleMessage("stack 모드"),
    "standard": MessageLookupByLibrary.simpleMessage("standard"),
    "start": MessageLookupByLibrary.simpleMessage("연결"),
    "startVpn": MessageLookupByLibrary.simpleMessage("시작 VPN"),
    "status": MessageLookupByLibrary.simpleMessage("상태"),
    "statusDesc": MessageLookupByLibrary.simpleMessage("상태 설명"),
    "stop": MessageLookupByLibrary.simpleMessage("연결 해제"),
    "stopVpn": MessageLookupByLibrary.simpleMessage("중지 VPN"),
    "style": MessageLookupByLibrary.simpleMessage("style"),
    "subRule": MessageLookupByLibrary.simpleMessage("SUB 규칙"),
    "submit": MessageLookupByLibrary.simpleMessage("submit"),
    "subscriptionExpired": MessageLookupByLibrary.simpleMessage("구독 만료됨"),
    "subscriptionExpiredDetail": m20,
    "subscriptionExpiresToday": MessageLookupByLibrary.simpleMessage(
      "구독 만료 오늘",
    ),
    "subscriptionExpiresTodayDetail": MessageLookupByLibrary.simpleMessage(
      "구독 만료 오늘 상세",
    ),
    "subscriptionExpiringInDays": MessageLookupByLibrary.simpleMessage(
      "구독 expiring IN 일",
    ),
    "subscriptionExpiringInDaysDetail": m21,
    "subscriptionNoSubscription": MessageLookupByLibrary.simpleMessage(
      "구독 없음 구독",
    ),
    "subscriptionNoSubscriptionDetail": MessageLookupByLibrary.simpleMessage(
      "구독 없음 구독 상세",
    ),
    "subscriptionNotLoggedIn": MessageLookupByLibrary.simpleMessage(
      "구독 NOT logged IN",
    ),
    "subscriptionNotLoggedInDetail": MessageLookupByLibrary.simpleMessage(
      "구독 NOT logged IN 상세",
    ),
    "subscriptionTrafficExhausted": MessageLookupByLibrary.simpleMessage(
      "구독 트래픽 exhausted",
    ),
    "subscriptionTrafficExhaustedDetail": MessageLookupByLibrary.simpleMessage(
      "구독 트래픽 exhausted 상세",
    ),
    "subscriptionValid": MessageLookupByLibrary.simpleMessage("구독 유효"),
    "subscriptionValidDetail": m22,
    "switchTheme": MessageLookupByLibrary.simpleMessage("switch 테마"),
    "sync": MessageLookupByLibrary.simpleMessage("sync"),
    "system": MessageLookupByLibrary.simpleMessage("시스템"),
    "systemApp": MessageLookupByLibrary.simpleMessage("시스템 앱"),
    "systemFont": MessageLookupByLibrary.simpleMessage("시스템 font"),
    "systemProxy": MessageLookupByLibrary.simpleMessage("시스템 프록시"),
    "systemProxyDesc": MessageLookupByLibrary.simpleMessage("시스템 프록시 설명"),
    "tab": MessageLookupByLibrary.simpleMessage("TAB"),
    "tabAnimation": MessageLookupByLibrary.simpleMessage("TAB animation"),
    "tabAnimationDesc": MessageLookupByLibrary.simpleMessage(
      "TAB animation 설명",
    ),
    "tapToConnect": MessageLookupByLibrary.simpleMessage("탭하여 연결"),
    "tcpConcurrent": MessageLookupByLibrary.simpleMessage("TCP 동시 연결"),
    "tcpConcurrentDesc": MessageLookupByLibrary.simpleMessage(
      "TCP concurrent 설명",
    ),
    "testUrl": MessageLookupByLibrary.simpleMessage("테스트 URL"),
    "textScale": MessageLookupByLibrary.simpleMessage("텍스트 scale"),
    "theme": MessageLookupByLibrary.simpleMessage("테마"),
    "themeColor": MessageLookupByLibrary.simpleMessage("테마 color"),
    "themeDesc": MessageLookupByLibrary.simpleMessage("테마 설명"),
    "themeMode": MessageLookupByLibrary.simpleMessage("테마 모드"),
    "threeColumns": MessageLookupByLibrary.simpleMessage("three columns"),
    "tight": MessageLookupByLibrary.simpleMessage("tight"),
    "time": MessageLookupByLibrary.simpleMessage("time"),
    "tip": MessageLookupByLibrary.simpleMessage("안내"),
    "toggle": MessageLookupByLibrary.simpleMessage("toggle"),
    "tonalSpotScheme": MessageLookupByLibrary.simpleMessage(
      "tonal spot scheme",
    ),
    "tools": MessageLookupByLibrary.simpleMessage("도구"),
    "totalCommission": MessageLookupByLibrary.simpleMessage("전체 커미션"),
    "totalInvites": MessageLookupByLibrary.simpleMessage("전체 invites"),
    "totalRecords": m23,
    "tproxyPort": MessageLookupByLibrary.simpleMessage("tproxy 포트"),
    "trafficUsage": MessageLookupByLibrary.simpleMessage("트래픽 사용량"),
    "transfer": MessageLookupByLibrary.simpleMessage("이체"),
    "transferAmount": MessageLookupByLibrary.simpleMessage("이체 금액"),
    "transferAmountExceeded": m24,
    "transferFailed": m25,
    "transferNote": MessageLookupByLibrary.simpleMessage("이체 note"),
    "transferSuccess": MessageLookupByLibrary.simpleMessage("이체 성공"),
    "transferSuccessMsg": m26,
    "transferToWallet": MessageLookupByLibrary.simpleMessage("이체 TO 지갑"),
    "transferring": MessageLookupByLibrary.simpleMessage("transferring"),
    "tun": MessageLookupByLibrary.simpleMessage("TUN"),
    "tunDesc": MessageLookupByLibrary.simpleMessage("TUN 설명"),
    "twoColumns": MessageLookupByLibrary.simpleMessage("TWO columns"),
    "unableToUpdateCurrentProfileDesc": MessageLookupByLibrary.simpleMessage(
      "unable TO 업데이트 현재 프로필 설명",
    ),
    "undo": MessageLookupByLibrary.simpleMessage("실행 취소"),
    "unifiedDelay": MessageLookupByLibrary.simpleMessage("unified 지연"),
    "unifiedDelayDesc": MessageLookupByLibrary.simpleMessage("unified 지연 설명"),
    "unknown": MessageLookupByLibrary.simpleMessage("알 수 없음"),
    "unnamed": MessageLookupByLibrary.simpleMessage("unnamed"),
    "update": MessageLookupByLibrary.simpleMessage("업데이트"),
    "updateCheckAllServersUnavailable": MessageLookupByLibrary.simpleMessage(
      "업데이트 확인 ALL servers 사용 불가",
    ),
    "updateCheckCurrentVersion": m27,
    "updateCheckForceUpdate": m28,
    "updateCheckMustUpdate": MessageLookupByLibrary.simpleMessage(
      "업데이트 확인 must 업데이트",
    ),
    "updateCheckNewVersionFound": m29,
    "updateCheckNoServerUrlsConfigured": MessageLookupByLibrary.simpleMessage(
      "업데이트 확인 없음 서버 URL configured",
    ),
    "updateCheckReleaseNotes": MessageLookupByLibrary.simpleMessage(
      "업데이트 확인 release notes",
    ),
    "updateCheckServerError": m30,
    "updateCheckServerTemporarilyUnavailable":
        MessageLookupByLibrary.simpleMessage("업데이트 확인 서버 temporarily 사용 불가"),
    "updateCheckServerUrlNotConfigured": MessageLookupByLibrary.simpleMessage(
      "업데이트 확인 서버 URL NOT configured",
    ),
    "updateCheckUpdateLater": MessageLookupByLibrary.simpleMessage(
      "업데이트 확인 업데이트 later",
    ),
    "updateCheckUpdateNow": MessageLookupByLibrary.simpleMessage(
      "업데이트 확인 업데이트 NOW",
    ),
    "upload": MessageLookupByLibrary.simpleMessage("업로드"),
    "url": MessageLookupByLibrary.simpleMessage("URL"),
    "urlDesc": MessageLookupByLibrary.simpleMessage("URL 설명"),
    "urlTip": m31,
    "useHosts": MessageLookupByLibrary.simpleMessage("USE hosts"),
    "useSystemHosts": MessageLookupByLibrary.simpleMessage("USE 시스템 hosts"),
    "userCenter": MessageLookupByLibrary.simpleMessage("개인 센터"),
    "value": MessageLookupByLibrary.simpleMessage("value"),
    "verificationCode": MessageLookupByLibrary.simpleMessage("인증 코드"),
    "verificationCode6Digits": MessageLookupByLibrary.simpleMessage(
      "인증 코드 6 digits",
    ),
    "verificationCodeSent": MessageLookupByLibrary.simpleMessage("인증 코드 sent"),
    "verificationCodeSentCheckEmail": MessageLookupByLibrary.simpleMessage(
      "인증 코드 sent 확인 이메일",
    ),
    "verificationCodeSentTo": m32,
    "vibrantScheme": MessageLookupByLibrary.simpleMessage("vibrant scheme"),
    "view": MessageLookupByLibrary.simpleMessage("보기"),
    "viewHistory": MessageLookupByLibrary.simpleMessage("보기 기록"),
    "visitWebVersion": MessageLookupByLibrary.simpleMessage("visit 웹 버전"),
    "vpnDesc": MessageLookupByLibrary.simpleMessage("VPN 설명"),
    "vpnEnableDesc": MessageLookupByLibrary.simpleMessage("VPN 활성화 설명"),
    "vpnSystemProxyDesc": MessageLookupByLibrary.simpleMessage(
      "VPN 시스템 프록시 설명",
    ),
    "vpnTip": MessageLookupByLibrary.simpleMessage("VPN 안내"),
    "walletBalance": MessageLookupByLibrary.simpleMessage("지갑 잔액"),
    "walletDetails": MessageLookupByLibrary.simpleMessage("지갑 상세"),
    "webDAVConfiguration": MessageLookupByLibrary.simpleMessage(
      "웹 davconfiguration",
    ),
    "whitelistMode": MessageLookupByLibrary.simpleMessage("whitelist 모드"),
    "withdraw": MessageLookupByLibrary.simpleMessage("출금"),
    "withdrawAccount": MessageLookupByLibrary.simpleMessage("출금 계정"),
    "withdrawCommission": MessageLookupByLibrary.simpleMessage("출금 커미션"),
    "withdrawMethod": MessageLookupByLibrary.simpleMessage("출금 방식"),
    "withdrawRequestSubmitted": MessageLookupByLibrary.simpleMessage(
      "출금 request submitted",
    ),
    "withdrawRequestSubmittedWaitReview": MessageLookupByLibrary.simpleMessage(
      "출금 request submitted wait review",
    ),
    "withdrawSubmissionFailed": MessageLookupByLibrary.simpleMessage(
      "출금 submission 실패",
    ),
    "withdrawSubmissionFailedWithError": m33,
    "withdrawSubmissionNote": MessageLookupByLibrary.simpleMessage(
      "출금 submission note",
    ),
    "withdrawableAmount": m34,
    "withdrawalAvailable": MessageLookupByLibrary.simpleMessage(
      "withdrawal 사용 가능",
    ),
    "xboard": MessageLookupByLibrary.simpleMessage("XBoard"),
    "xboard24HourCustomerService": MessageLookupByLibrary.simpleMessage(
      "24 시간 고객 서비스",
    ),
    "xboardAccountBalance": MessageLookupByLibrary.simpleMessage("계정 잔액"),
    "xboardAccountBanned": MessageLookupByLibrary.simpleMessage("계정 banned"),
    "xboardAccountBannedDetail": MessageLookupByLibrary.simpleMessage(
      "계정 banned 상세",
    ),
    "xboardAccountInfo": MessageLookupByLibrary.simpleMessage("계정 정보"),
    "xboardAccountManagement": MessageLookupByLibrary.simpleMessage("계정 관리"),
    "xboardActualPaidAmount": MessageLookupByLibrary.simpleMessage("결제 금액"),
    "xboardAddLinkToConfig": MessageLookupByLibrary.simpleMessage(
      "추가 링크 TO 설정",
    ),
    "xboardAddingToConfigList": MessageLookupByLibrary.simpleMessage(
      "adding TO 설정 목록",
    ),
    "xboardAfterPurchasingPlan": MessageLookupByLibrary.simpleMessage(
      "after purchasing 요금제",
    ),
    "xboardApiUrlNotConfigured": MessageLookupByLibrary.simpleMessage(
      "API URL NOT configured",
    ),
    "xboardAutoCheckEvery5Seconds": MessageLookupByLibrary.simpleMessage(
      "자동 확인 every 5 초",
    ),
    "xboardAutoDetectPaymentStatus": MessageLookupByLibrary.simpleMessage(
      "자동 detect 결제 상태",
    ),
    "xboardAutoOpeningPaymentPage": MessageLookupByLibrary.simpleMessage(
      "자동 opening 결제 page",
    ),
    "xboardAutoTesting": MessageLookupByLibrary.simpleMessage("자동 테스트 중"),
    "xboardBack": MessageLookupByLibrary.simpleMessage("back"),
    "xboardBalancePay": MessageLookupByLibrary.simpleMessage("잔액 결제"),
    "xboardBalanceWithAmount": m35,
    "xboardBrowserNotOpenedTip": MessageLookupByLibrary.simpleMessage(
      "브라우저 NOT opened 안내",
    ),
    "xboardBuyMoreTrafficOrUpgrade": MessageLookupByLibrary.simpleMessage(
      "BUY 더보기 트래픽 OR upgrade",
    ),
    "xboardBuyNow": MessageLookupByLibrary.simpleMessage("BUY NOW"),
    "xboardBuyoutPlan": MessageLookupByLibrary.simpleMessage("buyout 요금제"),
    "xboardCancel": MessageLookupByLibrary.simpleMessage("취소"),
    "xboardCancelOrder": MessageLookupByLibrary.simpleMessage("취소 주문"),
    "xboardCancelPayment": MessageLookupByLibrary.simpleMessage("취소 결제"),
    "xboardCanceling": MessageLookupByLibrary.simpleMessage("canceling"),
    "xboardChangePassword": MessageLookupByLibrary.simpleMessage("변경 비밀번호"),
    "xboardCheckPaymentFailed": MessageLookupByLibrary.simpleMessage(
      "확인 결제 실패",
    ),
    "xboardCheckPaymentStatus": MessageLookupByLibrary.simpleMessage(
      "확인 결제 상태",
    ),
    "xboardCheckStatus": MessageLookupByLibrary.simpleMessage("확인 상태"),
    "xboardChecking": MessageLookupByLibrary.simpleMessage("확인 중"),
    "xboardCleaningOldConfig": MessageLookupByLibrary.simpleMessage(
      "cleaning 이전 설정",
    ),
    "xboardClearError": MessageLookupByLibrary.simpleMessage("지우기 오류"),
    "xboardClickToCopy": MessageLookupByLibrary.simpleMessage("click TO 복사"),
    "xboardClickToSetupNodes": MessageLookupByLibrary.simpleMessage(
      "click TO setup 노드",
    ),
    "xboardCommissionConfirmed": MessageLookupByLibrary.simpleMessage(
      "커미션 confirmed 확인",
    ),
    "xboardCommissionIssuing": MessageLookupByLibrary.simpleMessage(
      "커미션 issuing",
    ),
    "xboardCompletePaymentInBrowser": MessageLookupByLibrary.simpleMessage(
      "complete 결제 IN 브라우저",
    ),
    "xboardConfigDownloadFailed": MessageLookupByLibrary.simpleMessage(
      "설정 다운로드 실패",
    ),
    "xboardConfigFormatError": MessageLookupByLibrary.simpleMessage(
      "설정 format 오류",
    ),
    "xboardConfigSaveFailed": MessageLookupByLibrary.simpleMessage("설정 저장 실패"),
    "xboardConfigurationError": MessageLookupByLibrary.simpleMessage("설정 오류"),
    "xboardConfirm": MessageLookupByLibrary.simpleMessage("확인"),
    "xboardConfirmAction": MessageLookupByLibrary.simpleMessage("확인 action"),
    "xboardConfirmChange": MessageLookupByLibrary.simpleMessage("확인 변경"),
    "xboardConfirmPassword": MessageLookupByLibrary.simpleMessage("확인 비밀번호"),
    "xboardConfirmPurchase": MessageLookupByLibrary.simpleMessage("확인 구매"),
    "xboardConfirmRenewPlan": MessageLookupByLibrary.simpleMessage(
      "확인 renew 요금제",
    ),
    "xboardConfirmResetTraffic": MessageLookupByLibrary.simpleMessage(
      "확인 초기화 트래픽",
    ),
    "xboardCongratulationsSubscriptionActivated":
        MessageLookupByLibrary.simpleMessage("congratulations 구독 activated"),
    "xboardConnectGlobalQualityNodes": MessageLookupByLibrary.simpleMessage(
      "연결 전역 품질 노드",
    ),
    "xboardConnectionTimeout": MessageLookupByLibrary.simpleMessage(
      "연결 시간이 초과되었습니다. 네트워크 연결을 확인하세요",
    ),
    "xboardContactCustomerService": MessageLookupByLibrary.simpleMessage(
      "고객지원",
    ),
    "xboardCopyFailed": MessageLookupByLibrary.simpleMessage("복사 실패"),
    "xboardCopyInviteCode": MessageLookupByLibrary.simpleMessage("복사 초대 코드"),
    "xboardCopyInviteLink": MessageLookupByLibrary.simpleMessage("복사 초대 링크"),
    "xboardCopyLink": MessageLookupByLibrary.simpleMessage("복사 링크"),
    "xboardCopyPaymentLink": MessageLookupByLibrary.simpleMessage("복사 결제 링크"),
    "xboardCopySubscriptionLinkAbove": MessageLookupByLibrary.simpleMessage(
      "복사 구독 링크 above",
    ),
    "xboardCouponExpired": MessageLookupByLibrary.simpleMessage("쿠폰 만료됨"),
    "xboardCouponNotYetActive": MessageLookupByLibrary.simpleMessage(
      "쿠폰 NOT YET active",
    ),
    "xboardCouponOptional": MessageLookupByLibrary.simpleMessage("쿠폰 optional"),
    "xboardCreateTicket": MessageLookupByLibrary.simpleMessage("create 티켓"),
    "xboardCreateTicketHint": MessageLookupByLibrary.simpleMessage(
      "create 티켓 힌트",
    ),
    "xboardCreatedAt": MessageLookupByLibrary.simpleMessage("created AT"),
    "xboardCreatingOrder": MessageLookupByLibrary.simpleMessage("creating 주문"),
    "xboardCreatingOrderPleaseWait": MessageLookupByLibrary.simpleMessage(
      "creating 주문 please wait",
    ),
    "xboardCurrentBalance": MessageLookupByLibrary.simpleMessage("현재 잔액"),
    "xboardCurrentNode": MessageLookupByLibrary.simpleMessage("현재 노드"),
    "xboardCurrentPassword": MessageLookupByLibrary.simpleMessage("현재 비밀번호"),
    "xboardCurrentPlanBased": MessageLookupByLibrary.simpleMessage(
      "현재 요금제 based",
    ),
    "xboardCurrentVersion": MessageLookupByLibrary.simpleMessage("현재 버전"),
    "xboardCustomRechargeAmount": MessageLookupByLibrary.simpleMessage(
      "사용자 지정 충전 금액",
    ),
    "xboardDays": MessageLookupByLibrary.simpleMessage("일"),
    "xboardDeductedBalance": MessageLookupByLibrary.simpleMessage(
      "deducted 잔액",
    ),
    "xboardDeductibleBalance": MessageLookupByLibrary.simpleMessage("공제 가능 잔액"),
    "xboardDeductibleDuringPayment": MessageLookupByLibrary.simpleMessage(
      "deductible during 결제",
    ),
    "xboardDeviceAutoOfflineHint": MessageLookupByLibrary.simpleMessage(
      "기기 자동 offline 힌트",
    ),
    "xboardDeviceCurrentDeviceLabel": MessageLookupByLibrary.simpleMessage(
      "기기 현재 기기 label",
    ),
    "xboardDeviceExpired": MessageLookupByLibrary.simpleMessage("기기 만료됨"),
    "xboardDeviceHistory": MessageLookupByLibrary.simpleMessage("기기 기록"),
    "xboardDeviceHistoryHint": MessageLookupByLibrary.simpleMessage("기기 기록 힌트"),
    "xboardDeviceLabelId": MessageLookupByLibrary.simpleMessage("기기 label ID"),
    "xboardDeviceLabelLastIp": MessageLookupByLibrary.simpleMessage(
      "기기 label last IP",
    ),
    "xboardDeviceLabelLastOnline": MessageLookupByLibrary.simpleMessage(
      "기기 label last 온라인",
    ),
    "xboardDeviceLabelOsVersion": MessageLookupByLibrary.simpleMessage(
      "기기 label OS 버전",
    ),
    "xboardDeviceLabelRevokedAt": MessageLookupByLibrary.simpleMessage(
      "기기 label revoked AT",
    ),
    "xboardDeviceLabelRevokedBy": MessageLookupByLibrary.simpleMessage(
      "기기 label revoked BY",
    ),
    "xboardDeviceManagement": MessageLookupByLibrary.simpleMessage("기기 관리"),
    "xboardDeviceNoRecords": MessageLookupByLibrary.simpleMessage("기기 없음 기록"),
    "xboardDeviceNoRecordsHint": MessageLookupByLibrary.simpleMessage(
      "기기 없음 기록 힌트",
    ),
    "xboardDeviceOffline": MessageLookupByLibrary.simpleMessage("기기 offline"),
    "xboardDeviceOnline": MessageLookupByLibrary.simpleMessage("기기 온라인"),
    "xboardDeviceRemoveCurrentConfirm": MessageLookupByLibrary.simpleMessage(
      "기기 삭제 현재 확인",
    ),
    "xboardDeviceRemoveTitle": MessageLookupByLibrary.simpleMessage("기기 삭제 제목"),
    "xboardDeviceRemoved": MessageLookupByLibrary.simpleMessage("기기 removed"),
    "xboardDeviceRevoked": MessageLookupByLibrary.simpleMessage("기기 revoked"),
    "xboardDeviceSummary": m36,
    "xboardDeviceUnknown": MessageLookupByLibrary.simpleMessage("기기 알 수 없음"),
    "xboardDeviceUnknownVersion": MessageLookupByLibrary.simpleMessage(
      "기기 알 수 없음 버전",
    ),
    "xboardDeviceUnlimited": MessageLookupByLibrary.simpleMessage("기기 무제한"),
    "xboardDiscountAmount": MessageLookupByLibrary.simpleMessage("discount 금액"),
    "xboardDiscounted": MessageLookupByLibrary.simpleMessage("discounted"),
    "xboardDiscountedPrice": MessageLookupByLibrary.simpleMessage(
      "discounted 가격",
    ),
    "xboardDocsCenter": MessageLookupByLibrary.simpleMessage("docs 센터"),
    "xboardDownloadingConfig": MessageLookupByLibrary.simpleMessage(
      "downloading 설정",
    ),
    "xboardEmail": MessageLookupByLibrary.simpleMessage("이메일"),
    "xboardEmailUnavailable": MessageLookupByLibrary.simpleMessage("이메일 사용 불가"),
    "xboardEnableTun": MessageLookupByLibrary.simpleMessage("활성화 TUN"),
    "xboardEnjoyFastNetworkExperience": MessageLookupByLibrary.simpleMessage(
      "enjoy fast 네트워크 experience",
    ),
    "xboardEnterAmount": MessageLookupByLibrary.simpleMessage("enter 금액"),
    "xboardEnterCouponCode": MessageLookupByLibrary.simpleMessage(
      "enter 쿠폰 코드",
    ),
    "xboardEnterGiftCardCode": MessageLookupByLibrary.simpleMessage(
      "enter 기프트 카드 코드",
    ),
    "xboardEnterGiftCardCodeHint": MessageLookupByLibrary.simpleMessage(
      "enter 기프트 카드 코드 힌트",
    ),
    "xboardExcellent": MessageLookupByLibrary.simpleMessage("매우 좋음"),
    "xboardExpiredOnDate": m37,
    "xboardExpiresOnDate": m38,
    "xboardExpiresOnWithDays": m39,
    "xboardExpiryTime": MessageLookupByLibrary.simpleMessage("expiry time"),
    "xboardFailedToCheckPaymentStatus": MessageLookupByLibrary.simpleMessage(
      "실패 TO 확인 결제 상태",
    ),
    "xboardFailedToGetSubscriptionInfo": MessageLookupByLibrary.simpleMessage(
      "실패 TO GET 구독 정보",
    ),
    "xboardFailedToOpenPaymentLink": MessageLookupByLibrary.simpleMessage(
      "실패 TO 열기 결제 링크",
    ),
    "xboardFailedToOpenPaymentPage": MessageLookupByLibrary.simpleMessage(
      "실패 TO 열기 결제 page",
    ),
    "xboardFair": MessageLookupByLibrary.simpleMessage("보통"),
    "xboardForceUpdate": MessageLookupByLibrary.simpleMessage("force 업데이트"),
    "xboardForgotPassword": MessageLookupByLibrary.simpleMessage("잊음 비밀번호"),
    "xboardGetGroupLinkFailed": MessageLookupByLibrary.simpleMessage(
      "GET 그룹 링크 실패",
    ),
    "xboardGettingIP": MessageLookupByLibrary.simpleMessage("getting IP"),
    "xboardGiftCardCode": MessageLookupByLibrary.simpleMessage("기프트 카드 코드"),
    "xboardGiftCardCodeLabel": MessageLookupByLibrary.simpleMessage(
      "기프트 카드 코드 label",
    ),
    "xboardGiftCardRedeem": MessageLookupByLibrary.simpleMessage(
      "기프트 카드 redeem",
    ),
    "xboardGiftCardRedeemTitle": MessageLookupByLibrary.simpleMessage(
      "기프트 카드 redeem 제목",
    ),
    "xboardGlobalNodes": MessageLookupByLibrary.simpleMessage("전역 노드"),
    "xboardGlobalProxy": MessageLookupByLibrary.simpleMessage("전역 프록시"),
    "xboardGood": MessageLookupByLibrary.simpleMessage("좋음"),
    "xboardGotIt": MessageLookupByLibrary.simpleMessage("확인"),
    "xboardGroup": MessageLookupByLibrary.simpleMessage("그룹"),
    "xboardGroupLinkNotConfigured": MessageLookupByLibrary.simpleMessage(
      "그룹 링크 NOT configured",
    ),
    "xboardHalfYearlyPayment": MessageLookupByLibrary.simpleMessage("반년 연간 결제"),
    "xboardHandleLater": MessageLookupByLibrary.simpleMessage("handle later"),
    "xboardHandlingFee": MessageLookupByLibrary.simpleMessage("handling FEE"),
    "xboardHigh": MessageLookupByLibrary.simpleMessage("높음"),
    "xboardHighSpeedNetwork": MessageLookupByLibrary.simpleMessage(
      "높음 속도 네트워크",
    ),
    "xboardHome": MessageLookupByLibrary.simpleMessage("홈"),
    "xboardImportFailed": MessageLookupByLibrary.simpleMessage("가져오기 실패"),
    "xboardImportSuccess": MessageLookupByLibrary.simpleMessage("가져오기 성공"),
    "xboardImportingSubscription": MessageLookupByLibrary.simpleMessage(
      "importing 구독",
    ),
    "xboardInsufficientBalance": MessageLookupByLibrary.simpleMessage(
      "insufficient 잔액",
    ),
    "xboardInvalidCredentials": MessageLookupByLibrary.simpleMessage(
      "유효하지 않음 credentials",
    ),
    "xboardInvalidOrExpiredCoupon": MessageLookupByLibrary.simpleMessage(
      "유효하지 않음 OR 만료됨 쿠폰",
    ),
    "xboardInvalidResponseFormat": MessageLookupByLibrary.simpleMessage(
      "유효하지 않음 response format",
    ),
    "xboardInviteCode": MessageLookupByLibrary.simpleMessage("초대 코드"),
    "xboardJoinGroup": MessageLookupByLibrary.simpleMessage("그룹 참여"),
    "xboardKeepSubscriptionLinkSafe": MessageLookupByLibrary.simpleMessage(
      "keep 구독 링크 안전",
    ),
    "xboardLater": MessageLookupByLibrary.simpleMessage("later"),
    "xboardLoadingFailed": MessageLookupByLibrary.simpleMessage("불러오는 중 실패"),
    "xboardLoadingPaymentPage": MessageLookupByLibrary.simpleMessage(
      "불러오는 중 결제 page",
    ),
    "xboardLocalIP": MessageLookupByLibrary.simpleMessage("로컬 IP"),
    "xboardLoggedIn": MessageLookupByLibrary.simpleMessage("logged IN"),
    "xboardLogin": MessageLookupByLibrary.simpleMessage("로그인"),
    "xboardLoginExpired": MessageLookupByLibrary.simpleMessage("로그인 만료됨"),
    "xboardLoginFailed": MessageLookupByLibrary.simpleMessage("로그인 실패"),
    "xboardLoginSuccess": MessageLookupByLibrary.simpleMessage("로그인 성공"),
    "xboardLoginToViewSubscription": MessageLookupByLibrary.simpleMessage(
      "로그인 TO 보기 구독",
    ),
    "xboardLogout": MessageLookupByLibrary.simpleMessage("로그아웃"),
    "xboardLogoutConfirmContent": MessageLookupByLibrary.simpleMessage(
      "로그아웃 확인 내용",
    ),
    "xboardLogoutConfirmTitle": MessageLookupByLibrary.simpleMessage(
      "로그아웃 확인 제목",
    ),
    "xboardLogoutFailed": MessageLookupByLibrary.simpleMessage("로그아웃 실패"),
    "xboardLogoutSuccess": MessageLookupByLibrary.simpleMessage("로그아웃 성공"),
    "xboardLow": MessageLookupByLibrary.simpleMessage("낮음"),
    "xboardMedium": MessageLookupByLibrary.simpleMessage("중간"),
    "xboardMine": MessageLookupByLibrary.simpleMessage("내 정보"),
    "xboardMissingRequiredField": MessageLookupByLibrary.simpleMessage(
      "missing 필수 field",
    ),
    "xboardMonthlyPayment": MessageLookupByLibrary.simpleMessage("월간 결제"),
    "xboardMonthlyRenewal": MessageLookupByLibrary.simpleMessage("월간 renewal"),
    "xboardMustUpdate": MessageLookupByLibrary.simpleMessage("must 업데이트"),
    "xboardMyServices": MessageLookupByLibrary.simpleMessage("MY services"),
    "xboardMyTickets": MessageLookupByLibrary.simpleMessage("MY 티켓"),
    "xboardMyWallet": MessageLookupByLibrary.simpleMessage("MY 지갑"),
    "xboardNetworkConnectionFailed": MessageLookupByLibrary.simpleMessage(
      "네트워크 connection 실패",
    ),
    "xboardNewVersionFound": MessageLookupByLibrary.simpleMessage("새 버전 found"),
    "xboardNext": MessageLookupByLibrary.simpleMessage("next"),
    "xboardNoAvailableNodes": MessageLookupByLibrary.simpleMessage(
      "없음 사용 가능 노드",
    ),
    "xboardNoAvailablePlan": MessageLookupByLibrary.simpleMessage(
      "없음 사용 가능 요금제",
    ),
    "xboardNoAvailableSubscription": MessageLookupByLibrary.simpleMessage(
      "없음 사용 가능 구독",
    ),
    "xboardNoInternetConnection": MessageLookupByLibrary.simpleMessage(
      "없음 internet connection",
    ),
    "xboardNoOrderRecords": MessageLookupByLibrary.simpleMessage("없음 주문 기록"),
    "xboardNoPaymentMethods": MessageLookupByLibrary.simpleMessage("없음 결제 방식"),
    "xboardNoSubscriptionInfo": MessageLookupByLibrary.simpleMessage(
      "없음 구독 정보",
    ),
    "xboardNoSubscriptionPlans": MessageLookupByLibrary.simpleMessage(
      "없음 구독 요금제",
    ),
    "xboardNoTicketRecords": MessageLookupByLibrary.simpleMessage("없음 티켓 기록"),
    "xboardNoTrafficRecords": MessageLookupByLibrary.simpleMessage("없음 트래픽 기록"),
    "xboardNodeName": MessageLookupByLibrary.simpleMessage("노드 이름"),
    "xboardNodeSelection": MessageLookupByLibrary.simpleMessage("노드 선택"),
    "xboardNone": MessageLookupByLibrary.simpleMessage("없음"),
    "xboardNormal": MessageLookupByLibrary.simpleMessage("정상"),
    "xboardNotLoggedIn": MessageLookupByLibrary.simpleMessage("NOT logged IN"),
    "xboardOneTimePayment": MessageLookupByLibrary.simpleMessage("ONE time 결제"),
    "xboardOpenPaymentFailed": MessageLookupByLibrary.simpleMessage("열기 결제 실패"),
    "xboardOpenPaymentLinkFailed": MessageLookupByLibrary.simpleMessage(
      "열기 결제 링크 실패",
    ),
    "xboardOperationFailed": MessageLookupByLibrary.simpleMessage(
      "operation 실패",
    ),
    "xboardOperationTips": MessageLookupByLibrary.simpleMessage("operation 안내"),
    "xboardOrderAmount": MessageLookupByLibrary.simpleMessage("주문 금액"),
    "xboardOrderCreationFailed": MessageLookupByLibrary.simpleMessage(
      "주문 creation 실패",
    ),
    "xboardOrderInfo": MessageLookupByLibrary.simpleMessage("주문 정보"),
    "xboardOrderLoadingFailed": MessageLookupByLibrary.simpleMessage(
      "주문 불러오는 중 실패",
    ),
    "xboardOrderNotFound": MessageLookupByLibrary.simpleMessage("주문 NOT found"),
    "xboardOrderNumber": MessageLookupByLibrary.simpleMessage("주문 number"),
    "xboardOrderRecords": MessageLookupByLibrary.simpleMessage("주문 기록"),
    "xboardOrderStatus": MessageLookupByLibrary.simpleMessage("주문 상태"),
    "xboardOrderStatusCancelled": MessageLookupByLibrary.simpleMessage(
      "주문 상태 cancelled",
    ),
    "xboardOrderStatusCompleted": MessageLookupByLibrary.simpleMessage(
      "주문 상태 completed",
    ),
    "xboardOrderStatusOffset": MessageLookupByLibrary.simpleMessage(
      "주문 상태 offset",
    ),
    "xboardOrderStatusOpening": MessageLookupByLibrary.simpleMessage(
      "주문 상태 opening",
    ),
    "xboardOrderStatusPending": MessageLookupByLibrary.simpleMessage(
      "주문 상태 pending",
    ),
    "xboardOriginalPrice": MessageLookupByLibrary.simpleMessage("original 가격"),
    "xboardPackageAmount": MessageLookupByLibrary.simpleMessage("package 금액"),
    "xboardPassword": MessageLookupByLibrary.simpleMessage("비밀번호"),
    "xboardPayNow": MessageLookupByLibrary.simpleMessage("결제 NOW"),
    "xboardPayableAmount": MessageLookupByLibrary.simpleMessage("payable 금액"),
    "xboardPaymentCancelled": MessageLookupByLibrary.simpleMessage(
      "결제 cancelled",
    ),
    "xboardPaymentComplete": MessageLookupByLibrary.simpleMessage(
      "결제 complete",
    ),
    "xboardPaymentCompleted": MessageLookupByLibrary.simpleMessage(
      "결제 completed",
    ),
    "xboardPaymentFailed": MessageLookupByLibrary.simpleMessage("결제 실패"),
    "xboardPaymentGateway": MessageLookupByLibrary.simpleMessage("결제 gateway"),
    "xboardPaymentInfo": MessageLookupByLibrary.simpleMessage("결제 정보"),
    "xboardPaymentInstructions1": MessageLookupByLibrary.simpleMessage(
      "결제 instructions 1",
    ),
    "xboardPaymentInstructions2": MessageLookupByLibrary.simpleMessage(
      "결제 instructions 2",
    ),
    "xboardPaymentInstructions3": MessageLookupByLibrary.simpleMessage(
      "결제 instructions 3",
    ),
    "xboardPaymentLink": MessageLookupByLibrary.simpleMessage("결제 링크"),
    "xboardPaymentLinkCopied": MessageLookupByLibrary.simpleMessage(
      "결제 링크 복사됨",
    ),
    "xboardPaymentMethodVerified": MessageLookupByLibrary.simpleMessage(
      "결제 방식 verified",
    ),
    "xboardPaymentMethodVerifiedPreparing":
        MessageLookupByLibrary.simpleMessage("결제 방식 verified preparing"),
    "xboardPaymentMethods": MessageLookupByLibrary.simpleMessage("결제 방식"),
    "xboardPaymentPageAutoOpened": MessageLookupByLibrary.simpleMessage(
      "결제 page 자동 opened",
    ),
    "xboardPaymentPageOpenedCompleteAndReturn":
        MessageLookupByLibrary.simpleMessage(
          "결제 page opened complete AND return",
        ),
    "xboardPaymentPageOpenedInBrowser": MessageLookupByLibrary.simpleMessage(
      "결제 page opened IN 브라우저",
    ),
    "xboardPaymentSuccess": MessageLookupByLibrary.simpleMessage("결제 성공"),
    "xboardPaymentSuccessful": MessageLookupByLibrary.simpleMessage("결제 성공"),
    "xboardPeriod": MessageLookupByLibrary.simpleMessage("기간"),
    "xboardPlanBased": MessageLookupByLibrary.simpleMessage("요금제 based"),
    "xboardPlanExpiryReminder": MessageLookupByLibrary.simpleMessage(
      "요금제 expiry reminder",
    ),
    "xboardPlanInfo": MessageLookupByLibrary.simpleMessage("요금제 정보"),
    "xboardPlanName": MessageLookupByLibrary.simpleMessage("요금제 이름"),
    "xboardPlanNotFound": MessageLookupByLibrary.simpleMessage("요금제 NOT found"),
    "xboardPlans": MessageLookupByLibrary.simpleMessage("요금제"),
    "xboardPleaseEnterGiftCardCode": MessageLookupByLibrary.simpleMessage(
      "please enter 기프트 카드 코드",
    ),
    "xboardPleaseSelectPaymentPeriod": MessageLookupByLibrary.simpleMessage(
      "please 선택 결제 기간",
    ),
    "xboardPleaseWait": MessageLookupByLibrary.simpleMessage("please wait"),
    "xboardPoor": MessageLookupByLibrary.simpleMessage("나쁨"),
    "xboardPreparingImport": MessageLookupByLibrary.simpleMessage(
      "preparing 가져오기",
    ),
    "xboardPreparingPaymentPage": MessageLookupByLibrary.simpleMessage(
      "preparing 결제 page",
    ),
    "xboardPrevious": MessageLookupByLibrary.simpleMessage("previous"),
    "xboardPriority": MessageLookupByLibrary.simpleMessage("priority"),
    "xboardProcessing": MessageLookupByLibrary.simpleMessage("processing"),
    "xboardProductInfo": MessageLookupByLibrary.simpleMessage("product 정보"),
    "xboardProfessionalSupport": MessageLookupByLibrary.simpleMessage("전문 지원"),
    "xboardProfile": MessageLookupByLibrary.simpleMessage("프로필"),
    "xboardProtectNetworkPrivacy": MessageLookupByLibrary.simpleMessage(
      "protect 네트워크 개인정보",
    ),
    "xboardProxy": MessageLookupByLibrary.simpleMessage("프록시"),
    "xboardProxyMode": MessageLookupByLibrary.simpleMessage("프록시 모드"),
    "xboardProxyModeDirectDescription": MessageLookupByLibrary.simpleMessage(
      "프록시 모드 직접 연결 설명",
    ),
    "xboardProxyModeGlobalDescription": MessageLookupByLibrary.simpleMessage(
      "프록시 모드 전역 설명",
    ),
    "xboardProxyModeRuleDescription": MessageLookupByLibrary.simpleMessage(
      "프록시 모드 규칙 설명",
    ),
    "xboardPurchasePlan": MessageLookupByLibrary.simpleMessage("구매 요금제"),
    "xboardPurchaseSubscription": MessageLookupByLibrary.simpleMessage("구매 구독"),
    "xboardPurchaseSubscriptionToUse": MessageLookupByLibrary.simpleMessage(
      "구매 구독 TO USE",
    ),
    "xboardPurchaseTraffic": MessageLookupByLibrary.simpleMessage("구매 트래픽"),
    "xboardQuarterlyPayment": MessageLookupByLibrary.simpleMessage(
      "quarterly 결제",
    ),
    "xboardRecharge": MessageLookupByLibrary.simpleMessage("충전"),
    "xboardRechargeBalance": MessageLookupByLibrary.simpleMessage("충전 잔액"),
    "xboardRechargeBalanceTip": MessageLookupByLibrary.simpleMessage(
      "충전 잔액 안내",
    ),
    "xboardRechargeNow": MessageLookupByLibrary.simpleMessage("충전 NOW"),
    "xboardRedeemFailed": MessageLookupByLibrary.simpleMessage("redeem 실패"),
    "xboardRedeemFailedWithError": m40,
    "xboardRedeemNow": MessageLookupByLibrary.simpleMessage("redeem NOW"),
    "xboardRedeemSuccess": MessageLookupByLibrary.simpleMessage("redeem 성공"),
    "xboardRefresh": MessageLookupByLibrary.simpleMessage("새로고침"),
    "xboardRefreshStatus": MessageLookupByLibrary.simpleMessage("새로고침 상태"),
    "xboardRefundAmount": MessageLookupByLibrary.simpleMessage("환불 금액"),
    "xboardRegister": MessageLookupByLibrary.simpleMessage("가입"),
    "xboardRegisterFailed": MessageLookupByLibrary.simpleMessage("가입 실패"),
    "xboardRegisterSuccess": MessageLookupByLibrary.simpleMessage("가입 성공"),
    "xboardReload": MessageLookupByLibrary.simpleMessage("다시 불러오기"),
    "xboardRelogin": MessageLookupByLibrary.simpleMessage("relogin"),
    "xboardRemainingBalance": MessageLookupByLibrary.simpleMessage("남음 잔액"),
    "xboardRememberPassword": MessageLookupByLibrary.simpleMessage(
      "remember 비밀번호",
    ),
    "xboardRenewPlan": MessageLookupByLibrary.simpleMessage("renew 요금제"),
    "xboardRenewToContinue": MessageLookupByLibrary.simpleMessage(
      "renew TO continue",
    ),
    "xboardReopen": MessageLookupByLibrary.simpleMessage("reopen"),
    "xboardReopenPayment": MessageLookupByLibrary.simpleMessage("reopen 결제"),
    "xboardReopenPaymentPageTip": MessageLookupByLibrary.simpleMessage(
      "reopen 결제 page 안내",
    ),
    "xboardResetCurrentPlanTraffic": MessageLookupByLibrary.simpleMessage(
      "초기화 현재 요금제 트래픽",
    ),
    "xboardResetTraffic": MessageLookupByLibrary.simpleMessage("초기화 트래픽"),
    "xboardResetTrafficByPlanCycle": MessageLookupByLibrary.simpleMessage(
      "초기화 트래픽 BY 요금제 cycle",
    ),
    "xboardResetTrafficConfirmContent": MessageLookupByLibrary.simpleMessage(
      "초기화 트래픽 확인 내용",
    ),
    "xboardResetTrafficInDays": m41,
    "xboardRetry": MessageLookupByLibrary.simpleMessage("재시도"),
    "xboardRetryGet": MessageLookupByLibrary.simpleMessage("재시도 GET"),
    "xboardReturn": MessageLookupByLibrary.simpleMessage("return"),
    "xboardReturnAfterPaymentAutoDetect": MessageLookupByLibrary.simpleMessage(
      "return after 결제 자동 detect",
    ),
    "xboardRunningTime": m42,
    "xboardSecureEncryption": MessageLookupByLibrary.simpleMessage(
      "secure encryption",
    ),
    "xboardSelectPaymentMethod": MessageLookupByLibrary.simpleMessage(
      "선택 결제 방식",
    ),
    "xboardSelectPaymentPeriod": MessageLookupByLibrary.simpleMessage(
      "선택 결제 기간",
    ),
    "xboardSelectPeriod": MessageLookupByLibrary.simpleMessage("선택 기간"),
    "xboardSelectRechargeAmount": MessageLookupByLibrary.simpleMessage(
      "선택 충전 금액",
    ),
    "xboardSendVerificationCode": MessageLookupByLibrary.simpleMessage(
      "보내기 인증 코드",
    ),
    "xboardServerError": MessageLookupByLibrary.simpleMessage("서버 오류"),
    "xboardSetup": MessageLookupByLibrary.simpleMessage("setup"),
    "xboardSixMonthCycle": MessageLookupByLibrary.simpleMessage("SIX 월 cycle"),
    "xboardSmartRouting": MessageLookupByLibrary.simpleMessage("smart routing"),
    "xboardSoftwareSettings": MessageLookupByLibrary.simpleMessage(
      "software 설정",
    ),
    "xboardSpeedLimit": MessageLookupByLibrary.simpleMessage("속도 한도"),
    "xboardStartProxy": MessageLookupByLibrary.simpleMessage("시작 프록시"),
    "xboardStop": MessageLookupByLibrary.simpleMessage("중지"),
    "xboardStopProxy": MessageLookupByLibrary.simpleMessage("중지 프록시"),
    "xboardSubmitTicket": MessageLookupByLibrary.simpleMessage("submit 티켓"),
    "xboardSubmitting": MessageLookupByLibrary.simpleMessage("submitting"),
    "xboardSubscription": MessageLookupByLibrary.simpleMessage("구독"),
    "xboardSubscriptionCopied": MessageLookupByLibrary.simpleMessage("구독 복사됨"),
    "xboardSubscriptionExpired": MessageLookupByLibrary.simpleMessage("구독 만료됨"),
    "xboardSubscriptionHasExpired": MessageLookupByLibrary.simpleMessage(
      "구독 HAS 만료됨",
    ),
    "xboardSubscriptionInfo": MessageLookupByLibrary.simpleMessage("구독 정보"),
    "xboardSubscriptionLink": MessageLookupByLibrary.simpleMessage("구독 링크"),
    "xboardSubscriptionLinkCopied": MessageLookupByLibrary.simpleMessage(
      "구독 링크 복사됨",
    ),
    "xboardSubscriptionPurchase": MessageLookupByLibrary.simpleMessage("구독 구매"),
    "xboardSubscriptionStatus": MessageLookupByLibrary.simpleMessage("구독 상태"),
    "xboardSurplusAmount": MessageLookupByLibrary.simpleMessage("이전 요금제 차감 금액"),
    "xboardSwitch": MessageLookupByLibrary.simpleMessage("switch"),
    "xboardTestLatency": MessageLookupByLibrary.simpleMessage("지연 시간 테스트"),
    "xboardTesting": MessageLookupByLibrary.simpleMessage("테스트 중"),
    "xboardThirtySixMonthCycle": MessageLookupByLibrary.simpleMessage(
      "thirty SIX 월 cycle",
    ),
    "xboardThreeMonthCycle": MessageLookupByLibrary.simpleMessage(
      "three 월 cycle",
    ),
    "xboardThreeYearPayment": MessageLookupByLibrary.simpleMessage(
      "three 년 결제",
    ),
    "xboardTicketClosed": MessageLookupByLibrary.simpleMessage("티켓 closed"),
    "xboardTicketDescription": MessageLookupByLibrary.simpleMessage("티켓 설명"),
    "xboardTicketDescriptionHint": MessageLookupByLibrary.simpleMessage(
      "티켓 설명 힌트",
    ),
    "xboardTicketPendingReply": MessageLookupByLibrary.simpleMessage(
      "티켓 pending reply",
    ),
    "xboardTicketReplied": MessageLookupByLibrary.simpleMessage("티켓 replied"),
    "xboardTicketTitle": MessageLookupByLibrary.simpleMessage("티켓 제목"),
    "xboardTicketTitleHint": MessageLookupByLibrary.simpleMessage("티켓 제목 힌트"),
    "xboardTimeout": MessageLookupByLibrary.simpleMessage("시간 초과"),
    "xboardTokenExpiredContent": MessageLookupByLibrary.simpleMessage(
      "토큰 만료됨 내용",
    ),
    "xboardTokenExpiredTitle": MessageLookupByLibrary.simpleMessage(
      "토큰 만료됨 제목",
    ),
    "xboardToolsSettings": MessageLookupByLibrary.simpleMessage("도구 설정"),
    "xboardTotal": MessageLookupByLibrary.simpleMessage("전체"),
    "xboardTotalTraffic": MessageLookupByLibrary.simpleMessage("총계"),
    "xboardTraffic": MessageLookupByLibrary.simpleMessage("트래픽"),
    "xboardTrafficDetails": MessageLookupByLibrary.simpleMessage("트래픽 상세"),
    "xboardTrafficExhausted": MessageLookupByLibrary.simpleMessage(
      "트래픽 exhausted",
    ),
    "xboardTrafficExhaustedRenewConfirmContent":
        MessageLookupByLibrary.simpleMessage(
          "요금제를 갱신해도 트래픽은 즉시 초기화되지 않습니다. 바로 사용하려면 트래픽을 초기화하거나 요금제를 변경하세요. 계속하시겠습니까?",
        ),
    "xboardTrafficLogHint": MessageLookupByLibrary.simpleMessage(
      "최근 한 달간의 트래픽만 표시됩니다",
    ),
    "xboardTrafficReminder": MessageLookupByLibrary.simpleMessage(
      "트래픽 reminder",
    ),
    "xboardTrafficUsedUp": MessageLookupByLibrary.simpleMessage("트래픽 사용됨 UP"),
    "xboardTunEnabled": MessageLookupByLibrary.simpleMessage("TUN 활성화됨"),
    "xboardTwelveMonthCycle": MessageLookupByLibrary.simpleMessage(
      "twelve 월 cycle",
    ),
    "xboardTwentyFourMonthCycle": MessageLookupByLibrary.simpleMessage(
      "twenty four 월 cycle",
    ),
    "xboardTwoYearPayment": MessageLookupByLibrary.simpleMessage("TWO 년 결제"),
    "xboardUnauthorizedAccess": MessageLookupByLibrary.simpleMessage(
      "unauthorized access",
    ),
    "xboardUnknownErrorRetry": MessageLookupByLibrary.simpleMessage(
      "알 수 없음 오류 재시도",
    ),
    "xboardUnknownPeriod": MessageLookupByLibrary.simpleMessage("알 수 없음 기간"),
    "xboardUnknownPlan": MessageLookupByLibrary.simpleMessage("알 수 없음 요금제"),
    "xboardUnknownUser": MessageLookupByLibrary.simpleMessage("알 수 없음 사용자"),
    "xboardUnlimited": MessageLookupByLibrary.simpleMessage("무제한"),
    "xboardUnlimitedSpeed": MessageLookupByLibrary.simpleMessage("무제한 속도"),
    "xboardUnselected": MessageLookupByLibrary.simpleMessage("unselected"),
    "xboardUnsupportedCouponType": MessageLookupByLibrary.simpleMessage(
      "지원하지 않는 쿠폰 유형",
    ),
    "xboardUpdateContent": MessageLookupByLibrary.simpleMessage("업데이트 내용"),
    "xboardUpdateLater": MessageLookupByLibrary.simpleMessage("업데이트 later"),
    "xboardUpdateNodes": MessageLookupByLibrary.simpleMessage("업데이트 노드"),
    "xboardUpdateNow": MessageLookupByLibrary.simpleMessage("업데이트 NOW"),
    "xboardUpdateSubscriptionRegularly": MessageLookupByLibrary.simpleMessage(
      "업데이트 구독 regularly",
    ),
    "xboardUploadImage": MessageLookupByLibrary.simpleMessage("업로드 이미지"),
    "xboardUsageInstructions": MessageLookupByLibrary.simpleMessage(
      "사용량 instructions",
    ),
    "xboardUseBalance": MessageLookupByLibrary.simpleMessage("USE 잔액"),
    "xboardUsed": MessageLookupByLibrary.simpleMessage("사용됨"),
    "xboardUsedTraffic": MessageLookupByLibrary.simpleMessage("사용됨 트래픽"),
    "xboardValidatingConfigFormat": MessageLookupByLibrary.simpleMessage(
      "validating 설정 format",
    ),
    "xboardValidationFailed": MessageLookupByLibrary.simpleMessage(
      "validation 실패",
    ),
    "xboardValidityPeriod": MessageLookupByLibrary.simpleMessage("validity 기간"),
    "xboardVerify": MessageLookupByLibrary.simpleMessage("인증"),
    "xboardVeryPoor": MessageLookupByLibrary.simpleMessage("매우 나쁨"),
    "xboardWaitingForPayment": MessageLookupByLibrary.simpleMessage(
      "waiting FOR 결제",
    ),
    "xboardWaitingPaymentCompletion": MessageLookupByLibrary.simpleMessage(
      "waiting 결제 completion",
    ),
    "xboardYearlyPayment": MessageLookupByLibrary.simpleMessage("연간 결제"),
    "years": MessageLookupByLibrary.simpleMessage("years"),
    "zh_CN": MessageLookupByLibrary.simpleMessage("중국어 간체"),
  };
}
