/*
  This software is based on bump.lua by Enrique García Cota
  https://github.com/kikito/bump.lua

  MIT License
  Copyright (c) 2014 Enrique García Cota

  Modifications by Brandon Skewes, 2026:
  - Ported to Odin

  Original License:

  MIT LICENSE

  Copyright (c) 2014 Enrique García Cota

  Permission is hereby granted, free of charge, to any person obtaining a
  copy of this software and associated documentation files (the
  "Software"), to deal in the Software without restriction, including
  without limitation the rights to use, copy, modify, merge, publish,
  distribute, sublicense, and/or sell copies of the Software, and to
  permit persons to whom the Software is furnished to do so, subject to
  the following conditions:

  The above copyright notice and this permission notice shall be included
  in all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
  OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
  CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
  TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
  SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

package engine

import "core:fmt"
import "core:math"
import "core:mem"
import "core:slice"
import "core:testing"

/*
   Constants
*/
DELTA :: 1e-10


/*
   Types
*/

ItemId :: distinct int

ResponseType :: enum {
	None,
	Touch,
	Slide,
	Cross,
	Bounce,
}

RectDetectCollision :: struct {
	Overlaps:  bool,
	ti:        f64,
	move:      Vector2,
	normal:    Vector2,
	touch:     Vector2,
	itemRect:  Rect,
	otherRect: Rect,
}

Collision :: struct {
	item:      ItemId,
	other:     ItemId,
	type:      ResponseType,
	overlaps:  bool,
	ti:        f64,
	move:      Vector2,
	normal:    Vector2,
	touch:     Vector2,
	itemRect:  Rect,
	otherRect: Rect,
	slide:     Vector2,
	bounce:    Vector2,
}

Filter :: proc(filter_ctx: ^FilterContext, item, other_item: ItemId) -> (ResponseType, bool)

FilterContext :: struct {
	ignored: map[ItemId]bool,
}


/*
   Auxiliary Functions
*/

@(private)
sign :: #force_inline proc(x: f64) -> int {
	if x > 0 do return 1
	if x == 0 do return 0
	return -1
}

@(private)
nearest :: #force_inline proc(x, a, b: f64) -> f64 {
	if math.abs(a - x) > math.abs(b - x) {
		return b
	}
	return a
}

@(private)
default_filter :: proc(
	filter_ctx: ^FilterContext,
	item, other_item: ItemId,
) -> (
	ResponseType,
	bool,
) {
	return .Slide, true
}

@(private)
cross_filter :: proc(
	filter_ctx: ^FilterContext,
	item, other_item: ItemId,
) -> (
	ResponseType,
	bool,
) {
	return .Cross, true
}

/*
   Rectangle Functions
*/
@(private)
rect_get_nearest_corner :: proc(x, y, w, h, px, py: f64) -> (f64, f64) {
	return nearest(px, x, x + w), nearest(py, y, y + h)
}

rect_get_segment_intersection_indicies :: proc(
	x, y, w, h, x1, y1, x2, y2: f64,
	ti1: f64 = 0,
	ti2: f64 = 1,
) -> (
	f64,
	f64,
	f64,
	f64,
	f64,
	f64,
	bool,
) {
	dx, dy := x2 - x1, y2 - y1
	ti1, ti2 := ti1, ti2
	nx, ny: f64
	nx1, ny1, nx2, ny2: f64
	p, q, r: f64

	for side in 0 ..< 4 {
		if side == 0 {
			nx, ny, p, q = -1, 0, -dx, x1 - x
		} else if side == 1 {
			nx, ny, p, q = 1, 0, dx, x + w - x1
		} else if side == 2 {
			nx, ny, p, q = 0, -1, -dy, y1 - y
		} else {
			nx, ny, p, q = 0, 1, dy, y + h - y1
		}
		if p == 0 {
			if q <= 0 do return 0, 0, 0, 0, 0, 0, false
		} else {
			r = q / p
			if p < 0 {
				if r > ti2 {
					return 0, 0, 0, 0, 0, 0, false
				} else if r > ti1 {
					ti1, nx1, ny1 = r, nx, ny
				}
			} else {
				if r < ti1 {
					return 0, 0, 0, 0, 0, 0, false
				} else if r < ti2 {
					ti2, nx2, ny2 = r, nx, ny
				}
			}
		}
	}

	return ti1, ti2, nx1, ny1, nx2, ny2, true
}

