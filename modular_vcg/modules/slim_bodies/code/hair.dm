/// Select native legacy slim hair without changing the player's saved style.
/// Current-only hairstyles retain TG's normal appendages, masks and artwork.
/obj/item/bodypart/head/proc/get_slim_compatible_hair_accessory()
	var/datum/sprite_accessory/hair/source = SSaccessories.hairstyles_list[hairstyle]
	if(!slim_body_build || !source)
		return source
	if(source.icon != 'icons/mob/human/human_face.dmi' && source.icon != 'modular_darkpack/master_files/icons/mob/human/human_face.dmi')
		return source
	var/native_state = source.icon_state
	if(native_state == "hair_devilock")
		native_state = "hair_devillock"
	if(!icon_exists('modular_vcg/modules/slim_bodies/icons/hair.dmi', native_state))
		return source
	var/static/list/native_accessories = list()
	if(!native_accessories[source.type])
		var/datum/sprite_accessory/hair/native = new source.type()
		native.icon = 'modular_vcg/modules/slim_bodies/icons/hair.dmi'
		native.icon_state = native_state
		// The old native state already contains its complete ponytail/bangs.
		// TG hair masks still apply, but adding the modern appendages duplicates it.
		native.hair_appendages_inner = null
		native.hair_appendages_outer = null
		native.y_offset = 0
		native_accessories[source.type] = native
	return native_accessories[source.type]

/// Present in the old vampire selector and current Darkpack art, but unregistered.
/datum/sprite_accessory/hair/legacy_tau
	name = "Tau"
	icon = 'modular_darkpack/master_files/icons/mob/human/human_face.dmi'
	icon_state = "hair_tau"
