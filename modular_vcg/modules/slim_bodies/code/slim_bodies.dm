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

/// Reuse TG's direction-aware limb offsets. Objects retain their original shape,
/// while the grip follows the native slim hands when turning or changing build.
/datum/worn_feature_offset/slim

/obj/item/bodypart/arm/proc/update_slim_hand_offset()
	if(!slim_body_build)
		if(istype(held_hand_offset, /datum/worn_feature_offset/slim))
			QDEL_NULL(held_hand_offset)
		return
	if(held_hand_offset)
		return
	held_hand_offset = new /datum/worn_feature_offset/slim(
		attached_part = src,
		feature_key = OFFSET_HELD,
		offset_x = body_zone == BODY_ZONE_L_ARM \
			? list("south" = -1, "north" = 1, "east" = -2, "west" = 0) \
			: list("south" = 1, "north" = -1, "east" = 0, "west" = 2),
	)

/// Compress the body region, preserving the head, canvas, directions and frames.
/// Whole integer columns are sampled: no interpolation or palette changes.
/proc/slim_convert_icon(icon/source)
	if(source.Width() < 32 || source.Height() < 32)
		return source
	var/width = source.Width()
	var/body_bottom = FLOOR((source.Height() - 32) / 2, 1) + 1
	var/body_top = body_bottom + 21
	var/slim_width = FLOOR(width * 28 / 32, 1)
	var/left = FLOOR((width - slim_width) / 2, 1) + 1
	var/icon/result = icon(source)
	result.DrawBox(null, 1, body_bottom, width, body_top)
	for(var/column in 0 to slim_width - 1)
		var/source_x = FLOOR((column + 0.5) * width / slim_width, 1) + 1
		var/icon/strip = icon(source)
		strip.Crop(source_x, body_bottom, source_x, body_top)
		result.Blend(strip, ICON_OVERLAY, column + left, body_bottom)
	return result

/// Fit clothing to the native torso, upper arms, hands and individual legs.
/// Each mask is an integer translation region derived from both body sheets.
/// Blending complete icons retains every direction, frame and source color.
/proc/slim_fit_icon(icon/source, draped = FALSE)
	if(source.Width() != 32 || source.Height() != 32)
		return slim_convert_icon(source)
	var/icon/result = icon(source)
	result.DrawBox(null, 1, 1, 32, 22)
	var/mask_file = draped ? 'modular_vcg/modules/slim_bodies/icons/body_fit_skirt.dmi' : 'modular_vcg/modules/slim_bodies/icons/body_fit.dmi'
	var/cache_key = draped ? "draped" : "body"
	var/static/list/translation_cache = list()
	var/list/translations = translation_cache[cache_key]
	if(!translations)
		translations = list()
		for(var/state in icon_states(mask_file))
			var/list/offset = splittext(state, "_")
			translations[state] = list(text2num(offset[1]), text2num(offset[2]))
		translation_cache[cache_key] = translations
	for(var/state in translations)
		var/list/offset = translations[state]
		var/icon/region = icon(source)
		if(offset[1])
			region.Shift(offset[1] > 0 ? EAST : WEST, abs(offset[1]))
		if(offset[2])
			region.Shift(offset[2] > 0 ? NORTH : SOUTH, abs(offset[2]))
		region.Blend(icon(mask_file, state), ICON_MULTIPLY)
		result.Blend(region, ICON_OVERLAY)
	return slim_trim_cloth_tip(result)

/// Trim only an isolated exterior breast point. Neighbor alpha keeps continuous
/// broad armor/outerwear intact; whole-icon operations retain every dir/frame.
/proc/slim_trim_cloth_tip(icon/source)
	var/icon/alpha = icon(source)
	alpha.MapColors(0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,255, 1,1,1,0)
	var/icon/support = icon(alpha)
	support.Shift(NORTH, 1)
	var/icon/below = icon(alpha)
	below.Shift(SOUTH, 1)
	support.Blend(below, ICON_OR)
	var/icon/east = icon(alpha)
	east.Shift(WEST, 1)
	east.Blend(icon('modular_vcg/modules/slim_bodies/icons/cloth_tip.dmi', "east"), ICON_MULTIPLY)
	support.Blend(east, ICON_OR)
	var/icon/west = icon(alpha)
	west.Shift(EAST, 1)
	west.Blend(icon('modular_vcg/modules/slim_bodies/icons/cloth_tip.dmi', "west"), ICON_MULTIPLY)
	support.Blend(west, ICON_OR)
	var/icon/keep = icon(source)
	keep.MapColors(0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 1,1,1,1)
	keep.Blend(icon('modular_vcg/modules/slim_bodies/icons/cloth_tip.dmi', "keep"), ICON_MULTIPLY)
	keep.Blend(support, ICON_OR)
	var/icon/result = icon(source)
	result.Blend(keep, ICON_MULTIPLY)
	return result

