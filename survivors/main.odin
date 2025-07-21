package survivors

import "base:runtime"
import "core:log"
import "core:math/linalg"
import "core:mem"
import sdl "vendor:sdl3"

shader_code_fraq_text :: #load("..//fragment.spirv")
shader_code_vert_text :: #load("..//vertex.spirv")


//TODO RemedyBG
//TODO add textures

//TODO draw 10 enemies

//TODO add batch rendering and check if it works in draw debugger


//TODO destroy / delete SDL3 stuff
//TODO add effect to only one enemy
//TODO use culling techniques to minimize pixel writes
//TODO INTEGRATE RAD DEBUGGER
//TODO integrate perf profiler
//TODO handle that max size is 16


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
	INIT_WINDOWS_WIDTH :: 1920 //TODO add issue detect unused constants in strict mode
	INIT_WINDOWS_HEIGHT :: 1080
	window_flags: sdl.WindowFlags
	window_flags += {.RESIZABLE}
	window: ^sdl.Window = sdl.CreateWindow(
		title = "ODIN SURVIVORS",
		w = 1920,
		h = 1080,
		flags = window_flags,
	)

	defer sdl.DestroyWindow(window)
	if window == nil {
		log.error("ODIN SURVIVORS | SDL_CreateWindow failed: {}", sdl.GetError())
		if (ODIN_DEBUG) {
			assert(false)
		}
		return
	}


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


	//SHADER SETUP
	NUMBER_OF_UNIFORMBUFFERS_VERTEX: u32 = 1
	NUMBER_OF_UNIFORMBUFFERS_FRAGMENT: u32 = 0
	log.debug("ODIN SURVIVORS | start Loading shaders")
	gpu_vertex_shader: ^sdl.GPUShader = load_shader(
		shader_code_vert_text,
		gpu_device,
		.VERTEX,
		NUMBER_OF_UNIFORMBUFFERS_VERTEX,
	)
	if gpu_vertex_shader == nil {
		log.error("ODIN SURVIVORS | SDL_CreateGPUShader (vertex) failed: {}", sdl.GetError())
		if (ODIN_DEBUG) {
			assert(false)
		}
		return
	}

	gpu_fragment_shader: ^sdl.GPUShader = load_shader(
		shader_code_fraq_text,
		gpu_device,
		.FRAGMENT,
		NUMBER_OF_UNIFORMBUFFERS_FRAGMENT,
	)

	if gpu_fragment_shader == nil {
		log.error("ODIN SURVIVORS | SDL_CreateGPUShader (fragment) failed: {}", sdl.GetError())
		if (ODIN_DEBUG) {
			assert(false)
		}
		return
	}

	sdl.ReleaseGPUShader(gpu_device, gpu_vertex_shader)
	sdl.ReleaseGPUShader(gpu_device, gpu_fragment_shader)
	log.debug("ODIN SURVIVORS | end Loading shaders")

	//setup vertex attributes and vertex buffer for the pipeline

	//vertex data (triangle)
	Vec3 :: [3]f32
	Vec4 :: [4]f32

	VertexData :: struct {
		position: Vec3, //position of the vertex
		color:    Vec4, //color of the vertex
	}

	vertices: []VertexData = {

		//QUAD
		{position = {-1, 1, 0}, color = {1, 0, 0, 1}}, //TOP LEFT
		{position = {1, 1, 0}, color = {0, 1, 1, 1}}, //TOP RIGHT
		{position = {-1, -1, 0}, color = {1, 0, 1, 1}}, //BOTTOM LEFT
		{position = {1, -1, 0}, color = {1, 0, 1, 1}}, //BOTTOM RIGHT
	}

	vertices_byte_size := len(vertices) * size_of(vertices[0])

	indices := []u32 {
		0,
		1,
		2, //first triangle 
		2,
		1,
		3, //second triangle
	}

	indices_byte_size := len(indices) * size_of(indices[0])


	//create the vertex buffer
	index_buffer := sdl.CreateGPUBuffer(
		gpu_device,
		{usage = {.INDEX}, size = u32(indices_byte_size)},
	)
	defer sdl.ReleaseGPUBuffer(gpu_device,index_buffer)

	//create the vertex buffer
	vertex_buffer := sdl.CreateGPUBuffer(
		gpu_device,
		{usage = {.VERTEX}, size = u32(vertices_byte_size)},
	)
	defer sdl.ReleaseGPUBuffer(gpu_device,vertex_buffer)


	//transfer buffer can upload vertex data and index data to the GPU
	transfer_buffer_create_info := sdl.GPUTransferBufferCreateInfo {
		usage = .UPLOAD,
		size  = u32(vertices_byte_size + indices_byte_size),
	}

	//upload the vertex data to GPU
	transfer_buffer := sdl.CreateGPUTransferBuffer(gpu_device, transfer_buffer_create_info)
	transfer_mem := cast([^]byte)sdl.MapGPUTransferBuffer(gpu_device, transfer_buffer, false)
	mem.copy(transfer_mem, raw_data(vertices), vertices_byte_size)
	mem.copy(transfer_mem[vertices_byte_size:], raw_data(indices), indices_byte_size)

	sdl.UnmapGPUTransferBuffer(gpu_device, transfer_buffer)

	copy_command_buffer := sdl.AcquireGPUCommandBuffer(gpu_device)
	

	copy_pass := sdl.BeginGPUCopyPass(copy_command_buffer)

	sdl.UploadToGPUBuffer(
		copy_pass,
		{transfer_buffer = transfer_buffer},
		{buffer = vertex_buffer, size = u32(vertices_byte_size)},
		false,
	)

	sdl.UploadToGPUBuffer(
		copy_pass,
		{transfer_buffer = transfer_buffer, offset = u32(vertices_byte_size)},
		{buffer = index_buffer, size = u32(indices_byte_size)},
		false,
	)

	sdl.EndGPUCopyPass(copy_pass)

	submit_command_buffer_OK: bool = sdl.SubmitGPUCommandBuffer(copy_command_buffer)
	if submit_command_buffer_OK == false {
		log.error(
			"ODIN SURVIVORS | SDL_SubmitGPUCommandBuffer failed for copy vertices data: {}",
			sdl.GetError(),
		)
		if (ODIN_DEBUG) {
			assert(false)
		}
	}

	sdl.ReleaseGPUTransferBuffer(gpu_device, transfer_buffer)

	vertex_attributes := []sdl.GPUVertexAttribute {

		//POSITION_IN
		{
			location = 0, //mapped to the shader attribute "in_position"
			format   = .FLOAT3, //location 0 is the position
			offset   = u32(offset_of(VertexData, position)), //position is the first field in the vertex data
		},

		//COLOR_IN
		{
			location = 1, //mapped to the shader attribute "in_color"
			format   = .FLOAT4, //location 1 is the color
			offset   = u32(offset_of(VertexData, color)), //color comes after position in the vertex data
		},
	}

	pipeline_create_info := sdl.GPUGraphicsPipelineCreateInfo {
		vertex_shader = gpu_vertex_shader,
		fragment_shader = gpu_fragment_shader,
		primitive_type = .TRIANGLELIST,
		vertex_input_state = {
			num_vertex_buffers = 1,
			vertex_buffer_descriptions = &(sdl.GPUVertexBufferDescription {
					slot = 0,
					pitch = size_of(VertexData),
				}),
			num_vertex_attributes = u32(len(vertex_attributes)),
			vertex_attributes = raw_data(vertex_attributes),
		},
		target_info = {
			num_color_targets = 1,
			color_target_descriptions = &(sdl.GPUColorTargetDescription {
					format = sdl.GetGPUSwapchainTextureFormat(gpu_device, window),
				}),
		},
	}

	//create the pipeline
	pipeline := sdl.CreateGPUGraphicsPipeline(gpu_device, pipeline_create_info)
	if pipeline == nil {
		log.error("ODIN SURVIVORS | SDL_CreateGPUGraphicsPipeline failed: {}", sdl.GetError())
		if (ODIN_DEBUG) {
			assert(false)
		}
		return
	}
	defer sdl.ReleaseGPUGraphicsPipeline(gpu_device, pipeline)


	//get the size of the windows from SDL
	window_size: [2]i32
	ok := sdl.GetWindowSize(window, &window_size.x, &window_size.y)
	if ok == false {
		log.error("ODIN SURVIVORS | SDL_GetWindowSize failed: {}", sdl.GetError())
		if (ODIN_DEBUG) {
			assert(false)
		}
		return
	}

	aspect_ratio: f32 = f32(window_size.x) / f32(window_size.y)
	orthographic_projection: linalg.Matrix4x4f32 = linalg.matrix_ortho3d_f32(
		left = -2.0 * aspect_ratio,
		right = 2.0 * aspect_ratio,
		bottom = -2.0,
		top = 2.0,
		near = -1,
		far = 1,
	)

	camera := camera_init()

	TARGET_FPS: u64 : 60
	TARGET_FRAME_TIME: u64 : 1000 / TARGET_FPS
	last_ticks := sdl.GetTicks()

	GAME_LOOP: for {

		new_ticks := sdl.GetTicks()
		delta_time: f32 = f32(new_ticks - last_ticks) / 1000

		should_quit_game := handle_input(&camera, delta_time)

		if should_quit_game {
			if (ODIN_DEBUG) {
				log.debug("ODIN SURVIVORS | quitting game")
			}
			break GAME_LOOP
		}

		game_update(delta_time)
		should_quit_game = render(
			&camera,
			orthographic_projection,
			gpu_device,
			window,
			pipeline,
			vertex_buffer,
			index_buffer,
		)

		if should_quit_game {
			if (ODIN_DEBUG) {
				log.debug("ODIN SURVIVORS | quitting game")
			}
			break GAME_LOOP
		}

		//frame rate limiting
		frame_time := sdl.GetTicks() - last_ticks
		if frame_time < TARGET_FRAME_TIME {
			sdl.Delay(u32(TARGET_FRAME_TIME - frame_time))
		}
		last_ticks = new_ticks

		free_all(context.temp_allocator)
	}
}

