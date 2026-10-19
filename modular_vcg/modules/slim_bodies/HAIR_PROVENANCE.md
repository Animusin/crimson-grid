# Native slim hairstyles

Donor: [Animusin/World-of-Darkness-13, revision 39142647cb5de07c201e9242a7474fd9d66bd5bf](https://github.com/Animusin/World-of-Darkness-13/tree/39142647cb5de07c201e9242a7474fd9d66bd5bf).
The donor's `species.dm` selects `icons/mob/human_face_f.dmi` for slim bodies
(`base_body_mod == "s"`). This is separate native artwork, with side views fitted
to the slim head; the donor does not compress its normal hair sheet at runtime.

`icons/hair.dmi` contains only its 319 unique registered base hairstyle states. Extraction
preserves every pixel, direction, frame and state metadata. It excludes facial
hair, eyes, lips and the obsolete dynamic hat states. Artwork remains under
[CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/), with attribution
to the donor repository and its original artists/history. Code follows AGPL.
Reproduce with `python tools/slim_sprites/port_hair.py <donor checkout>`.

Existing style IDs and names remain unchanged. Devil Lock maps its modern state
name to its old native state name. Bedhead 4 is already listed
as Bedhead 4x, and the old Over Eye (Short) is currently Over Eye. Tau uses its
already-present Darkpack standard artwork and is now registered once.
Modern-only hairstyles retain their normal artwork. Native legacy hairstyles
use TG's current tint, gradients and hat masks; their complete native ponytails
replace the modern separate appendages. Mask caches include source icon/state,
so rendering one build cannot replace the other's cached hair.
