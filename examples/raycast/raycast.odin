/*

	 Example From: https://lodev.org/cgtutor/raycasting.html

	 Original License:

	 Copyright (c) 2004-2021, Lode Vandevenne

	 All rights reserved.

	 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 	 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 	 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

	 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
	 "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
	 LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
	 A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
	 CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
	 EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
	 PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
	 PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
	 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
	 NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
	 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/


package raycast

import "bento:engine"
import "bento:execute"
import "core:math"

// -- Globals -- //


// Game state that will hold relevant global data
// for the life of the game
state: ^engine.GameState

screen_width: int // width of the screen in pixels
screen_height: int // height of the screen in pixels

MAP_WIDTH :: 24
MAP_HEIGHT :: 24
WorldMap := [MAP_HEIGHT][MAP_WIDTH]int {
	{1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1},
	{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
	{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
	{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
	{1, 0, 0, 0, 0, 0, 2, 2, 2, 2, 2, 0, 0, 0, 0, 3, 0, 3, 0, 3, 0, 0, 0, 1},
	{1, 0, 0, 0, 0, 0, 2, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
	{1, 0, 0, 0, 0, 0, 2, 0, 0, 0, 2, 0, 0, 0, 0, 3, 0, 0, 0, 3, 0, 0, 0, 1},
	{1, 0, 0, 0, 0, 0, 2, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
	{1, 0, 0, 0, 0, 0, 2, 2, 0, 2, 2, 0, 0, 0, 0, 3, 0, 3, 0, 3, 0, 0, 0, 1},
	{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
	{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
	{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
	{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
	{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
	{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
	{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
	{1, 4, 4, 4, 4, 4, 4, 4, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
	{1, 4, 0, 4, 0, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
	{1, 4, 0, 0, 0, 0, 5, 0, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
	{1, 4, 0, 4, 0, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
	{1, 4, 0, 4, 4, 4, 4, 4, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
	{1, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
	{1, 4, 4, 4, 4, 4, 4, 4, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
	{1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1},
}

// player
position: engine.Vector2
direction: engine.Vector2
plane: engine.Vector2


// -- Main Loop -- //

main :: proc() {
	// main proc, set game function pointers
	platform_config := engine.PlatformConfig {
		title         = "raycast",
		window_width  = 800,
		window_height = 600,
		fullscreen    = false,
		scale_mode    = .NEAREST,
		logging_level = .VERBOSE,
	}

	game_data := execute.Game {
		platform_config = platform_config,
		game_init       = init,
		game_update     = update,
		game_render     = render,
		game_shutdown   = shutdown,
	}

	// start main loop
	execute.engine_run(&game_data)
}


// -- Game Functions -- //

init :: proc(platform: ^engine.Platform) {

	// create new instance of gamestate
	err: engine.Error
	state, err = engine.game_state_new(platform)
	if err != nil {
		panic(engine.fmt_error(err, context.temp_allocator))
	}

	// fill in screen_width and height
	screen_width, screen_height = state.platform.get_window_size()

	position.x, position.y = 22, 12
	direction.x, direction.y = -1, 0
	plane.x, plane.y = 0, 0.66
}

update :: proc(input: ^engine.GameInput, dt: f64) -> bool {


	move_speed := dt * 5.0
	rot_speed := dt * 3.0

	if engine.input_state(input, engine.InputType.INPUT_KEY_W) > 0 {
		if WorldMap[int(position.x + direction.x * move_speed)][int(position.y)] == 0 {
			position.x += direction.x * move_speed
		}

		if WorldMap[int(position.x)][int(position.y + direction.y * move_speed)] == 0 {
			position.y += direction.y * move_speed
		}
	}


	if engine.input_state(input, engine.InputType.INPUT_KEY_S) > 0 {
		if WorldMap[int(position.x - direction.x * move_speed)][int(position.y)] == 0 {
			position.x -= direction.x * move_speed
		}

		if WorldMap[int(position.x)][int(position.y - direction.y * move_speed)] == 0 {
			position.y -= direction.y * move_speed
		}
	}

	if engine.input_state(input, engine.InputType.INPUT_KEY_D) > 0 {

		old_dir_x := direction.x

		direction.x = direction.x * math.cos(-rot_speed) - direction.y * math.sin(-rot_speed)
		direction.y = old_dir_x * math.sin(-rot_speed) + direction.y * math.cos(-rot_speed)
		old_plane_x := plane.x
		plane.x = plane.x * math.cos(-rot_speed) - plane.y * math.sin(-rot_speed)
		plane.y = old_plane_x * math.sin(-rot_speed) + plane.y * math.cos(-rot_speed)

	}

	if engine.input_state(input, engine.InputType.INPUT_KEY_A) > 0 {

		old_dir_x := direction.x

		direction.x = direction.x * math.cos(rot_speed) - direction.y * math.sin(rot_speed)
		direction.y = old_dir_x * math.sin(rot_speed) + direction.y * math.cos(rot_speed)
		old_plane_x := plane.x
		plane.x = plane.x * math.cos(rot_speed) - plane.y * math.sin(rot_speed)
		plane.y = old_plane_x * math.sin(rot_speed) + plane.y * math.cos(rot_speed)

	}

	return true
}

render :: proc() -> ^engine.RenderCommandBuffer {
	// reset command buffer, it is being allocated in the hot loop
	// resetting here makes sure that memory doesnt build up
	engine.cmd_reset(state.cmdbuf)

	// flush screen with a blank color
	engine.cmd_clear_screen(state.cmdbuf, engine.BLACK)

	// floor
	engine.cmd_draw_rect(
		state.cmdbuf,
		engine.rect(0, f64(screen_height / 2), f64(screen_width), f64(screen_height / 2)),
		engine.MU_BASE,
	)

	for x in 0 ..< screen_width {

		camera_x := 2 * f64(x) / f64(screen_width) - 1
		ray_dir := engine.vector2(
			direction.x + plane.x * camera_x,
			direction.y + plane.y * camera_x,
		)

		map_x, map_y := int(position.x), int(position.y)

		delta_dist_x := (ray_dir.x == 0) ? 1e30 : math.abs(1 / ray_dir.x)
		delta_dist_y := (ray_dir.y == 0) ? 1e30 : math.abs(1 / ray_dir.y)

		hit := 0
		step_x := 0
		step_y := 0
		side := 0
		side_dist_x: f64 = 0
		side_dist_y: f64 = 0

		perp_wall_dist: f64 = 0

		if ray_dir.x < 0 {
			step_x = -1
			side_dist_x = (position.x - f64(map_x)) * delta_dist_x
		} else {
			step_x = 1
			side_dist_x = (f64(map_x) + 1 - position.x) * delta_dist_x
		}

		if ray_dir.y < 0 {
			step_y = -1
			side_dist_y = (position.y - f64(map_y)) * delta_dist_y
		} else {
			step_y = 1
			side_dist_y = (f64(map_y) + 1 - position.y) * delta_dist_y
		}

		for hit == 0 {
			if side_dist_x < side_dist_y {

				side_dist_x += delta_dist_x
				map_x += step_x
				side = 0

			} else {
				side_dist_y += delta_dist_y
				map_y += step_y
				side = 1
			}

			if WorldMap[map_x][map_y] > 0 {
				hit = 1
			}
		}

		if side == 0 {
			perp_wall_dist = (side_dist_x - delta_dist_x)
		} else {
			perp_wall_dist = (side_dist_y - delta_dist_y)
		}


		line_height := int(f64(screen_height) / perp_wall_dist)

		draw_start := -line_height / 2 + screen_height / 2
		if draw_start < 0 {
			draw_start = 0
		}

		draw_end := line_height / 2 + screen_height / 2
		if draw_end >= screen_height {
			draw_end = screen_height - 1
		}

		color: engine.Color
		switch WorldMap[map_x][map_y] {
		case 1:
			color = engine.RED
		case 2:
			color = engine.GREEN
		case 3:
			color = engine.BLUE
		case 4:
			color = engine.WHITE
		case:
			color = engine.YELLOW
		}

		if side == 1 {
			color = engine.color(color.r / 2, color.g / 2, color.b / 2, color.a)
		}

		engine.cmd_draw_line(state.cmdbuf, f64(x), f64(draw_start), f64(x), f64(draw_end), color)
	}

	engine.cmd_draw_debug_text(
		state.cmdbuf,
		engine.vector2(10, 10),
		"move with w/s, rotate with a/d",
		2,
		engine.WHITE,
	)

	return state.cmdbuf
}

shutdown :: proc() {
	// free state
	engine.game_state_destroy(state)
}
