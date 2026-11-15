#version 330 compatibility

#include "/lib/settings.glsl"

attribute vec4 mc_Entity;
attribute vec2 mc_midTexCoord;

out vec2 texcoord;
out vec2 lmcoord;
out vec4 glcolor;
out vec3 normalW;
out float materialId;
out float smoothness;

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    glcolor  = gl_Color;

    normalW = normalize(mat3(gl_NormalMatrix) * gl_Normal);
    materialId = 2.0; // reflective opaque
    smoothness = 0.25; // medium default gloss for terrain

    // leaves / plants: no reflection
    float id = mc_Entity.x;
    if (id == 10001.0 || id == 10002.0) { materialId = 0.0; smoothness = 0.0; }

    gl_Position = ftransform();
}
