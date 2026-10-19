/// A cosmetic build, independent of gender, splat, stats and hitboxes.
/datum/preference/choiced/slim_body_build
	category = PREFERENCE_CATEGORY_SECONDARY_FEATURES
	priority = PREFERENCE_PRORITY_LATE_BODY_TYPE
	savefile_key = "slim_body_build"
	savefile_identifier = PREFERENCE_CHARACTER
	can_randomize = FALSE

/datum/preference/choiced/slim_body_build/init_possible_values()
	return list("Standard", "Slim (female)")

/datum/preference/choiced/slim_body_build/create_default_value()
	return "Standard"

/datum/preference/choiced/slim_body_build/apply_to_human(mob/living/carbon/human/target, value)
	target.dna.features["slim_body_build"] = value == "Slim (female)"

/mob/living/carbon/human/proc/uses_slim_body()
	if(physique != FEMALE || !dna?.features["slim_body_build"] || !(bodyshape & BODYSHAPE_HUMANOID) || (bodyshape & BODYSHAPE_DIGITIGRADE))
		return FALSE
	var/obj/item/bodypart/chest/chest = get_bodypart(BODY_ZONE_CHEST)
	return chest?.limb_id == SPECIES_HUMAN && !(chest.bodytype & BODYTYPE_ROBOTIC)

/// Disconnected limbs retain their appearance until attached to another owner.
/obj/item/bodypart
	var/slim_body_build = FALSE

/// Compress the body region, preserving the head, canvas, directions and frames.
/// Whole integer columns are sampled: no interpolation or palette changes.
/proc/slim_convert_icon(icon/source)
	if(source.Width() != 32 || source.Height() != 32)
		return source
	var/icon/result = icon(source)
	result.DrawBox(null, 1, 1, 32, 22)
	for(var/column in 0 to 27)
		var/source_x = FLOOR((column + 0.5) * 32 / 28, 1) + 1
		var/icon/strip = icon(source)
		strip.Crop(source_x, 1, source_x, 22)
		result.Blend(strip, ICON_OVERLAY, column + 3, 1)
	return result

/// Native replacements are scoped by source file, preventing state-name collisions.
/proc/slim_worn_icon(icon_file, icon_state, icon/prepared_icon, cache_variant = "default")
	var/native
	if(icon_file == 'modular_darkpack/modules/clothes/icons/worn.dmi')
		if(icon_exists('modular_vcg/modules/slim_bodies/icons/compatible_worn_f.dmi', icon_state))
			native = 'modular_vcg/modules/slim_bodies/icons/compatible_worn_f.dmi'
	if(native)
		return icon(native, icon_state)
	var/static/list/cache = list()
	var/key = "[icon_file]|[icon_state]|[cache_variant]"
	if(!cache[key])
		cache[key] = slim_convert_icon(prepared_icon || icon(icon_file, icon_state))
	return cache[key]
