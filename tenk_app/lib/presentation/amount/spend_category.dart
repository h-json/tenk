import 'package:flutter/material.dart';

/// 지출 카테고리 (고정 9종). 백엔드 `SpendCategory` enum 과 코드가 1:1 매칭된다.
///
/// 전송·저장은 안정적인 [code](예: `FOOD`), 표시는 [label](식비)·[icon]. 아이콘은 Material 벡터
/// (`IconData`) 라 색이 박혀있지 않고 렌더 시점에 테마 색으로 칠해진다 — 나중에 챌린지별 색을
/// 부여해도 자유롭게 대응된다. 여기가 code→label/icon 매핑의 진실의 원천.
@immutable
class SpendCategory {
  const SpendCategory({
    required this.code,
    required this.label,
    required this.icon,
  });

  final String code;
  final String label;
  final IconData icon;
}

/// 표시 순서 = 목록 순서. 백엔드 enum 선언 순서와 맞춰둔다.
const List<SpendCategory> kSpendCategories = [
  SpendCategory(code: 'FOOD', label: '식비', icon: Icons.restaurant),
  SpendCategory(code: 'TRANSPORT', label: '교통비', icon: Icons.directions_bus),
  SpendCategory(code: 'SHOPPING', label: '쇼핑', icon: Icons.shopping_bag),
  SpendCategory(code: 'LEISURE', label: '여가', icon: Icons.local_activity),
  SpendCategory(code: 'HEALTH', label: '건강', icon: Icons.health_and_safety),
  SpendCategory(code: 'EDUCATION', label: '교육', icon: Icons.school),
  SpendCategory(code: 'EVENT', label: '경조사', icon: Icons.card_giftcard),
  SpendCategory(code: 'LIVING', label: '생활비', icon: Icons.home),
  SpendCategory(code: 'ETC', label: '기타', icon: Icons.more_horiz),
];

/// 미매칭(옛 자유 텍스트·null)일 때의 폴백 — 기타.
const SpendCategory _fallbackCategory = SpendCategory(
  code: 'ETC',
  label: '기타',
  icon: Icons.more_horiz,
);

/// 코드로 카테고리를 찾는다. 9종에 없으면 [_fallbackCategory](기타) 로 폴백해
/// 화면이 깨지지 않게 한다 (검증 도입 이전에 저장된 자유 텍스트 대응).
SpendCategory spendCategoryForCode(String? code) {
  for (final category in kSpendCategories) {
    if (category.code == code) return category;
  }
  return _fallbackCategory;
}
