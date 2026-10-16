#version 460 core

layout(location = 0) in vec4 vPosition;
layout(location = 1) in vec4 vColor;

out vec4 outColor;
uniform mat4 vProjection;

void main() {
	gl_Position = vProjection * vec4(vPosition.x, -vPosition.y, vPosition.z, vPosition.w);
	outColor = vColor;
}
