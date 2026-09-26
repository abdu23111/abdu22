"""Tiles rendered shots into one contact sheet: python tools/harness/sheet.py OUT.png shot1 shot2 ..."""
import os
import sys

from PIL import Image, ImageDraw

DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "previews", "world")


def main():
    out, names = sys.argv[1], sys.argv[2:]
    cols = 2
    w, h = 640, 360
    rows = (len(names) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * w, rows * h), (0, 0, 0))
    for i, n in enumerate(names):
        img = Image.open(os.path.join(DIR, n + ".png")).convert("RGB").resize((w, h))
        ImageDraw.Draw(img).text((8, 6), n, fill=(255, 255, 255))
        sheet.paste(img, ((i % cols) * w, (i // cols) * h))
    sheet.save(out)


if __name__ == "__main__":
    main()
