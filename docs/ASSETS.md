# 动画素材接口

当前应用使用 `spritesheet-retina.png` 高清重绘版：3072 × 4576px，每格 384 × 416px，`pixelRatio: 2`。工作母版不打包进应用；画布倍数不代表所有源帧都有同倍数的原生细节。

- RGBA PNG，透明背景，非隔行，8-bit/channel。
- 标准图像：1536 × 2288，8 列 × 11 行；高清图像可以按整数倍输出。
- 逻辑帧：192 × 208pt，坐标从图片左上角开始。
- `pixelRatio` 可省略（默认 1），Retina 高清版本设为 2，此时实际帧为 384 × 416px，图像为 3072 × 4576px。显示尺寸不变，命中检测自动换算像素坐标。
- `Assets/animation-manifest.json` 的 `image` 为同目录文件名。
- 每动作包含 `row`、`frames`、`durationsMs` 和 `loop`。
- 视线：`lookDirections` 按角度升序排列，0° 向上，顺时针，90° 向右，180° 向下，270° 向左，间隔 22.5°。

| 行 | 动作 | 帧数 |
| --- | --- | --- |
| 0 | idle | 6 |
| 1 | running-right | 8 |
| 2 | running-left | 8 |
| 3 | waving | 4 |
| 4 | jumping | 5 |
| 5 | failed | 8 |
| 6 | waiting | 6 |
| 7 | running（思考工作，不是左右行走） | 6 |
| 8 | review | 6 |
| 9–10 | 16 个视线方向 | 16 |

应用使用 manifest 的每帧时长，不假设固定帧率。透明像素还用于鼠标穿透判断，因此不要把背景烘焙成白色、黑色或棋盘格。视线单元与待机帧应保持位置、比例和透明边界一致。

替换素材后运行 `python3 scripts/validate_assets.py`，再做 Mac 视觉验收。角色美术的许可与代码许可分开，见 `Assets/NOTICE.md`。
