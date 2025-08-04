package survivors

import "core:mem"
import "core:log"

import sdl "vendor:sdl3"

//vertex data
@(private)
Vec3 :: [3]f32


@(private)
VertexData :: struct {
	position: Vec3,
	color:    sdl.FColor,
	uv:       [2]f32,
}

@(private)
Camera :: struct {
	x:          f32,
	y:          f32,
	zoom:       f32,
	max_zoom:   f32,
	zoom_speed: f32,
	speed:      f32,
}

@(private)
@(require_results)
camera_init :: proc() -> Camera {
	camera: Camera = Camera {
		x          = 0,
		y          = 0,
		zoom       = 5.0,
		max_zoom   = 100.0,
		zoom_speed = 4.0,
		speed      = 2.0,
	}

	return camera
}

//data for the uniform buffer object (UBO)
UBO :: struct {
	mvp: matrix[4, 4]f32,
}

@(private)
DrawCommandBuffer :: union {}

@(private)
@(require_results)
load_shader :: proc(
	shader_code: []u8,
	gpu_device: ^sdl.GPUDevice,
	shader_stage: sdl.GPUShaderStage,
	num_uniform_buffers: u32,
	num_samplers: u32,
) -> ^sdl.GPUShader {
	shader_create_info := sdl.GPUShaderCreateInfo {
		code_size           = len(shader_code),
		code                = raw_data(shader_code),
		entrypoint          = "main",
		format              = {.SPIRV},
		stage               = shader_stage,
		num_uniform_buffers = num_uniform_buffers,
		num_samplers        = num_samplers,
	}

	return sdl.CreateGPUShader(gpu_device, shader_create_info)
}

draw_sprite :: proc(
	vertices: []VertexData,
	indices: []u32,
	destination: Rect,
	tile_x: u32,
	tile_y: u32,
	sprite_index: u32,
) {
	// Tilesheet constants
	TILE_SIZE :: 16
	TILE_SPACING :: 1
	SHEET_TILES_X :: 12
	SHEET_TILES_Y :: 11
	SHEET_WIDTH :: (SHEET_TILES_X * TILE_SIZE) + ((SHEET_TILES_X - 1) * TILE_SPACING) // 203
	SHEET_HEIGHT :: (SHEET_TILES_Y * TILE_SIZE) + ((SHEET_TILES_Y - 1) * TILE_SPACING) // 186

	// Calculate UV coordinates for the specific tile
	tile_pixel_x := tile_x * (TILE_SIZE + TILE_SPACING)
	tile_pixel_y := tile_y * (TILE_SIZE + TILE_SPACING)

	uv_left := f32(tile_pixel_x) / f32(SHEET_WIDTH)
	uv_right := f32(tile_pixel_x + TILE_SIZE) / f32(SHEET_WIDTH)
	uv_top := f32(tile_pixel_y) / f32(SHEET_HEIGHT)
	uv_bottom := f32(tile_pixel_y + TILE_SIZE) / f32(SHEET_HEIGHT)

	vertex_offset: u32 = 4 * sprite_index

	vertex_top_left: ^VertexData = &vertices[vertex_offset]
	vertex_top_left.position = {destination.world_pos_x, destination.world_pos_y, 0}
	vertex_top_left.color = COLOR_WHITE
	vertex_top_left.uv = {uv_left, uv_top}

	vertex_top_right: ^VertexData = &vertices[vertex_offset + 1]
	vertex_top_right.position = {
		destination.world_pos_x + destination.width,
		destination.world_pos_y,
		0,
	}
	vertex_top_right.color = COLOR_WHITE
	vertex_top_right.uv = {uv_right, uv_top}

	vertex_bottom_left: ^VertexData = &vertices[vertex_offset + 2]
	vertex_bottom_left.position = {
		destination.world_pos_x,
		destination.world_pos_y + destination.height,
		0,
	}
	vertex_bottom_left.color = COLOR_WHITE
	vertex_bottom_left.uv = {uv_left, uv_bottom}

	vertex_bottom_right: ^VertexData = &vertices[vertex_offset + 3]
	vertex_bottom_right.position = {
		destination.world_pos_x + destination.width,
		destination.world_pos_y + destination.height,
		0,
	}
	vertex_bottom_right.color = COLOR_WHITE
	vertex_bottom_right.uv = {uv_right, uv_bottom}

	indices_offset: u32 = 6 * sprite_index
	indices[indices_offset + 0] = vertex_offset + 0
	indices[indices_offset + 1] = vertex_offset + 1
	indices[indices_offset + 2] = vertex_offset + 2
	indices[indices_offset + 3] = vertex_offset + 2
	indices[indices_offset + 4] = vertex_offset + 1
	indices[indices_offset + 5] = vertex_offset + 3
}


clean_gpu_data :: proc(vertices: []VertexData, indices: []u32) {
	for &vertexData in vertices {
		vertexData.position.x = 0
		vertexData.position.y = 0
		vertexData.position.z = 0
		vertexData.color.r = 0
		vertexData.color.g = 0
		vertexData.color.b = 0
		vertexData.color.a = 0
		vertexData.uv[0] = 0
		vertexData.uv[1] = 0
	}

	for &ind in indices {
		ind = 0
	}
}

end_batch :: proc(
	gpu_device: ^sdl.GPUDevice,
	vertices: []VertexData,
	indices: []u32,
	vertices_byte_size: int,
	indices_byte_size: int,
	transfer_buffer: ^sdl.GPUTransferBuffer,
	vertex_buffer:^sdl.GPUBuffer,
	index_buffer:^sdl.GPUBuffer,
) {
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
}
