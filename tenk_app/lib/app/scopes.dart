import 'package:flutter/material.dart';

import '../data/amount/amount_api.dart';
import '../data/auth/auth_repository.dart';
import '../data/challenge/challenge_api.dart';

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

