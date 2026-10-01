"""Genera el icono de NovaDX en PNG para Android y web.

Dibuja el logo directamente con Pillow: fondo negro, "DX" en Arial Black
(blanco, grande) y "NOVA" en Bauhaus 93 (blanco, pegado debajo).

Uso:  python tool/gen_icons.py
"""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Tamanos de mipmap de Android para ic_launcher.
ANDROID = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

BG = (0, 0, 0)
FG = (255, 255, 255)

FONTS_DIR = r"C:\Windows\Fonts"
DX_FONT_FILE = "ariblk.ttf"      # Arial Black
NOVA_FONT_FILE = "BAUHS93.TTF"   # Bauhaus 93


def _font(file, size):
    return ImageFont.truetype(os.path.join(FONTS_DIR, file), size)


def draw_logo(size, rounded=True):
    """Devuelve una imagen RGBA del logo del tamano dado."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    if rounded:
        draw.rounded_rectangle(
            [0, 0, size - 1, size - 1], radius=int(size * 0.18), fill=BG
        )
    else:
        draw.rectangle([0, 0, size, size], fill=BG)

    # "DX" en Arial Black.
    dx_font = _font(DX_FONT_FILE, int(size * 0.44))
    dx = "DX"
    dxb = draw.textbbox((0, 0), dx, font=dx_font)
    dxw, dxh = dxb[2] - dxb[0], dxb[3] - dxb[1]

    # "NOVA" en Bauhaus 93 (fuente ancha: tamano y tracking moderados).
    nova_font = _font(NOVA_FONT_FILE, int(size * 0.135))
    nova = "NOVA"
    spacing = int(size * 0.03)
    widths, nova_h = [], 0
    for ch in nova:
        b = draw.textbbox((0, 0), ch, font=nova_font)
        widths.append(b[2] - b[0])
        nova_h = max(nova_h, b[3] - b[1])
    nova_w = sum(widths) + spacing * (len(nova) - 1)

    # Centrado vertical del conjunto, con NOVA pegado a DX.
    gap = int(size * 0.015)
    block_h = dxh + gap + nova_h
    top = (size - block_h) / 2

    draw.text(((size - dxw) / 2 - dxb[0], top - dxb[1]), dx, font=dx_font, fill=FG)

    ny = top + dxh + gap
    cx = (size - nova_w) / 2
    for ch, w in zip(nova, widths):
        b = draw.textbbox((0, 0), ch, font=nova_font)
        draw.text((cx - b[0], ny - b[1]), ch, font=nova_font, fill=FG)
        cx += w + spacing

    return img


def main():
    # Android mipmaps (con esquinas redondeadas).
    for folder, px in ANDROID.items():
        out_dir = os.path.join(ROOT, "android", "app", "src", "main", "res", folder)
        os.makedirs(out_dir, exist_ok=True)
        draw_logo(px, rounded=True).save(os.path.join(out_dir, "ic_launcher.png"))
        print(f"  {folder}/ic_launcher.png  ({px}x{px})")

    # Web: favicon e iconos PWA.
    web_dir = os.path.join(ROOT, "web")
    icons_dir = os.path.join(web_dir, "icons")
    os.makedirs(icons_dir, exist_ok=True)
    draw_logo(512, rounded=False).save(os.path.join(icons_dir, "Icon-512.png"))
    draw_logo(192, rounded=False).save(os.path.join(icons_dir, "Icon-192.png"))
    draw_logo(512, rounded=True).save(os.path.join(icons_dir, "Icon-maskable-512.png"))
    draw_logo(192, rounded=True).save(os.path.join(icons_dir, "Icon-maskable-192.png"))
    draw_logo(64, rounded=False).save(os.path.join(web_dir, "favicon.png"))
    print("  web/icons/* y favicon.png")

    # PNG grande de referencia (tiendas / redes).
    os.makedirs(os.path.join(ROOT, "assets", "logo"), exist_ok=True)
    draw_logo(1024, rounded=True).save(
        os.path.join(ROOT, "assets", "logo", "novadx_1024.png")
    )
    print("  assets/logo/novadx_1024.png (1024x1024)")
    print("Listo.")


if __name__ == "__main__":
    main()
