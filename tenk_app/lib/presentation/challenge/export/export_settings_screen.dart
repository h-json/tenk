import 'package:flutter/material.dart';

import '../../../data/amount/amount.dart';
import '../../../data/challenge/challenge.dart';
import '../../../data/export/video_composer.dart' show SubtitlePosition;
import 'export_compose_screen.dart';
import 'export_plan.dart';
import 'export_prefetch_screen.dart';
import 'export_result_screen.dart';

/// 영상 내보내기 2단계 — 합성 설정. 클립 선택([ExportScreen])을 마친 뒤 진입.
///
/// 자막 위치 / 자막 배경 / 결과 카드 포함만 고르는 가벼운 화면. "영상 만들기" 를 누르면 여기서
/// prefetch → compose → result 흐름을 이어받는다. 설정 상태는 화면 안에서만 산다.
class ExportSettingsScreen extends StatefulWidget {
  const ExportSettingsScreen({
    super.key,
    required this.challenge,
    required this.amounts,
    required this.items,
  });

  final Challenge challenge;

  /// 결과 카드 PNG 캡처에 쓰는 전체 통계용 (선택 해제분도 포함된 원본 목록).
  final List<Amount> amounts;

  /// 선택된 클립 + 자막 오버라이드. 합성에 들어갈 대상.
  final List<ExportPrefetchItem> items;

  @override
  State<ExportSettingsScreen> createState() => _ExportSettingsScreenState();
}

class _ExportSettingsScreenState extends State<ExportSettingsScreen> {
  SubtitlePosition _subtitlePosition = SubtitlePosition.bottom;
  bool _subtitleBackground = true;
  bool _includeResultCard = true;

  Future<void> _make() async {
    final plan = await Navigator.of(context).push<ExportPlan>(
      MaterialPageRoute<ExportPlan>(
        builder: (_) => ExportPrefetchScreen(
          challengeId: widget.challenge.id,
          items: widget.items,
        ),
      ),
    );
    if (!mounted || plan == null) return;

    final outputPath = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => ExportComposeScreen(
          challenge: widget.challenge,
          amounts: widget.amounts,
          plan: plan,
          includeResultCard: _includeResultCard,
          subtitlePosition: _subtitlePosition,
          subtitleBackground: _subtitleBackground,
        ),
      ),
    );
    if (!mounted || outputPath == null) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ExportResultScreen(videoPath: outputPath),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.items.length;

    return Scaffold(
      appBar: AppBar(title: const Text('내보내기 설정')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          children: [
            _SectionTitle('자막 위치'),
            const SizedBox(height: 8),
            SegmentedButton<SubtitlePosition>(
              segments: const [
                ButtonSegment(
                  value: SubtitlePosition.middle,
                  label: Text('중단'),
                  icon: Icon(Icons.vertical_align_center),
                ),
                ButtonSegment(
                  value: SubtitlePosition.bottom,
                  label: Text('하단'),
                  icon: Icon(Icons.vertical_align_bottom),
                ),
              ],
              selected: {_subtitlePosition},
              onSelectionChanged: (s) =>
                  setState(() => _subtitlePosition = s.first),
            ),
            const SizedBox(height: 24),
            _SettingSwitch(
              title: '자막 배경',
              subtitle: _subtitleBackground
                  ? '반투명 박스 위에 흰 글자로 표시해요.'
                  : '배경 없이 흰 글자 + 검은 외곽선으로 표시해요.',
              value: _subtitleBackground,
              onChanged: (v) => setState(() => _subtitleBackground = v),
            ),
            const Divider(height: 24),
            _SettingSwitch(
              title: '결과 카드 포함',
              subtitle: '챌린지 결과 카드를 3초 정지 화면으로 마지막에 추가해요.',
              value: _includeResultCard,
              onChanged: (v) => setState(() => _includeResultCard = v),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton(
            onPressed: _make,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: Text('영상 만들기 ($count개)'),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _SettingSwitch extends StatelessWidget {
  const _SettingSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: onChanged,
      title: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
