package survivors

import "base:runtime"
import "core:log"
import "core:math/linalg"
import "core:mem"
import sdl "vendor:sdl3"


shader_code_fraq := #load("..//shader.frag")
shader_code_vert := #load("..//shader.vert")


//data for the uniform buffer object (UBO)
//TODO handle that max size is 16
UBO :: struct  {
	mvp: matrix[4, 4]f32,
}

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


	if (ODIN_DEBUG) {
		log.debug("ODIN SURVIVORS | DEBUG enabled")
	} else {
		log.debug("ODIN SURVIVORS | DEBUG disabled")
	}


	if (ODIN_DEBUG) {
		log.debug("ODIN SURVIVORS | Memory tracking enabled")

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
				log.error(
					"ODIN SURVIVORS | ** %v incorrect frees: **\n",
					len(track.bad_free_array),
				)
				for entry in track.bad_free_array {
					log.error("- %p @ %v\n", entry.memory, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	} else {
		log.debug("ODIN SURVIVORS | Memory tracking disabled")
	}

	if (ODIN_DEBUG) {
		log.debug("ODIN SURVIVORS | SDL logging level is TRACE")
		sdl.SetLogPriorities(sdl.LogPriority.TRACE)
	} else {

		log.debug("ODIN SURVIVORS | SDL logging level is WARN")
		sdl.SetLogPriorities(sdl.LogPriority.WARN)
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

	window_size: [2]i32
	ok := sdl.GetWindowSize(window, &window_size.x, &window_size.y)

	if ok == false {
		log.error("ODIN SURVIVORS | SDL_GetWindowSize failed: {}", sdl.GetError())
		return
	}

	projection_matrix := linalg.matrix4_perspective_f32(
		 linalg.to_radians(f32(70.0)),
		f32(window_size.x) / f32(window_size.y),
		0.0001,
		1000,
	)

	rotation :f32 = 0.0

	


	//create gpu device
	should_debug := true
	if (ODIN_DEBUG) {
		log.debug("ODIN SURVIVORS | GPU debug enabled")
	} else {
		should_debug = false
		log.debug("ODIN SURVIVORS | GPU debug disabled")
	}

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

	//TOOD enable me later entity_manager: EntityManager = entity_create_entity_manager()

	TARGET_FPS: u64 : 60
	TARGET_FRAME_TIME: u64 : 1000 / TARGET_FPS
	SCALE_FACTOR: f32 : 20.0

	last_ticks := sdl.GetTicks()

	log.debug("ODIN SURVIVORS | start Loading shaders")
	gpu_shader_vertex: ^sdl.GPUShader = load_shader(shader_code_vert, gpu_device, .VERTEX, 1)
	if gpu_shader_vertex == nil {
		log.error("ODIN SURVIVORS | SDL_CreateGPUShader (vertex) failed: {}", sdl.GetError())
		return
	}

	gpu_shader_fragment: ^sdl.GPUShader = load_shader(shader_code_fraq, gpu_device, .FRAGMENT, 0)
	if gpu_shader_fragment == nil {
		log.error("ODIN SURVIVORS | SDL_CreateGPUShader (fragment) failed: {}", sdl.GetError())
		return
	}
	log.debug("ODIN SURVIVORS | end Loading shaders")

	graphics_pipeline_create_info := sdl.GPUGraphicsPipelineCreateInfo {
		vertex_shader = gpu_shader_vertex,
		fragment_shader = gpu_shader_fragment,
		primitive_type = .TRIANGLELIST,
		target_info = {
			num_color_targets = 1,
			color_target_descriptions = &(sdl.GPUColorTargetDescription {
					format = sdl.GetGPUSwapchainTextureFormat(gpu_device, window),
				}),
		},
	}

	//create the pipeline
	pipeline := sdl.CreateGPUGraphicsPipeline(gpu_device, graphics_pipeline_create_info)
	if pipeline == nil {
		log.error("ODIN SURVIVORS | SDL_CreateGPUGraphicsPipeline failed: {}", sdl.GetError())
		return
	}
	defer sdl.ReleaseGPUGraphicsPipeline(gpu_device, pipeline)

	sdl.ReleaseGPUShader(gpu_device, gpu_shader_vertex)
	sdl.ReleaseGPUShader(gpu_device, gpu_shader_fragment)

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


		model_view_matrix := linalg.matrix4_translate_f32({0,0,-5})* linalg.matrix4_rotate_f32(rotation, {0,1,0})
	
		rotation += 1.5 * delta_time

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

		ubo := UBO {
			mvp = projection_matrix * model_view_matrix, 
		}

		if (swapchain_texture != nil) {
			CLEAR_COLOR: sdl.FColor : {0, 0.2, 0.2, 1}
			//begin the render pass 
			color_target_info := sdl.GPUColorTargetInfo { 	//TODO understand all the steps in detail see docs
				texture     = swapchain_texture,
				load_op     = .CLEAR,
				clear_color = CLEAR_COLOR,
				store_op    = .STORE,
			}

			//game_render(command_buffer, pipeline, &color_target_info, &ubo)

			//TODO can do more render passes if needed, investigate why this is needed to understand 
			render_pass := sdl.BeginGPURenderPass(command_buffer, &color_target_info, 1, nil)
			sdl.BindGPUGraphicsPipeline(render_pass, pipeline)
			sdl.PushGPUVertexUniformData(command_buffer, 0, &ubo, size_of(ubo))
			//vertex attributes
			//uniform data
			sdl.DrawGPUPrimitives(render_pass, 3, 1, 0, 0)
			sdl.EndGPURenderPass(render_pass)

		} else {
			log.debug(
				"ODIN SURVIVORS | swapchain_texture is nil ---> not rendering anything !!, maybe ui is minimized?",
			)
		}


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

}

game_update :: proc(delta_time: f32) {

}

//TODO move stuff here when i can draw the player
game_render :: proc(
	command_buffer: ^sdl.GPUCommandBuffer,
	pipeline: ^sdl.GPUGraphicsPipeline,
	color_target_info: ^sdl.GPUColorTargetInfo,
	ubo: ^UBO,
) {

}

@(private = "file")
load_shader :: proc(
	shader_code: []u8,
	gpu_device: ^sdl.GPUDevice,
	stage: sdl.GPUShaderStage,
	num_uniform_b: u32,
) -> ^sdl.GPUShader {
	shader_create_info := sdl.GPUShaderCreateInfo {
		code_size           = len(shader_code),
		code                = raw_data(shader_code),
		entrypoint          = "main",
		format              = {.SPIRV},
		stage               = stage,
		num_uniform_buffers = num_uniform_b,
	}

	return sdl.CreateGPUShader(gpu_device, shader_create_info)
}
