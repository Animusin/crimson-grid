#if defined(UNIT_TESTS) || defined(SPACEMAN_DMM)
/datum/unit_test/slim_bodies
#ifdef SLIM_BODY_TESTS
	test_flags = UNIT_TEST_FOCUS
#endif

/datum/unit_test/slim_bodies/Run()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	human.physique = FEMALE
	var/datum/preference/choiced/slim_body_build/preference = new
	preference.apply_to_human(human, "Slim (female)")
	if(!human.uses_slim_body())
		Fail("The saved preference must select the slim female human body.")
	var/tone = human.skin_tone
	human.update_body_parts(TRUE)
	for(var/obj/item/bodypart/part as anything in human.bodyparts)
		if(!part.slim_body_build)
			Fail("[part.body_zone] did not inherit the cosmetic build.")
		var/state = "human_[part.body_zone][part.is_dimorphic ? "_f" : ""]"
		if(!icon_exists('modular_vcg/modules/slim_bodies/icons/bodyparts.dmi', state))
			Fail("Native bodypart missing: [state]")
		part.get_limb_icon(FALSE)
	if(human.skin_tone != tone)
		Fail("A cosmetic build must preserve skin color.")
	var/obj/item/clothing/under/vampire/brujah/uniform = allocate(/obj/item/clothing/under/vampire/brujah, human)
	var/original_file = uniform.worn_icon
	uniform.build_worn_icon(default_icon_file = original_file, bodyshape = human.bodyshape)
	if(uniform.worn_icon != original_file)
		Fail("Rendering must not mutate an item's shared worn icon.")
	var/icon/native = slim_worn_icon('modular_darkpack/modules/clothes/icons/worn.dmi', "brujah_f")
	for(var/direction in GLOB.cardinals)
		var/icon/expected = icon('modular_vcg/modules/slim_bodies/icons/compatible_worn_f.dmi', "brujah_f", direction)
		var/icon/actual = icon(native, "", direction)
		for(var/x in 1 to 32)
			for(var/y in 1 to 32)
				if(expected.GetPixel(x, y) != actual.GetPixel(x, y))
					Fail("Native clothing must take priority without another compression pass.")
					return
	human.physique = MALE
	if(human.uses_slim_body())
		Fail("The initial female build must not replace male bodies.")
	human.physique = FEMALE
	preference.apply_to_human(human, "Standard")
	if(human.uses_slim_body())
		Fail("Selecting Standard must restore normal rendering.")
	qdel(preference)

/datum/unit_test/slim_converter
#ifdef SLIM_BODY_TESTS
	test_flags = UNIT_TEST_FOCUS
#endif

/datum/unit_test/slim_converter/Run()
	var/icon/source = icon('modular_vcg/modules/slim_bodies/icons/converter_fixture.dmi', "sample")
	var/icon/converted = slim_convert_icon(source)
	if(converted.Width() != 32 || converted.Height() != 32)
		Fail("Conversion must preserve the canvas size.")
	for(var/direction in GLOB.cardinals)
		for(var/frame in 1 to 2)
			var/icon/original_frame = icon(source, "", direction, frame)
			var/icon/output_frame = icon(converted, "", direction, frame)
			for(var/x in 1 to 32)
				if(output_frame.GetPixel(x, 27) != original_frame.GetPixel(x, 27))
					Fail("The head must remain unchanged in every direction and animation frame.")
			for(var/column in 0 to 27)
				var/source_x = FLOOR((column + 0.5) * 32 / 28, 1) + 1
				if(output_frame.GetPixel(column+3, 12) != original_frame.GetPixel(source_x, 12))
					Fail("Fallback conversion lost a direction, frame or palette color.")
	if(source.GetPixel(1, 12) == null)
		Fail("Conversion mutated its source icon.")
	var/mutable_appearance/outer = mutable_appearance('modular_vcg/modules/slim_bodies/icons/converter_fixture.dmi', "sample")
	var/mutable_appearance/child = mutable_appearance(icon_state = "sample")
	child.color = COLOR_RED
	child.pixel_w = 3
	outer.overlays += child
	var/mutable_appearance/adapted = slim_worn_appearance(outer)
	var/image/adapted_child = adapted.overlays[1]
	if(!adapted_child.icon || adapted_child.pixel_w != child.pixel_w || adapted_child.color != child.color)
		Fail("Nested inherited-icon accessories must be adapted without losing offsets or tint.")
	var/icon/adapted_child_icon = icon(adapted_child.icon, adapted_child.icon_state)
	if(adapted_child_icon.GetPixel(1, 12))
		Fail("The nested accessory retained standard-width pixels.")
	if(child.icon || outer.icon_state != "sample")
		Fail("Adapting nested overlays must not mutate their shared source appearances.")
	var/icon/large = icon('icons/blanks/32x32.dmi', "nothing")
	large.Crop(1, 1, 64, 64)
	large.DrawBox(COLOR_RED, 1, 1, 64, 64)
	var/icon/large_adapted = slim_convert_icon(large)
	if(large_adapted.Width() != 64 || large_adapted.Height() != 64 || large_adapted.GetPixel(1, 20) || !large_adapted.GetPixel(1, 50))
		Fail("Oversized centered worn icons must adapt their body band while retaining canvas and head artwork.")

