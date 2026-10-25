# App icon

The app icon uses an opaque, square blue background that extends to every edge.
Do not bake rounded corners or a white outer margin into the artwork.

The source asset is `EasySchengen/Assets.xcassets/AppIcon.appiconset/AppIcon-1024x1024.png`.
All 18 PNGs in that asset catalog were resized from the same corrected image using
`sips`, with dimensions taken from `Contents.json`. Every PNG has no alpha channel.

## Artwork correction, 2026-10-25

Edited with the built-in Imagegen tool using the previous 1024px icon as the edit
target and `transparent_background: false`.

Prompt:

> Use case: precise-object-edit. Asset type: existing iOS app icon, square 1024x1024. Input image is the edit target. Make one minimal correction: remove the white outer margin and white rounded-corner areas by seamlessly extending the existing rich blue background to all four straight image edges and all four square corners. Output must be a full-bleed completely opaque square blue image, no rounded outer shape, no border, no white fringe. Preserve the existing central white calendar, all twelve yellow stars, their exact positions, sizes, shapes, colors and shadows, and the blue gradient as closely as possible. Do not redesign, recenter, enlarge or change any symbol. Do not add text, additional stars, a frame, or transparency.
