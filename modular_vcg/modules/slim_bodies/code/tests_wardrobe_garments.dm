#if defined(UNIT_TESTS) || defined(SPACEMAN_DMM)
/datum/unit_test/slim_wardrobe
#ifdef SLIM_BODY_TESTS
	test_flags = UNIT_TEST_FOCUS
#endif

/datum/unit_test/slim_wardrobe/Run()
	var/mob/living/carbon/human/dummy/consistent/preview = allocate(/mob/living/carbon/human/dummy/consistent)
	preview.underwear = /datum/sprite_accessory/clothing/underwear/female_bikini::name
	if(preview.ensure_undergarment("underwear") || length(preview.worn_undergarments))
		Fail("A character preview must never materialize physical underclothes.")
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	human.physique = FEMALE
	human.underwear = /datum/sprite_accessory/clothing/underwear/female_bikini::name
	human.underwear_color = "#28a8c8"
	human.undershirt = /datum/sprite_accessory/clothing/undershirt/sports_bra::name
	human.socks = /datum/sprite_accessory/clothing/socks/black_knee::name
	var/obj/item/undergarment/underwear = human.ensure_undergarment("underwear")
	var/obj/item/undergarment/shirt = human.ensure_undergarment("undershirt")
	var/obj/item/undergarment/socks = human.ensure_undergarment("socks")
	if(!underwear || !shirt || !socks || length(human.worn_undergarments) != 3)
		Fail("The currently worn preference styles must materialize as exactly three physical garments.")
		return
	if(human.ensure_undergarment("underwear") != underwear || human.ensure_undergarment("undershirt") != shirt || human.ensure_undergarment("socks") != socks)
		Fail("Repeated strip reads must reuse the same objects.")
	var/item_count = 0
	for(var/obj/item/undergarment/garment in human.contents)
		item_count++
	if(item_count != 3 || underwear in human.get_equipped_items())
		Fail("Underclothes must neither duplicate their cached objects nor acquire ordinary equipment slots.")
	// Simulate the real wardrobe's direct edits without applying preferences.
	human.underwear = /datum/sprite_accessory/clothing/underwear/male_briefs::name
	human.underwear_color = "#f0a040"
	if(human.ensure_undergarment("underwear") != underwear || underwear.selected_style != human.underwear || underwear.style_color != human.underwear_color)
		Fail("A wardrobe style/tint edit must update the same cached physical garment.")
	if(human.remove_undergarment("underwear", human) != underwear || human.underwear != "Nude" || !human.is_holding(underwear))
		Fail("Removing an undergarment must clear its appearance and return the same item to a hand.")
	if(!underwear.attack_self(human) || human.underwear != underwear.selected_style || human.underwear_color != "#f0a040" || underwear.loc != human)
		Fail("Clicking the removed item must restore its exact style and tint without consuming it.")
	underwear.forceMove(human.drop_location())
	if(human.has_undergarment("underwear") || human.worn_undergarments?["underwear"])
		Fail("Moving a worn physical garment out of its wearer must clear the phantom appearance.")
	qdel(shirt)
	if(human.has_undergarment("undershirt"))
		Fail("Deleting a worn item must clear its appearance layer.")

/// Override only the yielding input, keeping actual held-item actions intact.
/obj/item/undergarment/underwear/unit_test
	var/test_choice
	var/drop_during_choice = FALSE

/obj/item/undergarment/underwear/unit_test/choose_style(mob/living/carbon/human/wearer, list/styles)
	if(drop_during_choice)
		wearer.dropItemToGround(src)
	return test_choice

