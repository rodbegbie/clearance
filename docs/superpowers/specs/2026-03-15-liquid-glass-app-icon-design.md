# Liquid Glass App Icon Design

Date: 2026-03-15
Status: Approved for planning

## Goal

Update the existing `assets/branding/clearance-app-icon.svg` so it feels more aligned with Apple's newer Liquid Glass visual language while preserving the current icon concept:

- Rounded-square app icon background
- Document sheet centered in the icon
- Markdown heading/hash motif
- Mountain backdrop and blue palette

The icon should feel more luminous, layered, and glass-like without becoming abstract or losing small-size legibility.

## Selected Direction

Chosen direction: `Option C: Glossy Glass`

This direction keeps the current composition intact and increases:

- Background bloom and atmospheric depth
- Glass-like translucency on the paper/document panel
- Specular highlights and rim lighting
- Subtle glow around the hash glyph treatments

## Approach Options Considered

### Option A: Subtle Glass

Preserve the current icon almost exactly and add only light highlight and translucency changes.

Trade-off:
- Lowest risk
- Least visual change
- Weakest alignment with the requested Liquid Glass style

### Option B: Balanced Glass

Add visible but restrained material cues to the document and background.

Trade-off:
- Good legibility
- More modern material feel
- Less distinctive than the glossy direction

### Option C: Glossy Glass

Push reflections, luminous gradients, and translucent layering while keeping the same layout.

Trade-off:
- Strongest Liquid Glass read
- Most visually updated
- Slightly higher risk of over-stylization if highlights are too strong

This was selected.

## Visual Design

### Composition

The icon layout remains unchanged:

- Full-bleed rounded-square background
- Two mountain layers behind the document
- Main paper/document card
- Header and body text bars
- Large `#` and `##` treatments as the primary brand signal

No new symbols, badges, or layout simplifications are introduced in this pass.

### Material Treatment

The refresh should emphasize glass-like qualities using SVG-native effects:

- Brighter top-left and top-edge reflective bloom on the background
- More contrast between atmospheric background layers and the foreground document
- Semi-translucent document fill with a cooler tint instead of an opaque paper slab
- Thin rim-light or edge highlight to help the document feel like a glass pane
- Controlled highlight streaks or soft reflective bands across the document surface

### Color

The current blue family remains the base palette. Changes should stay within that system:

- Lighter ice-blue highlights
- Slightly cooler white/blue document tones
- Deeper low-end background blues for contrast
- Hash glyphs remain vivid blue and become slightly more radiant

## Data Flow and Asset Impact

Only the source SVG and generated icon outputs are in scope.

Primary source:

- `assets/branding/clearance-app-icon.svg`

Generated outputs:

- `Clearance/Resources/Assets.xcassets/AppIcon.appiconset/*`

The existing icon generation script remains the supported path for raster asset regeneration:

- `scripts/generate-app-iconset.sh`

## Error Handling

Failure modes to avoid:

- Highlights overpowering the content bars or hash marks
- Reduced contrast causing poor readability at small sizes
- Blur or glow effects becoming muddy when rasterized to smaller icon sizes
- Overly transparent document fill causing the icon to look washed out

Mitigations:

- Keep large shapes and the heading motif clearly separated in tone
- Prefer broad gradients and restrained blur over intricate detail
- Regenerate the iconset and inspect representative output sizes

## Testing and Verification

Implementation will be verified by:

- Regenerating the AppIcon asset set from the updated SVG
- Reviewing the generated 32px, 128px, 256px, and 1024px outputs
- Confirming the icon still reads clearly as a document/Markdown app at small sizes
- Confirming no build asset paths or script expectations change

## Out of Scope

- Redesigning the icon to a new abstract symbol
- Changing the overall composition or brand motif
- Reworking app branding outside the icon asset set
