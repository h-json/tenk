/// 휠(드럼) 방식 시각 선택 다이얼로그. 카카오톡 예약 메시지·갤럭시 알람과 같은 형태.
///
/// **Material `showTimePicker` 는 쓰지 않는다** — 아날로그 시계(dial)가 2초 기록의
/// 분 단위를 맞추기에 불편했다. 진입점은 `date_time_picker.dart` 의 `pickTenkTime`
/// 하나이므로 화면에서 이 파일을 직접 import 하지 말 것.
///
/// 구성: 오전/오후(2항, 순환 X) · 시(1~12, **무한 순환**) · 분(00~59, **무한 순환**).
/// 가운데 시/분 숫자를 탭하면 그 열만 직접 입력으로 바뀐다.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/scopes.dart';
import '../../data/settings/app_settings.dart';
import '../../design/tokens.dart';

/// 휠 시각 선택 다이얼로그를 띄운다. 취소하면 null.
Future<TimeOfDay?> showWheelTimePicker(
  BuildContext context, {
  required TimeOfDay initial,
  String? helpText,
}) {
  return showDialog<TimeOfDay>(
    context: context,
    builder: (_) => _WheelTimePickerDialog(initial: initial, helpText: helpText),
  );
}

/// 직접 입력 중인 열.
enum _EditTarget { none, hour, minute }

const double _itemExtent = 44;
const double _wheelHeight = _itemExtent * 5;

/// **평평한 목록처럼 보이게 하는 값들.**
///
/// `ListWheelScrollView` 는 항목을 원통 표면에 배치해서 기본값이면 위아래 항목이
/// 기울고 작아지는 3D 드럼이 된다. 원통 반지름을 크게(`diameterRatio`) + 원근을
/// 거의 0 으로(`perspective`) 주면 곡률이 사라져 **모든 항목이 같은 크기**로 보인다.
/// 확대경(`useMagnifier`)·압축(`squeeze`)·축 이탈(`offAxisFraction`)도 다 끈다.
/// 3D 느낌을 원하지 않는다는 결정이므로 기본값으로 되돌리지 말 것.
const double _flatDiameterRatio = 100;
const double _flatPerspective = 0.0001; // 0 은 assert 로 막혀 있어 최소값에 가깝게.

class _WheelTimePickerDialog extends StatefulWidget {
  const _WheelTimePickerDialog({required this.initial, this.helpText});

  final TimeOfDay initial;
  final String? helpText;

  @override
  State<_WheelTimePickerDialog> createState() => _WheelTimePickerDialogState();
}

class _WheelTimePickerDialogState extends State<_WheelTimePickerDialog> {
  late bool _isPm;

  /// 1~12. 0 이 아니라 12 로 표기한다 (자정=오전 12시, 정오=오후 12시).
  late int _hour12;
  late int _minute;

  /// 시 휠의 **원(raw) 인덱스**. 무한 순환이라 음수·12 이상으로도 간다.
  /// 오전/오후 자동 전환 판정에 필요해 따로 들고 있는다.
  late int _hourRaw;

  late final FixedExtentScrollController _amPmCtrl;
  late final FixedExtentScrollController _hourCtrl;
  late final FixedExtentScrollController _minuteCtrl;

  _EditTarget _editing = _EditTarget.none;
  final _editCtrl = TextEditingController();

