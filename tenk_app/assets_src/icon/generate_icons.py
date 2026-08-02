"""TenK 로고·런처 아이콘 생성기 — 마크 형상의 **진실의 원천**.

마크는 폰트·외부 자산 없이 전부 기하학으로 그린다. 어느 머신에서든 결과가 같고,
상수만 고치면 전 밀도·전 플랫폼이 한 번에 다시 나온다.

마크 = **'10'**. 세로획+깃발이 '1', 오른쪽 링이 '0' 이면서 **예산 게이지**다.
옅은 트랙(완전한 원)이 갭을 메워 '0' 으로 읽히고, 진한 링이 그 위에 얹힌다.

⚠️ 같은 형상을 Flutter 쪽에서도 그린다 — `lib/design/tenk_logo.dart` 의 `TenkLogoPainter`.
**비율 상수를 바꾸면 양쪽을 같이 고칠 것.** Dart 가 쓰는 잉크 bbox 는 `--ink` 로 뽑는다.

사용법은 이 디렉토리의 README.md 참고.
    python generate_icons.py            # 전체 산출물 갱신
    python generate_icons.py --preview  # 미리보기 시트만
    python generate_icons.py --ink      # Dart painter 용 잉크 bbox 출력
"""

import argparse
import json
import math
import os

from PIL import Image, ImageDraw

# ── 색 (design/tokens.dart 와 같은 값) ───────────────────────────────
MINT = (0x1F, 0xBE, 0x9C, 255)      # AppColors.primary
TRACK = (0xC6, 0xEE, 0xE4, 255)     # AppColors.logoTrack — 게이지 트랙
WHITE = (0xFF, 0xFF, 0xFF, 255)
BLACK = (0x00, 0x00, 0x00, 255)
BG_HEX = "#FFFFFF"                  # adaptive icon 바탕

# ── 마크 형상 ('1' + '0' 게이지 링) ──────────────────────────────────
# 좌표는 세로 1.0 을 기준으로 한 디자인 공간(y 는 아래로 증가). 링이 정원이어야 하므로
# x·y 스케일은 같다. 배치는 잉크 bbox 를 재서 캔버스 중앙에 맞춘다(_ink_box).
STROKE = 0.20            # 획 굵기
FLAG = (-0.16, 0.20)     # '1' 좌상단 깃발 끝
RING_CX, RING_R = 0.60, 0.40
GAP_AT, GAP_HALF = 0, 55  # 게이지 갭: 오른쪽 중심, 폭 110°

# 마크가 아이콘 캔버스에서 차지하는 비율 (긴 변 기준).
MARK_EXTENT = 0.56
# adaptive icon 은 108dp 캔버스 중 **가운데 72dp** 만 보인다.
ADAPTIVE_SAFE = 72 / 108
# API 25 이하엔 시스템 마스크가 없어 legacy PNG 에 라운드를 구워 넣는다.
LEGACY_CORNER = 0.22

