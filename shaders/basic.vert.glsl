#version 460 core

layout(location = 0) in vec4 vPosition;
layout(location = 1) in vec4 vColor;

in mat4 vProjection;
out vec4 outColor;

void main() {
	gl_Position = vProjection * vPosition;
	outColor = vColor;
}