  /// 진동 토글. 스크롤마다 읽으므로 미리 받아둔다 (CLAUDE.md "설정").
  AppSettings? _settings;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _settings ??= SettingsScope.of(context);
  }

  @override
  void initState() {
    super.initState();
    _isPm = widget.initial.period == DayPeriod.pm;
    // hourOfPeriod 는 12시를 0 으로 준다.
    final hop = widget.initial.hourOfPeriod;
    _hour12 = hop == 0 ? 12 : hop;
    _minute = widget.initial.minute;
    _hourRaw = _hour12 - 1;

    _amPmCtrl = FixedExtentScrollController(initialItem: _isPm ? 1 : 0);
    _hourCtrl = FixedExtentScrollController(initialItem: _hourRaw);
    _minuteCtrl = FixedExtentScrollController(initialItem: _minute);
  }

  @override
  void dispose() {
    _amPmCtrl.dispose();
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    _editCtrl.dispose();
    super.dispose();
  }

  /// raw 인덱스 [raw] 이하에 있는 **오전/오후 경계**의 개수.
  ///
  /// 경계는 "11시 → 12시" 사이, 즉 `raw ≡ 11 (mod 12)` 인 지점이다. 실제 시계가
  /// 오전 11시 다음에 오후 12시(정오)로 넘어가기 때문 — 12시→1시가 아니다.
  /// 두 지점의 차이가 홀수면 오전/오후를 뒤집는다.
  /// (`~/` 는 0 방향 절단이라 음수에서 어긋나므로 `.floor()` 를 쓴다.)
  static int _amPmBoundariesUpTo(int raw) => ((raw - 11) / 12).floor() + 1;

  /// 시 휠이 오전/오후를 자동 전환하며 AM/PM 휠을 프로그램적으로 굴리는 중.
  /// 그때는 진동을 한 번만 주려고(시 휠에서 이미 울림) 억제한다.
  bool _autoFlipping = false;

  void _onAmPmChanged(int index) {
    final next = index == 1;
    if (next == _isPm) return;
    setState(() => _isPm = next);
    if (!_autoFlipping) _settings?.selectionClick();
  }

  void _onHourChanged(int _) {
    // ⚠️ 콜백 인자를 쓰지 말 것. 순환 델리게이트에서는 0~11 로 **감싸진** 인덱스가
    // 와서 12시→1시 가 `11 → 0` 으로 보인다. 그러면 경계 차이가 -1(홀수)로 잡혀
    // 오전/오후가 한 번 더 뒤집힌다(오전 11시에서 두 칸 올리면 오전 1시가 아니라
    // 오후 1시가 되던 버그). 자동 전환은 **연속적인** 인덱스가 필요하므로
    // 컨트롤러에서 직접 읽는다.
    final raw = _hourCtrl.selectedItem;
    final crossings = _amPmBoundariesUpTo(raw) - _amPmBoundariesUpTo(_hourRaw);
    _hourRaw = raw;
    setState(() {
      _hour12 = raw % 12 + 1; // Dart 의 % 는 음수에서도 0 이상을 준다.
      if (crossings.isOdd) {
        _isPm = !_isPm;
        _autoFlipping = true;
        _amPmCtrl
            .animateToItem(
              _isPm ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            )
            .whenComplete(() => _autoFlipping = false);
      }
    });
    _settings?.selectionClick();
  }

  void _onMinuteChanged(int raw) {
    // 분은 감싸진 인덱스로도 값이 맞다 (0~59 그대로). carry 도 안 하므로 연속성 불필요.
    setState(() => _minute = raw % 60);
    _settings?.selectionClick();
  }

  void _startEditing(_EditTarget target) {
    if (_editing == target) return;
    _commitEdit();
    setState(() {
      _editing = target;
      _editCtrl.text = target == _EditTarget.hour
          ? _hour12.toString()
          : _minute.toString().padLeft(2, '0');
      _editCtrl.selection =
          TextSelection(baseOffset: 0, extentOffset: _editCtrl.text.length);
    });
  }

  /// 직접 입력값을 확정하고 휠 위치를 맞춘다. 입력 중이 아니면 no-op.
  void _commitEdit() {
    final target = _editing;
    if (target == _EditTarget.none) return;
    final parsed = int.tryParse(_editCtrl.text.trim());
    _editing = _EditTarget.none;
    if (parsed == null) {
      setState(() {});
      return;
    }
    if (target == _EditTarget.hour) {
      final next = parsed.clamp(1, 12);
      // jumpToItem 이 onSelectedItemChanged 를 부르므로 _hourRaw 를 **먼저** 목표로
      // 맞춰 둔다. 안 그러면 경계 차이가 홀수로 잡혀 오전/오후가 멋대로 뒤집힌다.
      _hour12 = next;
      _hourRaw = next - 1;
      _hourCtrl.jumpToItem(_hourRaw);
    } else {
      final next = parsed.clamp(0, 59);
      _minute = next;
      _minuteCtrl.jumpToItem(next);
    }
    setState(() {});
  }

  void _confirm() {
    _commitEdit();
    final hour = _isPm ? _hour12 % 12 + 12 : _hour12 % 12;
    Navigator.of(context).pop(TimeOfDay(hour: hour, minute: _minute));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.helpText ?? '시각 선택', style: AppTypo.title),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      content: SizedBox(
        width: 260,
        height: _wheelHeight,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 가운데 선택 밴드 — 숫자보다 뒤에 깔린다. **민트 채움 + 흰 글자**로,
            // 날짜 picker 의 선택된 날(민트 원 + 흰 글자)·FilledButton 과 같은 언어.
            // `surfaceAlt` 를 쓰면 다이얼로그 표면이 이미 옅은 틴트라 밴드가 오히려
            // **더 밝아져** 흰 알약처럼 보이고 "선택됨" 으로 안 읽힌다.
            IgnorePointer(
              child: Container(
                height: _itemExtent,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(flex: 3, child: _buildAmPmWheel()),
                Expanded(flex: 2, child: _buildHourColumn()),
                // 콜론도 밴드 안에 있으므로 밴드 위 글자색(흰색)을 따른다.
                SizedBox(
                  width: 12,
                  child: Text(
                    ':',
                    textAlign: TextAlign.center,
                    style: AppTypo.title
                        .copyWith(fontSize: 20, color: AppColors.onPrimary),
                  ),
                ),
                Expanded(flex: 2, child: _buildMinuteColumn()),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        TextButton(onPressed: _confirm, child: const Text('확인')),
      ],
    );
  }

  Widget _buildAmPmWheel() {
    return ListWheelScrollView(
      controller: _amPmCtrl,
      itemExtent: _itemExtent,
      physics: const FixedExtentScrollPhysics(),
      diameterRatio: _flatDiameterRatio,
      perspective: _flatPerspective,
      useMagnifier: false,
      squeeze: 1,
      onSelectedItemChanged: _onAmPmChanged,
      children: [
        _WheelLabel(text: '오전', selected: !_isPm),
        _WheelLabel(text: '오후', selected: _isPm),
      ],
    );
  }

  Widget _buildHourColumn() {
    return _EditableWheel(
      editing: _editing == _EditTarget.hour,
      editController: _editCtrl,
      onTapCenter: () => _startEditing(_EditTarget.hour),
      onSubmitted: _commitEdit,
      wheel: ListWheelScrollView.useDelegate(
        controller: _hourCtrl,
        itemExtent: _itemExtent,
        physics: const FixedExtentScrollPhysics(),
        diameterRatio: _flatDiameterRatio,
        perspective: _flatPerspective,
        useMagnifier: false,
        squeeze: 1,
        onSelectedItemChanged: _onHourChanged,
        childDelegate: ListWheelChildLoopingListDelegate(
          children: List.generate(
            12,
            (i) => _WheelLabel(
              text: '${i + 1}',
              selected: i + 1 == _hour12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMinuteColumn() {
    return _EditableWheel(
      editing: _editing == _EditTarget.minute,
      editController: _editCtrl,
      onTapCenter: () => _startEditing(_EditTarget.minute),
      onSubmitted: _commitEdit,
      wheel: ListWheelScrollView.useDelegate(
        controller: _minuteCtrl,
        itemExtent: _itemExtent,
        physics: const FixedExtentScrollPhysics(),
        diameterRatio: _flatDiameterRatio,
        perspective: _flatPerspective,
        useMagnifier: false,
        squeeze: 1,
        onSelectedItemChanged: _onMinuteChanged,
        childDelegate: ListWheelChildLoopingListDelegate(
          children: List.generate(
            60,
            (i) => _WheelLabel(
              text: i.toString().padLeft(2, '0'),
              selected: i == _minute,
            ),
          ),
        ),
      ),
    );
  }
}

/// 휠 한 칸. **크기는 모든 칸이 같고**(3D 축소 없음) 선택 여부는 색으로만 구분한다 —
/// 선택된 칸은 민트 밴드 위에 얹히므로 흰 글자, 나머지는 뮤트 그레이.
class _WheelLabel extends StatelessWidget {
  const _WheelLabel({required this.text, required this.selected});

  final String text;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        style: selected
            ? AppTypo.title.copyWith(fontSize: 20, color: AppColors.onPrimary)
            : AppTypo.body.copyWith(fontSize: 20, color: AppColors.inkMuted),
      ),
    );
  }
}

/// 휠 + "가운데 탭하면 직접 입력" 오버레이.
///
/// 편집 중에도 **휠은 트리에 남겨둔다** — 떼어내면 `FixedExtentScrollController` 가
/// detach 되어 편집 확정 후 `jumpToItem` 으로 위치를 맞출 수 없다.
class _EditableWheel extends StatelessWidget {
  const _EditableWheel({
    required this.wheel,
    required this.editing,
    required this.editController,
    required this.onTapCenter,
    required this.onSubmitted,
  });

  final Widget wheel;
  final bool editing;
  final TextEditingController editController;
  final VoidCallback onTapCenter;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        wheel,
        // 가운데 한 칸만 탭 대상. 위/아래는 휠 스크롤이 그대로 먹어야 한다.
        if (!editing)
          SizedBox(
            height: _itemExtent,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTapCenter,
              child: const SizedBox.expand(),
            ),
          ),
        if (editing)
          Container(
            height: _itemExtent,
            alignment: Alignment.center,
            // 밴드와 **같은 색·같은 라운드**라야 편집 중에도 가운데 칸이 이어져 보인다.
            // 라운드를 줘도 안쪽 코너는 뒤에 깔린 전폭 밴드(같은 민트)가 채워서 안
            // 보이고, 바깥쪽 코너만 밴드와 정확히 맞아떨어진다.
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppRadius.chip),
            ),
            child: TextField(
              controller: editController,
              autofocus: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 2,
              cursorColor: AppColors.onPrimary,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style:
                  AppTypo.title.copyWith(fontSize: 20, color: AppColors.onPrimary),
              decoration: const InputDecoration(
                counterText: '',
                isDense: true,
                filled: false,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: (_) => onSubmitted(),
              onTapOutside: (_) => onSubmitted(),
            ),
          ),
      ],
    );
  }
}
