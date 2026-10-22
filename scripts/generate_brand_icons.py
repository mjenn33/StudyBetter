"""Rasterize the simple StudyBetter book mark without external dependencies.

The editable vector reference is docs/assets/studybetter.svg.
"""
import math
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def png(size):
    rows = []
    for y in range(size):
        row = bytearray([0])
        for x in range(size):
            px, py = (x + .5) * 128 / size, (y + .5) * 128 / size
            color = (57, 73, 171, 255)
            top = 33 + 6 * (1 - abs(px - 64) / 40)
            bottom = 93 + 6 * (1 - abs(px - 64) / 40)
            if 24 <= px <= 104 and top <= py <= bottom:
                color = (255, 255, 255, 255)
            if abs(px - 64) < 2.5 and 40 < py < 96:
                color = (57, 73, 171, 255)
            # Distance to either check-mark segment.
            for ax, ay, bx, by in [(76, 60, 83, 67), (83, 67, 97, 49)]:
                t = max(0, min(1, ((px-ax)*(bx-ax)+(py-ay)*(by-ay))/((bx-ax)**2+(by-ay)**2)))
                if math.hypot(px-ax-t*(bx-ax), py-ay-t*(by-ay)) <= 3:
                    color = (0, 133, 119, 255)
            row.extend(color)
        rows.append(row)
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))
    return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>2I5B', size, size, 8, 6, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(b''.join(rows))) + chunk(b'IEND', b'')


for density, size in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]:
    (ROOT / f'app/android/app/src/main/res/mipmap-{density}/ic_launcher.png').write_bytes(png(size))
images = [(size, png(size)) for size in [16, 32, 48, 64, 128, 256]]
offset = 6 + len(images) * 16
entries = []
for size, data in images:
    entries.append(struct.pack('<4B2H2I', size % 256, size % 256, 0, 0, 1, 32, len(data), offset))
    offset += len(data)
(ROOT / 'app/windows/runner/resources/app_icon.ico').write_bytes(struct.pack('<3H', 0, 1, len(images)) + b''.join(entries) + b''.join(data for _, data in images))
