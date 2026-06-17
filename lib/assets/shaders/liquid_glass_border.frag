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
uniform float u_cornerRadius;
// Corner shape selector — mirrors liquid_glass.frag:
//   0 = circular rounded rect, 1 = squircle (full smoothing),
//   2 = continuous (Apple capsule-style).
uniform float u_cornerStyle;
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

// Capture-region mapping — see liquid_glass.frag. The bound texture
// covers parent rect [u_imageOffset, u_imageOffset + u_imageSize].
// Full-frame = (0,0)/u_resolution (old behavior); region = sub-rect.
uniform vec2 u_imageOffset;
uniform vec2 u_imageSize;

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

vec3 sampleAmbientColor(vec2 refractedPx) {
    // Map parent-pixel position into the bound texture's region rect.
    // Full-frame = refractedPx / u_resolution (old behavior).
    vec2 sampleUV = clamp((refractedPx - u_imageOffset) / u_imageSize,
                          vec2(0.001), vec2(0.999));
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

    vec2 lensHalfSizePx = 0.5 * vec2(u_lensWidth, u_lensHeight);
    vec2 lensCenterPx   = u_touch + lensHalfSizePx;
    vec2 lensCenterNorm = lensCenterPx * invResY;

    // =====================================================
    // Shape distance (only this part changes per shape)
    // =====================================================
    ShapeData shapeData;
    // Rounded rectangle. u_cornerStyle selects the corner SDF
    //   (2 = continuous, 1 = squircle, 0 = circular). Must mirror the main
    //   shader's branch exactly so the rim hugs the same outline as the fill.
    float maxCorner      = min(u_lensWidth, u_lensHeight) * 0.5;
    float cornerRadiusPx = min(u_cornerRadius, maxCorner);

    if (u_cornerStyle > 1.5 && cornerRadiusPx > 0.5) {
        // Continuous (Apple capsule-style) corners.
        vec2 reach = continuousRoundedRectReach(cornerRadiusPx, lensHalfSizePx);
        shapeData = evaluateContinuousRoundedRect(
            fragPosPx, lensCenterPx, lensHalfSizePx, cornerRadiusPx, reach);
    } else if (u_cornerStyle > 0.5 && cornerRadiusPx > 0.5) {
        // Squircle (Ln-norm) corners — smoothing fixed at full (1.0).
        vec2 zn = squircleCornerParams(cornerRadiusPx, 1.0, maxCorner);
        shapeData = evaluateSquircleRRect(
            fragPosPx, lensCenterPx, lensHalfSizePx, zn.x, zn.y);
    } else {
        shapeData = evaluateShape(
            fragPosPx,
            lensCenterPx,
            lensHalfSizePx,
            cornerRadiusPx
        );
    }

    // =====================================================
    // Border (shared for both shapes)
    // =====================================================
    vec3 ambientCol = vec3(0.0);

    // Soft outer-edge mask. The Skia path got outer AA "for free"
    // from the drawRRect call wrapping the border painter; on
    // Impeller (ImageFilter.shader inside a BackdropFilter) there is
    // no such wrapping draw, so we have to fade the border alpha
    // ourselves over the last screen-space pixel of the shape.
    //
    // 1-pixel constant — fwidth(float) trips up SkSL on some
    // devices, so don't use it.
    float outerAa = 1.0;
    float outerMask = 1.0 - smoothstep(-outerAa * 0.5, outerAa * 0.5,
                                       shapeData.orthoDist);

    // Cheap early-out for fragments well past the AA band.
    if (shapeData.orthoDist > outerAa) {
        frag_color = vec4(0.0);
        return;
    }

    vec2 magPx = applyLensMagnification(
        fragPosPx,
        lensCenterPx,
        u_magnification
    );
    float distAbsPx = abs(shapeData.orthoDist);
    float zoneLimit = u_distortionThicknessPx;
    float zoneMask = step(distAbsPx, zoneLimit);

    ambientCol = vec3(0.0);
    if (zoneMask < 0.5) {
        if (u_enableBackgroundTransparency <= 0.5) {
            ambientCol = sampleAmbientColor(magPx);
        }
    } else {
        float zoneT = 1.0 - clamp(distAbsPx / max(zoneLimit, EPS), 0.0, 1.0);
        float distortionFactor = computeDistortionFactor(u_distortion, zoneT);
        vec2 refrPx;

        if (u_refractionMode == REFRACTION_SHAPE) {
            // Stable shape refraction (inset-anchor based) — keep in
            // sync with liquid_glass.frag.
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

            // Experimental physical (Snell's law) refraction — disabled
            // for now (suspected Impeller raster crash on some devices).
            // Kept here to re-enable later; do not delete.
            // refrPx = computeRefractedPosition(
            //     magPx,
            //     shapeData.normal,
            //     shapeData.sdf,
            //     u_distortionThicknessPx,
            //     3.0,
            //     u_distortion,
            //     zoneT
            // );
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

        ambientCol = sampleAmbientColor(refrPx);
    }

    // The caller already passes the full band width (pre-doubled, and
    // including the optical-mode extra when applicable). After clipping
    // the outer half, the visible inner portion matches the intended
    // width. Kept as a named local for readability.
    float effectiveBorderWidth = u_borderWidth;

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
    // Apply the soft outer-edge mask so the rounded corners fade
    // out smoothly on Impeller (where there's no surrounding draw
    // call to provide AA).
    frag_color = borderPremul * outerMask;
}
