#version 460 core

layout(location = 0) in vec4 vPosition;
layout(location = 1) in vec4 vColor;
layout(location = 2) in vec2 vUV;

out vec4 outColor;
out vec2 outUv;
uniform mat4 vProjection;

void main() {
	gl_Position = vProjection * vec4(vPosition.x, -vPosition.y, vPosition.z, vPosition.w);
	outUv = vUV;
	outColor = vColor;
}