/datum/unit_test/slim_preferences
#ifdef SLIM_BODY_TESTS
	test_flags = UNIT_TEST_FOCUS
#endif

/datum/unit_test/slim_preferences/Run()
	var/datum/client_interface/client = allocate(/datum/client_interface)
	client.prefs = new(client)
	var/datum/preferences/preferences = client.prefs
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/body_type], FEMALE)
	var/datum/preference/build = GLOB.preference_entries[/datum/preference/choiced/slim_body_build]
	for(var/selection in list("Slim (female)", "Standard", "Slim (female)"))
		preferences.write_preference(build, selection)
		preferences.apply_prefs_to(human)
		var/expected = selection == "Slim (female)"
		if(human.uses_slim_body() != expected)
			Fail("Applying all preferences did not restore [selection].")
		for(var/obj/item/bodypart/part as anything in human.bodyparts)
			if(part.slim_body_build != expected)
				Fail("Preference pipeline left stale bodypart caches after selecting [selection].")
			if(istype(part, /obj/item/bodypart/arm))
				var/obj/item/bodypart/arm/arm = part
				if(istype(arm.held_hand_offset, /datum/worn_feature_offset/slim) != expected)
					Fail("Changing build did not restore held-item grip offsets.")
	qdel(client.prefs)
	client.prefs = null

/datum/unit_test/slim_anatomy
#ifdef SLIM_BODY_TESTS
	test_flags = UNIT_TEST_FOCUS
#endif

/datum/unit_test/slim_anatomy/Run()
	var/icon/source = icon('modular_vcg/modules/slim_bodies/icons/converter_fixture.dmi', "sample")
	var/icon/fitted = slim_fit_icon(source)
	for(var/direction in GLOB.cardinals)
		for(var/frame in 1 to 2)
			var/icon/actual = icon(fitted, "", direction, frame)
			var/icon/expected = icon('modular_vcg/modules/slim_bodies/icons/body_fit_fixture.dmi', "sample", direction, frame)
			for(var/x in 1 to 32)
				for(var/y in 1 to 32)
					if(actual.GetPixel(x, y) != expected.GetPixel(x, y))
						Fail("Runtime anatomy fit differs from offline conversion at [x],[y], dir [direction], frame [frame].")
						return
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	human.physique = FEMALE
	human.underwear = "Nude"
	human.undershirt = "Nude"
	human.socks = "Nude"
	var/datum/preference/choiced/slim_body_build/preference = GLOB.preference_entries[/datum/preference/choiced/slim_body_build]
	preference.apply_to_human(human, "Slim (female)")
	human.update_body_parts(TRUE)
	var/obj/item/clothing/under/color/grey/uniform = allocate(/obj/item/clothing/under/color/grey)
	if(!human.equip_to_slot_if_possible(uniform, ITEM_SLOT_ICLOTHING))
		Fail("Could not equip the actual GAGS grey uniform for coverage checks.")
		return
	human.regenerate_icons()
	for(var/direction in GLOB.cardinals)
		var/icon/clothes = getFlatIcon(human.overlays_standing[UNIFORM_LAYER], no_anim = TRUE, defdir = direction)
		for(var/part in list("chest_f", "l_arm", "r_arm", "l_leg", "r_leg"))
			var/icon/body = icon('modular_vcg/modules/slim_bodies/icons/bodyparts.dmi', "human_[part]", direction)
			for(var/x in 1 to 32)
				for(var/y in 4 to 20) // below the neckline, above deliberately bare feet
					// The standard female jumpsuit has this original side hem notch.
					if(direction == EAST && x == 17 && y == 4)
						continue
					if(body.GetPixel(x, y) && !clothes.GetPixel(x, y))
						Fail("Grey uniform exposes covered native [part] at [x],[y], dir [direction].")
		if(direction == NORTH || direction == SOUTH)
			var/icon/left_leg = icon('modular_vcg/modules/slim_bodies/icons/bodyparts.dmi', "human_l_leg", direction)
			var/icon/right_leg = icon('modular_vcg/modules/slim_bodies/icons/bodyparts.dmi', "human_r_leg", direction)
			for(var/y in 4 to 8)
				if(left_leg.GetPixel(16, y) || right_leg.GetPixel(16, y) || clothes.GetPixel(16, y))
					Fail("The native legs and trousers must preserve the visible center air channel.")