rect_get_diff :: #force_inline proc(x1, y1, w1, h1, x2, y2, w2, h2: f64) -> (f64, f64, f64, f64) {
	return x2 - x1 - w1, y2 - y1 - h1, w1 + w2, h1 + h2
}


rect_contains_point :: #force_inline proc(x, y, w, h, px, py: f64) -> bool {
	return px - x > DELTA && py - y > DELTA && x + w - px > DELTA && y + h - py > DELTA
}

rect_is_intersecting :: #force_inline proc(x1, y1, w1, h1, x2, y2, w2, h2: f64) -> bool {
	return x1 < x2 + w2 && x2 < x1 + w1 && y1 < y2 + h2 && y2 < y1 + h1
}

rect_get_square_distance :: proc(x1, y1, w1, h1, x2, y2, w2, h2: f64) -> f64 {
	dx := x1 - x2 + (w1 - w2) / 2
	dy := y1 - y2 + (h1 - h2) / 2
	return dx * dx + dy * dy
}

rect_detect_collision :: proc(
	x1, y1, w1, h1, x2, y2, w2, h2: f64,
	goalX: f64 = 0,
	goalY: f64 = 0,
) -> (
	RectDetectCollision,
	bool,
) {
	goalX := goalX
	goalY := goalY


	dx, dy := goalX - x1, goalY - y1
	x, y, w, h := rect_get_diff(x1, y1, w1, h1, x2, y2, w2, h2)

	tx, ty: f64
	nx, ny: f64

	hit := false

	ti, ti1, ti2, nx1, ny1: f64
	overlaps: bool
	if rect_contains_point(x, y, w, h, 0, 0) {
		px, py := rect_get_nearest_corner(x, y, w, h, 0, 0)
		wi, hi := math.min(w1, math.abs(px)), math.min(h1, math.abs(py))

		ti = -wi * hi
		overlaps = true
		hit = true
	} else {
		ok := false
		ti1, ti2, nx1, ny1, _, _, ok = rect_get_segment_intersection_indicies(
			x,
			y,
			w,
			h,
			0,
			0,
			dx,
			dy,
			-math.INF_F64,
			math.INF_F64,
		)
		if ok &&
		   ti1 < 1 &&
		   math.abs(ti1 - ti2) >= DELTA &&
		   (0 <= ti1 + DELTA || 0 == ti1 && ti2 > 0) {
			ti, nx, ny = ti1, nx1, ny1
			overlaps = false
			hit = true
		}
	}

	if !hit do return RectDetectCollision{}, false

	if overlaps {
		if dx == 0 && dy == 0 {
			px, py := rect_get_nearest_corner(x, y, w, h, 0, 0)
			if math.abs(px) < math.abs(py) {
				py = 0
			} else {
				px = 0
			}
			nx, ny = f64(sign(px)), f64(sign(py))
			tx, ty = x1 + px, y1 + py
		} else {
			ok := false
			ti1, _, nx, ny, _, _, ok = rect_get_segment_intersection_indicies(
				x,
				y,
				w,
				h,
				0,
				0,
				dx,
				dy,
				-math.INF_F64,
				1,
			)
			if !ok do return RectDetectCollision{}, false
			tx, ty = x1 + dx * ti1, y1 + dy * ti1
		}
	} else {
		tx, ty = x1 + dx * ti, y1 + dy * ti
	}

	return RectDetectCollision {
			Overlaps = overlaps,
			ti = ti,
			move = vector2(dx, dy),
			normal = vector2(nx, ny),
			touch = vector2(tx, ty),
			itemRect = rect(x1, y1, w1, h1),
			otherRect = rect(x2, y2, w2, h2),
		},
		true
}

/*
   Grid Functions
*/

grid_to_world :: #force_inline proc(cell_size, cx, cy: f64) -> (f64, f64) {
	return (cx - 1) * cell_size, (cy - 1) * cell_size
}

grid_to_cell :: #force_inline proc(cell_size, x, y: f64) -> (f64, f64) {
	return math.floor(x / cell_size) + 1, math.floor(y / cell_size) + 1
}

