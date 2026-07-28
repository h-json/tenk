import 'package:flutter/material.dart';

import '../data/amount/amount_api.dart';
import '../data/app/app_api.dart';
import '../data/auth/auth_repository.dart';
import '../data/challenge/challenge_api.dart';
import '../data/feedback/feedback_api.dart';
import '../data/media/media_api.dart';
import '../data/user/user_api.dart';

/// 트리 어디서든 [AuthRepository]를 꺼내쓰기 위한 단순 InheritedWidget.
///
/// 도메인이 늘어나면 같은 패턴으로 `XxxScope`를 추가한다. Riverpod/Provider 도입은
/// Scope가 5개를 넘어가는 시점에 재검토 (지금은 boilerplate가 그만한 비용을 정당화하지 못함).
class AuthScope extends InheritedWidget {
  const AuthScope({
    super.key,
    required this.repository,
    required super.child,
  });

  final AuthRepository repository;

  static AuthRepository of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AuthScope>();
    assert(scope != null, 'AuthScope not found in widget tree');
    return scope!.repository;
  }

  @override
  bool updateShouldNotify(AuthScope oldWidget) =>
      repository != oldWidget.repository;
}

/// 트리 어디서든 [ChallengeApi]를 꺼내쓰기 위한 단순 InheritedWidget.
class ChallengeScope extends InheritedWidget {
  const ChallengeScope({
    super.key,
    required this.api,
    required super.child,
  });

  final ChallengeApi api;

  static ChallengeApi of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ChallengeScope>();
    assert(scope != null, 'ChallengeScope not found in widget tree');
    return scope!.api;
  }

  @override
  bool updateShouldNotify(ChallengeScope oldWidget) => api != oldWidget.api;
}

/// 트리 어디서든 [AmountApi]를 꺼내쓰기 위한 단순 InheritedWidget.
class AmountScope extends InheritedWidget {
  const AmountScope({
    super.key,
    required this.api,
    required super.child,
  });

  final AmountApi api;

  static AmountApi of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AmountScope>();
    assert(scope != null, 'AmountScope not found in widget tree');
    return scope!.api;
  }

  @override
  bool updateShouldNotify(AmountScope oldWidget) => api != oldWidget.api;
}

/// 트리 어디서든 [MediaApi]를 꺼내쓰기 위한 단순 InheritedWidget.
/// 영상 export 의 prefetch 단계에서 원본 영상 다운로드용.
class MediaScope extends InheritedWidget {
  const MediaScope({
    super.key,
    required this.api,
    required super.child,
  });

  final MediaApi api;

  static MediaApi of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<MediaScope>();
    assert(scope != null, 'MediaScope not found in widget tree');
    return scope!.api;
  }

  @override
  bool updateShouldNotify(MediaScope oldWidget) => api != oldWidget.api;
}

/// 트리 어디서든 [UserApi]를 꺼내쓰기 위한 단순 InheritedWidget.
/// 결과 카드 화면에서 닉네임 fetch 등에 사용.
class UserScope extends InheritedWidget {
  const UserScope({
    super.key,
    required this.api,
    required super.child,
  });

  final UserApi api;

  static UserApi of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<UserScope>();
    assert(scope != null, 'UserScope not found in widget tree');
    return scope!.api;
  }

  @override
  bool updateShouldNotify(UserScope oldWidget) => api != oldWidget.api;
}

/// 트리 어디서든 [AppApi](앱 버전 게이트)를 꺼내쓰기 위한 단순 InheritedWidget.
/// SessionGate(부팅 강제/권장 업데이트)와 메뉴의 '앱 버전' 항목이 사용.
///
/// ⚠️ Scope 가 5개를 넘긴 지점 — CLAUDE.md 의 "Riverpod/Provider 재검토" 임계다.
/// 아래 [FeedbackScope] 까지 7개가 됐고, 상태 관리 이관은 별도 안건으로 handoff 에 남겼다.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.api,
    required super.child,
  });

  final AppApi api;

  static AppApi of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in widget tree');
    return scope!.api;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => api != oldWidget.api;
}

/// 트리 어디서든 [FeedbackApi]를 꺼내쓰기 위한 단순 InheritedWidget.
/// 메뉴의 '의견 보내기' 화면이 사용.
class FeedbackScope extends InheritedWidget {
  const FeedbackScope({
    super.key,
    required this.api,
    required super.child,
  });

  final FeedbackApi api;

  static FeedbackApi of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<FeedbackScope>();
    assert(scope != null, 'FeedbackScope not found in widget tree');
    return scope!.api;
  }

  @override
  bool updateShouldNotify(FeedbackScope oldWidget) => api != oldWidget.api;
}

