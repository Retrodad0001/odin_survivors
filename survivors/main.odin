package survivors

//TODO setup draw tooling
//TODO Show complete atlas
//TODO enable batching
//TODO hook-up ImGui and show FPS
//TODO change icon windows
//TODO add sound and music
//TODO log also in a file

import "base:runtime"
import "core:log"
import "core:mem"
import sdl "vendor:sdl3"


sdl_log :: proc "c" (
	userdata: rawptr,
	category: sdl.LogCategory,
	priority: sdl.LogPriority,
	message: cstring,
) {
	context = (cast(^runtime.Context)userdata)^
	level: log.Level
	switch priority {
	case .INVALID, .TRACE, .VERBOSE, .DEBUG:
		level = .Debug
	case .INFO:
		level = .Info
	case .WARN:
		level = .Warning
	case .ERROR:
		level = .Error
	case .CRITICAL:
		level = .Fatal
	}
	log.logf(level, "SDL {}: {}", category, message)
}

main :: proc() {
	context.logger = log.create_console_logger()
	log.debug("starting game")

	//setup memory tracking
	//TODO memory tracking should be only enabled in debug mode
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)

	defer {
		if len(track.allocation_map) > 0 {
			log.error(
				"ODIN SURVIVORS | **%v allocations not freed: **\n",
				len(track.allocation_map),
			)
			for _, entry in track.allocation_map {
				log.error("- %v bytes @ %v\n", entry.size, entry.location)
			}
		}
		if len(track.bad_free_array) > 0 {
			log.error("ODIN SURVIVORS | ** %v incorrect frees: **\n", len(track.bad_free_array))
			for entry in track.bad_free_array {
				log.error("- %p @ %v\n", entry.memory, entry.location)
			}
		}
		mem.tracking_allocator_destroy(&track)
	}

	//initialize SDL
	SDL_INIT_FLAGS :: sdl.INIT_VIDEO
	if (sdl.Init(SDL_INIT_FLAGS)) == false {
		log.error("ODIN SURVIVORS | SDL_Init failed: {}", sdl.GetError())
		return
	}
	defer sdl.Quit()

	//create window
	WINDOWS_WIDTH :: 1280
	WINDOWS_HEIGHT :: 720
	window_flags: sdl.WindowFlags
	window_flags += {.RESIZABLE}
	window: ^sdl.Window = sdl.CreateWindow(
		"ODIN SURVIVORS",
		WINDOWS_WIDTH,
		WINDOWS_HEIGHT,
		window_flags,
	)

	defer sdl.DestroyWindow(window)
	if window == nil {
		log.error("ODIN SURVIVORS | SDL_CreateWindow failed: {}", sdl.GetError())
		return
	}

	//create gpu device
	should_debug :: true //TODO set this only true when in debug mode else false
	gpu_device: ^sdl.GPUDevice = sdl.CreateGPUDevice({.SPIRV}, should_debug, nil)
	defer sdl.DestroyGPUDevice(gpu_device)
	if gpu_device == nil {
		log.error("ODIN SURVIVORS | SDL_CreateGPUDevice failed: {}", sdl.GetError())
		return
	}

	//claim the window for this gpu_device
	claim_window_OK: bool = sdl.ClaimWindowForGPUDevice(gpu_device, window)
	if claim_window_OK == false {
		log.error("ODIN SURVIVORS | SDL_ClaimWindowForGPUDevice failed: {}", sdl.GetError())
		return
	}

	TARGET_FPS: u64 : 60
	TARGET_FRAME_TIME: u64 : 1000 / TARGET_FPS
	SCALE_FACTOR: f32 : 20.0

	//TOOD enable me later entity_manager: EntityManager = entity_create_entity_manager()

	last_ticks := sdl.GetTicks()

	game_loop: for {

		// process events
		input_event: sdl.Event
		for sdl.PollEvent(&input_event) {

			#partial switch input_event.type {
			case .QUIT:
				break game_loop
			case .KEY_DOWN:
				if input_event.key.scancode == .ESCAPE do break game_loop
			}
		}

		//calculate delta time
		new_ticks := sdl.GetTicks()
		delta_time: f32 = f32(new_ticks - last_ticks) / 1000

		game_update(delta_time)


		//get some command buffer from the gpu device
		command_buffer := sdl.AcquireGPUCommandBuffer(gpu_device)

		//get some swapchain texture (aka Render Target)
		swapchain_texture: ^sdl.GPUTexture
		acquire_swapchain_texture_OK: bool = sdl.WaitAndAcquireGPUSwapchainTexture(
			command_buffer,
			window,
			&swapchain_texture,
			nil,
			nil,
		)
		if acquire_swapchain_texture_OK == false {
			log.error(
				"ODIN SURVIVORS | SDL_WaitAndAcquireGPUSwapchainTexture failed: {}",
				sdl.GetError(),
			)
			break game_loop
		}

		//begin the render pass 
		color_target := sdl.GPUColorTargetInfo {
			texture     = swapchain_texture,
			load_op     = .CLEAR,
			clear_color = {0, 0.2, 0.4, 1},
			store_op    = .STORE,
		}

		render_pass := sdl.BeginGPURenderPass(command_buffer, &color_target, 1, nil)


		//render stuff


		//fimnish the first render pass
		//TODO can do more render passes if needed, investigate why this is needed to understand 

		//submit the command buffer
		submit_command_buffer_OK: bool = sdl.SubmitGPUCommandBuffer(command_buffer)
		if submit_command_buffer_OK == false {
			log.error("ODIN SURVIVORS | SDL_SubmitGPUCommandBuffer failed: {}", sdl.GetError())
			break game_loop
		}

		//frame rate limiting
		frame_time := sdl.GetTicks() - last_ticks
		if frame_time < TARGET_FRAME_TIME {
			sdl.Delay(u32(TARGET_FRAME_TIME - frame_time))
		}
		last_ticks = new_ticks
	}
	
	// Cleanup
//TODO Cleanup
/*
SDL_ReleaseGPUTexture(gpu, model.texture);
SDL_ReleaseGPUBuffer(gpu, model.vertex_buf);
SDL_ReleaseGPUBuffer(gpu, model.index_buf);
SDL_ReleaseGPUSampler(gpu, sampler);
SDL_ReleaseGPUGraphicsPipeline(gpu, pipeline);
SDL_ReleaseGPUTexture(gpu, depth_texture);
//SDL_Releasegpud(gpu);
SDL_DestroyWindow(window);
SDL_Quit();
*/
}

game_render :: proc() {

}

game_update :: proc(delta_time: f32) {

}
