package main

import "base:runtime"
import "core:log"
import "core:math/linalg/glsl"
import "core:os"
import "core:time"
import "core:fmt"
import "vendor:glfw"

import "game"
import "ui"

TITLE :: "Bidou"

delta_time: f64

ui_ctx: ui.Context

framebuffer_size_callback :: proc "c" (
	handle: glfw.WindowHandle,
	width, height: i32,
) {
	context = runtime.default_context()
    context.user_ptr = glfw.GetWindowUserPointer(handle)

	// log.debug(glsl.ivec2{width, height})
	// log.debug(glfw.GetWindowSize(handle))

	game.renderer().framebuffer_resized = true
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

	game.window_init(TITLE) or_return
	defer game.window_deinit()

	if game.window().handle == nil {
		log.fatal("GLFW has failed to load the window.")
		return
	}

	glfw.SetFramebufferSizeCallback(game.window().handle, framebuffer_size_callback)

	glfw.MakeContextCurrent(game.window().handle)
	when ODIN_DEBUG {
		glfw.SwapInterval(0)
	} else {
		glfw.SwapInterval(1)
	}

	game.init_game() or_return
	defer game.deinit_game()

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

        game.window_update()

        game.game_update()

		// log.debug("Window:", glfw.GetWindowSize(window.handle))
		// log.debug("Frambuffer:", glfw.GetFramebufferSize(window.handle))

		game.renderer_begin_draw()

		game.floor_update()
		ui.update(&ui_ctx)

		if game.keyboard_is_key_press(.Key_Q) {
			game.camera_rotate_counter_clockwise()
			game.world_update_after_rotation(.Counter_Clockwise)
		} else if game.keyboard_is_key_press(.Key_E) {
			game.camera_rotate_clockwise()
			game.world_update_after_rotation(.Clockwise)
		}
		game.camera_update(delta_time)

		game.world_update()
		game.update_cutaways()


		// game.draw_object_tool()
		game.world_draw()

		// game.draw_game() or_return
		game.tools_update(delta_time)

		ui.draw(&ui_ctx)

	    game.ui_render()

		game.renderer_end_draw()


		should_close = bool(glfw.WindowShouldClose(game.window().handle))
		game.keyboard_update()
		game.mouse_update()
		game.update_cursor()

		free_all(context.temp_allocator)

		frames += 1
	}

	return true
}

main :: proc() {
	start()
}