grid_traverse_init_step :: proc(cell_size, ct, t1, t2: f64) -> (f64, f64, f64) {
	v := t2 - t1
	if v > 0 {
		return 1, cell_size / v, ((ct + v) * cell_size - t1) / v
	} else if v < 0 {
		return -1, -cell_size / v, ((ct + v - 1) * cell_size - t1) / v
	} else {
		return 0, math.INF_F64, math.INF_F64
	}
}


grid_traverse :: proc(cell_size, x1, y1, x2, y2: f64, f: proc(_: f64, _: f64)) {
	cx1, cy1 := grid_to_cell(cell_size, x1, y1)
	cx2, cy2 := grid_to_cell(cell_size, x2, y2)
	stepX, dx, tx := grid_traverse_init_step(cell_size, cx1, x1, x2)
	stepY, dy, ty := grid_traverse_init_step(cell_size, cy1, y1, y2)
	cx, cy := cx1, cy1
	f(cx, cy)

	for (math.abs(cx - cx2) + math.abs(cy - cy2) > 1) {
		if tx < ty {
			tx, cx = tx + dx, cx + stepX
			f(cx, cy)
		} else {
			if tx == ty do f(cx + stepX, cy)
			ty, cy = ty + dy, cy + stepY
			f(cx, cy)
		}
	}
	if cx != cx2 || cy != cy2 do f(cx2, cy2)
}

grid_to_cell_rect :: proc(cell_size, x, y, w, h: f64) -> (int, int, int, int) {
	cx, cy := grid_to_cell(cell_size, x, y)
	cr, cb := math.ceil((x + w) / cell_size), math.ceil((y + h) / cell_size)
	return int(cx), int(cy), int(cr - cx + 1), int(cb - cy + 1)
}

/*
   Responses 
*/

@(private)
Response :: proc(
	world: ^World,
	col: ^Collision,
	x, y, w, h, goal_x, goal_y: f64,
	filter: Filter,
	filter_context: ^FilterContext,
) -> (
	f64,
	f64,
	[dynamic]Collision,
	int,
)

@(private)
response_touch :: proc(
	world: ^World,
	col: ^Collision,
	x, y, w, h, goal_x, goal_y: f64,
	filter: Filter,
	filter_ctx: ^FilterContext,
) -> (
	f64,
	f64,
	[dynamic]Collision,
	int,
) {
	cols := make([dynamic]Collision)
	return col.touch.x, col.touch.y, cols, 0
}

@(private)
response_cross :: proc(
	world: ^World,
	col: ^Collision,
	x, y, w, h, goal_x, goal_y: f64,
	filter: Filter,
	filter_ctx: ^FilterContext,
) -> (
	f64,
	f64,
	[dynamic]Collision,
	int,
) {
	cols, col_len := world_project(world, col.item, x, y, w, h, goal_x, goal_y, filter, filter_ctx)
	return goal_x, goal_y, cols, col_len
}

@(private)
response_slide :: proc(
	world: ^World,
	col: ^Collision,
	x, y, w, h, goal_x, goal_y: f64,
	filter: Filter,
	filter_ctx: ^FilterContext,
) -> (
	f64,
	f64,
	[dynamic]Collision,
	int,
) {
	goal_x := goal_x
	goal_y := goal_y
	x, y := x, y

	tch, move := col.touch, col.move
	if move.x != 0 || move.y != 0 {
		if col.normal.x != 0 {
			goal_x = tch.x
		} else {
			goal_y = tch.y
		}
	}

	col.slide = vector2(goal_x, goal_y)
	x, y = tch.x, tch.y
	cols, colLen := world_project(world, col.item, x, y, w, h, goal_x, goal_y, filter, filter_ctx)
	return goal_x, goal_y, cols, colLen
}

@(private)
get_response_by_type :: proc(response_type: ResponseType) -> Response {
	#partial switch response_type {
	case .Touch:
		return response_touch
	case .Cross:
		return response_cross
	case .Slide:
		return response_slide
	case:
		panic("failed to get response")
	}
}


/*
   World
*/

SegmentInfo :: struct {
	item: ItemId,
	ti1:  f64,
	ti2:  f64,
	x1:   f64,
	y1:   f64,
	x2:   f64,
	y2:   f64,
}

Cell :: struct {
	item_count: int,
	x:          int,
	y:          int,
	items:      map[ItemId]bool,
}

