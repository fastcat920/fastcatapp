import 'package:fl_clash/xboard/domain/domain.dart';

const _unset = Object();

/// 通用UI状态
class UIState {
  final bool isLoading;
  final String? errorMessage;
  final DateTime? lastUpdated;

  const UIState({
    this.isLoading = false,
    this.errorMessage,
    this.lastUpdated,
  });

  UIState copyWith({
    bool? isLoading,
    Object? errorMessage = _unset,
    Object? lastUpdated = _unset,
  }) {
    return UIState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      lastUpdated: identical(lastUpdated, _unset)
          ? this.lastUpdated
          : lastUpdated as DateTime?,
    );
  }

  UIState clearError() {
    return copyWith(errorMessage: null);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UIState &&
        other.isLoading == isLoading &&
        other.errorMessage == errorMessage &&
        other.lastUpdated == lastUpdated;
  }

  @override
  int get hashCode {
    return isLoading.hashCode ^ errorMessage.hashCode ^ lastUpdated.hashCode;
  }
}

/// 用户认证状态
class UserAuthState {
  final bool isAuthenticated;
  final bool isInitialized;
  final String? email;
  final bool isLoading;
  final String? errorMessage;
  final DomainUser? userInfo;
  final DomainSubscription? subscriptionInfo;

  const UserAuthState({
    this.isAuthenticated = false,
    this.isInitialized = false,
    this.email,
    this.isLoading = false,
    this.errorMessage,
    this.userInfo,
    this.subscriptionInfo,
  });

  UserAuthState copyWith({
    bool? isAuthenticated,
    bool? isInitialized,
    Object? email = _unset,
    bool? isLoading,
    Object? errorMessage = _unset,
    Object? userInfo = _unset,
    Object? subscriptionInfo = _unset,
  }) {
    return UserAuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isInitialized: isInitialized ?? this.isInitialized,
      email: identical(email, _unset) ? this.email : email as String?,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      userInfo:
          identical(userInfo, _unset) ? this.userInfo : userInfo as DomainUser?,
      subscriptionInfo: identical(subscriptionInfo, _unset)
          ? this.subscriptionInfo
          : subscriptionInfo as DomainSubscription?,
    );
  }

  UserAuthState clearError() {
    return copyWith(errorMessage: null);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserAuthState &&
        other.isAuthenticated == isAuthenticated &&
        other.isInitialized == isInitialized &&
        other.email == email &&
        other.isLoading == isLoading &&
        other.errorMessage == errorMessage &&
        other.userInfo == userInfo &&
        other.subscriptionInfo == subscriptionInfo;
  }

  @override
  int get hashCode {
    return isAuthenticated.hashCode ^
        isInitialized.hashCode ^
        email.hashCode ^
        isLoading.hashCode ^
        errorMessage.hashCode ^
        userInfo.hashCode ^
        subscriptionInfo.hashCode;
  }
}
