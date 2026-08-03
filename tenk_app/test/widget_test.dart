import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tenk_app/presentation/login/login_screen.dart';

void main() {
  testWidgets('LoginScreen 렌더링 smoke test', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    // 워드마크 표기는 `TenK` 고정 (CLAUDE.md "릴리스 빌드 / 배포" — 2026-07-28 브랜드 통일).
    expect(find.text('TenK'), findsOneWidget);
    expect(find.text('카카오로 로그인'), findsOneWidget);
  });
}
