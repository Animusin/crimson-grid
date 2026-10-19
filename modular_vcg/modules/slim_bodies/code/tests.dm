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
		var/icon/expected = icon('modular_darkpack/modules/clothes/icons/worn_slim_f.dmi', "brujah_f", direction)
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
#endif