@(private)
@(require_results)
handle_input :: proc(camera: ^Camera, delta_time: f32) -> bool {
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

@(private)
game_update :: proc(delta_time: f32) {

}

@(private)
@(require_results)
render :: proc(
	camera: ^Camera,
	orthographic_projection: linalg.Matrix4x4f32,
	gpu_device: ^sdl.GPUDevice,
	window: ^sdl.Window,
	pipeline: ^sdl.GPUGraphicsPipeline,
	vertex_bufffer: ^sdl.GPUBuffer,
	index_buffer: ^sdl.GPUBuffer,
) -> bool {

	//TODO add a command buffer to the gpu device
	//TODO add a render pass to the command buffer
	//TODO add a swapchain texture to the render pass

	//create the command buffer
	if (gpu_device == nil) {
		log.error("ODIN SURVIVORS | GPU device is nil")
		if (ODIN_DEBUG) {
			assert(false)
		}
		return true
	}
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
		return true
	}

	rotation_sprite :: 0 //FOR NOW, we don't use per sprite/entity rotation
	model_view_matrix :=
		linalg.matrix4_translate_f32({0, 0, -1}) *
		linalg.matrix4_rotate_f32(rotation_sprite, {0, 1, 0})

	// set max and min zoom limits
	camera.zoom = clamp(camera.zoom, 0.1, camera.max_zoom)

	// Create view matrix with camera position and zoom
	view_camera_matrix :=
		linalg.matrix4_scale_f32({camera.zoom, camera.zoom, 1}) *
		linalg.matrix4_translate_f32({-camera.x, -camera.y, 0})

	ubo := UBO {
		mvp = orthographic_projection * view_camera_matrix * model_view_matrix,
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


		//we need only one buffer and render_pass for this demo game and we don't doe parallel rendering

		/* The app can begin new Render Passes and make new draws in the same command buffer 
		until the entire scene is rendered. */
		render_pass := sdl.BeginGPURenderPass(command_buffer, &color_target_info, 1, nil)
		sdl.BindGPUGraphicsPipeline(render_pass, pipeline)

		sdl.BindGPUVertexBuffers(
			render_pass,
			0,
			&(sdl.GPUBufferBinding{buffer = vertex_bufffer, offset = 0}),
			1, //number of vertex buffers
		)

		sdl.BindGPUIndexBuffer(render_pass, {buffer = index_buffer}, ._32BIT)


		SLOT_INDEX_UBO: sdl.Uint32 : 0
		sdl.PushGPUVertexUniformData(command_buffer, SLOT_INDEX_UBO, &ubo, size_of(ubo))
		//vertex attributes
		//uniform data
		sdl.DrawGPUIndexedPrimitives(render_pass, 6, 1, 0, 0, 0)


		sdl.EndGPURenderPass(render_pass)

	} else {
		log.debug(
			"ODIN SURVIVORS | swapchain_texture is nil ---> not rendering anything !!, maybe ui is minimized?",
		)
	}

	//submit the command buffer to the GPU
	submit_command_buffer_OK: bool = sdl.SubmitGPUCommandBuffer(command_buffer)
	if submit_command_buffer_OK == false {
		log.error("ODIN SURVIVORS | SDL_SubmitGPUCommandBuffer failed: {}", sdl.GetError())
		if (ODIN_DEBUG) {
			assert(false)
		}
		return true
	}
	return false
}