World :: struct {
	cell_size:       f64,
	rects:           map[ItemId]Rect,
	rows:            map[int]map[int]^Cell,
	non_empty_cells: map[^Cell]bool,
	responses:       map[string]ResponseType,
	allocator:       mem.Allocator,
	_next_id:        ItemId,
}

world_new :: proc(cell_size: f64 = 64, allocator := context.allocator) -> ^World {
	world := new(World, allocator)

	world.rects = make(map[ItemId]Rect, allocator)
	world.rows = make(map[int]map[int]^Cell, allocator)
	world.non_empty_cells = make(map[^Cell]bool, allocator)
	world.responses = make(map[string]ResponseType, allocator)
	world.cell_size = cell_size
	world.allocator = allocator
	world._next_id = ItemId(1)
	return world
}

world_destroy :: proc(world: ^World) {
	if world == nil do return

	allocator := world.allocator

	for _, row in world.rows {
		for _, cell in row {
			if cell != nil {
				delete(cell.items)
				free(cell, allocator)
			}
		}

		delete(row)
	}

	delete(world.rects)
	delete(world.rows)
	delete(world.non_empty_cells)
	delete(world.responses)

	free(world, allocator)
}

@(private)
world_add_item_to_cell :: proc(world: ^World, item: ItemId, cx, cy: int) {
	allocator := world.allocator
	row, rok := world.rows[cy]
	if !rok {
		row = make(map[int]^Cell, allocator)
		world.rows[cy] = row
	}

	cell, cok := row[cx]
	if !cok {
		cell = new(Cell, allocator)
		cell.item_count = 0
		cell.x = cx
		cell.y = cy
		cell.items = make(map[ItemId]bool, allocator)

		row[cx] = cell
		world.rows[cy] = row
	}

	world.non_empty_cells[cell] = true
	_, iok := cell.items[item]
	if !iok {
		cell.items[item] = true
		cell.item_count += 1
	}
}

@(private)
world_remove_item_from_cell :: proc(world: ^World, item: ItemId, cx, cy: int) -> bool {

	row, row_ok := world.rows[cy]
	if !row_ok {
		return false
	}

	cell, cell_ok := row[cx]
	if !cell_ok || cell == nil {
		return false
	}

	_, ok := cell.items[item]
	if !ok {
		return false
	}

	delete_key(&cell.items, item)
	cell.item_count -= 1

	if cell.item_count == 0 {
		delete_key(&world.non_empty_cells, cell)
	}
	return true
}

@(private)
world_get_dict_items_in_cell_rect :: proc(world: ^World, cl, ct, cw, ch: int) -> map[ItemId]bool {

	items_dict := make(map[ItemId]bool)

	for cy in ct ..< ct + ch {
		row, row_ok := world.rows[cy]
		if row_ok {
			for cx in cl ..< cl + cw {
				cell, cell_ok := row[cx]
				if cell_ok && cell != nil {
					if cell.item_count > 0 {
						for item, _ in cell.items {
							items_dict[item] = true
						}
					}
				}
			}
		}
	}

	return items_dict
}

world_add :: proc(world: ^World, x, y, w, h: f64) -> (ItemId, bool) {

	item := world._next_id
	world._next_id += 1

	_, r_ok := world.rects[item]
	if r_ok {
		fmt.eprintf("Item: %d added to the world twice\n", int(item))
		return ItemId(0), false
	}
	r := rect(x, y, w, h)
	assert_rect(r)

	world.rects[item] = r

	cl, ct, cw, ch := grid_to_cell_rect(world.cell_size, x, y, w, h)
	for cy in ct ..< ct + ch {
		for cx in cl ..< cl + cw {
			world_add_item_to_cell(world, item, cx, cy)
		}
	}

	return item, true
}

world_get_rect :: proc(world: ^World, item: ItemId) -> (Rect, bool) {
	r, rok := world.rects[item]
	if !rok {
		fmt.eprintf("Item %d not found\n", int(item))
		return Rect{}, false
	}

	return r, true
}

