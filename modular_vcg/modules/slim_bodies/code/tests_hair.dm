#if defined(UNIT_TESTS) || defined(SPACEMAN_DMM)
/datum/unit_test/slim_hair
#ifdef SLIM_BODY_TESTS
	test_flags = UNIT_TEST_FOCUS
#endif

/datum/unit_test/slim_hair/Run()
	var/list/styles = list("short" = "Bob Hair", "long" = "Longest Bedhead", "ponytail" = "Ponytail")
	var/list/colors = list("brown" = "#633b24", "cyan" = "#21b8ce")
	var/datum/preference/choiced/slim_body_build/preference = GLOB.preference_entries[/datum/preference/choiced/slim_body_build]
	for(var/style_key in styles)
		var/datum/sprite_accessory/hair/source = SSaccessories.hairstyles_list[styles[style_key]]
		if(!source)
			Fail("Missing existing hairstyle [styles[style_key]].")
			continue
		var/original_icon = source.icon
		var/original_state = source.icon_state
		var/icon/standard_before = icon(source.getCachedIcon())
		for(var/color_key in colors)
			for(var/build in list("Standard", "Slim"))
				var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
				human.physique = FEMALE
				human.set_hairstyle(styles[style_key])
				human.set_facial_hairstyle("Shaved")
				human.set_haircolor(colors[color_key])
				preference.apply_to_human(human, build == "Slim" ? "Slim (female)" : "Standard")
				human.update_body_parts(TRUE)
				human.regenerate_icons()
				var/obj/item/bodypart/head/head = human.get_bodypart(BODY_ZONE_HEAD)
				var/datum/sprite_accessory/hair/selected = head.get_slim_compatible_hair_accessory()
				if((selected.icon == 'modular_vcg/modules/slim_bodies/icons/hair.dmi') != (build == "Slim"))
					Fail("[build] [style_key] selected the wrong hair artwork.")
				var/image/tinted_hair
				for(var/image/overlay as anything in head.get_hair_overlays(FALSE))
					if(overlay.color == colors[color_key])
						tinted_hair = overlay
						break
				if(!tinted_hair)
					Fail("Actual head overlays lost the [color_key] hair tint.")
					continue
				var/direction_index = 0
				for(var/direction in GLOB.cardinals)
					direction_index++
					human.setDir(direction)
					var/icon/actual_hair = getFlatIcon(tinted_hair, no_anim = TRUE, defdir = direction)
					var/icon/expected_hair = build == "Slim" \
						? icon('modular_vcg/modules/slim_bodies/icons/hair.dmi', selected.icon_state, direction) \
						: icon(standard_before, "", direction)
					expected_hair.Blend(colors[color_key], ICON_MULTIPLY)
					check_pixels(actual_hair, expected_hair, "[build] [style_key] [color_key] dir [direction]")
					var/icon/actual_mob = getFlatIcon(human, no_anim = TRUE, defdir = direction)
					var/visible_tinted_pixels = 0
					for(var/x in 1 to 32)
						for(var/y in 23 to 32)
							if(expected_hair.GetPixel(x, y) && actual_mob.GetPixel(x, y) == expected_hair.GetPixel(x, y))
								visible_tinted_pixels++
					if(visible_tinted_pixels < 5)
						Fail("Actual mob [build] [style_key] [color_key] dir [direction] lost visible tinted hair.")
					fcopy(actual_mob, "data/slim_hair/[style_key]_[color_key]_[build]_[direction_index].png")
		if(source.icon != original_icon || source.icon_state != original_state)
			Fail("Slim hair mutated the shared standard hairstyle.")
		for(var/direction in GLOB.cardinals)
			check_pixels(icon(source.getCachedIcon(), "", direction), icon(standard_before, "", direction), "Standard cache isolation")

	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	human.physique = FEMALE
	preference.apply_to_human(human, "Slim (female)")
	human.update_body_parts(TRUE)
	var/obj/item/bodypart/head/head = human.get_bodypart(BODY_ZONE_HEAD)
	human.set_hairstyle("Afro (Huge)")
	if(head.get_slim_compatible_hair_accessory() != SSaccessories.hairstyles_list[human.hairstyle])
		Fail("A modern-only hairstyle must retain its original artwork and appendages.")
	human.set_hairstyle("Ponytail")
	human.set_haircolor("#633b24")
	human.set_hair_gradient_color("#21b8ce")
	human.set_hair_gradient_style(/datum/sprite_accessory/gradient/reflected_inverse::name)
	var/obj/item/clothing/head/beret/hat = allocate(/obj/item/clothing/head/beret)
	if(!human.equip_to_slot_if_possible(hat, ITEM_SLOT_HEAD))
		Fail("Hair fixture could not equip a real hat.")
	human.regenerate_icons()
	if(!length(human.hair_masks))
		Fail("The real beret must exercise TG hair masks.")
	var/datum/sprite_accessory/hair/native_hair = head.get_slim_compatible_hair_accessory()
	var/icon/without_hat_mask = native_hair.getCachedIcon()
	var/icon/with_hat_mask = native_hair.getCachedIcon(human.hair_masks)
	var/mask_changes = 0
	for(var/direction in GLOB.cardinals)
		var/icon/bare = icon(without_hat_mask, "", direction)
		var/icon/masked = icon(with_hat_mask, "", direction)
		for(var/x in 1 to 32)
			for(var/y in 1 to 32)
				if(bare.GetPixel(x, y) != masked.GetPixel(x, y))
					mask_changes++
	if(!mask_changes)
		Fail("TG's hat mask did not affect native slim hair.")
	var/direction_index = 0
	var/total_cyan_gradient_pixels = 0
	for(var/direction in GLOB.cardinals)
		direction_index++
		human.setDir(direction)
		var/icon/with_gradient = getFlatIcon(human, no_anim = TRUE, defdir = direction)
		fcopy(with_gradient, "data/slim_hair/hat_gradient_Slim_[direction_index].png")
		human.set_hair_gradient_style(SPRITE_ACCESSORY_NONE)
		var/icon/without_gradient = getFlatIcon(human, no_anim = TRUE, defdir = direction)
		var/cyan_gradient_pixels = 0
		for(var/x in 1 to 32)
			for(var/y in 1 to 32)
				var/pixel = with_gradient.GetPixel(x, y)
				if(!pixel || pixel == without_gradient.GetPixel(x, y))
					continue
				var/red = hex2num(copytext(pixel, 2, 4))
				if(hex2num(copytext(pixel, 4, 6)) > red && hex2num(copytext(pixel, 6, 8)) > red)
					cyan_gradient_pixels++
		total_cyan_gradient_pixels += cyan_gradient_pixels
		human.set_hair_gradient_style(/datum/sprite_accessory/gradient/reflected_inverse::name)
	if(!total_cyan_gradient_pixels)
		Fail("The actual hatted slim mob lost its cyan hair gradient.")
	var/list/manifest = list("styles" = styles, "colors" = colors, "builds" = list("Standard", "Slim"), "directions" = list("N", "S", "E", "W"))
	fdel("data/slim_hair/manifest.json")
	text2file(json_encode(manifest), "data/slim_hair/manifest.json")

/datum/unit_test/slim_hair/proc/check_pixels(icon/actual, icon/expected, context)
	if(actual.Width() != expected.Width() || actual.Height() != expected.Height())
		Fail("[context]: hair canvas dimensions changed.")
		return
	for(var/x in 1 to actual.Width())
		for(var/y in 1 to actual.Height())
			if(actual.GetPixel(x, y) != expected.GetPixel(x, y))
				Fail("[context]: wrong native hair pixels, tint, or direction at [x],[y].")
				return
#endif