/datum/unit_test/slim_wardrobe/held_actions/Run()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	human.underwear = "Nude"
	var/obj/item/undergarment/underwear/unit_test/garment = allocate(/obj/item/undergarment/underwear/unit_test)
	human.put_in_hands(garment)
	if(garment.attack_self(human) || QDELETED(garment) || human.underwear != "Nude")
		Fail("Cancelling style selection must retain both the item and the current appearance.")
	garment.test_choice = "invalid test style"
	if(garment.attack_self(human) || QDELETED(garment) || human.underwear != "Nude")
		Fail("An unavailable style must not consume the garment or alter appearance.")
	garment.test_choice = /datum/sprite_accessory/clothing/underwear/female_bikini::name
	garment.drop_during_choice = TRUE
	if(garment.attack_self(human) || garment.loc == human || human.underwear != "Nude")
		Fail("Dropping the item during the selection must prevent an out-of-hand equip.")
	garment.drop_during_choice = FALSE
	human.put_in_hands(garment)
	ADD_TRAIT(human, TRAIT_NO_UNDERWEAR, TRAIT_SOURCE_UNIT_TESTS)
	if(garment.attack_self(human) || QDELETED(garment) || human.underwear != "Nude")
		Fail("An incompatible body must not consume or equip physical underclothes.")
	REMOVE_TRAIT(human, TRAIT_NO_UNDERWEAR, TRAIT_SOURCE_UNIT_TESTS)
	if(!garment.attack_self(human) || QDELETED(garment))
		Fail("A valid first-use selection must put on the same reusable item.")
	var/obj/item/undergarment/underwear/other = allocate(/obj/item/undergarment/underwear)
	other.configure_style(/datum/sprite_accessory/clothing/underwear/male_briefs::name, "#ff0000", human.physique, human.bodyshape)
	human.put_in_hands(other)
	if(other.wear_on(human, human) || human.ensure_undergarment("underwear") != garment || !human.is_holding(other))
		Fail("An occupied appearance must not overwrite the old garment or lose the held replacement.")
	ADD_TRAIT(garment, TRAIT_NO_STRIP, TRAIT_SOURCE_UNIT_TESTS)
	if(human.remove_undergarment("underwear", human) || human.ensure_undergarment("underwear") != garment)
		Fail("Quick-removal helpers must respect no-strip traits too.")
	REMOVE_TRAIT(garment, TRAIT_NO_STRIP, TRAIT_SOURCE_UNIT_TESTS)
	var/obj/item/clothing/under/uniform = allocate(/obj/item/clothing/under/color/grey)
	human.equip_to_slot_if_possible(uniform, ITEM_SLOT_ICLOTHING, disable_warning = TRUE)
	if(human.undergarment_covering_item("underwear") != uniform || human.remove_undergarment("underwear", human))
		Fail("A covered body part must block underclothing removal and identify the covering garment.")
	var/mob/living/basic/mouse/mouse = allocate(/mob/living/basic/mouse)
	if(other.attack_self(mouse) || QDELETED(other))
		Fail("A nonhuman click must leave the purchased undergarment intact.")

