// -----------------------------------------------------------------------------
// EXPERIMENTAL — continuous-curvature (Apple-style) squircle glass that runs
// the SAME refraction pipeline as liquid_glass.frag, but sourced from a baked
// SDF texture instead of an analytic SDF.
//
// It #includes liquid_glass_common.glsl and calls the identical helpers
// (evaluateShape's gradient model, computeDistortionFactor,
//  computeShapeRefraction, applySaturation). The ONLY difference from the main
// shader is `evaluateShapeFromSdf`, which reads `sd` from the baked texture and
// derives the gradient/normal with the exact same 5-tap central difference.
//
// Baked SDF encoding (see liquid_glass_sdf_baker.dart):
//   R = signed distance: sd = (R*2 - 1) * u_maxDistance   (px, <0 inside)
//   A = coverage
// -----------------------------------------------------------------------------

#include <flutter/runtime_effect.glsl>
#include "liquid_glass_common.glsl"

precision highp float;

uniform vec2  u_resolution;     // full canvas size (logical px)
uniform sampler2D u_content;    // background being refracted (fills canvas)
uniform sampler2D u_sdf;        // baked SDF texture

uniform vec2  u_lensTopLeft;    // lens top-left in canvas px
uniform vec2  u_lensSize;       // lens size in px
uniform vec2  u_sdfTexSize;     // SDF texture pixel size (= lensSize + 2*pad)
uniform float u_padding;        // baked empty border (px)
uniform float u_maxDistance;    // distance that maps R to 0/1 (px)

uniform float u_magnification;
uniform float u_distortion;
uniform float u_distortionThicknessPx;
uniform float u_diagonalFlip;
uniform float u_saturation;
uniform float u_chromaticAberration;

out vec4 frag_color;

// ── Sample the baked signed distance (px) at a canvas pixel coord ──
float sampleSdfPx(vec2 fragPx) {
    vec2 sdfPx = (fragPx - u_lensTopLeft) + vec2(u_padding);
    vec2 uv = sdfPx / u_sdfTexSize;
    vec4 s = texture(u_sdf, uv);
    return (s.r * 2.0 - 1.0) * u_maxDistance;
}

// ── Identical to evaluateShape() in liquid_glass_common.glsl, but the SDF
//    samples come from the baked texture instead of the analytic functions. ──
ShapeData evaluateShapeFromSdf(vec2 fragPx) {
    float h = 1.0;
    float fC  = sampleSdfPx(fragPx);
    float fXp = sampleSdfPx(fragPx + vec2(h, 0.0));
    float fXm = sampleSdfPx(fragPx - vec2(h, 0.0));
    float fYp = sampleSdfPx(fragPx + vec2(0.0, h));
    float fYm = sampleSdfPx(fragPx - vec2(0.0, h));

    vec2 grad = 0.5 * vec2(fXp - fXm, fYp - fYm);
    float gL  = max(length(grad), EPS);

    ShapeData d;
    d.sdf       = fC;
    d.grad      = grad;
    d.normal    = grad / gL;
    d.orthoDist = fC / gL;
    return d;
}

// ── Minimal sampling helpers (same math as liquid_glass.frag) ──
vec3 applyChromaticAberration(vec2 uv, float shift) {
    vec3 color = texture(u_content, uv).rgb;
    if (shift < 0.001) return color;
    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
    vec2 offset = vec2(shift * luma);
    float r = texture(u_content, uv + offset).r;
    float g = texture(u_content, uv).g;
    float b = texture(u_content, uv - offset).b;
    return vec3(r, g, b);
}

vec3 applySaturation(vec3 color, float saturation) {
    float luminance = dot(color, vec3(0.299, 0.587, 0.114));
    return mix(vec3(luminance), color, saturation);
}

float computeShapeMask(float shapeDistPx) {
    float aa = 1.0;
    float mask = 1.0 - smoothstep(0.0, aa, shapeDistPx);
    mask *= step(shapeDistPx, 0.0);
    return mask;
}

vec4 finalSample(vec2 refractedScaled, vec2 texScale, float shapeMask) {
    vec2 sampleUV = clamp(refractedScaled * texScale, vec2(0.001), vec2(0.999));
    vec3 c = applyChromaticAberration(sampleUV, u_chromaticAberration);
    c = applySaturation(c, u_saturation);
    return vec4(c * shapeMask, shapeMask);
}

void main() {
    vec2 fragPx   = FlutterFragCoord().xy;
    float invResY = 1.0 / u_resolution.y;
    vec2 texScale = u_resolution.y / u_resolution;

    vec2 lensCenterPx = u_lensTopLeft + 0.5 * u_lensSize;

    // Shape distance from the baked SDF (your evaluateShape, texture-sourced).
    ShapeData shapeData = evaluateShapeFromSdf(fragPx);
    float shapeDistPx = shapeData.orthoDist;
    float shapeMask   = computeShapeMask(shapeDistPx);

    float distAbsPx = abs(shapeDistPx);
    float zoneLimit = u_distortionThicknessPx;
    float zoneMask  = step(distAbsPx, zoneLimit);

    vec2 magPx = applyLensMagnification(fragPx, lensCenterPx, u_magnification);
    vec2 magUV = magPx * invResY;

    if (zoneMask < 0.5) {
        // Outside the distortion band — plain magnified sample.
        frag_color = finalSample(magUV, texScale, shapeMask);
        return;
    }

    // Inside the distortion band — your shape refraction, verbatim.
    float zoneT = 1.0 - clamp(distAbsPx / max(zoneLimit, EPS), 0.0, 1.0);
    float distortionFactor = computeDistortionFactor(u_distortion, zoneT);

    vec2 refrPx = computeShapeRefraction(
        magPx,
        shapeData.normal,
        shapeData.sdf,
        u_distortionThicknessPx,
        distortionFactor,
        u_magnification,
        u_diagonalFlip,
        zoneT
    );

    vec2 refrUV = refrPx * invResY;
    frag_color = finalSample(refrUV, texScale, shapeMask);
}
