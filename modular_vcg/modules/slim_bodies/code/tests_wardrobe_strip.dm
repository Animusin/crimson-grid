#if defined(UNIT_TESTS) || defined(SPACEMAN_DMM)
#define WARDROBE_STRIP_ASSERT(condition, reason) if(!(condition)) { return Fail(reason, __FILE__, __LINE__) }
#define WARDROBE_STRIP_NOTNULL(value, reason) WARDROBE_STRIP_ASSERT(!isnull(value), reason)
#define WARDROBE_STRIP_EQUAL(actual, expected, reason) do { \
	var/received_value = (actual); \
	var/expected_value = (expected); \
	if(received_value != expected_value) { \
		return Fail("Expected [received_value] to equal [expected_value]: [reason]", __FILE__, __LINE__); \
	} \
} while(FALSE)

/datum/unit_test/wardrobe_strip
#ifdef SLIM_BODY_TESTS
	test_flags = UNIT_TEST_FOCUS
#endif

/datum/unit_test/wardrobe_strip/proc/first_style(list/registry)
	for(var/style in registry)
		var/datum/sprite_accessory/clothing/accessory = registry[style]
		if(accessory?.icon_state)
			return style

/datum/unit_test/wardrobe_strip/proc/use_menu(datum/strip_menu/menu, datum/tgui/ui, mob/user, category)
	var/previous_usr = usr
	usr = user
	ui.user = user
	ui.status = menu.ui_status(user, menu.ui_state(user))
	menu.ui_act("use", list("key" = category), ui, menu.ui_state(user))
	usr = previous_usr

/datum/unit_test/wardrobe_strip/proc/drag_body(mob/living/carbon/human/wearer, mob/user)
	var/previous_usr = usr
	usr = user
	wearer.MouseDrop(user)
	usr = previous_usr

/datum/unit_test/wardrobe_strip/Run()
	var/mob/living/carbon/human/wearer = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/mob/living/carbon/human/other = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	ADD_TRAIT(wearer, TRAIT_PRESERVE_UI_WITHOUT_CLIENT, TRAIT_SOURCE_UNIT_TESTS)
	ADD_TRAIT(other, TRAIT_PRESERVE_UI_WITHOUT_CLIENT, TRAIT_SOURCE_UNIT_TESTS)
	wearer.mock_client = allocate(/datum/client_interface)
	other.mock_client = allocate(/datum/client_interface)
	wearer.underwear = first_style(SSaccessories.underwear_list)
	wearer.undershirt = first_style(SSaccessories.undershirt_list)
	wearer.socks = first_style(SSaccessories.socks_list)
	wearer.underwear_color = "#833fac"
	var/datum/element/strippable/element = SSdcs.GetElement(list(/datum/element/strippable, GLOB.strippable_human_items, TYPE_PROC_REF(/mob/living/carbon/human/, should_strip)))
	drag_body(wearer, wearer)
	var/datum/strip_menu/menu = LAZYACCESS(element.strip_menus, wearer)
	WARDROBE_STRIP_NOTNULL(menu, "Self-drag must cache a real strip menu.")
	var/datum/tgui/ui = allocate(/datum/tgui, wearer, menu, "StripMenu")
	var/list/data = menu.ui_data(wearer)
	for(var/category in list("underwear", "undershirt", "socks"))
		WARDROBE_STRIP_ASSERT(data["items"][category]?["name"], "The menu must display the starting [category] style.")
		var/datum/strippable_item/entry = element.items[category]
		var/obj/item/undergarment/garment = entry.get_item(wearer)
		WARDROBE_STRIP_NOTNULL(garment, "A starting preference must produce a removable [category].")
		WARDROBE_STRIP_EQUAL(entry.get_item(wearer), garment, "Refreshing the menu must reuse the same [category] item.")
		garment.strip_delay = 1
		garment.equip_delay_self = 1
		garment.equip_delay_other = 1
		var/style = wearer.get_undergarment_style(category)
		for(var/mob/living/carbon/human/user in list(wearer, other))
			WARDROBE_STRIP_EQUAL(menu.ui_status(user, menu.ui_state(user)), UI_INTERACTIVE, "An adjacent capable user must be able to use the strip menu.")
			use_menu(menu, ui, user, category)
			WARDROBE_STRIP_ASSERT(!wearer.has_undergarment(category), "The actual UI action must remove [category] for [user == wearer ? "self" : "other"].")
			WARDROBE_STRIP_ASSERT(user.is_holding(garment), "Removing [category] must hand over its original physical item.")
			user.active_hand_index = user.get_held_index_of_item(garment)
			use_menu(menu, ui, user, category)
			WARDROBE_STRIP_EQUAL(wearer.get_undergarment_style(category), style, "Putting [category] back through the UI must restore its exact style.")
			WARDROBE_STRIP_EQUAL(entry.get_item(wearer), garment, "Re-equipping [category] must reuse its original item.")
			WARDROBE_STRIP_EQUAL(wearer.underwear_color, "#833fac", "The UI must preserve the starting underwear tint.")

/datum/unit_test/wardrobe_strip/covering

