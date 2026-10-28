#!/usr/bin/env python3
"""Render docs/demo/rev-eng.gif and docs/demo/rev-eng.cast.

The prompt and answer come verbatim from docs/demo/session.json, captured from a
live dsh agent run with dsh-rev-eng installed. Only the typing pace, cursor,
layout, and colors are generated here.

Run: python3 scripts/make-demo-gif.py
"""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
DOCS = ROOT / "docs" / "demo"
SESSION = json.loads((DOCS / "session.json").read_text())

W, H = 1000, 400
MARGIN = 24
WIN = (MARGIN, MARGIN, W - MARGIN, H - MARGIN)
TITLE_H = 38
BODY_X = 56
BODY_Y = WIN[1] + TITLE_H + 30
FONT_PATH = "/System/Library/Fonts/Menlo.ttc"

BG = "#0d1117"
TITLE_BG = "#161b22"
BORDER = "#30363d"
TEXT = "#c9d1d9"
DIM = "#8b949e"
FAINT = "#6e7681"
GREEN = "#3fb950"
BLUE = "#79c0ff"
PURPLE = "#d2a8ff"

F_REGULAR = ImageFont.truetype(FONT_PATH, 20, index=0)
F_BOLD = ImageFont.truetype(FONT_PATH, 20, index=1)
F_TITLE = ImageFont.truetype(FONT_PATH, 15, index=1)
F_SMALL = ImageFont.truetype(FONT_PATH, 13, index=0)

LINE_H = 27
CHAR_W = F_REGULAR.getlength("M")
BODY_W = WIN[2] - BODY_X - 24
CURSOR = "\u2588"

SKILL_COLORS = {"reverse-engineer-anything": BLUE, "bama": PURPLE}


def tokens(text):
    out, current = [], ""
    for char in text:
        current += char
        if char == " ":
            out.append(current)
            current = ""
    if current:
        out.append(current)
    return out


def wrap(segments, max_width):
    lines, line, width = [], [], 0.0
    for text, color, font in segments:
        for token in tokens(text):
            token_w = font.getlength(token)
            if width + token_w > max_width and line:
                lines.append(line)
                line, width = [], 0.0
                if token.isspace():
                    continue
            line.append((token, color, font))
            width += token_w
    if line:
        lines.append(line)
    return lines


PROMPT_SEGMENTS = [
    ("\u276f ", GREEN, F_BOLD),
    (SESSION["prompt_trigger"], GREEN, F_BOLD),
    (" ", TEXT, F_REGULAR),
    (SESSION["prompt"], TEXT, F_REGULAR),
]
PROMPT_LINES = wrap(PROMPT_SEGMENTS, BODY_W)

ANSWER_LINES = []
for item in SESSION["answer"]:
    skill = item["skill"]
    ANSWER_LINES.extend(
        wrap(
            [
                (f"{skill}: ", SKILL_COLORS.get(skill, BLUE), F_BOLD),
                (item["text"], TEXT, F_REGULAR),
            ],
            BODY_W,
        )
    )

PROMPT_START_Y = BODY_Y
ANSWER_START_Y = PROMPT_START_Y + (len(PROMPT_LINES) + 1) * LINE_H


def line_length(line):
    return sum(len(text) for text, _, _ in line)


def lines_length(lines):
    return sum(line_length(line) for line in lines)


def draw_lines(draw, lines, y, limit):
    """Draw at most `limit` characters across wrapped lines; return end position."""
    remaining = limit
    last = (BODY_X, y)
    for index, line in enumerate(lines):
        if remaining <= 0:
            break
        y_line = y + index * LINE_H
        x = BODY_X
        for text, color, font in line:
            take = max(0, min(len(text), remaining))
            if take:
                piece = text[:take]
                draw.text((x, y_line), piece, font=font, fill=color)
                x += font.getlength(piece)
                remaining -= take
            last = (x, y_line)
            if take < len(text):
                return last
    return last


def end_of(lines, y):
    return BODY_X + sum(F_REGULAR.getlength(t) for t, _, _ in lines[-1]), y + (len(lines) - 1) * LINE_H