world_remove :: proc(world: ^World, item: ItemId) -> bool {
	r, rok := world_get_rect(world, item)
	if !rok {
		return false
	}

	delete_key(&world.rects, item)
	cl, ct, cw, ch := grid_to_cell_rect(world.cell_size, r.x, r.y, r.width, r.height)
	for cy in ct ..< ct + ch {
		for cx in cl ..< cl + cw {
			world_remove_item_from_cell(world, item, cx, cy)
		}
	}
	return true
}

world_update :: proc(world: ^World, item: ItemId, x2, y2, w2, h2: f64) {
	r, rok := world_get_rect(world, item)
	if !rok {
		fmt.eprintf("Item not found: %d\n", int(item))
		return
	}

	x1, y1, w1, h1 := r.x, r.y, r.width, r.height

	w2 := w2
	h2 := h2
	if w2 == 0 do w2 = w1
	if h2 == 0 do h2 = h1

	assert_rect(rect(x2, y2, w2, h2))
	if x1 != x2 || y1 != y2 || w1 != w2 || h1 != h2 {
		cell_size := world.cell_size
		cl1, ct1, cw1, ch1 := grid_to_cell_rect(cell_size, x1, y1, w1, h1)
		cl2, ct2, cw2, ch2 := grid_to_cell_rect(cell_size, x2, y2, w2, h2)

		if cl1 != cl2 || ct1 != ct2 || cw1 != cw2 || ch1 != ch2 {
			cr1, cb1 := cl1 + cw1 - 1, ct1 + ch1 - 1
			cr2, cb2 := cl2 + cw2 - 1, ct2 + ch2 - 1

			cy_out: bool
			for cy in ct1 ..< cb1 + 1 {
				cy_out = cy < ct2 || cy > cb2
				for cx in cl1 ..< cr1 + 1 {
					if cy_out || cx < cl2 || cx > cr2 {
						world_remove_item_from_cell(world, item, cx, cy)
					}
				}
			}

			for cy in ct2 ..< cb2 + 1 {
				cy_out = cy < ct1 || cy > cb1
				for cx in cl2 ..< cr2 + 1 {
					if cy_out || cx < cl1 || cx > cr1 {
						world_add_item_to_cell(world, item, cx, cy)
					}
				}
			}
		}
		world.rects[item] = rect(x2, y2, w2, h2)
	}
}

world_has_item :: proc(world: ^World, item: ItemId) -> bool {
	_, rok := world.rects[item]
	if !rok {
		return false
	}
	return true
}

world_count_items :: proc(world: ^World) -> int {
	return len(world.rects)
}

world_count_cells :: proc(world: ^World) -> int {
	count := 0
	for _, row in world.rows {
		count += len(row)
	}
	return count
}

world_get_items :: proc(world: ^World) -> ([dynamic]ItemId, int) {
	items := make([dynamic]ItemId)
	for item, _ in world.rects {
		append(&items, item)
	}
	return items, len(items)
}

world_to_world :: proc(world: ^World, cx, cy: f64) -> (f64, f64) {
	return grid_to_world(world.cell_size, cx, cy)
}

world_to_cell :: proc(world: ^World, x, y: f64) -> (f64, f64) {
	return grid_to_cell(world.cell_size, x, y)
}

// TODO: add filters
world_query_rect :: proc(world: ^World, x, y, w, h: f64) -> ([dynamic]ItemId, int) {
	assert_rect(rect(x, y, w, h))


	cl, ct, cw, ch := grid_to_cell_rect(world.cell_size, x, y, w, h)
	dict_items_in_cell_rect := world_get_dict_items_in_cell_rect(world, cl, ct, cw, ch)
	defer delete(dict_items_in_cell_rect)

	items := make([dynamic]ItemId)

	for item, _ in dict_items_in_cell_rect {
		r, ok := world.rects[item]
		if !ok do continue

		if (rect_is_intersecting(x, y, w, h, r.x, r.y, r.width, r.height)) {
			append(&items, item)
		}
	}

	return items, len(items)
}

world_query_point :: proc(world: ^World, x, y: f64) -> ([dynamic]ItemId, int) {

	cx, cy := world_to_cell(world, x, y)
	dict_items_in_cell_rect := world_get_dict_items_in_cell_rect(world, int(cx), int(cy), 1, 1)
	defer delete(dict_items_in_cell_rect)

	items := make([dynamic]ItemId)

	for item, _ in dict_items_in_cell_rect {
		r, ok := world.rects[item]
		if !ok do continue

		if (rect_contains_point(r.x, r.y, r.width, r.height, x, y)) {
			append(&items, item)
		}
	}

	return items, len(items)
}

