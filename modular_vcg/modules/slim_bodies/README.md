# Optional slim female bodies

Character preferences now include **Body build → Standard / Slim (female)**.
The choice is independent of character gender. It applies to female humanoids
with human organic chests; male, digitigrade and other species bodies retain
their existing appearance. It changes no stats, movement, collision or anatomy.
The preference defaults to Standard and is stored per character. Its DNA feature
also travels through normal DNA copying; it does not replace existing limb IDs.

The native head, chest, arms, hands and legs come from the old vampire fork's
`shuman_*` bodyparts, renamed to modern `human_*` states. Current TG skin colors,
limb layers, dismemberment, leg masks and height handling are retained. Limbs cache
the build separately and detached limbs keep the shape they last acquired.

## Clothes and conversion

Crimson already contains `modular_darkpack/modules/clothes/icons/worn_slim_f.dmi`
(267 states). This PR activates layout-compatible native states through
`compatible_worn_f.dmi`, generated against the corresponding standard clothing
sheet (238 compatible states). A two-frame source with only one native frame
falls back to conversion, preserving its animation. The complete old female wardrobe is also
retained in `icons/legacy_worn_f.dmi` (223 states), including states no longer
present in the current native sheet. This is an overlay port, not a duplicate
set of item definitions or additions to shop inventories.

Native replacements are matched by source file **and** state. An unrelated item
with the same state name cannot accidentally receive a vampire outfit. Native
clothing is used directly, without a second compression pass.

Other 32×32 worn clothes and underwear use a cached fallback. Rows 1–22 in BYOND
coordinates narrow from 32 to 28 pixels, centered on the original canvas. Whole
integer columns are sampled; the head region, height, palette, alpha, directions
and animation frames remain intact. This keeps the head aligned with existing
hair/face accessories. Female uniform shaping and GAGS colors are processed
before fallback conversion. Blood/worn overlays are copied before adaptation.
Held items keep their existing in-hand sprites. Larger custom canvases retain
their original artwork, pending a native body-specific adaptation.

The fallback is a compatibility treatment, not hand-drawn artwork. Unusual wide
or asymmetrical clothes may still need a native sprite. It does not modify an
item's `worn_icon`, so rendering a slim wearer cannot affect a standard wearer.

For offline conversion:

```text
python tools/slim_sprites/convert.py source.dmi output.dmi --native native.dmi
python tools/slim_sprites/convert.py source.dmi compatible.dmi --native native.dmi --native-only
python tools/slim_sprites/convert.py old_bodyparts.dmi bodyparts.dmi --extract-body
```

Pillow is required. The tool keeps source state metadata, including animation timing,
loops and rewind. A native state is substituted only when its direction/frame
layout matches the source. Native timing does not overwrite source timing.
Outputs use separate paths. Standing/moving state pairs with the same name are
retained independently. Run `python tools/slim_sprites/test_convert.py` for the
file/CLI integration tests.

## Provenance

Bodyparts and the complete legacy wardrobe are from
[Animusin/World-of-Darkness-13 at 39142647cb5de07c201e9242a7474fd9d66bd5bf](https://github.com/Animusin/World-of-Darkness-13/tree/39142647cb5de07c201e9242a7474fd9d66bd5bf),
`icons/mob/human_parts_greyscale.dmi` and `code/modules/wod13/worn_slim_f.dmi`.
The old vampire implementation used these files through `base_body_mod = "s"`.
The Onyx body-build system was inspected as additional reference; no Onyx item
logic or stat modifiers are imported. Original artist attribution remains with
the source repository and its history. Imported artwork retains the source's
[CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/) asset license;
code follows this repository's AGPL licensing.

## Validation

The normal BYOND build and focused engine tests cover selection/default restore,
all native bodypart states, unchanged skin tone, standard item icon isolation,
four-direction native clothes and two-frame/four-direction fallback conversion.
The colored test fixture deliberately makes lost directions/frames detectable.
Use `UNIT_TESTS` and `SLIM_BODY_TESTS` for the focused group.
