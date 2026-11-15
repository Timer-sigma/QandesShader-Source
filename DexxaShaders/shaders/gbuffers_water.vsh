#version 330 compatibility

#include "/lib/settings.glsl"

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform float frameTimeCounter;

attribute vec4 mc_Entity;
attribute vec2 mc_midTexCoord;

out vec2 texcoord;
out vec2 lmcoord;
out vec4 glcolor;
out vec3 normalW;
out vec3 viewPosW;
out float isWater;

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    glcolor  = gl_Color;
    normalW  = normalize(mat3(gl_NormalMatrix) * gl_Normal);

    vec4 pos = gl_ModelViewMatrix * gl_Vertex;
    isWater = mc_Entity.x == 10008.0 ? 1.0 : 0.0;

#ifdef ENABLE_WATER_WAVES
    // gentle vertical wave on water top faces (world-space Y displacement)
    if (isWater > 0.5 && normalW.y > 0.9) {
        float t = frameTimeCounter * WATER_WAVE_SPEED;
        vec4 worldPos = gbufferModelViewInverse * pos;
        float wave = sin(worldPos.x * 1.4 + t * 1.1) * 0.030
                   + sin(worldPos.z * 1.9 - t * 0.9) * 0.024
                   + sin((worldPos.x + worldPos.z) * 3.6 + t * 1.9) * 0.012;
        worldPos.y += wave;
        pos = gbufferModelView * worldPos;
    }
#endif

    viewPosW = pos.xyz;
    gl_Position = gl_ProjectionMatrix * pos;
}