world_project :: proc(
	world: ^World,
	item: ItemId,
	x, y, w, h, goal_x, goal_y: f64,
	filter: Filter,
	filter_ctx: ^FilterContext,
) -> (
	[dynamic]Collision,
	int,
) {
	assert_rect(rect(x, y, w, h))

	collisions := make([dynamic]Collision)

	visited := make(map[ItemId]bool)
	defer delete(visited)


	tl, tt := math.min(goal_x, x), math.min(goal_y, y)
	tr, tb := math.max(goal_x + w, x + w), math.max(goal_y + h, y + h)
	tw, th := tr - tl, tb - tt

	cl, ct, cw, ch := grid_to_cell_rect(world.cell_size, tl, tt, tw, th)
	dict_items_in_cell_rect := world_get_dict_items_in_cell_rect(world, cl, ct, cw, ch)
	defer delete(dict_items_in_cell_rect)

	for other, _ in dict_items_in_cell_rect {
		_, visited_ok := visited[other]
		if !visited_ok {
			visited[other] = true

			if filter_ctx != nil && filter_ctx.ignored != nil {
				_, ignored := filter_ctx.ignored[other]
				if ignored do continue
			}

			response_name, response_ok := filter(filter_ctx, item, other)
			if response_ok && response_name != .None {
				or, orok := world_get_rect(world, other)
				if !orok {
					continue
				}

				col, col_ok := rect_detect_collision(
					x,
					y,
					w,
					h,
					or.x,
					or.y,
					or.width,
					or.height,
					goal_x,
					goal_y,
				)

				if !col_ok {
					continue
				}

				append(
					&collisions,
					Collision {
						item = item,
						other = other,
						type = response_name,
						overlaps = col.Overlaps,
						ti = col.ti,
						move = col.move,
						normal = col.normal,
						touch = col.touch,
						itemRect = col.itemRect,
						otherRect = col.otherRect,
					},
				)
			}
		}
	}

	slice.sort_by(collisions[:], world_sort_by_ti_and_distance)
	return collisions, len(collisions)
}

@(private)
world_sort_by_ti_and_distance :: proc(a, b: Collision) -> bool {
	if a.ti == b.ti {
		ir := a.itemRect
		ar := a.otherRect
		br := b.otherRect

		ad := rect_get_square_distance(
			ir.x,
			ir.y,
			ir.width,
			ir.height,
			ar.x,
			ar.y,
			ar.width,
			ar.height,
		)

		bd := rect_get_square_distance(
			ir.x,
			ir.y,
			ir.width,
			ir.height,
			br.x,
			br.y,
			br.width,
			br.height,
		)

		return ad < bd
	}

	return a.ti < b.ti
}

world_check :: proc(
	world: ^World,
	item: ItemId,
	goal_x, goal_y: f64,
	filter: Filter,
) -> (
	f64,
	f64,
	[dynamic]Collision,
	int,
	bool,
) {

	cols := make([dynamic]Collision)
	r, ok := world_get_rect(world, item)
	if !ok {
		return goal_x, goal_y, cols, len(cols), false
	}

	goal_x, goal_y := goal_x, goal_y
	x, y := r.x, r.y
	w, h := r.width, r.height


	filter_ctx := FilterContext {
		ignored = make(map[ItemId]bool),
	}
	defer delete(filter_ctx.ignored)

	filter_ctx.ignored[item] = true

	projected_cols, projected_len := world_project(
		world,
		item,
		x,
		y,
		w,
		h,
		goal_x,
		goal_y,
		filter,
		&filter_ctx,
	)
	defer delete(projected_cols)

	for projected_len > 0 {
		col := projected_cols[0]

		append(&cols, col)
		col_ptr := &cols[len(cols) - 1]

		filter_ctx.ignored[col.other] = true

		response := get_response_by_type(col.type)

		delete(projected_cols)

		new_goal_x, new_goal_y, new_projected_cols, new_projected_len := response(
			world,
			col_ptr,
			x,
			y,
			w,
			h,
			goal_x,
			goal_y,
			filter,
			&filter_ctx,
		)

		goal_x = new_goal_x
		goal_y = new_goal_y
		projected_cols = new_projected_cols
		projected_len = new_projected_len
	}


	return goal_x, goal_y, cols, len(cols), true
}