/datum/unit_test/slim_underwear
#ifdef SLIM_BODY_TESTS
	test_flags = UNIT_TEST_FOCUS
#endif

/datum/unit_test/slim_underwear/Run()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	human.physique = FEMALE
	human.dna.features["slim_body_build"] = TRUE
	for(var/accessory_type in list(/datum/sprite_accessory/clothing/underwear/female_bikini, /datum/sprite_accessory/clothing/underwear/male_briefs, /datum/sprite_accessory/clothing/underwear/swimsuit_halter, /datum/sprite_accessory/clothing/undershirt/sports_bra, /datum/sprite_accessory/clothing/socks/stockings_cyan))
		var/datum/sprite_accessory/clothing/accessory = new accessory_type
		var/mutable_appearance/original = accessory.make_appearance("#28a8c8", FEMALE, human.bodyshape)
		var/original_color = original.color
		var/icon/original_icon = icon(original.icon, original.icon_state)
		var/state = accessory.get_icon_state(FEMALE, human.bodyshape)
		var/mutable_appearance/adapted = human.fit_slim_underwear(original, accessory)
		if(adapted.color != original_color)
			Fail("Slim underwear must preserve its chosen tint exactly once.")
		var/native = icon_exists('modular_vcg/modules/slim_bodies/icons/compatible_underwear_f.dmi', state)
		var/icon/expected = native ? icon('modular_vcg/modules/slim_bodies/icons/compatible_underwear_f.dmi', state) : slim_fit_icon(original_icon)
		if(istype(accessory, /datum/sprite_accessory/clothing/socks))
			expected.Blend(icon('modular_vcg/modules/slim_bodies/icons/sock_fit.dmi', "socks"), ICON_MULTIPLY)
		var/mutable_appearance/expected_appearance = mutable_appearance(expected)
		expected_appearance.color = original_color
		for(var/direction in GLOB.cardinals)
			var/icon/actual_flat = getFlatIcon(adapted, no_anim = TRUE, defdir = direction)
			var/icon/expected_flat = getFlatIcon(expected_appearance, no_anim = TRUE, defdir = direction)
			for(var/x in 1 to 32)
				for(var/y in 1 to 32)
					if(actual_flat.GetPixel(x, y) != expected_flat.GetPixel(x, y))
						Fail("Native/fallback underwear lost palette or player tint for [accessory_type], dir [direction].")
		qdel(accessory)

/datum/unit_test/slim_draped_and_socks
#ifdef SLIM_BODY_TESTS
	test_flags = UNIT_TEST_FOCUS
#endif

