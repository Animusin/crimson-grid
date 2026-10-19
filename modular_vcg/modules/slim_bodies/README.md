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
The donor's overlapping front/back legs receive a one-pixel center air channel
below the pelvis. Their outside contours, feet and side poses retain native art.

## Clothes and conversion

Crimson already contains `modular_darkpack/modules/clothes/icons/worn_slim_f.dmi`
(267 unique state names). This PR activates layout-compatible native states through
`compatible_worn_f.dmi`, generated against the corresponding standard clothing
sheet (238 compatible entries, including 237 named clothing states). A two-frame
source with only one native frame falls back to conversion, preserving its
animation. The complete old female wardrobe is also
retained in `icons/legacy_worn_f.dmi` (223 unique state names, 225 standing/moving
blocks), including states no longer present in the current native sheet.
The wardrobe reuses canonical item types and restores three missing types.
Its loadout, retail and cargo routes and reusable physical underclothes are
documented in [WARDROBE.md](WARDROBE.md).

Native replacements are matched by source file **and** state. An unrelated item
with the same state name cannot accidentally receive a vampire outfit. Native
clothing is used directly, without a second compression pass. Native trousers
receive the same center channel only where the standard garment already has a
transparent gap between its legs. Skirts and dresses retain their fabric bridges.

Underwear, undershirts and socks have 44 compatible native states from the old
female slim underwear sheet. Modern-only states use the anatomical fallback;
their current preparation and selected tint remain intact. Native lookup occurs
before prepared icons lose their original accessory identity.

Other 32×32 clothing uses separate integer UV regions for the native chest,
upper arms, hands and individual legs. The side breast/back contours are covered
by sampling their corresponding standard anatomy. The ankle rows stay anchored
so trousers retain their original hem. The inter-leg region samples source alpha:
trousers retain air, while skirts retain opaque fabric. The map never fills gaps
with body colors or draws a patch over exposed skin. Female uniform shaping and
GAGS colors are processed before fitting. Head pixels, palette, alpha, directions
and animation frames are preserved. `body_fit.py` derives the map from both body
sheets and writes translation masks used by the runtime and offline converter.
Breast-band and neckline rows retain their height; only the lower torso shortens.
An isolated exterior breast point is trimmed per direction and animation frame
only when no cloth continues above, below or outward. Continuous broad armor
retains its fabric; native body and clothing artwork are unchanged.
Existing cutouts remain source alpha. Dresses and TOP_ONLY skirts without leg
coverage use a draped map: the lower garment narrows uniformly while its original
hem rows and center fabric bridge remain intact, rather than following each leg.
Tight socks additionally follow the native lower-body silhouette, including the
pantyhose waist. This mask never applies to shoes: their heel and sole extensions
remain native artwork or fitted source pixels.

Bags, belts, ID cards and other objects use the generic cached fallback: the lower
22 body rows narrow from 32 to 28 pixels. Larger centered canvases retain their
size and adapt the matching body band; anatomical fitting is limited to 32×32
clothing. Icons smaller than a body tile retain their artwork. Worn, separate
blood and nested accessory overlays are copied recursively, including inherited
icons and underlays, using their parent's fitting mode. Body damage, bleeding and
restraint overlays use the generic treatment.

Held objects keep their original shape. Direction-aware TG limb offsets move
their grips to the slim hands (1 pixel front/back, 2 pixels on the relevant side),
using the Onyx slim layout as a reference. Turning updates the grip immediately;
selecting Standard removes these offsets. Existing offsets on custom limbs take
priority. An unusually anchored custom canvas may still need its own native art.

The fallback is a compatibility treatment, not hand-drawn artwork. Unusual wide
or asymmetrical clothes may still need a native sprite. It does not modify an
item's `worn_icon`, so rendering a slim wearer cannot affect a standard wearer.

For offline conversion:

```text
python tools/slim_sprites/convert.py source.dmi output.dmi --native native.dmi
python tools/slim_sprites/convert.py source.dmi output.dmi --body-fit
python tools/slim_sprites/convert.py skirt.dmi output.dmi --body-fit --draped
python tools/slim_sprites/convert.py source.dmi compatible.dmi --native native.dmi --native-only --leg-gap
python tools/slim_sprites/convert.py old_bodyparts.dmi bodyparts.dmi --extract-body --leg-gap
python tools/slim_sprites/body_fit.py
```