world_move :: proc(
	world: ^World,
	item: ItemId,
	goal_x, goal_y: f64,
	filter: Filter = default_filter,
) -> (
	f64,
	f64,
	[dynamic]Collision,
	int,
	bool,
) {
	actual_x, actual_y, cols, col_len, ok := world_check(world, item, goal_x, goal_y, filter)

	if !ok {
		return actual_x, actual_y, cols, col_len, false
	}

	world_update(world, item, actual_x, actual_y, 0, 0)

	return actual_x, actual_y, cols, col_len, true
}

// debug purposes
world_draw :: proc(world: ^World, cmdbuf: ^RenderCommandBuffer) {
	for _, item in world.rects {
		cmd_draw_rect_line(cmdbuf, item, color(255, 0, 0, 255))
	}
}


/*
   Tests
*/

@(private)
approx_eq :: proc(a, b: f64, eps: f64 = 0.0001) -> bool {
	return math.abs(a - b) <= eps
}

@(private)
expect_f64 :: proc(t: ^testing.T, actual, expected: f64) {
	testing.expect(t, approx_eq(actual, expected))
}

@(test)
test_rect_get_diff :: proc(t: ^testing.T) {
	x, y, w, h := rect_get_diff(0, 0, 10, 10, 20, 5, 5, 5)

	expect_f64(t, x, 10)
	expect_f64(t, y, -5)
	expect_f64(t, w, 15)
	expect_f64(t, h, 15)
}

@(test)
test_rect_contains_point_strictly_inside :: proc(t: ^testing.T) {
	testing.expect(t, rect_contains_point(10, 20, 30, 40, 20, 30))
}

@(test)
test_rect_contains_point_rejects_edges :: proc(t: ^testing.T) {
	testing.expect(t, !rect_contains_point(10, 20, 30, 40, 10, 30))
	testing.expect(t, !rect_contains_point(10, 20, 30, 40, 40, 30))
	testing.expect(t, !rect_contains_point(10, 20, 30, 40, 20, 20))
	testing.expect(t, !rect_contains_point(10, 20, 30, 40, 20, 60))
}

@(test)
test_rect_is_intersecting :: proc(t: ^testing.T) {
	testing.expect(t, rect_is_intersecting(0, 0, 10, 10, 5, 5, 10, 10))
}

@(test)
test_rect_is_intersecting_rejects_touching_edges :: proc(t: ^testing.T) {
	testing.expect(t, !rect_is_intersecting(0, 0, 10, 10, 10, 0, 10, 10))
	testing.expect(t, !rect_is_intersecting(0, 0, 10, 10, 0, 10, 10, 10))
}

@(test)
test_rect_get_square_distance_same_size :: proc(t: ^testing.T) {
	d := rect_get_square_distance(0, 0, 10, 10, 10, 0, 10, 10)
	expect_f64(t, d, 100)
}

@(test)
test_segment_intersection_left_to_right :: proc(t: ^testing.T) {
	ti1, ti2, nx1, ny1, nx2, ny2, ok := rect_get_segment_intersection_indicies(
		10,
		10,
		20,
		20,
		0,
		20,
		40,
		20,
		0,
		1,
	)

	testing.expect(t, ok)
	expect_f64(t, ti1, 0.25)
	expect_f64(t, ti2, 0.75)
	expect_f64(t, nx1, -1)
	expect_f64(t, ny1, 0)
	expect_f64(t, nx2, 1)
	expect_f64(t, ny2, 0)
}

@(test)
test_segment_intersection_top_to_bottom :: proc(t: ^testing.T) {
	ti1, ti2, nx1, ny1, nx2, ny2, ok := rect_get_segment_intersection_indicies(
		10,
		10,
		20,
		20,
		20,
		0,
		20,
		40,
		0,
		1,
	)

	testing.expect(t, ok)
	expect_f64(t, ti1, 0.25)
	expect_f64(t, ti2, 0.75)
	expect_f64(t, nx1, 0)
	expect_f64(t, ny1, -1)
	expect_f64(t, nx2, 0)
	expect_f64(t, ny2, 1)
}