/// The same worn object must transfer between people, rather than being bound
/// to its original preference owner or retaining the donor's body build.
/datum/unit_test/slim_wardrobe/transfer_between_wearers/Run()
	var/mob/living/carbon/human/donor = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/mob/living/carbon/human/recipient = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	for(var/mob/living/carbon/human/human in list(donor, recipient))
		human.physique = FEMALE
		human.underwear = "Nude"
		human.undershirt = "Nude"
		human.socks = "Nude"
	recipient.dna.features["slim_body_build"] = TRUE
	recipient.update_body_parts(TRUE)
	if(donor.uses_slim_body() || !recipient.uses_slim_body())
		return Fail("The transfer fixture must cover Standard donor and Slim recipient bodies.", __FILE__, __LINE__)
	var/list/styles = list(
		"underwear" = /datum/sprite_accessory/clothing/underwear/female_bikini::name,
		"undershirt" = /datum/sprite_accessory/clothing/undershirt/sports_bra::name,
		"socks" = /datum/sprite_accessory/clothing/socks/black_knee::name,
	)
	for(var/category in styles)
		var/style = styles[category]
		donor.set_undergarment_style(category, style, "#28a8c8")
		recipient.set_undergarment_style(category, style, "#e87030")
		var/obj/item/undergarment/original = donor.ensure_undergarment(category)
		var/obj/item/undergarment/previous = recipient.ensure_undergarment(category)
		if(!original || !previous || original == previous)
			return Fail("Each actual wearer must begin with a distinct physical [category].", __FILE__, __LINE__)
		if(donor.remove_undergarment(category, donor) != original || !donor.dropItemToGround(original) || !recipient.put_in_hands(original))
			return Fail("A removed [category] must pass through actual hands/floor pickup to another human.", __FILE__, __LINE__)
		if(original.attack_self(recipient) || !recipient.is_holding(original) || recipient.ensure_undergarment(category) != previous)
			return Fail("Another person's [category] must not overwrite an occupied category or lose either item.", __FILE__, __LINE__)
		if(recipient.remove_undergarment(category, recipient) != previous)
			return Fail("The recipient must remove their own [category] before wearing the received item.", __FILE__, __LINE__)
		ADD_TRAIT(recipient, TRAIT_NO_UNDERWEAR, TRAIT_SOURCE_UNIT_TESTS)
		if(original.attack_self(recipient) || !recipient.is_holding(original))
			return Fail("An incompatible recipient must retain the transferred [category] without equipping it.", __FILE__, __LINE__)
		REMOVE_TRAIT(recipient, TRAIT_NO_UNDERWEAR, TRAIT_SOURCE_UNIT_TESTS)
		var/obj/item/clothing/under/color/grey/uniform = allocate(/obj/item/clothing/under/color/grey)
		if(!recipient.equip_to_slot_if_possible(uniform, ITEM_SLOT_ICLOTHING))
			return Fail("The recipient must wear real covering clothes for the transfer guard.", __FILE__, __LINE__)
		if(original.attack_self(recipient) || !recipient.is_holding(original) || recipient.has_undergarment(category))
			return Fail("Covering clothes must block transferred [category] without consuming it.", __FILE__, __LINE__)
		if(!recipient.temporarilyRemoveItemFromInventory(uniform))
			return Fail("The recipient must be able to uncover the transferred garment's body region.", __FILE__, __LINE__)
		uniform.forceMove(get_turf(recipient))
		if(!original.attack_self(recipient) || original.worn_by != recipient || original.loc != recipient || recipient.ensure_undergarment(category) != original)
			return Fail("Another human must wear the original physical [category] through its real held-item action.", __FILE__, __LINE__)
		if(donor.has_undergarment(category) || donor.worn_undergarments?[category] || recipient.get_undergarment_style(category) != style)
			return Fail("Ownership transfer must clear the donor cache and retain the exact received style.", __FILE__, __LINE__)
		if(category == "underwear" && (recipient.underwear_color != "#28a8c8" || original.style_color != "#28a8c8"))
			return Fail("Received underwear must retain the donor garment's tint, not the recipient's previous color.", __FILE__, __LINE__)
		var/list/overlays = recipient.get_underwear_overlays()
		if(length(overlays) != 1)
			return Fail("The received [category] must use the recipient's real body appearance pipeline.", __FILE__, __LINE__)
		if(recipient.remove_undergarment(category, recipient) != original || !recipient.dropItemToGround(original) || !donor.put_in_hands(original) || !original.attack_self(donor))
			return Fail("The same [category] must also transfer back from Slim to Standard without becoming owner-bound.", __FILE__, __LINE__)
		if(original.worn_by != donor || donor.ensure_undergarment(category) != original || recipient.has_undergarment(category) || QDELETED(previous))
			return Fail("A round-trip transfer must preserve both physical item identities and both wearer caches.", __FILE__, __LINE__)
		qdel(previous)
		qdel(original)

/datum/unit_test/slim_wardrobe/middle_click
	var/cancel_dispatches = 0

/datum/unit_test/slim_wardrobe/middle_click/proc/cancel_click(datum/source, atom/target, params)
	SIGNAL_HANDLER
	cancel_dispatches++
	return COMSIG_MOB_CANCEL_CLICKON

