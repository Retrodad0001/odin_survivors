package survivors

import "base:runtime"
import "core:log"
import "core:math/linalg"
import "core:mem"
import sdl "vendor:sdl3"

shader_code_fraq_text :: #load("..//shader.frag")
shader_code_vert_text :: #load("..//shader.vert")

//TODO draw quad from code instead of hardcoding it in shader //index buffers?

//TODO draw 10 enemies
//TODO add textures
//TODO add batch rendering
//TODO learn by adding parameter delta_time to update color triangle
//TODO learn moving the camera around en zoom (2D)
//TODO add effect to only one enemy
//TODO destroy / delete SDL3 stuff
//TODO INTEGRATE RAD DEBUGGER
//TODO integrate perf profiler
//TODO handle that max size is 16

//data for the uniform buffer object (UBO)
UBO :: struct {
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
		if (ODIN_DEBUG) {
			assert(false)
		}
	case .CRITICAL:
		level = .Fatal
	}
	log.logf(level, "SDL {}: {}", category, message)
}

main :: proc() {
	context.logger = log.create_console_logger()
	log.debug("starting game")

	if (ODIN_DEBUG) {
		log.debug("ODIN SURVIVORS | OS USED : " + ODIN_OS_STRING)
	}

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
		if (ODIN_DEBUG) {
			assert(false)
		}
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
		if (ODIN_DEBUG) {
			assert(false)
		}
		return
	}

	window_size: [2]i32
	ok := sdl.GetWindowSize(window, &window_size.x, &window_size.y)

	if ok == false {
		log.error("ODIN SURVIVORS | SDL_GetWindowSize failed: {}", sdl.GetError())
		if (ODIN_DEBUG) {
			assert(false)
		}
		return
	}

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
		if (ODIN_DEBUG) {
			assert(false)
		}
		return
	}

	//claim the window for this gpu_device
	claim_window_OK: bool = sdl.ClaimWindowForGPUDevice(gpu_device, window)
	if claim_window_OK == false {
		log.error("ODIN SURVIVORS | SDL_ClaimWindowForGPUDevice failed: {}", sdl.GetError())
		if (ODIN_DEBUG) {
			assert(false)
		}
		return
	}

	//TOOD enable me later entity_manager: EntityManager = entity_create_entity_manager()
	TARGET_FPS: u64 : 60
	TARGET_FRAME_TIME: u64 : 1000 / TARGET_FPS

	last_ticks := sdl.GetTicks()

	log.debug("ODIN SURVIVORS | start Loading shaders")
	gpu_shader_vertex: ^sdl.GPUShader = load_shader(shader_code_vert_text, gpu_device, .VERTEX, 1)
	if gpu_shader_vertex == nil {
		log.error("ODIN SURVIVORS | SDL_CreateGPUShader (vertex) failed: {}", sdl.GetError())
		if (ODIN_DEBUG) {
			assert(false)
		}
		return
	}

	gpu_shader_fragment: ^sdl.GPUShader = load_shader(
		shader_code_fraq_text,
		gpu_device,
		.FRAGMENT,
		0,
	)

	if gpu_shader_fragment == nil {
		log.error("ODIN SURVIVORS | SDL_CreateGPUShader (fragment) failed: {}", sdl.GetError())
		if (ODIN_DEBUG) {
			assert(false)
		}
		return
	}

	sdl.ReleaseGPUShader(gpu_device, gpu_shader_vertex)
	sdl.ReleaseGPUShader(gpu_device, gpu_shader_fragment)
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
		if (ODIN_DEBUG) {
			assert(false)
		}
		return
	}
	defer sdl.ReleaseGPUGraphicsPipeline(gpu_device, pipeline)


	GAME_LOOP: for {

		// process events
		input_event: sdl.Event
		for sdl.PollEvent(&input_event) {

			#partial switch input_event.type {
			case .QUIT:
				break GAME_LOOP
			case .KEY_DOWN:
				if input_event.key.scancode == .ESCAPE do break GAME_LOOP
			}
		}

		//calculate delta time
		new_ticks := sdl.GetTicks()
		delta_time: f32 = f32(new_ticks - last_ticks) / 1000


		 rotation_sprite :: 0 //FOR NOW, we dont use per sprite/entity rotation
		 model_view_matrix :=
		 	linalg.matrix4_translate_f32({0, 0, -1}) *
		 	linalg.matrix4_rotate_f32(rotation_sprite, {0, 1, 0})
		 game_update(delta_time)

		//get some command buffer from the gpu device
		command_buffer := sdl.AcquireGPUCommandBuffer(gpu_device)
		//FIXME delete or reuse commandbuffer?

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
			if (ODIN_DEBUG) {
				assert(false)
			}
			break GAME_LOOP
		}

		//for transform stuff to screen
        orthograpic_projection: linalg.Matrix4x4f32 = linalg.matrix_ortho3d_f32(
            left   = -2.0,
            right  = 2.0,
            bottom = -1.5, 
            top    = 1.5,
            near   = -1,
            far    = 1,
        )

        view_matrix := linalg.MATRIX4F32_IDENTITY//CAMERA
       
        ubo := UBO {
            mvp = orthograpic_projection * view_matrix * model_view_matrix,
        }

		if (swapchain_texture != nil) {
			CLEAR_COLOR: sdl.FColor : {0, 0.0, 0.1, 1}
			//begin the render pass 
			color_target_info := sdl.GPUColorTargetInfo {
				texture     = swapchain_texture,
				load_op     = .CLEAR,
				clear_color = CLEAR_COLOR,
				store_op    = .STORE,
			}

			//game_render(command_buffer, pipeline, &color_target_info, &ubo)

			//TODO can do more render passes if needed, investigate why this is needed to understand 

			render_pass := sdl.BeginGPURenderPass(command_buffer, &color_target_info, 1, nil)
			sdl.BindGPUGraphicsPipeline(render_pass, pipeline)

			SLOT_INDEX_UBO: sdl.Uint32 : 0 //FIXME can i get this from shader after loading the shader like opengl glGenuniformLocation
			sdl.PushGPUVertexUniformData(command_buffer, SLOT_INDEX_UBO, &ubo, size_of(ubo))
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
			if (ODIN_DEBUG) {
				assert(false)
			}
			break GAME_LOOP
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