/datum/unit_test/wardrobe_strip/covering/Run()
	var/mob/living/carbon/human/wearer = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	ADD_TRAIT(user, TRAIT_PRESERVE_UI_WITHOUT_CLIENT, TRAIT_SOURCE_UNIT_TESTS)
	user.mock_client = allocate(/datum/client_interface)
	wearer.underwear = first_style(SSaccessories.underwear_list)
	wearer.undershirt = first_style(SSaccessories.undershirt_list)
	wearer.socks = first_style(SSaccessories.socks_list)
	var/datum/element/strippable/element = SSdcs.GetElement(list(/datum/element/strippable, GLOB.strippable_human_items, TYPE_PROC_REF(/mob/living/carbon/human/, should_strip)))
	drag_body(wearer, user)
	var/datum/strip_menu/menu = LAZYACCESS(element.strip_menus, wearer)
	WARDROBE_STRIP_NOTNULL(menu, "Dragging another human onto the user must still open the ordinary strip menu.")
	var/datum/tgui/ui = allocate(/datum/tgui, user, menu, "StripMenu")
	var/obj/item/pen/held = allocate(/obj/item/pen)
	WARDROBE_STRIP_ASSERT(user.put_in_active_hand(held), "The fixture must hold an unrelated item.")
	var/obj/item/clothing/under/color/grey/uniform = allocate(/obj/item/clothing/under/color/grey)
	WARDROBE_STRIP_ASSERT(wearer.equip_to_slot_if_possible(uniform, ITEM_SLOT_ICLOTHING), "The fixture must wear a real covering uniform.")
	for(var/category in list("underwear", "undershirt", "socks"))
		var/datum/strippable_item/entry = element.items[category]
		WARDROBE_STRIP_EQUAL(entry.get_obscuring(wearer), STRIPPABLE_OBSCURING_INACCESSIBLE, "A uniform must block access to [category].")
		var/style = wearer.get_undergarment_style(category)
		use_menu(menu, ui, user, category)
		WARDROBE_STRIP_EQUAL(wearer.get_undergarment_style(category), style, "A covered UI action must preserve [category].")
	WARDROBE_STRIP_EQUAL(wearer.get_item_by_slot(ITEM_SLOT_ICLOTHING), uniform, "Underlayer actions must leave the ordinary uniform slot alone.")
	WARDROBE_STRIP_ASSERT(user.is_holding(held), "Underlayer actions must not change an unrelated held item.")
	WARDROBE_STRIP_ASSERT(wearer.temporarilyRemoveItemFromInventory(uniform), "The fixture must uncover the underlayers.")
	uniform.forceMove(get_turf(wearer))
	var/datum/strippable_item/entry = element.items["underwear"]
	var/obj/item/undergarment/garment = entry.get_item(wearer)
	garment.strip_delay = 1
	garment.equip_delay_other = 1
	WARDROBE_STRIP_ASSERT(entry.try_unequip(wearer, user) && entry.start_unequip(wearer, user), "An uncovered removal must complete the real strip delay.")
	WARDROBE_STRIP_ASSERT(wearer.equip_to_slot_if_possible(uniform, ITEM_SLOT_ICLOTHING), "The fixture must cover the body again before the final transfer.")
	WARDROBE_STRIP_ASSERT(!entry.finish_unequip(wearer, user), "The final transfer must recheck coverage after the delay.")
	WARDROBE_STRIP_EQUAL(entry.get_item(wearer), garment, "A newly covered body must retain its original garment.")
	wearer.temporarilyRemoveItemFromInventory(uniform)
	uniform.forceMove(get_turf(wearer))
	WARDROBE_STRIP_ASSERT(entry.finish_unequip(wearer, user), "An uncovered body must permit the final removal.")
	user.active_hand_index = user.get_held_index_of_item(garment)
	WARDROBE_STRIP_ASSERT(entry.try_equip(wearer, garment, user) && entry.start_equip(wearer, garment, user), "An uncovered replacement must complete its real equip delay.")
	WARDROBE_STRIP_ASSERT(wearer.equip_to_slot_if_possible(uniform, ITEM_SLOT_ICLOTHING), "The fixture must cover the body before the final equip.")
	WARDROBE_STRIP_ASSERT(!entry.finish_equip(wearer, garment, user), "Replacement must recheck coverage after its delay.")
	WARDROBE_STRIP_ASSERT(user.is_holding(garment) && user.is_holding(held), "Rejected replacement must preserve both held item identities.")
	wearer.temporarilyRemoveItemFromInventory(uniform)
	uniform.forceMove(get_turf(wearer))
	use_menu(menu, ui, user, "underwear")
	WARDROBE_STRIP_EQUAL(entry.get_item(wearer), garment, "The real menu must restore the same garment after uncovering.")
	WARDROBE_STRIP_ASSERT(user.is_holding(held), "Re-equipping an underlayer must leave the unrelated held item alone.")
	var/obj/item/clothing/shoes/sneakers/black/shoes = allocate(/obj/item/clothing/shoes/sneakers/black)
	WARDROBE_STRIP_ASSERT(wearer.equip_to_slot_if_possible(shoes, ITEM_SLOT_FEET), "The fixture must equip real shoes.")
	var/datum/strippable_item/socks_entry = element.items["socks"]
	WARDROBE_STRIP_EQUAL(socks_entry.get_obscuring(wearer), STRIPPABLE_OBSCURING_INACCESSIBLE, "Shoes must block stockings even without a uniform.")
#undef WARDROBE_STRIP_ASSERT
#undef WARDROBE_STRIP_NOTNULL
#undef WARDROBE_STRIP_EQUAL
#endif
