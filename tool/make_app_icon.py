"""Build a multi-resolution Windows .ico from the Witrack brand mark."""

from __future__ import annotations

import struct
from pathlib import Path

from PIL import Image

SRC = Path(r"C:\Users\kodex\.cursor\projects\d-WItrack\assets\witrack_app_icon_1024.jpg")
OUT = Path(r"d:\WItrack\windows\runner\resources\app_icon.ico")
PNG_OUT = Path(r"d:\WItrack\assets\branding\witrack_icon_512.png")
SIZES = [16, 24, 32, 48, 64, 128, 256]


def _square(img: Image.Image) -> Image.Image:
    img = img.convert("RGBA")
    w, h = img.size
    side = min(w, h)
    left = (w - side) // 2
    top = (h - side) // 2
    return img.crop((left, top, left + side, top + side))


def _png_bytes(img: Image.Image) -> bytes:
    from io import BytesIO

    buf = BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


def write_ico(path: Path, images: list[Image.Image]) -> None:
    """Write ICO with embedded PNG images (Vista+ style, reliable)."""
    entries: list[tuple[int, int, bytes]] = []
    for image in images:
        raw = _png_bytes(image)
        entries.append((image.width, image.height, raw))

    count = len(entries)
    offset = 6 + (16 * count)
    header = struct.pack("<HHH", 0, 1, count)
    directory = bytearray()
    blobs = bytearray()
    for width, height, raw in entries:
        w_byte = 0 if width >= 256 else width
        h_byte = 0 if height >= 256 else height
        directory.extend(
            struct.pack(
                "<BBBBHHII",
                w_byte,
                h_byte,
                0,
                0,
                1,
                32,
                len(raw),
                offset,
            )
        )
        blobs.extend(raw)
        offset += len(raw)

    path.write_bytes(header + directory + blobs)


def main() -> None:
    base = _square(Image.open(SRC))
    images = [
        base.resize((size, size), Image.Resampling.LANCZOS) for size in SIZES
    ]
    write_ico(OUT, images)
    PNG_OUT.parent.mkdir(parents=True, exist_ok=True)
    base.resize((512, 512), Image.Resampling.LANCZOS).save(PNG_OUT)
    print(f"wrote {OUT} ({OUT.stat().st_size} bytes, {len(SIZES)} sizes)")
    print(f"wrote {PNG_OUT}")


if __name__ == "__main__":
    main()
