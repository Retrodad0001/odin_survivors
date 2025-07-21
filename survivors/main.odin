package survivors

import "base:runtime"
import "core:log"
import "core:math/linalg"
import "core:mem"
import sdl "vendor:sdl3"
import stbi "vendor:stb/image"

shader_code_fraq_text :: #load("..//fragment.spirv")
shader_code_vert_text :: #load("..//vertex.spirv")

SPRITE_COUNT :: 2
COLOR_WHITE :: sdl.FColor{1, 1, 1, 1}
COLOR_OTHER :: sdl.FColor{0, 1, 1, 1}
COLOR_BLACK :: sdl.FColor{0, 0, 0, 0}


//TODO draw only idle soldier

//TODO RemedyBG
//TODO draw 10 enemies

//TODO add batch rendering and check if it works in draw debugger

//TODO add debug info

//TODO add effect to only one enemy

//TODO use culling techniques to minimize pixel writes

//TODO integrate perf profiler spalt


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

	log.debug("ODIN SURVIVORS | start Loading shaders")
	gpu_vertex_shader: ^sdl.GPUShader = load_shader(
		shader_code_vert_text,
		gpu_device,
		.VERTEX,
		num_uniform_buffers = 1,
		num_samplers = 0,
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
		num_uniform_buffers = 1,
		num_samplers = 1,
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


	//TODO set max sprite count instead of dynamic
	//vertices: []SpriteData = {}

	//for each sprite add data
	i := 2
	for i < SPRITE_COUNT {
		

		i += 1
	}

		// vertices[0].position = {-1, 1, 0}
		// vertices[0].color = COLOR_WHITE
		// vertices[0].uv = {0, 0}

		// vertices[1].position = {1, 1, 0}
		// vertices[1].color = COLOR_WHITE
		// vertices[1].uv = {1, 0}

		// vertices[2].position = {-1, -1, 0}
		// vertices[2].color = COLOR_WHITE
		// vertices[2].uv = {0, 1}

		// vertices[3].position = {1, -1, 0}
		// vertices[3].color = COLOR_WHITE
		// vertices[3].uv = {1, 1}

	// //setup vertex attributes and vertex buffer for the pipeline
	vertices: []SpriteData = {

		//QUAD #1
		{position = {-1, 1, 0}, color = COLOR_WHITE, uv = {0, 0}}, //TOP LEFT
		{position = {1, 1, 0}, color = COLOR_WHITE, uv = {1, 0}}, //TOP RIGHT
		{position = {-1, -1, 0}, color = COLOR_WHITE, uv = {0, 1}}, //BOTTOM LEFT
		{position = {1, -1, 0}, color = COLOR_WHITE, uv = {1, 1}}, //BOTTOM RIGHT

		//QUAD #2
		{position = {-1, 1, 0}, color = COLOR_WHITE, uv = {0, 0}}, //TOP LEFT
		{position = {1, 1, 0}, color = COLOR_WHITE, uv = {1, 0}}, //TOP RIGHT
		{position = {-1, -1, 0}, color = COLOR_WHITE, uv = {0, 1}}, //BOTTOM LEFT
		{position = {1, -1, 0}, color = COLOR_WHITE, uv = {1, 1}}, //BOTTOM RIGHT
	}

	vertices_byte_size := len(vertices) * size_of(vertices[0])

	indices := []u32 {

		//0 tm 4
		0,
		1,
		2, //first triangle 
		2,
		1,
		3, //second triangle
		0 + 4,
		1 + 4,
		2 + 4, //first triangle 
		2 + 4,
		1 + 4,
		3 + 4, //second triangle
	}

	indices_byte_size := len(indices) * size_of(indices[0])

	//create the vertex buffer
	index_buffer := sdl.CreateGPUBuffer(
		gpu_device,
		{usage = {.INDEX}, size = u32(indices_byte_size)},
	)

	//create the vertex buffer
	sprite_data_buffer := sdl.CreateGPUBuffer(
		gpu_device,
		{usage = {.VERTEX}, size = SPRITE_COUNT * u32(vertices_byte_size)},
	)

	//upload the vertex data to GPU
	transfer_buffer := sdl.CreateGPUTransferBuffer(
		gpu_device,
		{usage = .UPLOAD, size = SPRITE_COUNT * u32(vertices_byte_size + indices_byte_size)},
	)

	transfer_mem := cast([^]byte)sdl.MapGPUTransferBuffer(gpu_device, transfer_buffer, false)
	mem.copy(transfer_mem, raw_data(vertices), vertices_byte_size)
	mem.copy(transfer_mem[vertices_byte_size:], raw_data(indices), indices_byte_size)
	sdl.UnmapGPUTransferBuffer(gpu_device, transfer_buffer)


	//LOAD ATLAS
	img_size: [2]i32
	pixels := stbi.load("assets/spritesheet.png", &img_size.x, &img_size.y, nil, 4) //4 bytes based on format
	pixels_byte_size := img_size.x * img_size.y * 4 //*4 bytes
	gpu_texture := sdl.CreateGPUTexture(
		gpu_device,
		{
			format = .R8G8B8A8_UNORM,
			usage = {.SAMPLER},
			width = u32(img_size.x),
			height = u32(img_size.y),
			layer_count_or_depth = 1,
			num_levels = 1,
		},
	)

	texture_transfer_buffer := sdl.CreateGPUTransferBuffer(
		gpu_device,
		{usage = .UPLOAD, size = u32(pixels_byte_size)},
	)

	texture_transfer_mem := sdl.MapGPUTransferBuffer(gpu_device, texture_transfer_buffer, false)
	mem.copy(texture_transfer_mem, pixels, int(pixels_byte_size))
	sdl.UnmapGPUTransferBuffer(gpu_device, texture_transfer_buffer)


	copy_command_buffer := sdl.AcquireGPUCommandBuffer(gpu_device)

	copy_pass := sdl.BeginGPUCopyPass(copy_command_buffer)

	sdl.UploadToGPUBuffer(
		copy_pass,
		{transfer_buffer = transfer_buffer},
		{buffer = sprite_data_buffer, size = u32(vertices_byte_size)},
		false,
	)

	sdl.UploadToGPUBuffer(
		copy_pass,
		{transfer_buffer = transfer_buffer, offset = u32(vertices_byte_size)},
		{buffer = index_buffer, size = u32(indices_byte_size)},
		false,
	)

	sdl.UploadToGPUTexture(
		copy_pass,
		{transfer_buffer = texture_transfer_buffer, offset = 0},
		{texture = gpu_texture, w = u32(img_size.x), h = u32(img_size.y), d = 1},
		false,
	)

	sdl.EndGPUCopyPass(copy_pass)
	sdl.ReleaseGPUTransferBuffer(gpu_device, transfer_buffer)
	sdl.ReleaseGPUTransferBuffer(gpu_device, texture_transfer_buffer)

	gpu_sampler := sdl.CreateGPUSampler(
		gpu_device,
		{
			min_filter = .NEAREST,
			mag_filter = .NEAREST,
			mipmap_mode = .NEAREST,
			address_mode_u = .CLAMP_TO_EDGE,
			address_mode_v = .CLAMP_TO_EDGE,
			address_mode_w = .CLAMP_TO_EDGE,
		},
	)

	defer sdl.ReleaseGPUSampler(gpu_device, gpu_sampler)

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

	vertex_attributes := []sdl.GPUVertexAttribute {
		//POSITION_IN
		{location = 0, format = .FLOAT3, offset = u32(offset_of(SpriteData, position))},
		//COLOR_IN
		{location = 1, format = .FLOAT4, offset = u32(offset_of(SpriteData, color))},
		//UV_IN
		{location = 2, format = .FLOAT2, offset = u32(offset_of(SpriteData, uv))},
	}

	pipeline_create_info := sdl.GPUGraphicsPipelineCreateInfo {
		vertex_shader = gpu_vertex_shader,
		fragment_shader = gpu_fragment_shader,
		primitive_type = .TRIANGLELIST,
		vertex_input_state = {
			num_vertex_buffers = 1,
			vertex_buffer_descriptions = &(sdl.GPUVertexBufferDescription {
					slot = 0,
					pitch = size_of(SpriteData),
				}),
			num_vertex_attributes = u32(len(vertex_attributes)),
			vertex_attributes = raw_data(vertex_attributes),
		},
		target_info = {
			num_color_targets = 1,
			color_target_descriptions = &(sdl.GPUColorTargetDescription {
					format = sdl.GetGPUSwapchainTextureFormat(gpu_device, window),
					blend_state = {
						enable_blend = true,
						color_blend_op = .ADD,
						alpha_blend_op = .ADD,
						src_color_blendfactor = .SRC_ALPHA,
						dst_color_blendfactor = .SRC_ALPHA,
						src_alpha_blendfactor = .SRC_ALPHA,
						dst_alpha_blendfactor = .SRC_ALPHA,
					},
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
			sprite_data_buffer,
			index_buffer,
			gpu_texture,
			gpu_sampler,
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
	sprite_data_buffer: ^sdl.GPUBuffer,
	index_buffer: ^sdl.GPUBuffer,
	gpu_texture: ^sdl.GPUTexture,
	gpu_sampler: ^sdl.GPUSampler,
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
		CLEAR_COLOR: sdl.FColor : COLOR_BLACK
		//begin the render pass 
		color_target_info := sdl.GPUColorTargetInfo {
			texture     = swapchain_texture,
			load_op     = .CLEAR,
			clear_color = CLEAR_COLOR,
			store_op    = .STORE,
		}

		render_pass := sdl.BeginGPURenderPass(command_buffer, &color_target_info, 1, nil)

		sdl.BindGPUGraphicsPipeline(render_pass, pipeline)

		sdl.BindGPUVertexBuffers(
			render_pass,
			0,
			&(sdl.GPUBufferBinding{buffer = sprite_data_buffer, offset = 0}),
			1, //number of vertex buffers
		)

		sdl.BindGPUIndexBuffer(render_pass, {buffer = index_buffer}, ._32BIT)
		sdl.PushGPUVertexUniformData(command_buffer, 0, &ubo, size_of(ubo))

		texture_binding := sdl.GPUTextureSamplerBinding {
			texture = gpu_texture,
			sampler = gpu_sampler,
		}

		//for each sprite add data
		i := 2
		for i < SPRITE_COUNT {


			i += 1
		}

		sdl.BindGPUFragmentSamplers(render_pass, 0, &texture_binding, 1)
		sdl.DrawGPUIndexedPrimitives(
			render_pass = render_pass,
			num_indices = SPRITE_COUNT * 6,
			num_instances = 1,
			first_index = 0,
			vertex_offset = 0,
			first_instance = 0,
		)


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
