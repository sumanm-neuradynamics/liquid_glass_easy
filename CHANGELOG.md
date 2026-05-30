## 2.0.1
- Fixed lens position being clamped to the parent bounds even when `outOfBoundaries: true`. A lens moved past the parent's edge (in any direction) now keeps its true position instead of being pinned, so spacing between lenses stays correct.

## 2.0.0
- Added **optical border mode** (`OpticalBorder`) — Apple-style, SDF-based rim lighting with background-tinted highlights, dual-sided specular reflections, and a lens height profile — alongside the existing `ClassicBorder`.
- Added new ready-made components: `LiquidGlassButton`, `LiquidGlassSearchBar`, `LiquidGlassAppIcon`, `LiquidGlassDock`, `LiquidGlassTabBar`, and `LiquidGlassBottomNavBar`.
- Improved rendering stability on release/profile builds with Impeller.
- Fixed lens and border content rendering upside down on Impeller's OpenGL ES backend (older Android devices) by inverting the texture sample Y-axis under `IMPELLER_TARGET_OPENGLES`.
- **Breaking:** `oneSideLightIntensity` and `doubleSideLightIntensity` moved from the shape to `ClassicBorder`. Pass them via `borderType: ClassicBorder(...)` instead of directly on the shape.

## 1.1.1
- Formatted the dart files and changed the size of the thumbnail of screenshot.

## 1.1.0
- Added new refraction modes: **shape refraction** and **radial refraction**.
- Added new light modes: **edge** and **radial**.
- Added **chromatic aberration** support.
- Added **one side light intensity** support.
- Added **saturation** control.
- Updated magnification behavior to apply to the entire lens area rather than only the distortion region.
- Improved and optimized shader code.
- Removed `highDistortionOnCurves`; the same effect can now be achieved by increasing `distortion` and setting `distortionWidth` to half of the smallest lens dimension.

## 1.0.0
**Initial Stable Release – Liquid Glass Easy**

- First official release of the **`liquid_glass_easy`** Flutter package.
- Provides real-time **liquid glass lens effects** with smooth distortion, magnification, and refraction.
- Built with **shader-based rendering** for high performance and flexibility.
- Includes `LiquidGlassView` and `LiquidGlass` widgets for quick and easy integration into any UI.
- Example app included to demonstrate usage, configuration, and visual styles.
- Ready for production and pub.dev distribution.