/datum/unit_test/slim_draped_and_socks/Run()
	var/icon/source = icon('modular_vcg/modules/slim_bodies/icons/converter_fixture.dmi', "sample")
	var/icon/fitted = slim_fit_icon(source, draped = TRUE)
	for(var/direction in GLOB.cardinals)
		for(var/frame in 1 to 2)
			var/icon/actual = icon(fitted, "", direction, frame)
			var/icon/expected = icon('modular_vcg/modules/slim_bodies/icons/body_fit_skirt_fixture.dmi', "sample", direction, frame)
			for(var/x in 1 to 32)
				for(var/y in 1 to 32)
					if(actual.GetPixel(x, y) != expected.GetPixel(x, y))
						Fail("Runtime draped fit differs from offline conversion, dir [direction], frame [frame].")
						return
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	human.physique = FEMALE
	human.dna.features["slim_body_build"] = TRUE
	human.update_body_parts(TRUE)
	var/obj/item/clothing/under/color/jumpskirt/grey/skirt = allocate(/obj/item/clothing/under/color/jumpskirt/grey)
	if(!human.equip_to_slot_if_possible(skirt, ITEM_SLOT_ICLOTHING))
		Fail("Could not equip the actual GAGS skirt for hem checks.")
		return
	human.regenerate_icons()
	var/icon/prepared = wear_female_version(skirt.icon_state, skirt.worn_icon, skirt.worn_icon, skirt.female_sprite_flags, skirt.greyscale_colors, human.bodyshape)
	for(var/direction in GLOB.cardinals)
		var/icon/original = icon(prepared, "", direction)
		var/icon/rendered = getFlatIcon(human.overlays_standing[UNIFORM_LAYER], no_anim = TRUE, defdir = direction)
		var/source_hem = 32
		var/fitted_hem = 32
		for(var/x in 1 to 32)
			for(var/y in 1 to 11)
				if(original.GetPixel(x, y))
					source_hem = min(source_hem, y)
				if(rendered.GetPixel(x, y))
					fitted_hem = min(fitted_hem, y)
		if(source_hem != fitted_hem)
			Fail("Draped skirt changed its actual hem height, dir [direction].")
		for(var/y in 1 to 11)
			if(!!original.GetPixel(16, y) != !!rendered.GetPixel(16, y))
				Fail("Draped skirt lost its real center fabric bridge, dir [direction].")
	for(var/accessory_type in list(/datum/sprite_accessory/clothing/socks/black_knee, /datum/sprite_accessory/clothing/socks/stockings_cyan, /datum/sprite_accessory/clothing/socks/pantyhose))
		var/datum/sprite_accessory/clothing/accessory = new accessory_type
		var/mutable_appearance/adapted = human.fit_slim_underwear(accessory.make_appearance(null, FEMALE, human.bodyshape), accessory)
		for(var/direction in GLOB.cardinals)
			var/icon/actual = getFlatIcon(adapted, no_anim = TRUE, defdir = direction)
			var/icon/body = icon('modular_vcg/modules/slim_bodies/icons/sock_fit.dmi', "socks", direction)
			for(var/x in 1 to 32)
				for(var/y in 1 to 32)
					if(actual.GetPixel(x, y) && !body.GetPixel(x, y))
						Fail("Tight socks extend beyond the native lower body, [accessory_type], dir [direction].")
		qdel(accessory)
	var/obj/item/clothing/shoes/vampire/heels/heels = allocate(/obj/item/clothing/shoes/vampire/heels, human)
	var/mutable_appearance/heel_overlay = heels.build_worn_icon(default_layer = SHOES_LAYER, default_icon_file = heels.worn_icon, bodyshape = human.bodyshape)
	for(var/direction in list(NORTH, SOUTH))
		var/icon/actual = getFlatIcon(heel_overlay, no_anim = TRUE, defdir = direction)
		// The native heel/sole extends beyond bare feet. A stocking mask here
		// would incorrectly remove these deliberate footwear pixels.
		if(!actual.GetPixel(12, 2) || !actual.GetPixel(20, 2))
			Fail("The tight-sock silhouette must not clip native heels or soles.")

/// Export actual equipped human appearances, rather than assembling DMI files in Python.
/// PNGs deliberately live in data/; the small contact sheet is the review artifact.
/datum/unit_test/slim_visual
#ifdef SLIM_BODY_TESTS
	test_flags = UNIT_TEST_FOCUS
