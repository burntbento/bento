#version 410 core

layout (location = 0) in vec3 aPos;
layout (location = 1) in vec3 aColor;
layout (location = 2) in vec2 aTexCoord;

uniform vec2 uv_offset;
uniform vec2 uv_scale;
uniform mat4 v_proj;
uniform mat4 v_translation;
uniform mat4 v_scale;

out vec3 ourColor;
out vec2 TexCoord;

void main() {
	gl_Position = v_proj * v_translation * v_scale * vec4(aPos.x, -aPos.y, aPos.z, 1.0);
  ourColor = aColor;
	TexCoord = uv_offset + uv_scale * vec2(aTexCoord.x, 1.0 - aTexCoord.y);
}
