import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/scopes.dart';
import '../../../data/amount/amount.dart';
import '../../../data/challenge/challenge.dart';
import '../../../data/export/result_card_capture.dart';
import '../../../design/tokens.dart';
import 'result_card_painters.dart';
import 'result_card_widget.dart';

/// 챌린지 결과 카드 풀스크린 화면. finalize 직후 자동 푸시 + 챌린지 상세의 진입 카드 양쪽에서 들어온다.
///
/// 화면에선 [FittedBox] 로 480x864 카드를 디바이스 비율에 맞춰 표시. 갤러리 저장/공유는 같은 카드를
/// [ResultCardCapture] 로 캡처해 PNG 로 저장. 같은 화면 안에서 두 번째 호출은 캐시 재사용.
class ResultCardScreen extends StatefulWidget {
  const ResultCardScreen({
    super.key,
    required this.challenge,
    required this.amounts,
    this.celebrate = false,
  });

  final Challenge challenge;
  final List<Amount> amounts;

  /// 진입 순간 컨페티를 터뜨릴지. **확정 직후 자동 진입일 때만 true** — 상세에서 다시
  /// 열어볼 때마다 터지면 축하가 아니라 지연으로 느껴진다. 성공한 챌린지에만 적용된다.
  final bool celebrate;

  @override
  State<ResultCardScreen> createState() => _ResultCardScreenState();
}

class _ResultCardScreenState extends State<ResultCardScreen> {
  /// 닉네임 fetch 완료 시 채워짐. fetch 전엔 null → 카드 헤더에 닉네임 없이 표시.
  String? _nickname;

  /// 저장/공유 시 await 하기 위한 future — fetch 가 늦으면 그때까지 기다린 뒤 캡처.
  Future<String?>? _nicknameFuture;

  /// 캡처된 PNG 파일 경로. 같은 세션 내 첫 호출 때만 캡처, 이후 재사용.
  String? _capturedPngPath;

