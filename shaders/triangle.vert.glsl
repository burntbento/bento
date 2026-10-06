#version 410 core

layout(location = 0) in vec4 vPosition;

uniform mat4 v_proj;
uniform mat4 v_translation;
uniform mat4 v_scale;

void main() {
	gl_Position = v_proj * v_translation * v_scale * vPosition;
}
