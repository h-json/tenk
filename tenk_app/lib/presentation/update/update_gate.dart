import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../design/tokens.dart';

/// 앱 버전 게이트 UI (강제/권장). 판정은 서버가 하고(`GET /api/app/version`), 여기서는 그 결과에
/// 따라 화면만 분기한다. SessionGate 가 부팅 시 다음처럼 배선한다:
/// - 강제(UPDATE_REQUIRED) → [ForceUpdateScreen] 으로 트리 자체를 대체 (뒤로/이탈 차단)
/// - 권장(UPDATE_AVAILABLE) → 정상 목적지를 [RecommendedUpdateHost] 로 감싸 첫 프레임에 1회 안내
///
/// 스토어 URL 은 서버가 플랫폼별로 내려준다. null 이면(예: 아직 미출시 플랫폼) 버튼 대신 안내만 노출.

/// 스토어 페이지를 외부 브라우저/스토어 앱으로 연다. url 이 없으면 SnackBar 로 안내.
Future<void> openStorePage(BuildContext context, String? url) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (url == null || url.isEmpty) {
    messenger?.showSnackBar(
      const SnackBar(content: Text('스토어 주소를 불러올 수 없어요. 스토어에서 Tenk 를 검색해 주세요.')),
    );
    return;
  }
  final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  if (!ok) {
    messenger?.showSnackBar(
      const SnackBar(content: Text('스토어를 열 수 없어요. 스토어에서 Tenk 를 검색해 주세요.')),
    );
  }
}

/// 강제 업데이트 — 앱 사용을 막고 업데이트만 유도. 뒤로/스와이프 차단 (연령·동의 게이트와 동일 원칙).
class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({super.key, required this.storeUrl});

  final String? storeUrl;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.system_update, size: 64, color: AppColors.primary),
                const SizedBox(height: AppSpacing.lg),
                Text('업데이트가 필요해요',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  '원활하고 안전한 사용을 위해 최신 버전으로 업데이트해 주세요.\n업데이트 후 다시 이용할 수 있어요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.inkSub, height: 1.5),
                ),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => openStorePage(context, storeUrl),
                    child: const Text('업데이트하기'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 권장 업데이트 — [child](정상 목적지)를 그대로 렌더하되, 첫 프레임 직후 1회 안내 다이얼로그를 띄운다.
/// '나중에' 로 닫으면 이번 실행에선 계속 사용 가능 (다음 콜드 스타트에 다시 안내).
class RecommendedUpdateHost extends StatefulWidget {
  const RecommendedUpdateHost({
    super.key,
    required this.storeUrl,
    required this.child,
  });

  final String? storeUrl;
  final Widget child;

  @override
  State<RecommendedUpdateHost> createState() => _RecommendedUpdateHostState();
}

class _RecommendedUpdateHostState extends State<RecommendedUpdateHost> {
  bool _prompted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _promptOnce());
  }

  Future<void> _promptOnce() async {
    if (_prompted || !mounted) return;
    _prompted = true;
    final update = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('새 버전이 나왔어요'),
        content: const Text('최신 버전으로 업데이트하면 더 안정적으로 이용할 수 있어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('나중에'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('업데이트'),
          ),
        ],
      ),
    );
    if (update == true && mounted) {
      await openStorePage(context, widget.storeUrl);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
