# bento

2D Game Engine written in Odin with SDL3.

# Architecture

The engine is split into 3 layers, engine, platform and execute.

The engine layer is responsible for general data structures and logic that will be general across most games e.g. camera struct and transitions. It also provides a the api interface for the platform layer.

The platform layer is what interacts with the operating system and provides platform specific code to, for example, draw a rectangle or play some audio. Currently the only platform layer is a sdl3 implementation. It would be good at somepoint to extend this to OpenGL, Vulkan, raylib etc.

The execute layer is a small layer that takes in a game vtable and runs the main game loop. If this layer was not here, every game would have to implement its own main loop which can be a bit tedious. However, they still can if they want.

```
// Implement this and run
Game :: struct {
	game_init:     proc(platform_data: ^engine.Platform),
	game_update:   proc(input: ^engine.GameInput, dt: f64) -> bool,
	game_render:   proc() -> ^engine.RenderCommandBuffer,
	game_shutdown: proc(),
}
```