/datum/unit_test/slim_wardrobe/middle_click/Run()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	human.underwear = /datum/sprite_accessory/clothing/underwear/female_bikini::name
	human.underwear_color = "#28a8c8"
	human.undershirt = /datum/sprite_accessory/clothing/undershirt/sports_bra::name
	human.socks = /datum/sprite_accessory/clothing/socks/black_knee::name
	human.zone_selected = BODY_ZONE_PRECISE_GROIN
	var/obj/item/undergarment/underwear = human.ensure_undergarment("underwear")
	var/obj/item/undergarment/socks = human.ensure_undergarment("socks")
	RegisterSignal(human, COMSIG_MOB_MIDDLECLICKON, PROC_REF(cancel_click))
	human.MiddleClickOn(human, "middle=1")
	if(cancel_dispatches != 1 || !human.has_undergarment("underwear") || !human.has_undergarment("socks"))
		Fail("The parent's consumed middle-click signal must dispatch exactly once and prevent stripping.")
	UnregisterSignal(human, COMSIG_MOB_MIDDLECLICKON)
	ADD_TRAIT(human, TRAIT_HANDS_BLOCKED, TRAIT_SOURCE_UNIT_TESTS)
	human.MiddleClickOn(human, "middle=1")
	if(!human.has_undergarment("underwear") || !human.has_undergarment("socks"))
		Fail("The quick self action must require usable hands, like the ordinary strip panel.")
	REMOVE_TRAIT(human, TRAIT_HANDS_BLOCKED, TRAIT_SOURCE_UNIT_TESTS)
	human.MiddleClickOn(human, "middle=1")
	if(human.has_undergarment("underwear") || human.has_undergarment("socks") || !human.has_undergarment("undershirt"))
		Fail("An unconsumed self/groin middle-click must remove only currently worn underwear and stockings.")
	if(!human.is_holding(underwear) || !human.is_holding(socks) || QDELETED(underwear) || QDELETED(socks))
		Fail("Middle-click removal must return the same two reusable items without consuming them.")
	var/count = length(human.contents)
	human.MiddleClickOn(human, "middle=1")
	if(length(human.contents) != count)
		Fail("Repeated middle clicks while undressed must not create additional garments.")

/datum/unit_test/slim_wardrobe/legacy_styles/Run()
	var/list/audit = json_decode(file2text('modular_vcg/modules/slim_bodies/review/legacy_underwear_audit.json'))
	var/list/types = list("underwear" = /obj/item/undergarment/underwear, "undershirt" = /obj/item/undergarment/undershirt, "socks" = /obj/item/undergarment/socks)
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	human.physique = FEMALE
	human.dna.features["slim_body_build"] = TRUE
	human.underwear = "Nude"
	human.undershirt = "Nude"
	human.socks = "Nude"
	var/verified = 0
	for(var/list/choice as anything in audit["choices"])
		if(isnull(choice["icon_state"]))
			continue
		var/category = choice["category"]
		var/garment_type = types[category]
		var/obj/item/undergarment/garment = allocate(garment_type)
		var/style = choice["current_name"]
		human.put_in_hands(garment)
		if(!(style in garment.available_styles(human)) || !garment.configure_style(style, "#28a8c8", human.physique, human.bodyshape) || !garment.wear_on(human, human))
			Fail("A real item must make legacy [category]/[style] wearable through the existing appearance pipeline.")
			qdel(garment)
			continue
		if(human.ensure_undergarment(category) != garment || human.remove_undergarment(category, human) != garment || garment.selected_style != style)
			Fail("Legacy [category]/[style] must survive removal as the same physical style instance.")
		if(category == "underwear" && garment.style_color != "#28a8c8")
			Fail("Physical legacy underwear must retain its selected tint.")
		if(garment.custom_price || garment.custom_premium_price || garment.GetComponent(/datum/component/selling))
			Fail("Free wardrobe or preference styles must not produce resale income.")
		verified++
		qdel(garment)
	if(verified != 44)
		Fail("Every one of the 44 non-Nude native legacy styles must be usable as a physical garment, got [verified].")
	for(var/category in types)
		var/item_type = types[category]
		if(!GLOB.all_loadout_datums[item_type])
			Fail("Each physical underclothing category must be selectable in the backpack loadout.")
	for(var/shop_type in list(/obj/structure/retail/clothing_store, /obj/structure/retail/hot_ishu))
		var/obj/structure/retail/shop = allocate(shop_type)
		for(var/category in types)
			var/entries = 0
			for(var/datum/data/vending_product/product as anything in shop.products_list)
				if(product.product_path == types[category])
					entries++
			if(entries != 1)
				Fail("[shop_type] must vend one canonical [category] item, got [entries].")
	var/datum/supply_pack/local/underclothing/pack = new()
	var/obj/structure/closet/crate/crate = allocate(/obj/structure/closet/crate)
	pack.fill(crate)
	for(var/category in types)
		var/count = 0
		for(var/obj/item/undergarment/garment in crate.contents)
			if(garment.type == types[category])
				count++
		if(count != 3)
			Fail("The actual cargo assortment must deliver three [category] items, got [count].")
	qdel(pack)
#endif
