package engine

import clay "./vendor/clay-odin"
import "core:math"
import "core:mem"
import "core:strings"


clay_clear_render_commands :: proc(renderer: ^clay.ClayArray(clay.RenderCommand)) {
	mem.set(renderer, 0, size_of(renderer))
}

platform_clay_render_commands :: proc(
	cmdbuf: ^RenderCommandBuffer,
	clay_render_command_array: ^clay.ClayArray(clay.RenderCommand),
	state: ^GameState,
) {
	// always flush clay_render_commands, otherwise there
	// might be some still left on scene switches
	defer clay_clear_render_commands(clay_render_command_array)

	for i in 0 ..< clay_render_command_array.length {
		rcmd := clay.RenderCommandArray_Get(clay_render_command_array, i)
		bounding_box := rcmd.boundingBox
		bb_rect := rect(
			f64(bounding_box.x),
			f64(bounding_box.y),
			f64(bounding_box.width),
			f64(bounding_box.height),
		)

		switch rcmd.commandType {
		case .Rectangle:
			config := &rcmd.renderData.rectangle
			color := clay_color_to_engine(config.backgroundColor)
			cmd_draw_rect(cmdbuf, bb_rect, color)
		case .Text:
			config := &rcmd.renderData.text
			color := clay_color_to_engine(config.textColor)
			text := strings.clone(
				string(config.stringContents.chars[:config.stringContents.length]),
				state.scratch_allocator,
			)
			cmd_draw_text(cmdbuf, vector2(bb_rect.x, bb_rect.y), text, int(config.fontId), color)
		case .Border:
			config := &rcmd.renderData.border
			color := clay_color_to_engine(config.color)

			min_radius := math.min(bb_rect.width, bb_rect.height) / 2.0
			clamped_radii := clay.CornerRadius {
				topLeft     = math.min(config.cornerRadius.topLeft, f32(min_radius)),
				topRight    = math.min(config.cornerRadius.topRight, f32(min_radius)),
				bottomLeft  = math.min(config.cornerRadius.bottomLeft, f32(min_radius)),
				bottomRight = math.min(config.cornerRadius.bottomRight, f32(min_radius)),
			}

			if config.width.left > 0 {
				starting_y := bb_rect.y + f64(clamped_radii.topLeft)
				length :=
					bb_rect.height - f64(clamped_radii.topLeft) - f64(clamped_radii.bottomLeft)
				line := rect(bb_rect.x - 1, starting_y, f64(config.width.left), length)
				cmd_draw_rect(cmdbuf, line, color)
			}

			if config.width.right > 0 {
				starting_x := bb_rect.x + bb_rect.width - f64(config.width.right) + 1
				starting_y := bb_rect.y + f64(clamped_radii.topRight)
				length :=
					bb_rect.height - f64(clamped_radii.topRight) - f64(clamped_radii.bottomRight)
				line := rect(starting_x, starting_y, f64(config.width.right), length)
				cmd_draw_rect(cmdbuf, line, color)
			}

			if config.width.top > 0 {
				starting_x := bb_rect.x + f64(clamped_radii.topLeft)
				length := bb_rect.width - f64(clamped_radii.topLeft) - f64(clamped_radii.topRight)
				line := rect(starting_x, bb_rect.y - 1, length, f64(config.width.top))
				cmd_draw_rect(cmdbuf, line, color)
			}

			if config.width.bottom > 0 {
				starting_x := bb_rect.x + f64(clamped_radii.bottomLeft)
				starting_y := bb_rect.y + bb_rect.height - f64(config.width.bottom) + 1
				length :=
					bb_rect.width - f64(clamped_radii.bottomLeft) - f64(clamped_radii.bottomRight)
				line := rect(starting_x, starting_y, length, f64(config.width.bottom))
				cmd_draw_rect(cmdbuf, line, color)
			}

			if config.cornerRadius.topLeft > 0 {
				center_x := f32(bb_rect.x) + clamped_radii.topLeft - 1
				center_y := f32(bb_rect.y) + clamped_radii.topLeft - 1
				cmd_draw_arc(
					cmdbuf,
					vector2(f64(center_x), f64(center_y)),
					clamped_radii.topLeft,
					180.0,
					270.0,
					f32(config.width.top),
					color,
				)
			}

			if config.cornerRadius.topRight > 0 {
				center_x := f32(bb_rect.x) + f32(bb_rect.width) - clamped_radii.topRight
				center_y := f32(bb_rect.y) + clamped_radii.topRight - 1
				cmd_draw_arc(
					cmdbuf,
					vector2(f64(center_x), f64(center_y)),
					clamped_radii.topRight,
					270.0,
					360.0,
					f32(config.width.top),
					color,
				)
			}

			if config.cornerRadius.bottomLeft > 0 {
				center_x := f32(bb_rect.x) + clamped_radii.bottomLeft - 1
				center_y := f32(bb_rect.y) + f32(bb_rect.height) - clamped_radii.bottomLeft
				cmd_draw_arc(
					cmdbuf,
					vector2(f64(center_x), f64(center_y)),
					clamped_radii.bottomLeft,
					90.0,
					180.0,
					f32(config.width.bottom),
					color,
				)
			}

			if config.cornerRadius.bottomRight > 0 {
				center_x := f32(bb_rect.x) + f32(bb_rect.width) - clamped_radii.bottomRight
				center_y := f32(bb_rect.y) + f32(bb_rect.height) - clamped_radii.bottomRight
				cmd_draw_arc(
					cmdbuf,
					vector2(f64(center_x), f64(center_y)),
					clamped_radii.bottomRight,
					0.0,
					90.0,
					f32(config.width.bottom),
					color,
				)
			}

		case .ScissorStart:
			cmd_set_clipping_rect(cmdbuf, bb_rect)
		case .ScissorEnd:
			cmd_end_clipping_rect(cmdbuf)
		case .Image:
			texture := cast(^RenderCommandDrawSprite)rcmd.renderData.image.imageData
			if texture == nil do continue
			cmd_draw_sprite(
				cmdbuf,
				vector2(bb_rect.x, bb_rect.y),
				texture.scale,
				texture.rotation,
				texture.pivot,
				texture.texture,
				texture.texture_rect,
				texture.color,
				texture.flip_x,
				texture.flip_y,
			)
		case .OverlayColorStart:
		// TODO: implement

		case .OverlayColorEnd:
		// TODO: implement

		case .Custom:
			config := cast(^ClayCustomPtr)rcmd.renderData.custom.customData
			switch v in config {
			case ^ClayNineSliceFrame:
				// NOTE: explicitly cast pointer, otherwise it will segfault
				val := cast(^ClayNineSliceFrame)config
				clay_draw_sprite_frame(cmdbuf, val, bb_rect)
			}

		case .None:
		// TODO: implement

		case:
			state.platform.logger(.DEBUG, "Unknown render command type: %d", rcmd.commandType)
		}
	}
}

