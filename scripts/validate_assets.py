#!/usr/bin/env python3
"""Validate the final manifest and transparent PNG with Python's standard library."""
import json
import hashlib
from pathlib import Path
import struct
import zlib

ROOT = Path(__file__).resolve().parents[1]


def read_rgba_png(path):
    data = path.read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", "Not a PNG"
    position, packed, header = 8, bytearray(), None
    while position < len(data):
        length = struct.unpack(">I", data[position:position + 4])[0]
        kind = data[position + 4:position + 8]
        payload = data[position + 8:position + 8 + length]
        checksum = struct.unpack(">I", data[position + 8 + length:position + 12 + length])[0]
        assert zlib.crc32(kind + payload) & 0xFFFFFFFF == checksum, "PNG chunk CRC mismatch"
        if kind == b"IHDR":
            header = struct.unpack(">IIBBBBB", payload)
        elif kind == b"IDAT":
            packed.extend(payload)
        position += length + 12
        if kind == b"IEND":
            break
    assert header is not None, "Missing PNG header"
    width, height, depth, color, compression, filtering, interlace = header
    assert (depth, color, compression, filtering, interlace) == (8, 6, 0, 0, 0), "Expected non-interlaced 8-bit RGBA PNG"
    raw = zlib.decompress(packed)
    stride = width * 4
    assert len(raw) == (stride + 1) * height, "Wrong PNG data size"
    lines, previous = [], bytearray(stride)
    for y in range(height):
        offset = y * (stride + 1)
        mode = raw[offset]
        line = bytearray(raw[offset + 1:offset + 1 + stride])
        assert mode in range(5), "Invalid PNG filter"
        for x in range(stride):
            left = line[x - 4] if x >= 4 else 0
            up = previous[x]
            upper_left = previous[x - 4] if x >= 4 else 0
            if mode == 1:
                predictor = left
            elif mode == 2:
                predictor = up
            elif mode == 3:
                predictor = (left + up) // 2
            elif mode == 4:
                p = left + up - upper_left
                distances = (abs(p - left), abs(p - up), abs(p - upper_left))
                predictor = (left, up, upper_left)[distances.index(min(distances))]
            else:
                predictor = 0
            line[x] = (line[x] + predictor) & 255
        lines.append(line)
        previous = line
    return width, height, lines


def validate():
    manifest = json.loads((ROOT / "Assets/animation-manifest.json").read_text())
    assert manifest.get("status") == "validated", "Artwork has not passed final validation; preview assets must not be published"
    cell_width, cell_height = manifest["cellWidth"], manifest["cellHeight"]
    columns, rows = manifest["columns"], manifest["rows"]
    ratio = manifest.get("pixelRatio", 1)
    assert ratio in (1, 2, 3, 4), "Unsupported pixel ratio"
    assert (columns, rows, cell_width / ratio, cell_height / ratio) == (8, 11, 192, 208)
    assert manifest["image"] == Path(manifest["image"]).name
    image_path = ROOT / "Assets" / manifest["image"]
    if "sha256" in manifest:
        assert hashlib.sha256(image_path.read_bytes()).hexdigest() == manifest["sha256"], "Atlas checksum mismatch"
    if "fileSizeBytes" in manifest:
        assert image_path.stat().st_size == manifest["fileSizeBytes"], "Atlas file size mismatch"
    width, height, lines = read_rgba_png(image_path)
    assert (width, height) == (manifest["width"], manifest["height"]) == (columns * cell_width, rows * cell_height)
    expected = {"idle", "running-left", "running-right", "waving", "jumping", "failed", "waiting", "running", "review"}
    assert set(manifest["animations"]) == expected
    cells = []
    for name, animation in manifest["animations"].items():
        assert 0 <= animation["row"] < rows
        assert 0 < animation["frames"] <= columns
        assert len(animation["durationsMs"]) == animation["frames"]
        assert all(isinstance(value, int) and value > 0 for value in animation["durationsMs"])
        cells.extend((animation["row"], column, name) for column in range(animation["frames"]))
    assert len(cells) == 57
    assert [item["angle"] for item in manifest["lookDirections"]] == [index * 22.5 for index in range(16)]
    cells.extend((item["row"], item["column"], f"look-{item['angle']}") for item in manifest["lookDirections"])
    assert len({(row, column) for row, column, _ in cells}) == 73
    for row, column, name in cells:
        assert 0 <= row < rows and 0 <= column < columns
        alpha = [line[column * cell_width * 4 + 3:(column + 1) * cell_width * 4:4]
                 for line in lines[row * cell_height:(row + 1) * cell_height]]
        visible = sum(value > 30 for line in alpha for value in line)
        transparent = sum(value == 0 for line in alpha for value in line)
        assert visible > 500, f"Empty/incomplete frame: {name}/{column}"
        assert transparent > cell_width * cell_height * 0.15, f"Missing transparency: {name}/{column}"
    print(f"PASS: {width}×{height} RGBA atlas, 9 animations / 57 frames, 16 gaze directions, 73 nonempty transparent cells")


if __name__ == "__main__":
    validate()
