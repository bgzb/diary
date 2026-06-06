# -*- coding: utf-8 -*-
# dmgbuild settings for Diary
# Executed by dmgbuild via exec() — defines globals control the DMG build.

# ── Background image (passed via -D from make_dmg.sh) ──
background = defines["bg_path"]

# ── Icon positions (600×400 window, centered with space for arrow between) ──
icon_locations = {
    "Diary.app": (160, 150),
    "Applications": (400, 150),
}

# ── Window ──
window_rect = ((400, 200), (600, 400))
default_view = "icon-view"
icon_size = 80

# ── Hide Finder chrome ──
show_toolbar = False
show_status_bar = False
show_pathbar = False
show_sidebar = False

# ── Label on bottom ──
label_pos = "bottom"

# ── Files ──
files = ["Diary.app"]
symlinks = {"Applications": "/Applications"}

# ── Format: UDZO (zlib compressed, best compatibility) ──
format = "UDZO"
compression_level = 9