#endif

/datum/unit_test/slim_visual/Run()
	var/list/scenarios = list("body", "native", "fallback_uniform", "long_sleeve", "skirt", "native_bikini", "briefs", "bra", "socks", "modern_underwear", "modern_socks", "undershirt", "workboots", "dress_shoes", "high_boots", "punk_boots", "heels", "red_heels", "legacy_uniform", "legacy_cap", "chief_vest", "bogatyr_skirt", "backpack", "satchel", "duffel", "all_slots", "blood_accessory", "injury", "held_items", "restraints")
	var/list/manifest = list("directions" = list("N", "S", "E", "W"), "scenarios" = scenarios, "builds" = list("Standard", "Slim"))
	for(var/scenario in scenarios)
		for(var/build in list("Standard", "Slim"))
			var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
			human.physique = FEMALE
			human.set_hairstyle(/datum/sprite_accessory/hair/bedheadv4::name)
			human.set_haircolor("#633b24")
			human.underwear = "Nude"
			human.undershirt = "Nude"
			human.socks = "Nude"
			var/datum/preference/choiced/slim_body_build/preference = GLOB.preference_entries[/datum/preference/choiced/slim_body_build]
			var/list/save_data = list()
			var/selection = build == "Slim" ? "Slim (female)" : "Standard"
			if(!preference.write(save_data, selection) || preference.read(save_data) != selection)
				Fail("Body build must survive the actual preference serializer.")
			preference.apply_to_human(human, preference.read(save_data))
			human.update_body_parts(TRUE)
			if(scenario == "fallback_uniform")
				equip(human, /obj/item/clothing/under/color/grey, ITEM_SLOT_ICLOTHING)
			else if(scenario == "long_sleeve")
				equip(human, /obj/item/clothing/under/suit/charcoal, ITEM_SLOT_ICLOTHING)
			else if(scenario == "skirt")
				equip(human, /obj/item/clothing/under/color/jumpskirt/grey, ITEM_SLOT_ICLOTHING)
			else if(scenario == "native_bikini")
				human.underwear = /datum/sprite_accessory/clothing/underwear/female_bikini::name
				human.underwear_color = "#28a8c8"
			else if(scenario == "briefs")
				human.underwear = /datum/sprite_accessory/clothing/underwear/male_briefs::name
				human.underwear_color = "#28a8c8"
			else if(scenario == "bra")
				human.undershirt = /datum/sprite_accessory/clothing/undershirt/sports_bra::name
			else if(scenario == "socks")
				human.socks = /datum/sprite_accessory/clothing/socks/black_knee::name
			else if(scenario == "modern_underwear")
				human.underwear = /datum/sprite_accessory/clothing/underwear/swimsuit_halter::name
				human.underwear_color = "#28a8c8"
			else if(scenario == "modern_socks")
				human.socks = /datum/sprite_accessory/clothing/socks/stockings_cyan::name
			else if(scenario == "undershirt")
				human.undershirt = /datum/sprite_accessory/clothing/undershirt/bluejersey::name
			else if(scenario == "workboots")
				equip(human, /obj/item/clothing/shoes/workboots, ITEM_SLOT_FEET)
			else if(scenario == "dress_shoes")
				equip(human, /obj/item/clothing/shoes/vampire, ITEM_SLOT_FEET)
			else if(scenario == "high_boots")
				equip(human, /obj/item/clothing/shoes/vampire/jackboots/high, ITEM_SLOT_FEET)
			else if(scenario == "punk_boots")
				equip(human, /obj/item/clothing/shoes/vampire/jackboots/punk, ITEM_SLOT_FEET)
			else if(scenario == "heels")
				equip(human, /obj/item/clothing/shoes/vampire/heels, ITEM_SLOT_FEET)
			else if(scenario == "red_heels")
				equip(human, /obj/item/clothing/shoes/vampire/heels/red, ITEM_SLOT_FEET)
			else if(scenario == "legacy_uniform")
				equip(human, /obj/item/clothing/under/vampire/nazi, ITEM_SLOT_ICLOTHING)
			else if(scenario == "legacy_cap")
				equip(human, /obj/item/clothing/head/vampire/nazi, ITEM_SLOT_HEAD)
			else if(scenario == "chief_vest")
				equip(human, /obj/item/clothing/under/vampire/brujah/female, ITEM_SLOT_ICLOTHING)
				equip(human, /obj/item/clothing/suit/vampire/vest/police/chief, ITEM_SLOT_OCLOTHING)
			else if(scenario == "bogatyr_skirt")
				equip(human, /obj/item/clothing/under/vampire/bogatyr/female, ITEM_SLOT_ICLOTHING)
			else if(scenario != "body" && scenario != "injury" && scenario != "held_items" && scenario != "restraints")
				equip(human, /obj/item/clothing/under/vampire/brujah/female, ITEM_SLOT_ICLOTHING)
			if(scenario == "backpack")
				equip(human, /obj/item/storage/backpack, ITEM_SLOT_BACK)
			if(scenario == "satchel")
				equip(human, /obj/item/storage/backpack/satchel/leather, ITEM_SLOT_BACK)
			if(scenario == "duffel")
				equip(human, /obj/item/storage/backpack/duffelbag, ITEM_SLOT_BACK)
			if(scenario == "all_slots")
				equip(human, /obj/item/storage/backpack/satchel/leather, ITEM_SLOT_BACK)
				equip(human, /obj/item/clothing/shoes/vampire, ITEM_SLOT_FEET)
				equip(human, /obj/item/clothing/gloves/color/black, ITEM_SLOT_GLOVES)
				equip(human, /obj/item/storage/belt/utility, ITEM_SLOT_BELT)
				equip(human, /obj/item/card/id, ITEM_SLOT_ID)
				equip(human, /obj/item/radio/headset, ITEM_SLOT_EARS)
				equip(human, /obj/item/clothing/neck/tie, ITEM_SLOT_NECK)
				equip(human, /obj/item/clothing/mask/bandana/black, ITEM_SLOT_MASK)
				equip(human, /obj/item/clothing/glasses/sunglasses, ITEM_SLOT_EYES)
				equip(human, /obj/item/clothing/head/beret, ITEM_SLOT_HEAD)
				equip(human, /obj/item/clothing/suit/vampire/jacket, ITEM_SLOT_OCLOTHING)
				equip(human, /obj/item/tank/internals/emergency_oxygen, ITEM_SLOT_SUITSTORE)
			if(scenario == "blood_accessory")
				var/obj/item/clothing/accessory/armband/accessory = allocate(/obj/item/clothing/accessory/armband)
				accessory.attach(human.w_uniform)
				var/obj/item/clothing/under/uniform = human.w_uniform
				uniform.add_blood_DNA(list("slim-visual-test" = /datum/blood_type/human/o_plus))
				uniform.update_clothes_damaged_state(CLOTHING_DAMAGED)
			if(scenario == "injury")
				human.apply_damage(25, BRUTE, BODY_ZONE_CHEST)
				human.apply_damage(15, BURN, BODY_ZONE_L_ARM)
			if(scenario == "held_items")
				var/obj/item/flashlight/light = allocate(/obj/item/flashlight)
				var/obj/item/knife/knife = allocate(/obj/item/knife)
				human.put_in_hands(light)
				human.put_in_hands(knife)
			if(scenario == "restraints")
				human.handcuffed = allocate(/obj/item/restraints/handcuffs, human)
			human.regenerate_icons()
			var/direction_index = 0
			for(var/direction in GLOB.cardinals)
				direction_index++
				human.setDir(direction)
				fcopy(getFlatIcon(human, no_anim = TRUE, defdir = direction), "data/slim_visual/[scenario]_[build]_[direction_index].png")
	fdel("data/slim_visual/manifest.json")
	text2file(json_encode(manifest), "data/slim_visual/manifest.json")

/datum/unit_test/slim_visual/proc/equip(mob/living/carbon/human/human, item_type, slot)
	var/obj/item/item = allocate(item_type)
	if(!human.equip_to_slot_if_possible(item, slot))
		Fail("Visual test could not equip [item_type] in slot [slot].")
#endif
