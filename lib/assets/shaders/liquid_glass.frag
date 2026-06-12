// -----------------------------------------------------------------------------
// Copyright © 2025 Ahmed Gamil
//
// Free to use in any project.
// If you find this useful, a small credit would be appreciated.
// -----------------------------------------------------------------------------

#include <flutter/runtime_effect.glsl>
#include "liquid_glass_common.glsl"
#include "liquid_glass_border.glsl"
#define PI 3.14159265

precision highp float;

// =====================================================
// Uniforms
// =====================================================
uniform vec2  u_resolution;
uniform vec2  u_touch;
uniform sampler2D u_texture_input;
uniform float u_lensWidth;
uniform float u_lensHeight;
uniform float u_cornerRadius;
uniform float u_cornerSmoothing;

uniform float u_magnification;
uniform float u_distortion;
uniform float u_distortionThicknessPx;
uniform float u_enableBackgroundTransparency;
uniform float u_diagonalFlip;

// Border
uniform float u_borderWidth;
uniform float u_borderSoftness;
uniform vec4  u_borderColor;
uniform float u_borderAlpha;
uniform float u_lightIntensity;
uniform vec4  u_lightColor;
uniform vec4  u_shadowColor;
uniform float u_lightDirection;
uniform vec4 u_lensColor;
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

// Slider/toggle opt-in: when > 0.5, the refracted BACKGROUND sample's
// captured alpha is honored — the lens output coverage is multiplied by
// the texel's alpha so the real backdrop shows through in proportion to
// its transparency (a fully transparent texel becomes fully transparent,
// a 50%-alpha colored texel blends 50% with the backdrop). Keyed on the
// background sample only; the border overlay is applied afterwards and
// survives. No-op when 0 (every full-screen / opaque-background lens).
uniform float u_transparentWhenBlack;

// Capture-region mapping. The bound texture (u_texture_input) covers the
// parent-space rectangle [u_imageOffset, u_imageOffset + u_imageSize] in
// the SAME pixel space as FlutterFragCoord / u_resolution. For a normal
// full-frame capture this is offset (0,0) and size u_resolution, which
// reproduces the old `refrPx / u_resolution` mapping exactly. For a
// region capture it is the captured sub-rect, so a smaller texture can be
// bound without recompositing it back to full size.
uniform vec2 u_imageOffset;
uniform vec2 u_imageSize;


out vec4 frag_color;

// ===================================================

#define REFRACTION_SHAPE    0
#define REFRACTION_RADIAL   1

#define PIXEL_TO_NORM(px) ((px) / u_resolution.y)

vec3 applyChromaticAberration(vec2 uv, float shift) {
    // Compute offsets based on luma
    vec3 color = texture(u_texture_input, uv).rgb;
    if(shift < 0.001) return color;
    // Luma calculation (Rec. 709)
    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));

    // Offset depends on brightness
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
// ===================================================
// Final texture sampling after refraction
// ===================================================


vec4 finalSample(
    vec2 refractedPx,
    float shapeMask,
    out vec3 preTintColor
){
    vec3 refrColor;

    // Map the refracted PARENT-pixel position into the bound texture's
    // [u_imageOffset, u_imageOffset + u_imageSize] rect. Full-frame =
    // (refractedPx - 0) / u_resolution, identical to the old behavior.
    vec2 sampleUV = clamp((refractedPx - u_imageOffset) / u_imageSize,
                          vec2(0.001), vec2(0.999));
    #ifdef IMPELLER_TARGET_OPENGLES
    sampleUV.y = 1.0 - sampleUV.y;
    #endif
    refrColor = applyChromaticAberration(sampleUV, u_chromaticAberration);
    // Apply saturation BEFORE tinting
    refrColor = applySaturation(refrColor,u_saturation);
    preTintColor = refrColor; // capture before tint for optical border

    // Alpha-honoring transparency (slider/toggle opt-in). The captured
    // background is a premultiplied RGBA texture: a fully transparent
    // texel decodes to black (rgb 0, a 0) and a colored-but-semi-
    // transparent texel keeps its premultiplied rgb plus a partial
    // alpha. When the flag is on we sample that alpha and fold it into
    // the output coverage so the real backdrop shows through in
    // proportion to the texel's transparency — instead of forcing the
    // sample opaque (the old binary black-key dropped only near-black
    // pixels and also clobbered genuinely dark opaque content). Because
    // the sample is premultiplied, refrColor * shapeMask stays the
    // correct premultiplied rgb; only the alpha changes. The caller
    // still lays the border on top afterwards, so the rim survives.
    float coverage = shapeMask;
    if (u_transparentWhenBlack > 0.5) {
        float texAlpha = texture(u_texture_input, sampleUV).a;
        coverage = shapeMask * texAlpha;
    }

    vec4 base = vec4(refrColor * shapeMask, coverage);
    // Then apply lens tint
    base.rgb = applyLensTint(base.rgb, shapeMask, u_lensColor, u_borderAlpha);
    return base;
}


