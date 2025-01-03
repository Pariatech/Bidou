package main

import "base:runtime"
import "core:log"
import "core:math/linalg/glsl"
import "core:os"
import "core:time"
import "vendor:glfw"

import "billboard"
import "camera"
import "cursor"
import "floor"
import "game"
import "keyboard"
import "mouse"
import "renderer"
import "terrain"
import "tools"
import "tools/floor_tool"
import "tools/terrain_tool"
import "ui"
import "window"
import "world"

TITLE :: "Bidou"

delta_time: f64

ui_ctx: ui.Context

framebuffer_size_callback :: proc "c" (
	_: glfw.WindowHandle,
	width, height: i32,
) {
	context = runtime.default_context()

	// log.debug(glsl.ivec2{width, height})
	// log.debug(glfw.GetWindowSize(handle))

	renderer.framebuffer_resized = true
	// window.size.x = f32(width)
	// window.size.y = f32(height)
}

start :: proc() -> (ok: bool = false) {
	game_context := new(game.Game_Context)
	defer free(game_context)
	context.user_ptr = game_context

	defer game.free_models()

	when ODIN_DEBUG {
		context.logger = log.create_console_logger()
		defer log.destroy_console_logger(context.logger)
	} else {
		mode: int = 0
        when ODIN_OS != .Windows {
            mode = os.S_IRUSR + os.S_IWUSR
        }
		h, _ := os.open(
			"logs",
			os.O_WRONLY + os.O_CREATE,
			mode,
		)
		context.logger = log.create_file_logger(h)

		defer log.destroy_file_logger(context.logger)
	}

	window.init(TITLE) or_return
	defer window.deinit()

	if window.handle == nil {
		log.fatal("GLFW has failed to load the window.")
		return
	}

	glfw.SetFramebufferSizeCallback(window.handle, framebuffer_size_callback)

	glfw.MakeContextCurrent(window.handle)
	when ODIN_DEBUG {
		glfw.SwapInterval(0)
	} else {
		glfw.SwapInterval(1)
	}

	if (!renderer.init()) do return
	defer renderer.deinit()

	game.init_wall_renderer() or_return

	keyboard.init()
	defer keyboard.deinit()
	mouse.init()
	defer mouse.deinit()
	cursor.init()

	billboard.init_draw_contexts() or_return
	terrain.init_terrain()

	game.load_models() or_return

	game.init_objects() or_return

	floor_tool.init()
	terrain_tool.init()

	tools.init()
	defer tools.deinit()

	game.init_cutaways()

	defer game.delete_textures()
	defer game.delete_objects()

	game.init_game() or_return
	defer game.deinit_game()

	world.init()

	ui.init(&ui_ctx) or_return
	defer ui.deinit(&ui_ctx)

	should_close := false
	current_time_ns := time.now()
	previous_time_ns := time.now()
	fps_stopwatch: time.Stopwatch
	time.stopwatch_start(&fps_stopwatch)
	frames: i64 = 0

	free_all(context.temp_allocator)

	for !should_close {
		previous_time_ns = current_time_ns
		current_time_ns = time.now()
		diff := time.diff(previous_time_ns, current_time_ns)
		delta_time = time.duration_seconds(diff)
		if time.stopwatch_duration(fps_stopwatch) >= time.Second {
			log.debug("FPS:", frames)
			frames = 0
			time.stopwatch_reset(&fps_stopwatch)
			time.stopwatch_start(&fps_stopwatch)
		}

		glfw.PollEvents()

		// log.debug("Window:", glfw.GetWindowSize(window.handle))
		// log.debug("Frambuffer:", glfw.GetFramebufferSize(window.handle))

		renderer.begin_draw()

		floor.update()
		ui.update(&ui_ctx)

		if keyboard.is_key_press(.Key_Q) {
			camera.rotate_counter_clockwise()
			world.update_after_rotation(.Counter_Clockwise)
		} else if keyboard.is_key_press(.Key_E) {
			camera.rotate_clockwise()
			world.update_after_rotation(.Clockwise)
		}
		camera.update(delta_time)

		world.update()
		game.update_cutaways()


		// game.draw_object_tool()
		world.draw()

		// game.draw_game() or_return
		tools.update(delta_time)

		ui.draw(&ui_ctx)

		renderer.end_draw()


		should_close = bool(glfw.WindowShouldClose(window.handle))
		keyboard.update()
		mouse.update()
		cursor.update()

		free_all(context.temp_allocator)

		frames += 1
	}

	return true
}

main :: proc() {
	start()
}