def base_canvas():
    img = Image.new("RGB", (W, H), BG)
    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle(WIN, radius=12, fill=BG, outline=BORDER, width=1)
    draw.rounded_rectangle((WIN[0], WIN[1], WIN[2], WIN[1] + TITLE_H), radius=12, fill=TITLE_BG)
    draw.rectangle((WIN[0], WIN[1] + TITLE_H - 12, WIN[2], WIN[1] + TITLE_H), fill=TITLE_BG)
    for index, color in enumerate(("#ff5f56", "#ffbd2e", "#27c93f")):
        cx = WIN[0] + 24 + index * 20
        cy = WIN[1] + TITLE_H // 2
        draw.ellipse((cx - 6, cy - 6, cx + 6, cy + 6), fill=color)
    title = "rev-eng \u2014 dsh demo"
    draw.text(((W - F_TITLE.getlength(title)) / 2, WIN[1] + TITLE_H // 2 - 9), title, font=F_TITLE, fill=DIM)
    draw.text((BODY_X, BODY_Y - 28), SESSION["header"], font=F_SMALL, fill=FAINT)
    footer = SESSION["footer"]
    draw.text((WIN[2] - 24 - F_SMALL.getlength(footer), WIN[3] - 30), footer, font=F_SMALL, fill=FAINT)
    return img


def frame(typed_prompt=0, typed_answer=-1, cursor=False):
    """Render one frame. typed_answer=-1 means the answer has not started."""
    canvas = base_canvas()
    draw = ImageDraw.Draw(canvas)
    draw_lines(draw, PROMPT_LINES, PROMPT_START_Y, lines_length(PROMPT_LINES))
    cursor_pos = end_of(PROMPT_LINES, PROMPT_START_Y)
    if typed_answer > 0:
        cursor_pos = draw_lines(draw, ANSWER_LINES, ANSWER_START_Y, typed_answer)
    elif typed_answer == 0:
        cursor_pos = (BODY_X, ANSWER_START_Y)
    if typed_prompt > 0 and typed_prompt < lines_length(PROMPT_LINES):
        canvas = base_canvas()
        draw = ImageDraw.Draw(canvas)
        cursor_pos = draw_lines(draw, PROMPT_LINES, PROMPT_START_Y, typed_prompt)
    if cursor:
        draw.text(cursor_pos, CURSOR, font=F_REGULAR, fill=TEXT)
    return canvas


def main():
    full = frame(
        typed_prompt=lines_length(PROMPT_LINES),
        typed_answer=lines_length(ANSWER_LINES),
        cursor=False,
    )
    palette = full.quantize(colors=128, method=Image.Quantize.MEDIANCUT)
    frames, durations = [], []

    def add(img, ms):
        frames.append(img.quantize(palette=palette, dither=Image.Dither.NONE))
        durations.append(ms)

    prompt_total = lines_length(PROMPT_LINES)
    answer_total = lines_length(ANSWER_LINES)

    add(base_canvas(), 350)
    add(frame(cursor=True), 300)

    typed = 0
    step = max(1, prompt_total // 44)
    while typed < prompt_total:
        typed = min(prompt_total, typed + step)
        add(frame(typed_prompt=typed, cursor=True), 70)
    add(frame(cursor=False), 220)
    add(frame(cursor=True), 220)

    add(frame(cursor=False, typed_answer=-1), 380)
    add(frame(cursor=True, typed_answer=0), 420)

    revealed = 0
    answer_step = max(1, answer_total // 30)
    while revealed < answer_total:
        revealed = min(answer_total, revealed + answer_step)
        add(frame(typed_answer=revealed, cursor=True), 55)
    add(frame(typed_answer=answer_total, cursor=False), 260)
    add(frame(typed_answer=answer_total, cursor=True), 260)
    add(frame(typed_answer=answer_total, cursor=True), 2600)

    gif = DOCS / "rev-eng.gif"
    frames[0].save(
        gif,
        save_all=True,
        append_images=frames[1:],
        duration=durations,
        loop=0,
        optimize=True,
        disposal=2,
    )

    # asciinema v2 cast of the same prompt/answer, for people who prefer a recording.
    events = []
    clock = 0.0

    def out(text, delay):
        nonlocal clock
        clock += delay
        events.append([round(clock, 3), "o", text])

    out("\u001b[38;5;244m" + SESSION["header"] + "\u001b[0m\r\n\r\n", 0.3)
    out("\u001b[38;5;71m\u276f \u001b[1m" + SESSION["prompt_trigger"] + "\u001b[0m ", 0.4)
    for index in range(0, len(SESSION["prompt"]), 5):
        out(SESSION["prompt"][index:index + 5], 0.06)
    out("\r\n", 0.2)
    out("\r\n", 0.6)
    for item in SESSION["answer"]:
        color = "75" if item["skill"] == "reverse-engineer-anything" else "183"
        out(f"\u001b[1m\u001b[{color}m{item['skill']}\u001b[0m: ", 0.15)
        for index in range(0, len(item["text"]), 4):
            out(item["text"][index:index + 4], 0.03)
        out("\r\n", 0.25)
    out("\r\n\u001b[38;5;244m" + SESSION["footer"] + "\u001b[0m\r\n", 0.4)

    cast = {
        "version": 2,
        "width": 96,
        "height": 24,
        "timestamp": SESSION["timestamp"],
        "title": "dsh-rev-eng /rev-eng router demo",
        "env": {"SHELL": "/bin/zsh", "TERM": "xterm-256color"},
    }
    cast_path = DOCS / "rev-eng.cast"
    with cast_path.open("w") as handle:
        handle.write(json.dumps(cast) + "\n")
        for event in events:
            handle.write(json.dumps(event) + "\n")

    transcript = DOCS / "session.txt"
    answer_block = "\n".join(f"{item['skill']}: {item['text']}" for item in SESSION["answer"])
    transcript.write_text(
        "dsh-rev-eng \u2014 /rev-eng router demo\n"
        "\n"
        f"Captured: {SESSION['captured']} \u00b7 dsh 0.2.1-rc.3 \u00b7 model route: {SESSION['model_route']}\n"
        "\n"
        f"\u276f {SESSION['prompt_trigger']} {SESSION['prompt']}\n"
        "\n"
        f"{answer_block}\n"
        "\n"
        f"{SESSION['note']}\n"
    )

    print(f"wrote {gif.relative_to(ROOT)} ({len(frames)} frames, {gif.stat().st_size / 1024:.0f} KiB)")
    print(f"wrote {cast_path.relative_to(ROOT)} ({len(events)} events)")


if __name__ == "__main__":
    main()