Pillow is required. The tool keeps source state metadata, including animation timing,
loops and rewind. A native state is substituted only when its direction/frame
layout matches the source. Native timing does not overwrite source timing.
Outputs use separate paths. Standing/moving state pairs with the same name are
retained independently. Run `python tools/slim_sprites/test_convert.py` for the
file/CLI integration tests. The offline anatomical mode supports one/four-direction
sprites; eight-direction sheets retain generic conversion and all diagonal frames.

## Provenance

Bodyparts and the complete legacy wardrobe are from
[Animusin/World-of-Darkness-13 at 39142647cb5de07c201e9242a7474fd9d66bd5bf](https://github.com/Animusin/World-of-Darkness-13/tree/39142647cb5de07c201e9242a7474fd9d66bd5bf),
`icons/mob/human_parts_greyscale.dmi`, `code/modules/wod13/worn_slim_f.dmi`, and
`icons/mob/clothing/underwear_s_female.dmi` (the donor's `_f` sheet is its fat build,
not its female slim build).
The old vampire implementation used these files through `base_body_mod = "s"`.
The Onyx body-build system was inspected as additional reference; no Onyx item
logic or stat modifiers are imported. Original artist attribution remains with
the source repository and its history. Imported artwork retains the source's
[CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/) asset license;
code follows this repository's AGPL licensing.
Native hairstyle extraction, registration and attribution are documented in
[HAIR_PROVENANCE.md](HAIR_PROVENANCE.md).
The complete legacy item audit, reused aliases and the three missing restored
looks are documented in [CLOTHING_PROVENANCE.md](CLOTHING_PROVENANCE.md).
The 47 active legacy underwear/undershirt/sock choices already have current
selectors; [their mapping](review/legacy_underwear_audit.json) and engine audit
verify all 44 nonblank native styles without adding duplicate choices.

## Validation

The normal BYOND build and focused engine tests cover selection/default restore,
all native bodypart states, unchanged skin tone, standard item icon isolation,
four-direction native clothes and two-frame/four-direction fallback conversion.
The anatomical test compares every runtime pixel against offline conversion for
two animation frames in all four directions, including thin-jumpsuit/broad-armor
frames that require different contour masks, then checks an actual GAGS uniform's
chest, upper-arm and trouser coverage. Its original one-pixel side hem notch is
preserved. Native and fallback underwear tests verify the composited palette and
selected tint in every direction. CLI tests check pants/skirt alpha, the hem,
source immutability, duplicate movement states and eight-direction preservation.
The colored test fixture deliberately makes lost directions/frames detectable.
Use `UNIT_TESTS` and `SLIM_BODY_TESTS` for the focused group.

The preference test also runs the complete mock-client `apply_prefs_to` pipeline
through Slim → Standard → Slim, checking limb caches and held-item offsets.
The visual tester equips actual mobs, then exports their real overlay trees in
four directions to `data/slim_visual/` (31 scenarios × two builds × four directions,
248 renders). It covers the nude body, native/fallback/long-sleeve uniforms, skirts,
colored native bikini and briefs, a modern-only bra, native/current socks,
modern-only swimwear and undershirt, continuous broad armor, workboots, dress
shoes, high/punk boots and two heel variants, restored legacy uniform/cap/vest
and the Bogatyr skirt,
backpacks/satchels/duffels, every visible wearable slot, bloody damaged clothes
with an accessory, body injuries, held tools and handcuffs. Source sprites and
the standard wearer's appearances must remain unchanged.

After running those engine tests, generate the review artifacts with:

```text
python tools/slim_sprites/review.py
python tools/slim_sprites/review.py --output modular_vcg/modules/slim_bodies/review/fit --scenarios body fallback_uniform long_sleeve skirt native_bikini briefs bra socks modern_underwear modern_socks undershirt broad_armor --directions S E
python tools/slim_sprites/review.py --output modular_vcg/modules/slim_bodies/review/footwear --scenarios workboots dress_shoes high_boots punk_boots heels red_heels
python tools/slim_sprites/review.py --output modular_vcg/modules/slim_bodies/review/legacy --scenarios legacy_uniform legacy_cap chief_vest bogatyr_skirt
```

`review/equipment.png` is the contact sheet. `review/equipment.html` is a portable
viewer with zoom/background controls and embedded engine renders. These inspect
the mob's composited appearances; client lighting/filter rendering and unusual
item variants still need normal in-game playtesting. They are not substitutes
for every asset in the repository.

`review/breast_tip/equipment.png` and its portable HTML compare the five reported
garments before and after the contour correction in both profile directions.
The engine pixel comparison preserves all 120 previous Standard renders and
every native/body pixel, changing only one exterior pixel in each of ten Slim
profiles. Broad armor remains continuous in the added regression scenario.