/// Copy the complete appearance tree, including inherited-icon accessory/blood layers.
/// Keeping the caller's shared appearances intact is essential for standard wearers.
/proc/slim_worn_appearance(image/source, already_slim_icon, inherited_icon, inherited_state, body_fit = FALSE, draped = FALSE)
	var/mutable_appearance/result = new /mutable_appearance(source)
	var/source_icon = result.icon || inherited_icon
	var/source_state = result.icon_state || inherited_state
	// Prepared/GAGS icons use the empty state even when a parent has a named one.
	if(source_icon && !icon_exists(source_icon, source_state) && icon_exists(source_icon, ""))
		source_state = ""
	if(source_icon && source_icon != already_slim_icon)
		result.icon = slim_worn_icon(source_icon, source_state, body_fit = body_fit, draped = draped)
		result.icon_state = ""
	var/list/children = list()
	for(var/image/child as anything in result.overlays)
		children += slim_worn_appearance(child, already_slim_icon, source_icon, source_state, body_fit, draped)
	result.overlays = children
	children = list()
	for(var/image/child as anything in result.underlays)
		children += slim_worn_appearance(child, already_slim_icon, source_icon, source_state, body_fit, draped)
	result.underlays = children
	return result

/// Native replacements are scoped by source file, preventing state-name collisions.
/proc/slim_worn_icon(icon_file, icon_state, icon/prepared_icon, cache_variant = "default", body_fit = FALSE, draped = FALSE)
	var/native
	if(icon_file == 'modular_darkpack/modules/clothes/icons/worn.dmi')
		if(icon_exists('modular_vcg/modules/slim_bodies/icons/compatible_worn_f.dmi', icon_state))
			native = 'modular_vcg/modules/slim_bodies/icons/compatible_worn_f.dmi'
	else if(icon_file == 'icons/mob/clothing/underwear.dmi')
		if(icon_exists('modular_vcg/modules/slim_bodies/icons/compatible_underwear_f.dmi', icon_state))
			native = 'modular_vcg/modules/slim_bodies/icons/compatible_underwear_f.dmi'
	else if(icon_file == 'modular_vcg/modules/slim_bodies/icons/legacy_missing_worn.dmi')
		if(icon_exists('modular_vcg/modules/slim_bodies/icons/legacy_missing_worn_f.dmi', icon_state))
			native = 'modular_vcg/modules/slim_bodies/icons/legacy_missing_worn_f.dmi'
	if(native)
		return icon(native, icon_state)
	// Procedurally generated overlay icons can change between draws. Keeping each
	// icon object in a permanent cache would retain those temporary resources.
	if(istype(icon_file, /icon))
		return body_fit ? slim_fit_icon(prepared_icon || icon(icon_file, icon_state), draped) : slim_convert_icon(prepared_icon || icon(icon_file, icon_state))
	var/static/list/cache = list()
	var/key = "[icon_file]|[icon_state]|[cache_variant]|[body_fit]|[draped]"
	if(!cache[key])
		cache[key] = body_fit ? slim_fit_icon(prepared_icon || icon(icon_file, icon_state), draped) : slim_convert_icon(prepared_icon || icon(icon_file, icon_state))
	return cache[key]

/// Keep accessory identity until after native lookup: make_appearance may return
/// a procedurally prepared icon whose empty state no longer names the underwear.
/mob/living/carbon/human/proc/fit_slim_underwear(mutable_appearance/overlay, datum/sprite_accessory/clothing/accessory)
	if(!overlay || !uses_slim_body())
		return overlay
	overlay.icon = slim_worn_icon(accessory.icon, accessory.get_icon_state(physique, bodyshape), icon(overlay.icon, overlay.icon_state), "[accessory.type]-[accessory.greyscale_colors]-[bodyshape]", body_fit = TRUE)
	if(istype(accessory, /datum/sprite_accessory/clothing/socks))
		var/icon/fitted_socks = icon(overlay.icon)
		fitted_socks.Blend(icon('modular_vcg/modules/slim_bodies/icons/sock_fit.dmi', "socks"), ICON_MULTIPLY)
		overlay.icon = fitted_socks
	overlay.icon_state = ""
	return overlay
