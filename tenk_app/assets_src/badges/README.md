# 배지 원본 (번들 제외)

`assets/badges/` 에 들어가는 배지 PNG 의 **1024px 원본**. 이 디렉토리는 `pubspec.yaml`
의 `flutter.assets` 에 등록돼 있지 않아 **APK/AAB 에 포함되지 않는다.**

## 왜 나눠 뒀나

배지는 화면에서 최대 180px 로 그려지는데 원본이 1024px(개당 700KB~1MB, 9개 합쳐
~6.7MB)이라 디코딩·메모리·번들 크기가 모두 손해였다. 획득 연출을 정교하게 만들수록
첫 프레임 디코딩 지연이 그대로 드러나는 자리라 **384px 로 줄여 번들에 넣는다**
(9개 합쳐 ~1.3MB).

## 다시 만드는 법

원본을 고쳤거나 크기를 바꾸려면 리포 루트에서 PowerShell 로:

```powershell
Add-Type -AssemblyName System.Drawing
$src = "tenk_app\assets_src\badges"; $dst = "tenk_app\assets\badges"; $target = 384
Get-ChildItem $src -Filter *.png | ForEach-Object {
  $img = [System.Drawing.Image]::FromFile($_.FullName)
  $bmp = New-Object System.Drawing.Bitmap $target, $target
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g.DrawImage($img, (New-Object System.Drawing.Rectangle 0, 0, $target, $target))
  $g.Dispose(); $img.Dispose()
  $bmp.Save((Join-Path $dst $_.Name), [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
}
```

⚠️ `CompositingMode.SourceCopy` 를 빼면 투명 배경이 검게 합성된다.

## 색 사다리 (연출이 여기에 맞춰져 있다)

| 단계 | 색 | 비고 |
|---|---|---|
| 3 | 구리/브론즈 | |
| 7 | 은/실버 | |
| 14 | 금/골드 | |
| 30 | 금 + 보석 + 리본 | 자산에 반짝임이 이미 많다 |
| 성공 | 금 트로피 | |

**타입(STREAK/NO_SPEND)이 아니라 단계로 색이 갈린다** — `streak_3` 과 `no_spend_3` 이
같은 구리색. 획득 모달의 글로우·파티클 색이 이 표를 따라가므로
([badge_style.dart](../../lib/presentation/challenge/widgets/badge_style.dart)),
자산 색을 바꾸면 그쪽도 같이 맞출 것.