float computeShapeMask(float shapeDistPx) {
    // Original behavior — always worked on Skia and Impeller.
    // Don't try to use fwidth(): SkSL's transpiler chokes on
    // fwidth(float) and the vec2 workaround was wrong on this
    // device too. A 1-pixel constant is fine in practice.
    float aa = 1.0;
    float mask = 1.0 - smoothstep(0.0, aa, shapeDistPx);
    mask *= step(shapeDistPx, 0.0);
    return mask;
}


// =====================================================
// Main entry
// =====================================================
void main() {
    // ===============================
    // Fragment coordinate setup
    // ===============================
    vec2 fragPx   = FlutterFragCoord().xy;
    float invResY = 1.0 / u_resolution.y;
    vec2 uvNorm   = fragPx * invResY;

    // ===============================
    // Lens geometry
    // ===============================
    vec2 lensHalfSizePx = 0.5 * vec2(u_lensWidth, u_lensHeight);
    vec2 lensCenterPx   = u_touch + lensHalfSizePx;
    vec2 lensCenterNorm = lensCenterPx * invResY;

    // ===============================
    // Shape distance (SDF)
    // ===============================
    float shapeDistPx;
    float shapeMask;
    ShapeData shapeData;

    // Rounded rectangle. u_cornerSmoothing carries the CONTINUOUS-CORNER
    // smoothing (0 = plain circular corners, 1 = full Apple-style
    // continuous corners).
    float maxCorner      = min(u_lensWidth, u_lensHeight) * 0.5;
    float cornerRadiusPx = min(u_cornerRadius, maxCorner);
    float smoothing      = clamp(u_cornerSmoothing, 0.0, 1.0);

    if (smoothing > 0.001 && cornerRadiusPx > 0.5) {
        vec2 zn = continuousCornerParams(cornerRadiusPx, smoothing, maxCorner);
        shapeData = evaluateContinuousRRect(
            fragPx, lensCenterPx, lensHalfSizePx, zn.x, zn.y);
    } else {
        shapeData = evaluateShape(
            fragPx,
            lensCenterPx,
            lensHalfSizePx,
            cornerRadiusPx
        );
    }

    shapeDistPx = shapeData.orthoDist;

    // --- Shared antialiasing + mask ---
    shapeMask = computeShapeMask(shapeDistPx);

    // ===============================
    // Distortion band setup
    // ===============================
    float distAbsPx = abs(shapeDistPx);
    float zoneLimit = u_distortionThicknessPx;
    float zoneMask  = step(distAbsPx, zoneLimit);

    // ===============================
    // Apply uniform magnification to entire lens
    // ===============================

    vec2 magPx = applyLensMagnification(
        fragPx,
        lensCenterPx,
        u_magnification
    );

    if (zoneMask < 0.5) {
        // Outside distortion zone
        vec3 preTintCol = vec3(0.0);
        vec4 base = (u_enableBackgroundTransparency > 0.5)
        ? vec4(0.0)
        : finalSample(magPx, shapeMask, preTintCol);

        vec3 ambientCol = preTintCol;
        vec4 borderPremul = getSweepBorder(
            uvNorm, lensCenterNorm, shapeData.orthoDist,shapeData.grad,
            u_borderWidth, u_borderSoftness, u_borderColor,
            u_lightColor, u_shadowColor,
            u_lightIntensity, u_borderAlpha, u_lightDirection, u_oneSideLightIntensity,u_lightMode,
            ambientCol, u_ambientIntensity,
            u_doubleSideLightIntensity,
            u_borderSaturation,
            u_borderSolidity,
            u_borderMode
        );

        frag_color = overlayPremul(base, borderPremul, u_borderMode);
        return;
    }

    // ===============================
    // Distortion zone logic
    // ===============================
    float zoneT = 1.0 - clamp(distAbsPx / max(zoneLimit, EPS), 0.0, 1.0);
    float distortionFactor = computeDistortionFactor(u_distortion, zoneT);

    // ===============================
    // Refracted position
    // ===============================

    vec2 refrPx;

    if(u_refractionMode== REFRACTION_SHAPE) {
        // Stable shape refraction (inset-anchor based).
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
    }
    else if(u_refractionMode== REFRACTION_RADIAL){
        vec2 distortionCenter = lensCenterPx;
        refrPx = refractFromAnchorPx(
            magPx,
            distortionCenter,
            distortionFactor,
            u_magnification,
            u_diagonalFlip,
            zoneT
        );
    }
    // ===============================
    // Final sample & border
    // ===============================
    vec3 preTintCol2 = vec3(0.0);
    vec4 base = finalSample(refrPx, shapeMask, preTintCol2);

    vec3 ambientCol2 = preTintCol2;
    vec4 borderPremul = getSweepBorder(
        uvNorm, lensCenterNorm, shapeData.orthoDist,shapeData.grad,
        u_borderWidth, u_borderSoftness, u_borderColor,
        u_lightColor, u_shadowColor,
        u_lightIntensity, u_borderAlpha, u_lightDirection, u_oneSideLightIntensity,u_lightMode,
        ambientCol2, u_ambientIntensity,
        u_doubleSideLightIntensity,
        u_borderSaturation,
        u_borderSolidity,
        u_borderMode
    );

    // ===============================
    // Output composite
    // ===============================
    frag_color = overlayPremul(base, borderPremul, u_borderMode);
}
