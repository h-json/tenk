import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/legal_config.dart';
import '../../design/tokens.dart';

/// 법적 고지 문서를 외부 브라우저로 연다. 실패 시 SnackBar 로 안내.
/// 로그인 화면 푸터·동의 화면에서 공유.
Future<void> openLegalDoc(BuildContext context, String url) async {
  final messenger = ScaffoldMessenger.of(context);
  bool ok = false;
  try {
    ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {
    ok = false;
  }
  if (!ok) {
    messenger.showSnackBar(
      const SnackBar(content: Text('문서를 여는 데 실패했어요. 잠시 후 다시 시도해주세요.')),
    );
  }
}

/// 가입 온보딩·동의 게이트에서 공유하는 필수 동의 위젯.
///
/// 이용약관 + 개인정보 수집·이용 두 **필수** 항목 + '전체 동의' 헬퍼. [보기] 는 각 문서를
/// 외부 브라우저로 연다. 두 필수 항목이 모두 체크됐는지 여부를 [onChanged] 로 부모에 알려
/// 부모가 '시작하기' 버튼 활성을 판정한다. (Tenk 은 마케팅·푸시가 없어 선택 항목은 두지 않는다.)
class ConsentSection extends StatefulWidget {
  const ConsentSection({super.key, required this.onChanged});

  /// 필수 항목이 모두 체크됐는지 여부.
  final ValueChanged<bool> onChanged;

  @override
  State<ConsentSection> createState() => _ConsentSectionState();
}

class _ConsentSectionState extends State<ConsentSection> {
  bool _terms = false;
  bool _privacy = false;

  bool get _allChecked => _terms && _privacy;

  void _notify() => widget.onChanged(_allChecked);

  void _toggleAll(bool? v) {
    final next = v ?? false;
    setState(() {
      _terms = next;
      _privacy = next;
    });
    _notify();
  }

  void _toggleTerms(bool? v) {
    setState(() => _terms = v ?? false);
    _notify();
  }

  void _togglePrivacy(bool? v) {
    setState(() => _privacy = v ?? false);
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        children: [
          // 전체 동의 (헬퍼)
          InkWell(
            onTap: () => _toggleAll(!_allChecked),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
              child: Row(
                children: [
                  Checkbox(
                    value: _allChecked,
                    onChanged: _toggleAll,
                    activeColor: AppColors.primary,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  const SizedBox(width: 4),
                  Text('전체 동의', style: AppTypo.title),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.line),
          _consentRow(
            checked: _terms,
            onChanged: _toggleTerms,
            label: '이용약관 동의',
            onView: () => openLegalDoc(context, termsUrl),
          ),
          _consentRow(
            checked: _privacy,
            onChanged: _togglePrivacy,
            label: '개인정보 수집·이용 동의',
            onView: () => openLegalDoc(context, privacyPolicyUrl),
          ),
        ],
      ),
    );
  }

  Widget _consentRow({
    required bool checked,
    required ValueChanged<bool?> onChanged,
    required String label,
    required VoidCallback onView,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 4, 0),
      child: Row(
        children: [
          Checkbox(
            value: checked,
            onChanged: onChanged,
            activeColor: AppColors.primary,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: InkWell(
              onTap: () => onChanged(!checked),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text.rich(
                  TextSpan(
                    style: AppTypo.body,
                    children: [
                      const TextSpan(
                        text: '[필수] ',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(text: label),
                    ],
                  ),
                ),
              ),
            ),
          ),
          TextButton(
            onPressed: onView,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.inkSub,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 40),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('보기', style: TextStyle(decoration: TextDecoration.underline)),
          ),
        ],
      ),
    );
  }
}