@(test)
test_segment_misses_rect :: proc(t: ^testing.T) {
	_, _, _, _, _, _, ok := rect_get_segment_intersection_indicies(
		10,
		10,
		20,
		20,
		0,
		0,
		40,
		0,
		0,
		1,
	)

	testing.expect(t, !ok)
}

@(test)
test_rect_detect_collision_tunnel :: proc(t: ^testing.T) {
	col, ok := rect_detect_collision(0, 0, 10, 10, 20, 0, 10, 10, 30, 0)

	testing.expect(t, ok)
	testing.expect(t, !col.Overlaps)
	expect_f64(t, col.ti, 1.0 / 3.0)
	expect_f64(t, col.normal.x, -1)
	expect_f64(t, col.normal.y, 0)
	expect_f64(t, col.touch.x, 10)
	expect_f64(t, col.touch.y, 0)
}

@(test)
test_rect_detect_collision_overlap_stationary :: proc(t: ^testing.T) {
	col, ok := rect_detect_collision(0, 0, 10, 10, 5, 0, 10, 10, 0, 0)

	testing.expect(t, ok)
	testing.expect(t, col.Overlaps)
	testing.expect(t, col.ti < 0)
	expect_f64(t, col.touch.x, -5)
	expect_f64(t, col.touch.y, 0)
	expect_f64(t, col.normal.x, -1)
	expect_f64(t, col.normal.y, 0)
}

@(test)
test_rect_detect_collision_no_hit :: proc(t: ^testing.T) {
	_, ok := rect_detect_collision(0, 0, 10, 10, 30, 0, 10, 10, 5, 0)

	testing.expect(t, !ok)
}

@(test)
test_world_move_slides_against_wall :: proc(t: ^testing.T) {
	world := world_new(64)
	defer world_destroy(world)

	player, player_ok := world_add(world, 80, 80, 32, 32)
	_, wall_ok := world_add(world, 180, 80, 32, 32)
	testing.expect(t, player_ok)
	testing.expect(t, wall_ok)
	x, y, cols, col_len, ok := world_move(world, player, 240, 80, default_filter)
	defer delete(cols)

	testing.expect(t, ok)
	testing.expect(t, col_len == 1)
	expect_f64(t, x, 148)
	expect_f64(t, y, 80)
}

@(test)
test_world_move_demo_layout_hits_first_wall :: proc(t: ^testing.T) {
	world := world_new(64)
	defer world_destroy(world)

	player, player_ok := world_add(world, 80, 120, 32, 32)
	_, wall_ok := world_add(world, 180, 60, 32, 260)
	testing.expect(t, player_ok)
	testing.expect(t, wall_ok)
	x, y, cols, col_len, ok := world_move(world, player, 400, 120, default_filter)
	defer delete(cols)

	testing.expect(t, ok)
	testing.expect(t, col_len == 1)
	expect_f64(t, x, 148)
	expect_f64(t, y, 120)
}

@(test)
test_world_move_stays_blocked_when_touching_wall :: proc(t: ^testing.T) {
	world := world_new(64)
	defer world_destroy(world)

	player, player_ok := world_add(world, 148, 120, 32, 32)
	_, wall_ok := world_add(world, 180, 60, 32, 260)
	testing.expect(t, player_ok)
	testing.expect(t, wall_ok)
	x, y, cols, col_len, ok := world_move(world, player, 152, 120, default_filter)
	defer delete(cols)

	testing.expect(t, ok)
	testing.expect(t, col_len == 1)
	expect_f64(t, x, 148)
	expect_f64(t, y, 120)
}

@(test)
test_world_move_cross_reports_without_blocking :: proc(t: ^testing.T) {
	world := world_new(64)
	defer world_destroy(world)

	player, player_ok := world_add(world, 80, 80, 32, 32)
	_, trigger_ok := world_add(world, 180, 80, 32, 32)
	testing.expect(t, player_ok)
	testing.expect(t, trigger_ok)
	x, y, cols, col_len, ok := world_move(world, player, 240, 80, cross_filter)
	defer delete(cols)

	testing.expect(t, ok)
	testing.expect(t, col_len == 1)
	testing.expect(t, cols[0].type == .Cross)
	expect_f64(t, x, 240)
	expect_f64(t, y, 80)
}
