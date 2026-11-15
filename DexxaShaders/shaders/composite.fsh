#version 330 compatibility

#include "/lib/settings.glsl"
#include "/lib/common.glsl"

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D depthtex0;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

uniform vec3 skyColor;
uniform vec3 fogColor;
uniform float sunAngle;

in vec2 texcoord;

layout(location = 0) out vec4 outColor;

// project view-space pos to screen
vec3 viewToScreen(vec3 viewPos) {
    vec4 clip = gbufferProjection * vec4(viewPos, 1.0);
    return clip.xyz / clip.w * 0.5 + 0.5;
}

vec3 screenToView(vec3 screenPos) {
    vec4 ndc = vec4(screenPos * 2.0 - 1.0, 1.0);
    vec4 view = gbufferProjectionInverse * ndc;
    return view.xyz / view.w;
}

// medium-quality SSR: linear march + short binary refine
vec3 ssr(vec3 viewPos, vec3 viewNormal, float dither) {
    vec3 reflectDir = reflect(normalize(viewPos), viewNormal);
    reflectDir.z = -abs(reflectDir.z); // force toward viewer space -z (into screen)

    const int steps = SSR_STEPS;
    const int refine = SSR_REFINE_STEPS;

    float stepLen = 1.6 / float(steps);
    vec3 rayPos = viewPos + viewNormal * 0.05 + reflectDir * stepLen * dither;
    vec3 rayStep = reflectDir * stepLen;

    vec3 hitScreen = vec3(0.0);
    bool hit = false;

    for (int i = 0; i < steps; i++) {
        rayPos += rayStep;
        vec3 sp = viewToScreen(rayPos);
        if (clamp(sp.xy, 0.0, 1.0) != sp.xy) break;

        float sceneDepth = texture2D(depthtex0, sp.xy).r;
        float sampleViewZ = screenToView(vec3(sp.xy, sceneDepth)).z;
        float rayViewZ = rayPos.z;

        if (rayViewZ < sampleViewZ - 0.02 && rayViewZ > sampleViewZ - 1.2) {
            // binary refine
            vec3 lo = rayPos - rayStep;
            vec3 hi = rayPos;
            for (int j = 0; j < refine; j++) {
                vec3 mid = (lo + hi) * 0.5;
                vec3 msp = viewToScreen(mid);
                float mdepth = texture2D(depthtex0, msp.xy).r;
                float mviewZ = screenToView(vec3(msp.xy, mdepth)).z;
                if (mid.z < mviewZ - 0.02) hi = mid; else lo = mid;
            }
            hitScreen = viewToScreen((lo + hi) * 0.5);
            hit = true;
            break;
        }
    }

    if (!hit) return vec3(-1.0);
    if (clamp(hitScreen.xy, 0.0, 1.0) != hitScreen.xy) return vec3(-1.0);

    // fade near screen edges
    vec2 e = min(hitScreen.xy, 1.0 - hitScreen.xy);
    float edgeFade = smoothstep(0.0, 0.12, min(e.x, e.y));
    return texture2D(colortex0, hitScreen.xy).rgb * edgeFade;
}

void main() {
    vec4 color = texture2D(colortex0, texcoord);
    float depth = texture2D(depthtex0, texcoord).r;
    vec4 data1 = texture2D(colortex1, texcoord);

    if (depth >= 1.0 || data1.a < 0.004) {
        outColor = color;
        return;
    }

    vec3 normalW = decodeNormal(data1.rg);
    float smoothness = data1.b;
    float matId = floor(data1.a * 255.0 + 0.5);

    // only water and reflective surfaces
    if (matId < 0.5 || smoothness < 0.01) {
        outColor = color;
        return;
    }

    vec3 viewPos = screenToView(vec3(texcoord, depth));
    vec3 viewNormal = normalize(mat3(gbufferModelView) * normalW);

    // base color, optionally refracted by water wave normals
    vec3 baseColor = color.rgb;
#ifdef ENABLE_REFRACTION
    if (matId < 1.5) {
        float distFade = clamp(6.0 / max(length(viewPos), 1.0), 0.25, 1.5);
        vec2 off = viewNormal.xy * 0.018 * distFade;
        baseColor = texture2D(colortex0, clamp(texcoord + off, vec2(0.001), vec2(0.999))).rgb;
    }
#endif

    float dither = bayer4(gl_FragCoord.xy);
    vec3 refl = ssr(viewPos, viewNormal, dither);

    // fallback: procedural sky reflection
    vec3 reflDirView = reflect(normalize(viewPos), viewNormal);
    vec3 reflDirWorld = mat3(gbufferModelViewInverse) * reflDirView;
    vec3 skyRefl = proceduralSky(normalize(reflDirWorld), skyColor, fogColor, sunAngle);

    if (refl.r < 0.0) refl = skyRefl;
    refl *= REFLECTION_DARKEN; // slightly darker reflections

    float fres = fresnelSchlick(clamp(dot(-normalize(viewPos), viewNormal), 0.0, 1.0), 0.02);
    float strength = REFLECTION_STRENGTH * smoothness * (matId > 1.5 ? 1.0 : (0.35 + 0.65 * fres));

    vec3 finalColor = mix(baseColor, refl, clamp(strength, 0.0, 1.0));

#ifdef ENABLE_SUN_SPECULAR
    // sun glint on water
    if (matId < 1.5) {
        float dayVis = 1.0 - smoothstep(0.49, 0.52, sunAngle); // sun above horizon
        vec3 sunDirWorld = normalize(vec3(0.0, sin(sunAngle * 6.2831853), -cos(sunAngle * 6.2831853)));
        vec3 sunDirView = normalize(mat3(gbufferModelView) * sunDirWorld);
        float spec = pow(max(dot(reflDirView, sunDirView), 0.0), 220.0);
        spec += pow(max(dot(reflDirView, sunDirView), 0.0), 24.0) * 0.12; // soft glow
        finalColor += vec3(1.0, 0.85, 0.6) * spec * dayVis * 1.2;
    }
#endif

    outColor = vec4(finalColor, color.a);
}
