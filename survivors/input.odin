package survivors

import "core:prof/spall"

import sdl "vendor:sdl3"

@(require_results)
handle_input :: proc(camera: ^Camera, delta_time: f32) -> bool {
	spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, #procedure)

	should_quit: bool = false

	input_event: sdl.Event
	for sdl.PollEvent(&input_event) {

		#partial switch input_event.type {
		case .QUIT:
			{
				should_quit = true
				continue
			}
		case .KEY_DOWN:
			if input_event.key.scancode == .ESCAPE {
				should_quit = true
				continue
			}

			if input_event.key.scancode == .W || input_event.key.scancode == .UP {
				camera.y += 1 * camera.speed * delta_time // Move up
			} else if input_event.key.scancode == .S || input_event.key.scancode == .DOWN {
				camera.y -= 1 * camera.speed * delta_time // Move down
			} else if input_event.key.scancode == .A || input_event.key.scancode == .LEFT {
				camera.x -= 1 * camera.speed * delta_time // Move left
			} else if input_event.key.scancode == .D || input_event.key.scancode == .RIGHT {
				camera.x += 1 * camera.speed * delta_time // Move right
			}
		}
		//update zoom based on mouse wheel
		if input_event.type == .MOUSE_WHEEL {
			if input_event.wheel.y > 0 {
				camera.zoom += camera.zoom_speed * delta_time // Zoom in
			} else if input_event.wheel.y < 0 {
				camera.zoom -= camera.zoom_speed * delta_time // Zoom out
			}
		}
	}

	return should_quit
}