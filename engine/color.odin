package engine

Color :: struct {
	r, g, b, a: u8,
}


color :: #force_inline proc(r, g, b, a: u8) -> Color {
	return {r = r, g = g, b = b, a = a}
}

WHITE :: Color{255, 255, 255, 255}
BLACK :: Color{0, 0, 0, 255}
RED :: Color{255, 0, 0, 255}
GREEN :: Color{0, 255, 0, 255}
BLUE :: Color{0, 0, 255, 255}
YELLOW :: Color{255, 255, 0, 255}
CYAN :: Color{0, 255, 255, 255}
MAGENTA :: Color{255, 0, 255, 255}
LAVENDER :: Color{172, 158, 236, 255}

// assets/palette.aseprite
PAL_DARK :: Color{25, 27, 26, 255}
PAL_NAVY :: Color{41, 66, 87, 255}
PAL_TEAL :: Color{87, 156, 154, 255}
PAL_MINT :: Color{153, 201, 179, 255}

// microui default style base colors
MU_TEXT :: Color{230, 230, 230, 255}
MU_BORDER :: Color{25, 25, 25, 255}
MU_WINDOW_BG :: Color{50, 50, 50, 255}
MU_TITLE_BG :: Color{25, 25, 25, 255}
MU_TITLE_TEXT :: Color{240, 240, 240, 255}
MU_PANEL_BG :: Color{0, 0, 0, 0}
MU_BUTTON :: Color{75, 75, 75, 255}
MU_BUTTON_HOVER :: Color{95, 95, 95, 255}
MU_BUTTON_FOCUS :: Color{115, 115, 115, 255}
MU_BASE :: Color{30, 30, 30, 255}
MU_BASE_HOVER :: Color{35, 35, 35, 255}
MU_BASE_FOCUS :: Color{40, 40, 40, 255}
MU_SCROLL_BASE :: Color{43, 43, 43, 255}
MU_SCROLL_THUMB :: Color{30, 30, 30, 255}
