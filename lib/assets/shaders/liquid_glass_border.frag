// -----------------------------------------------------------------------------
// Copyright © 2025 Ahmed Gamil
//
// Free to use in any project.
// If you find this useful, a small credit would be appreciated.
// -----------------------------------------------------------------------------

#include <flutter/runtime_effect.glsl>
#include "liquid_glass_border.glsl"
#include "liquid_glass_common.glsl"
#define PI 3.14159265
precision highp float; // or highp float

/* ================
   SHARED UNIFORMS
   ================ */
uniform vec2 u_resolution;
uniform vec2 u_touch;
uniform sampler2D u_texture_input;

uniform float u_lensWidth;
uniform float u_lensHeight;
uniform float u_shapeType; // 0 = rounded-rect, 1 = superellipse
uniform float u_cornerRadius;
uniform float u_superN;
uniform float u_magnification;
uniform float u_distortion;
uniform float u_distortionThicknessPx;
uniform float u_enableBackgroundTransparency;
uniform float u_diagonalFlip;

// Border controls
uniform float u_borderWidth;
uniform float u_borderSoftness;
uniform vec4  u_borderColor;
uniform float u_borderAlpha;
uniform float u_lightIntensity;
uniform vec4  u_lightColor;
uniform vec4  u_shadowColor;
uniform float u_lightDirection;
uniform float u_oneSideLightIntensity;
uniform float u_chromaticAberration;
uniform float u_saturation;
uniform float u_lightMode;
uniform float u_refractionMode;
uniform float u_ambientIntensity;
uniform float u_doubleSideLightIntensity;
uniform float u_borderSaturation;
uniform float u_borderSolidity;
uniform float u_borderMode;

out vec4 frag_color;

#define REFRACTION_SHAPE    0
#define REFRACTION_RADIAL   1

vec3 applyChromaticAberration(vec2 uv, float shift) {
    vec3 color = texture(u_texture_input, uv).rgb;
    if (shift < 0.001) return color;

    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
    vec2 offset = vec2(shift * luma);

    float r = texture(u_texture_input, uv + offset).r;
    float g = texture(u_texture_input, uv).g;
    float b = texture(u_texture_input, uv - offset).b;

    return vec3(r, g, b);
}

vec3 applySaturation(vec3 color, float saturation) {
    float luminance = dot(color, vec3(0.299, 0.587, 0.114));
    return mix(vec3(luminance), color, saturation);
}

vec3 sampleAmbientColor(vec2 refractedNorm, vec2 texScale) {
    vec2 sampleUV = clamp(refractedNorm * texScale, vec2(0.001), vec2(0.999));
    #ifdef IMPELLER_TARGET_OPENGLES
    sampleUV.y = 1.0 - sampleUV.y;
    #endif

    vec3 color = applyChromaticAberration(sampleUV, u_chromaticAberration);
    return applySaturation(color, u_saturation);
}

/* ================
   MAIN
   ================ */
void main() {
    vec2 fragPosPx = FlutterFragCoord().xy;
    float invResY  = 1.0 / u_resolution.y;
    vec2  uvNorm   = fragPosPx * invResY;
    vec2  texScale = u_resolution.y / u_resolution;

    vec2 lensHalfSizePx = 0.5 * vec2(u_lensWidth, u_lensHeight);
    vec2 lensCenterPx   = u_touch + lensHalfSizePx;
    vec2 lensCenterNorm = lensCenterPx * invResY;

    // =====================================================
    // Shape distance (only this part changes per shape)
    // =====================================================
    ShapeData shapeData;
    if (u_shapeType > 0.5) {
        // Superellipse
        float n = max(u_superN, 1.0001);
        shapeData = evaluateShape(fragPosPx,lensCenterPx, lensHalfSizePx, n,u_shapeType);
    } else {
        // Rounded rectangle
        float maxCorner      = min(u_lensWidth, u_lensHeight) * 0.5;
        float cornerRadiusPx = min(u_cornerRadius, maxCorner);
        shapeData = evaluateShape(
            fragPosPx,
            lensCenterPx,
            lensHalfSizePx,
            cornerRadiusPx,
            u_shapeType
        );
    }

    // =====================================================
    // Border (shared for both shapes)
    // =====================================================
    vec3 ambientCol = vec3(0.0);

    // Clip border to inner side only — discard fragments outside the shape
    if (shapeData.orthoDist > 0.0) {
        frag_color = vec4(0.0);
        return;
    }

    vec2 magPx = applyLensMagnification(
        fragPosPx,
        lensCenterPx,
        u_magnification
    );
    vec2 magUV = magPx * invResY;

    float distAbsPx = abs(shapeData.orthoDist);
    float zoneLimit = u_distortionThicknessPx;
    float zoneMask = step(distAbsPx, zoneLimit);

    ambientCol = vec3(0.0);
    if (zoneMask < 0.5) {
        if (u_enableBackgroundTransparency <= 0.5) {
            ambientCol = sampleAmbientColor(magUV, texScale);
        }
    } else {
        float zoneT = 1.0 - clamp(distAbsPx / max(zoneLimit, EPS), 0.0, 1.0);
        float distortionFactor = computeDistortionFactor(u_distortion, zoneT);
        vec2 refrPx;

        if (u_refractionMode == REFRACTION_SHAPE) {
            refrPx = computeShapeRefraction(
                magPx,
                shapeData.normal,
                shapeData.sdf,
                u_distortionThicknessPx,
                distortionFactor,
                u_magnification,
                u_diagonalFlip,
                zoneT
            );
        } else {
            refrPx = refractFromAnchorPx(
                magPx,
                lensCenterPx,
                distortionFactor,
                u_magnification,
                u_diagonalFlip,
                zoneT
            );
        }

        ambientCol = sampleAmbientColor(refrPx * invResY, texScale);
    }

    // Double the border width so that after clipping the outer half,
    // the visible inner portion matches the intended width
    float effectiveBorderWidth = u_borderWidth * 2.0;

    vec4 borderPremul = getSweepBorder(
        uvNorm,
        lensCenterNorm,
        shapeData.orthoDist,
    shapeData.grad,// unified signed-distance value
        effectiveBorderWidth,
        u_borderSoftness,
        u_borderColor,
        u_lightColor,
        u_shadowColor,
        u_lightIntensity,
        u_borderAlpha,
        u_lightDirection, u_oneSideLightIntensity,u_lightMode,
        ambientCol, u_ambientIntensity,
        u_doubleSideLightIntensity,
        u_borderSaturation,
        u_borderSolidity,
        u_borderMode
    );
    frag_color = borderPremul;
}