  bool _saving = false;
  bool _sharing = false;
  bool _savedToGallery = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchNickname());
  }

  Future<void> _fetchNickname() async {
    if (!mounted) return;
    final api = UserScope.of(context);
    final future = () async {
      try {
        final user = await api.getMe();
        return user.nickname;
      } catch (_) {
        // 닉네임이 못 와도 카드 표시/저장은 진행. 헤더만 "만원 챌린지" 로.
        return null;
      }
    }();
    _nicknameFuture = future;
    final value = await future;
    if (!mounted) return;
    setState(() => _nickname = value);
  }

  /// 캡처 PNG 를 만든다 (없으면). 동시 호출 시 같은 future 를 재사용하지 않고 있지만 _saving/_sharing
  /// guard 로 동시 트리거가 막혀 있어 race 우려 없음.
  Future<String> _ensureCaptured() async {
    if (_capturedPngPath != null) return _capturedPngPath!;
    // 닉네임 fetch 가 아직이면 잠깐 기다림 — 보통 즉시 끝남.
    if (_nicknameFuture != null && _nickname == null) {
      await _nicknameFuture;
    }
    if (!mounted) {
      throw StateError('Result card screen unmounted before capture');
    }
    final tmp = await getTemporaryDirectory();
    if (!mounted) {
      throw StateError('Result card screen unmounted before capture');
    }
    final path =
        '${tmp.path}/tenk_result_card/${widget.challenge.id}.png';
    await ResultCardCapture.captureToFile(
      context: context,
      challenge: widget.challenge,
      amounts: widget.amounts,
      nickname: _nickname,
      outputPath: path,
      pixelRatio: 2.0,
    );
    _capturedPngPath = path;
    return path;
  }

  Future<void> _saveToGallery() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final path = await _ensureCaptured();
      final hasAccess = await Gal.hasAccess(toAlbum: false);
      if (!hasAccess) {
        final granted = await Gal.requestAccess(toAlbum: false);
        if (!granted) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('갤러리 접근 권한이 거부됐어요. 설정에서 사진 접근을 허용해주세요.'),
            ),
          );
          return;
        }
      }
      // 앨범명만 'Tenk' 로 남긴다 (표기는 TenK 로 통일됐지만) — 바꾸면 이전에 저장한 결과물과
      // 새 결과물이 서로 다른 앨범으로 갈라진다. 표기 통일보다 사용자 자산의 연속성이 우선.
      await Gal.putImage(path, album: 'Tenk');
      if (!mounted) return;
      setState(() => _savedToGallery = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('갤러리에 저장됐어요.')),
      );
    } on GalException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_galErrorMessage(e))),
      );
    } catch (_) {
      if (!mounted) return;
      // 예외 원문(영문)을 그대로 띄우지 말 것 — 원인을 아는 실패는 위 GalException 분기가 이미 처리했다.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('갤러리에 저장하지 못했어요. 잠시 후 다시 시도해 주세요.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final path = await _ensureCaptured();
      final params = ShareParams(
        files: [XFile(path, mimeType: 'image/png')],
        text: '만원 챌린지 결과',
      );
      await SharePlus.instance.share(params);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('공유하지 못했어요. 잠시 후 다시 시도해 주세요.')),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  static String _galErrorMessage(GalException e) {
    return switch (e.type) {
      GalExceptionType.accessDenied =>
        '갤러리 접근 권한이 거부됐어요. 설정에서 사진 접근을 허용해주세요.',
      GalExceptionType.notEnoughSpace => '저장 공간이 부족해요.',
      GalExceptionType.notSupportedFormat => '지원하지 않는 이미지 형식이에요.',
      GalExceptionType.unexpected => '알 수 없는 오류가 발생했어요.',
    };
  }

  @override
  Widget build(BuildContext context) {
    // **풀블리드**: AppBar 를 두지 않고 카드를 화면 폭에 꽉 맞춘다. 카드 하단이 화이트라
    // 아래 남는 여백(액션 버튼 자리)과 이어져 경계가 안 보이고, 상단 컬러 블록이 화면 위를
    // 그대로 채운다. 카드 테두리·라운드도 없앴다 — 공유 이미지는 full-bleed 여야 하고,
    // 화면에서도 액자처럼 보이면 카드가 작아 보인다.
    //
    // ⚠️ 이 "꽉 맞춘다" 를 지키는 장치가 **두 겹**이다 (2026-08-17, #29 — 실기기에서 두 번
    // 재발한 자리다). 하나라도 빼면 양옆에 흰 여백이 돌아온다:
    //   ① 액션 Row 를 Column 에서 빼 **카드 위에 띄운다** → 카드가 상태바 아래 전부를 쓴다.
    //      Column 자식으로 두면 그 76dp 만큼 가용 높이가 줄어 임계선(폭 × 1.8)을 넘나든다.
    //   ② [BoxFit.fitWidth] → 폭을 **무조건** 채운다. `BoxFit.contain` 은 폭·높이 중 빡빡한
    //      쪽에 맞추므로, 가용 높이가 `화면 폭 × 1.8`(카드 비율 480:864) 밑으로 내려가는
    //      순간 높이 기준으로 축소되고 그 차이가 그대로 좌우 여백이 된다.
    // 세로가 모자라면 카드 **아래**(흰 영역·워터마크)가 잘린다 — 좌우가 비는 것보다 낫고,
    // ① 덕분에 잘리는 양이 애초에 작다. 캡처물은 오프스크린 480x864 고정이라 무관하다.
    final celebrating = widget.celebrate &&
        widget.challenge.result == ChallengeResult.success;
    final isSuccess = widget.challenge.result == ChallengeResult.success;
    // 상태바 뒤를 카드 상단 블록과 같은 색으로 덮는다. 안 그러면 카드가 상태바 밑으로
    // 파고들어 닉네임 줄이 시계와 겹친다. (카드 위젯 자체는 건드리지 않는다 — 캡처물엔
    // 상태바가 없으므로 이 띠는 화면 전용이다.)
    final blockColor =
        isSuccess ? AppColors.rewardSuccessTop : AppColors.rewardFailTop;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          Column(
            // ⚠️ **stretch 를 빼지 말 것 — 이게 없으면 ② 가 무력화된다.** Column 기본값
            // (center)이면 자식이 loose 한 폭 제약을 받는데, `RenderFittedBox` 는 그때
            // `constrainSizeAndAttemptToPreserveAspectRatio` 로 **자기 자신부터 자식 비율대로
            // 줄여버린다**(360 → 342). 그러면 `fitWidth` 는 이미 줄어든 상자를 채울 뿐이라
            // 여백이 그대로 남는다 — 실제로 이 조합으로 한 번 헛다리를 짚었다.
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: MediaQuery.paddingOf(context).top,
                color: blockColor,
              ),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.fitWidth,
                  alignment: Alignment.topCenter,
                  // 세로가 모자랄 때 카드 아래를 잘라낸다. FittedBox 기본값은 Clip.none 이라
                  // 명시하지 않으면 넘친 부분이 액션 바 위로 삐져나와 그려진다.
                  clipBehavior: Clip.hardEdge,
                  child: ResultCardWidget(
                    challenge: widget.challenge,
                    amounts: widget.amounts,
                    nickname: _nickname,
                  ),
                ),
              ),
            ],
          ),
          // 액션은 **카드 위에 얹는다** (Column 자식이 아니다 — 위 ① 참고). 카드 하단이
          // 화이트라 같은 색 바닥을 깔면 경계가 안 보이고, 화면이 짧아 카드가 이 자리까지
          // 내려오는 경우엔 이 바닥이 잘린 끝단을 덮어준다.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ColoredBox(
              color: AppColors.bg,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: _saving ? null : _saveToGallery,
                          icon: Icon(_savedToGallery
                              ? Icons.check
                              : Icons.download_outlined),
                          label: Text(
                            _saving
                                ? '저장 중…'
                                : _savedToGallery
                                    ? '저장됨'
                                    : '갤러리 저장',
                          ),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _sharing ? null : _share,
                          icon: const Icon(Icons.ios_share),
                          label: Text(_sharing ? '공유 중…' : '공유하기'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // 닫기는 카드 위에 얹는다 (AppBar 를 없앴으므로). 헤더가 가운데 정렬이라
          // **우상단**이 비어 있고, 카드 상단 패딩(62)이 이 버튼 자리를 비워둔 것이다.
          // 좌상단에 두면 긴 챌린지 이름과 겹친다.
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close),
                // 상단 블록이 진한 채움이라 아이콘은 흰색이어야 읽힌다.
                color: AppColors.rewardOnBlock,
                tooltip: '닫기',
              ),
            ),
          ),
          if (celebrating)
            // 카드 안의 정적 컨페티와 같은 색 — 화면 연출과 캡처물이 한 언어로 읽히게.
            // (화면은 캡처 대상이 아니라 토큰을 그대로 써도 된다.)
            const Positioned.fill(
              child: ResultCardConfettiOverlay(colors: AppColors.rewardConfetti),
            ),
        ],
      ),
    );
  }
}
