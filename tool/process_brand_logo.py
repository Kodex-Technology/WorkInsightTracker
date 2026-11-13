from pathlib import Path

from PIL import Image

src = Path(r"d:\WItrack\assets\branding\workinsight_logo_raw.png")
img = Image.open(src).convert("RGBA")
pixels = img.load()
w, h = img.size
for y in range(h):
    for x in range(w):
        r, g, b, a = pixels[x, y]
        brightness = (r + g + b) / 3
        if brightness < 40:
            pixels[x, y] = (0, 0, 0, 0)
        else:
            alpha = min(255, int((brightness - 40) * (255 / 215)))
            pixels[x, y] = (255, 255, 255, alpha)

bbox = img.getbbox()
if bbox:
    img = img.crop(bbox)

side = max(img.size)
square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
ox = (side - img.size[0]) // 2
oy = (side - img.size[1]) // 2
square.paste(img, (ox, oy), img)

mark = square.resize((512, 512), Image.Resampling.LANCZOS)
out = Path(r"d:\WItrack\assets\branding\workinsight_mark.png")
mark.save(out)
mark.save(Path(r"d:\WItrack\assets\branding\witrack_icon_512.png"))

sizes = [16, 24, 32, 48, 64, 128, 256]
icons = [square.resize((s, s), Image.Resampling.LANCZOS) for s in sizes]
ico_path = Path(r"d:\WItrack\windows\runner\resources\app_icon.ico")
icons[-1].save(
    ico_path,
    format="ICO",
    sizes=[(s, s) for s in sizes],
    append_images=icons[:-1],
)
print("saved", out)
print("ico", ico_path)