SS = 4  # supersample

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.normpath(os.path.join(HERE, "..", ".."))
ANDROID_RES = os.path.join(APP, "android", "app", "src", "main", "res")
IOS_ICONSET = os.path.join(APP, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")

# Android 런처 아이콘 밀도별 px (legacy 48dp / adaptive 108dp)
DENSITIES = {
    "mdpi": (48, 108),
    "hdpi": (72, 162),
    "xhdpi": (96, 216),
    "xxhdpi": (144, 324),
    "xxxhdpi": (192, 432),
}


# ── 그리기 ──────────────────────────────────────────────────────────

def _dots(d, pts, w, fill):
    """원 브러시를 촘촘히 찍어 그린다 — 굵은 폴리라인은 관절마다 톱니가 생긴다."""
    r = w / 2
    for x, y in pts:
        d.ellipse([x - r, y - r, x + r, y + r], fill=fill)


def _seg(p0, p1, n=240):
    return [(p0[0] + (p1[0] - p0[0]) * i / n, p0[1] + (p1[1] - p0[1]) * i / n)
            for i in range(n + 1)]


def _arc(a0, a1, n=520):
    return [(RING_CX + RING_R * math.cos(math.radians(a0 + (a1 - a0) * i / n)),
             0.5 + RING_R * math.sin(math.radians(a0 + (a1 - a0) * i / n)))
            for i in range(n + 1)]


def _paint(px, unit, origin, fill, track):
    img = Image.new("RGBA", (px, px), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    def P(p):
        return (origin[0] + p[0] * unit, origin[1] + p[1] * unit)

    s = STROKE * unit
    # '0' — 트랙(완전한 원) 먼저, 그 위에 게이지 링
    if track is not None:
        _dots(d, [P(p) for p in _arc(0, 360)], s, track)
    _dots(d, [P(p) for p in _arc(GAP_AT - GAP_HALF, GAP_AT - 360 + GAP_HALF)], s, fill)
    # '1'
    _dots(d, [P(p) for p in _seg((0, 0), (0, 1))], s, fill)
    _dots(d, [P(p) for p in _seg(FLAG, (0, 0))], s, fill)
    return img


def ink_box():
    """디자인 공간에서 마크 잉크가 차지하는 (x, y, w, h). Dart painter 가 같은 값을 쓴다."""
    u = 500
    img = _paint(u * 4, u, (u, u), MINT, TRACK)
    l, t, r, b = img.getbbox()
    return ((l - u) / u, (t - u) / u, (r - l) / u, (b - t) / u)


def draw_mark(size, fill=MINT, track=TRACK, extent=MARK_EXTENT):
    """마크만 그린 투명 이미지 — 잉크 bbox 기준 캔버스 정중앙 배치."""
    px = size * SS
    bx, by, bw, bh = ink_box()
    unit = px * extent / max(bw, bh)
    origin = (px / 2 - (bx + bw / 2) * unit, px / 2 - (by + bh / 2) * unit)
    return _paint(px, unit, origin, fill, track).resize((size, size), Image.LANCZOS)


def _mask(size, kind, corner=LEGACY_CORNER):
    m = Image.new("L", (size * SS, size * SS), 0)
    d = ImageDraw.Draw(m)
    if kind == "circle":
        d.ellipse([0, 0, size * SS - 1, size * SS - 1], fill=255)
    else:
        d.rounded_rectangle([0, 0, size * SS - 1, size * SS - 1],
                            radius=int(size * SS * corner), fill=255)
    return m.resize((size, size), Image.LANCZOS)


def draw_icon(size, kind=None):
    base = Image.new("RGBA", (size, size), WHITE)
    base.alpha_composite(draw_mark(size))
    if kind:
        base.putalpha(_mask(size, kind))
    return base


def _save(img, path, keep_alpha=True):
    d = os.path.dirname(path)
    if not os.path.isdir(d):
        os.makedirs(d)
    if not keep_alpha:
        flat = Image.new("RGB", img.size, (255, 255, 255))
        flat.paste(img, mask=img.split()[3] if img.mode == "RGBA" else None)
        flat.save(path, "PNG", optimize=True)
    else:
        img.save(path, "PNG", optimize=True)
    return path


# ── 산출물 ──────────────────────────────────────────────────────────

def build_android():
    written = []
    fg_extent = MARK_EXTENT * ADAPTIVE_SAFE
    for density, (legacy_px, adaptive_px) in DENSITIES.items():
        mip = os.path.join(ANDROID_RES, "mipmap-" + density)
        written.append(_save(draw_icon(legacy_px, "rounded"),
                             os.path.join(mip, "ic_launcher.png")))
        written.append(_save(draw_icon(legacy_px, "circle"),
                             os.path.join(mip, "ic_launcher_round.png")))
        written.append(_save(draw_mark(adaptive_px, extent=fg_extent),
                             os.path.join(mip, "ic_launcher_foreground.png")))
        # API 33+ themed icon — 시스템이 색을 입히므로 단색 실루엣(트랙도 같은 색).
        written.append(_save(draw_mark(adaptive_px, fill=BLACK, track=BLACK,
                                       extent=fg_extent),
                             os.path.join(mip, "ic_launcher_monochrome.png")))

    anydpi = os.path.join(ANDROID_RES, "mipmap-anydpi-v26")
    if not os.path.isdir(anydpi):
        os.makedirs(anydpi)
    xml = (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        '    <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>\n'
        "</adaptive-icon>\n"
    )
    for name in ("ic_launcher.xml", "ic_launcher_round.xml"):
        path = os.path.join(anydpi, name)
        with open(path, "w", encoding="utf-8") as f:
            f.write(xml)
        written.append(path)

    colors = os.path.join(ANDROID_RES, "values", "colors.xml")
    with open(colors, "w", encoding="utf-8") as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n'
                "<resources>\n"
                "    <!-- adaptive icon 바탕. 마크가 민트라 바탕은 흰색이다. -->\n"
                '    <color name="ic_launcher_background">' + BG_HEX + "</color>\n"
                "</resources>\n")
    written.append(colors)
    return written


def build_ios():
    """Contents.json 에 이미 적힌 파일명·크기를 그대로 덮어쓴다.

    iOS 아이콘은 **알파 채널이 있으면 App Store 업로드가 거부**되므로 RGB 로 저장하고,
    라운드도 굽지 않는다(시스템이 마스킹한다).
    """
    with open(os.path.join(IOS_ICONSET, "Contents.json"), encoding="utf-8") as f:
        contents = json.load(f)

    written, seen = [], set()
    for entry in contents["images"]:
        filename = entry.get("filename")
        if not filename or filename in seen:
            continue
        seen.add(filename)
        base = float(entry["size"].split("x")[0])
        px = int(round(base * float(entry["scale"].rstrip("x"))))
        written.append(_save(draw_icon(px), os.path.join(IOS_ICONSET, filename),
                             keep_alpha=False))
    return written


def build_store():
    """Play Console 업로드용(번들 아님) + 검토용 원본."""
    return [
        _save(draw_icon(512), os.path.join(HERE, "play_store_512.png")),
        _save(draw_icon(1024), os.path.join(HERE, "icon_master_1024.png")),
    ]


def build_preview():
    tiles = [draw_icon(160, "rounded"), draw_icon(112, "circle"),
             draw_icon(96, "rounded"), draw_icon(48, "rounded")]
    sheet = Image.new("RGB", (560, 200), (0xF1, 0xF3, 0xF6))
    x = 20
    for img in tiles:
        sheet.paste(img, (x, 20 + (160 - img.size[1]) // 2), img)
        x += img.size[0] + 20
    return [_save(sheet, os.path.join(HERE, "preview.png"))]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", action="store_true", help="미리보기 시트만 생성")
    ap.add_argument("--ink", action="store_true", help="Dart painter 용 잉크 bbox 출력")
    args = ap.parse_args()

    if args.ink:
        bx, by, bw, bh = ink_box()
        print("ink box: x=%.4f y=%.4f w=%.4f h=%.4f" % (bx, by, bw, bh))
        return

    written = build_preview() if args.preview else (
        build_android() + build_ios() + build_store() + build_preview())
    for path in written:
        print(os.path.relpath(path, APP))
    print("\n%d files" % len(written))


if __name__ == "__main__":
    main()
