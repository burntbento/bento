#version 460 core

layout(location = 0) in vec4 vPosition;
layout(locattion = 1) in vec4 vColor;

in vec4 vProjection;
out vec4 outColor;

void main() {
	gl_Position = vProjection;
	outColor = vColor;
}