// command implementation so that it doesnt get messy

// clay_draw_sprite_frame will implement the 9 slice algorithm
// for dynamically drawing a frame on any size rectangle given
// a 9 slice sprite, for now, lets assume the 9 slice is 9 16x16 tiles
// the corners will be drawn as normal but the the others will be streched
// to fit the required space
clay_draw_sprite_frame :: proc(
	cmdbuf: ^RenderCommandBuffer,
	config: ^ClayNineSliceFrame,
	clay_rect: Rect,
) {

	start := config.origin

	// sprite tiles
	// top
	top_left := rect(start.x, start.y, f64(config.tile_size), f64(config.tile_size))
	top_middle := rect(
		start.x + f64(config.tile_size),
		start.y,
		f64(config.tile_size),
		f64(config.tile_size),
	)
	top_right := rect(
		start.x + 2 * f64(config.tile_size),
		start.y,
		f64(config.tile_size),
		f64(config.tile_size),
	)

	// middle
	middle_left := rect(
		start.x,
		start.y + f64(config.tile_size),
		f64(config.tile_size),
		f64(config.tile_size),
	)
	middle_middle := rect(
		start.x + f64(config.tile_size),
		start.y + f64(config.tile_size),
		f64(config.tile_size),
		f64(config.tile_size),
	)
	middle_right := rect(
		start.x + f64(config.tile_size) * 2,
		start.y + f64(config.tile_size),
		f64(config.tile_size),
		f64(config.tile_size),
	)

	// bottom
	bottom_left := rect(
		start.x,
		start.y + f64(config.tile_size) * 2,
		f64(config.tile_size),
		f64(config.tile_size),
	)
	bottom_middle := rect(
		start.x + f64(config.tile_size),
		start.y + f64(config.tile_size) * 2,
		f64(config.tile_size),
		f64(config.tile_size),
	)
	bottom_right := rect(
		start.x + f64(config.tile_size) * 2,
		start.y + f64(config.tile_size) * 2,
		f64(config.tile_size),
		f64(config.tile_size),
	)

	// top left
	cmd_draw_sprite(
		cmdbuf,
		vector2(clay_rect.x, clay_rect.y),
		f64(config.scale),
		0,
		vector2(0, 0),
		config.texture,
		top_left,
		WHITE,
		false,
		false,
	)

	// top right
	cmd_draw_sprite(
		cmdbuf,
		vector2(clay_rect.x + clay_rect.width - f64(config.tile_size * config.scale), clay_rect.y),
		f64(config.scale),
		0,
		vector2(0, 0),
		config.texture,
		top_right,
		WHITE,
		false,
		false,
	)

	// bottom left
	cmd_draw_sprite(
		cmdbuf,
		vector2(
			clay_rect.x,
			clay_rect.y + clay_rect.height - f64(config.tile_size * config.scale),
		),
		f64(config.scale),
		0,
		vector2(0, 0),
		config.texture,
		bottom_left,
		WHITE,
		false,
		false,
	)

	// bottom right
	cmd_draw_sprite(
		cmdbuf,
		vector2(
			clay_rect.x + clay_rect.width - f64(config.tile_size * config.scale),
			clay_rect.y + clay_rect.height - f64(config.tile_size * config.scale),
		),
		f64(config.scale),
		0,
		vector2(0, 0),
		config.texture,
		bottom_right,
		WHITE,
		false,
		false,
	)

	relative_width := clay_rect.width / f64(config.scale)
	relative_height := clay_rect.height / f64(config.scale)
	stretch_x := (relative_width - f64(config.tile_size) * 3) + 1
	stretch_y := (relative_height - f64(config.tile_size) * 3) + 1

	// top
	cmd_draw_sprite(
		cmdbuf,
		vector2(clay_rect.x + f64(config.tile_size * config.scale), clay_rect.y),
		f64(config.scale),
		0,
		vector2(0, 0),
		config.texture,
		top_middle,
		WHITE,
		false,
		false,
		int(stretch_x),
	)

	// bottom middle
	cmd_draw_sprite(
		cmdbuf,
		vector2(
			clay_rect.x + f64(config.tile_size * config.scale),
			clay_rect.y + clay_rect.height - f64(config.tile_size * config.scale),
		),
		f64(config.scale),
		0,
		vector2(0, 0),
		config.texture,
		bottom_middle,
		WHITE,
		false,
		false,
		int(stretch_x),
	)

	// middle left
	cmd_draw_sprite(
		cmdbuf,
		vector2(clay_rect.x, clay_rect.y + f64(config.tile_size * config.scale)),
		f64(config.scale),
		0,
		vector2(0, 0),
		config.texture,
		middle_left,
		WHITE,
		false,
		false,
		0,
		int(stretch_y),
	)

	// middle right
	cmd_draw_sprite(
		cmdbuf,
		vector2(
			clay_rect.x + clay_rect.width - f64(config.tile_size * config.scale),
			clay_rect.y + f64(config.tile_size * config.scale),
		),
		f64(config.scale),
		0,
		vector2(0, 0),
		config.texture,
		middle_right,
		WHITE,
		false,
		false,
		0,
		int(stretch_y),
	)

	// middle middle
	cmd_draw_sprite(
		cmdbuf,
		vector2(
			clay_rect.x + f64(config.tile_size * config.scale),
			clay_rect.y + f64(config.tile_size * config.scale),
		),
		f64(config.scale),
		0,
		vector2(0, 0),
		config.texture,
		middle_middle,
		WHITE,
		false,
		false,
		int(stretch_x),
		int(stretch_y),
	)

}
