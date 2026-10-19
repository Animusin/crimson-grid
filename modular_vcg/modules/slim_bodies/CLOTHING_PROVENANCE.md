# Complete legacy vampire wardrobe mapping

The source is `code/modules/wod13/clothcode.dm` in
[Animusin/World-of-Darkness-13, revision 39142647cb5de07c201e9242a7474fd9d66bd5bf](https://github.com/Animusin/World-of-Darkness-13/tree/39142647cb5de07c201e9242a7474fd9d66bd5bf).
`legacy_clothing_manifest.json` maps all 202 item definitions onto current items,
including clothing, footwear and holsters. This audit concerns the vampire
wardrobe, rather than copying the old TG clothing framework into its successor.

192 definitions retain an existing type. Four old vampire holsters map to the
equivalent Darkpack holsters, the old agent suit is the current hound suit, and
old Bogatyr armor/helmet artwork remains available through the heavy variants.
These seven aliases receive no duplicate item definitions. The existing female
Bogatyr outfit restores its unused skirt state through a small inventory/floor
state alias copied from its existing current `bogatyr` artwork. Its inventory
appearance stays the same, and TG's uniform rendering remains unchanged.
All 14 old footwear types already exist, including
high boots and black/red heels. Thirteen have four-direction native slim artwork;
punk boots (`daboots`) use fitted fallback, as the donor also lacks native art.

Only three genuinely missing looks are restored: the police chief vest and the
old historical uniform and cap. Four small `legacy_missing_*` sheets hold just
their three standard-worn and native-slim states, plus inventory/floor states
and the Bogatyr state alias described above, copied
without frame or direction changes. The slim uniform receives the same single
pixel trouser-channel correction as other native trousers, only where its
standard art already separates the legs; hats, vests and skirts are unaffected.
The costumes behave as ordinary removable clothing. The chief vest reuses the equivalent
modern protective-vest armor datum. The current catalogue, store and cargo routes
and their role restrictions are documented in [WARDROBE.md](WARDROBE.md).

Source artwork: `code/modules/wod13/clothing.dmi`, `onfloor.dmi`, `worn.dmi`,
and `worn_slim_f.dmi`. Imported artwork retains
[CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/) and attribution to
the donor repository and original artists/history; code follows AGPL.

Reproduce the small art extraction with
`python tools/slim_sprites/port_legacy_clothing.py <donor checkout>` and the full
mapping audit with `python tools/slim_sprites/audit_clothing.py <donor checkout>`.
