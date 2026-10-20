#if defined(UNIT_TESTS) || defined(SPACEMAN_DMM)
/// All active underwear choices from the pinned vampire donor already exist.
/// Verify their renamed selectors and native art instead of adding duplicates.
/datum/unit_test/slim_legacy_underwear
#ifdef SLIM_BODY_TESTS
	test_flags = UNIT_TEST_FOCUS
#endif

/datum/unit_test/slim_legacy_underwear/Run()
	var/list/audit = json_decode(file2text('modular_vcg/modules/slim_bodies/review/legacy_underwear_audit.json'))
	var/list/choices = audit["choices"]
	if(length(choices) != 47 || audit["native_style_count"] != 44 || audit["missing_selector_count"])
		Fail("The pinned donor audit must contain 47 choices, 44 native styles and no missing selectors.")
		return
	var/list/registries = list(
		"underwear" = SSaccessories.underwear_list,
		"undershirt" = SSaccessories.undershirt_list,
		"socks" = SSaccessories.socks_list,
	)
	var/list/preference_types = list(
		"underwear" = /datum/preference/choiced/underwear,
		"undershirt" = /datum/preference/choiced/undershirt,
		"socks" = /datum/preference/choiced/socks,
	)
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	human.physique = FEMALE
	human.dna.features["slim_body_build"] = TRUE
	var/list/seen = list()
	var/list/native_states = list()
	for(var/list/choice as anything in choices)
		var/category = choice["category"]
		var/current_name = choice["current_name"]
		var/icon_state = choice["icon_state"]
		var/list/registry = registries[category]
		var/datum/preference/choiced/preference = GLOB.preference_entries[preference_types[category]]
		if(!islist(registry) || !preference?.is_valid(current_name))
			Fail("Legacy choice [choice["legacy_name"]] must remain selectable as [current_name].")
			continue
		var/identity = "[category]/[current_name]"
		if(seen[identity])
			Fail("Legacy choices must reuse one current selector per style: [identity].")
		seen[identity] = TRUE
		// Nude is a registry key with no accessory datum or native sprite.
		if(isnull(icon_state))
			continue
		var/datum/sprite_accessory/clothing/accessory = registry[current_name]
		if(accessory?.type != text2path(choice["current_path"]) || accessory.icon_state != icon_state)
			Fail("Legacy choice [identity] resolves to the wrong accessory or icon state.")
			continue
		if(!icon_exists('modular_vcg/modules/slim_bodies/icons/compatible_underwear_f.dmi', icon_state))
			Fail("Active legacy choice [identity] is missing native slim artwork: [icon_state].")
			continue
		native_states |= icon_state
		var/mutable_appearance/overlay = accessory.make_appearance("#28a8c8", FEMALE, human.bodyshape)
		var/original_color = overlay.color
		human.fit_slim_underwear(overlay, accessory)
		if(overlay.color != original_color)
			Fail("Native legacy underwear must preserve its selected tint: [identity].")
		for(var/direction in GLOB.cardinals)
			var/icon/actual = icon(overlay.icon, overlay.icon_state, direction)
			var/icon/expected = icon('modular_vcg/modules/slim_bodies/icons/compatible_underwear_f.dmi', icon_state, direction)
			var/icon/chest = icon('modular_vcg/modules/slim_bodies/icons/bodyparts.dmi', "human_chest_f", direction)
			var/icon/left_leg = icon('modular_vcg/modules/slim_bodies/icons/bodyparts.dmi', "human_l_leg", direction)
			var/icon/right_leg = icon('modular_vcg/modules/slim_bodies/icons/bodyparts.dmi', "human_r_leg", direction)
			for(var/x in 1 to 32)
				for(var/y in 1 to 32)
					var/expected_color = expected.GetPixel(x, y)
					// Socks follow the slim leg/lower-waist silhouette. Preserve
					// native color inside it and the approved alpha trim outside.
					if(category == "socks" && (y > 14 || !(chest.GetPixel(x, y) || left_leg.GetPixel(x, y) || right_leg.GetPixel(x, y))))
						expected_color = null
					if(actual.GetPixel(x, y) != expected_color)
						Fail("Legacy native artwork was refitted or replaced: [identity], dir [direction].")
						return
	if(length(native_states) != 44)
		Fail("Every one of the 44 nonblank legacy native styles must have a selectable current counterpart.")
#endif
