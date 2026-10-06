#version 430 core

layout(location = 0) in vec4 vPosition;

uniform mat4 u_proj;

void main() {
	gl_Position = u_proj * vPosition;
}
