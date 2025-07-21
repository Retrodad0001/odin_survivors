package survivors

import sdl "vendor:sdl3"

//vertex data
@(private)
Vec3 :: [3]f32


@(private)
SpriteData :: struct {
	position: Vec3, //position of the vertex
	color:    sdl.FColor, //color of the vertex
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
		zoom       = 1.0,
		max_zoom   = 10.0,
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
//TODO feature request when use stricty detect unused structs amd unions when marked with minimal @private tag (not high priority)
