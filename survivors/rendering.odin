package survivors

import sdl "vendor:sdl3"

@(private)
Camera :: struct {
	x:            f32,
	y:            f32,
	zoom:         f32,
	max_zoom:     f32,
	zoom_speed:   f32,
	speed: f32,
}

@(private)
camera_init :: proc() -> Camera {
	camera: Camera = Camera {
		x            = 0,
		y            = 0,
		zoom         = 1.0,
		max_zoom     = 10.0,
		zoom_speed   = 4.0,
		speed = 2.0,
	}

	return camera
}

@(private)
DrawCommandBuffer :: union {}

@(private)
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
//TODO feature request when use stricty detect unused structs amd unions when marked with minimal @private tag (not high priority)
