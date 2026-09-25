package engine

// render comand buffer structure
MAXCOMMANDS :: 1024

// render command types
RenderCommandPushCanvas :: struct {
	canvas: int,
}

RenderCommandPopCanvas :: struct {}

RenderCommandClearScreen :: struct {
	color: Color,
}

RenderCommandDrawCircle :: struct {
	circle: Circle,
	color:  Color,
}

RenderCommandDrawArc :: struct {
	center:      Vector2,
	radius:      f32,
	start_angle: f32,
	end_angle:   f32,
	thickness:   f32,
	color:       Color,
}

RenderCommandDrawRect :: struct {
	rect:  Rect,
	color: Color,
}

RenderCommandSetClippingRect :: struct {
	rect: Rect,
}
RenderCommandEndClippingRect :: struct {}

RenderCommandDrawRectLine :: struct {
	using _: RenderCommandDrawRect,
}

RenderCommandDrawDebugText :: struct {
	position: Vector2,
	text:     string,
	scale:    f32,
	color:    Color,
}

RenderCommandDrawText :: struct {
	position: Vector2,
	text:     string,
	font:     int,
	color:    Color,
}

RenderCommandDrawSprite :: struct {
	position:             Vector2,
	scale, rotation:      f64,
	pivot:                Vector2,
	texture:              int,
	texture_rect:         Rect,
	color:                Color,
	flip_x, flip_y:       bool,
	stretch_x, stretch_y: int,
}

RenderCommandAttachCamera :: struct {
	cam: ^Camera2D,
}

RenderCommandDetachCamera :: struct {}

RenderCommandPushShader :: struct {
	handle: int,
}

RenderCommandPopShader :: struct {}

// add to render command tagged union
RenderCommand :: union {
	RenderCommandPushCanvas,
	RenderCommandPopCanvas,
	RenderCommandClearScreen,
	RenderCommandDrawRect,
	RenderCommandDrawSprite,
	RenderCommandDrawDebugText,
	RenderCommandAttachCamera,
	RenderCommandDetachCamera,
	RenderCommandDrawRectLine,
	RenderCommandDrawText,
	RenderCommandDrawCircle,
	RenderCommandSetClippingRect,
	RenderCommandEndClippingRect,
	RenderCommandDrawArc,
	RenderCommandPushShader,
	RenderCommandPopShader,
}

// buffer to be read and written to
RenderCommandBuffer :: struct {
	commands: [MAXCOMMANDS]RenderCommand,
	count:    int,
}


// pushes commands to the cmd buffer
@(private)
cmd_push :: proc(cmdbuf: ^RenderCommandBuffer, cmd: RenderCommand) {
	if cmdbuf.count >= MAXCOMMANDS do return
	cmdbuf.commands[cmdbuf.count] = cmd
	cmdbuf.count += 1
}

cmd_reset :: proc(cmdbuf: ^RenderCommandBuffer) {
	cmdbuf.count = 0
}


rendercommandbuffer_new :: proc() -> ^RenderCommandBuffer {
	cmdbuf := new(RenderCommandBuffer)
	return cmdbuf
}


// command interfaces

// sends a single color to clear screen
cmd_clear_screen :: proc(cmdbuf: ^RenderCommandBuffer, color: Color) {
	cmd_push(cmdbuf, RenderCommandClearScreen{color = color})
}

// draw circle filled
cmd_draw_circle :: proc(cmdbuf: ^RenderCommandBuffer, circle: Circle, color: Color) {
	cmd_push(cmdbuf, RenderCommandDrawCircle{circle = circle, color = color})
}

// draw arc
cmd_draw_arc :: proc(
	cmdbuf: ^RenderCommandBuffer,
	center: Vector2,
	radius, start_angle, end_angle, thickness: f32,
	color: Color,
) {
	cmd_push(
		cmdbuf,
		RenderCommandDrawArc{center, radius, start_angle, end_angle, thickness, color},
	)
}

// draws a single rectangle
cmd_draw_rect :: proc(cmdbuf: ^RenderCommandBuffer, rect: Rect, color: Color) {
	cmd_push(cmdbuf, RenderCommandDrawRect{rect = rect, color = color})
}

// draws a single rectangle outline
cmd_draw_rect_line :: proc(cmdbuf: ^RenderCommandBuffer, rect: Rect, color: Color) {
	cmd_push(cmdbuf, RenderCommandDrawRectLine{rect = rect, color = color})
}

// draws a single sprite
// stretch x and y will stretch the texture the additional pixels
cmd_draw_sprite :: proc(
	cmdbuf: ^RenderCommandBuffer,
	position: Vector2,
	scale, rotation: f64,
	pivot: Vector2,
	texture: int,
	texture_rect: Rect,
	color: Color,
	flip_x, flip_y: bool,
	stretch_x: int = 0,
	stretch_y: int = 0,
) {
	cmd_push(
		cmdbuf,
		RenderCommandDrawSprite {
			position = position,
			scale = scale,
			rotation = rotation,
			pivot = pivot,
			texture = texture,
			texture_rect = texture_rect,
			color = color,
			flip_x = flip_x,
			flip_y = flip_y,
			stretch_x = stretch_x,
			stretch_y = stretch_y,
		},
	)
}


// draw debug text
cmd_draw_debug_text :: proc(
	cmdbuf: ^RenderCommandBuffer,
	position: Vector2,
	text: string,
	scale: f32,
	color: Color,
) {

	cmd_push(
		cmdbuf,
		RenderCommandDrawDebugText{position = position, text = text, scale = scale, color = color},
	)
}

// draw text with font
cmd_draw_text :: proc(
	cmdbuf: ^RenderCommandBuffer,
	position: Vector2,
	text: string,
	font: int,
	color: Color,
) {
	cmd_push(
		cmdbuf,
		RenderCommandDrawText{position = position, text = text, font = font, color = color},
	)
}

// attach & detach camera
cmd_attach_camera :: proc(cmdbuf: ^RenderCommandBuffer, cam: ^Camera2D) {
	cmd_push(cmdbuf, RenderCommandAttachCamera{cam = cam})
}

cmd_detach_camera :: proc(cmdbuf: ^RenderCommandBuffer) {
	cmd_push(cmdbuf, RenderCommandDetachCamera{})
}

// set and end clipping rect
cmd_set_clipping_rect :: proc(cmdbuf: ^RenderCommandBuffer, rect: Rect) {
	cmd_push(cmdbuf, RenderCommandSetClippingRect{rect = rect})
}

cmd_end_clipping_rect :: proc(cmdbuf: ^RenderCommandBuffer) {
	cmd_push(cmdbuf, RenderCommandEndClippingRect{})
}

// push and pop shader
cmd_push_shader :: proc(cmdbuf: ^RenderCommandBuffer, shader_handle: int) {
	cmd_push(cmdbuf, RenderCommandPushShader{handle = shader_handle})
}

cmd_pop_shader :: proc(cmdbuf: ^RenderCommandBuffer) {
	cmd_push(cmdbuf, RenderCommandPopShader{})
}

// push and pop canvas
cmd_push_canvas :: proc(cmdbuf: ^RenderCommandBuffer, canvas: int) {
	cmd_push(cmdbuf, RenderCommandPushCanvas{canvas = canvas})
}

cmd_pop_canvas :: proc(cmdbuf: ^RenderCommandBuffer) {
	cmd_push(cmdbuf, RenderCommandPopCanvas{})
}
