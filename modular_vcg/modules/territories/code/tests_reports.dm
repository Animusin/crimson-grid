#if defined(UNIT_TESTS) || defined(SPACEMAN_DMM)
/obj/structure/city_business/unit_test/false_challenge
	var/test_successes = 2
	var/test_rolls = 0

/obj/structure/city_business/unit_test/false_challenge/false_challenge_roll(mob/living/user)
	test_rolls++
	return test_successes

/datum/unit_test/city_business/false_challenges/Run()
	var/obj/structure/city_business/unit_test/false_challenge/business = allocate(/obj/structure/city_business/unit_test/false_challenge)
	var/mob/living/carbon/human/npc/shop/clerk = allocate(/mob/living/carbon/human/npc/shop)
	business.bind_clerk(clerk)
	var/mob/living/carbon/human/business_test/suspect = allocate(/mob/living/carbon/human/business_test)
	var/obj/item/card/city_badge/anarchs/badge = allocate(/obj/item/card/city_badge/anarchs, suspect)
	var/obj/item/clothing/under/color/grey/uniform = allocate(/obj/item/clothing/under/color/grey)
	var/obj/item/card/id/advanced/id = allocate(/obj/item/card/id/advanced)
	id.registered_name = "Borrowed Identity"
	suspect.real_name = "Concealed True Identity"
	if(!suspect.equip_to_slot_if_possible(uniform, ITEM_SLOT_ICLOTHING) || !suspect.equip_to_slot_if_possible(id, ITEM_SLOT_ID))
		Fail("The false-challenge fixture must wear a visible, named ID.")
		return
	var/mob/living/carbon/human/business_test/owner = allocate(/mob/living/carbon/human/business_test)
	var/mob/living/carbon/human/business_test/claimed_member = allocate(/mob/living/carbon/human/business_test)
	claimed_member.test_faction = FACTION_ANARCHS
	var/mob/living/carbon/human/business_test/bystander = allocate(/mob/living/carbon/human/business_test)
	bystander.test_faction = FACTION_SABBAT
	var/list/phones = list()
	for(var/mob/living/carbon/human/person in list(owner, claimed_member, bystander))
		var/obj/item/smartphone/phone = allocate(/obj/item/smartphone, person)
		phone.owner_weakref = WEAKREF(person)
		if(!phone.sim_card)
			phone.sim_card = new /obj/item/sim_card(phone)
			phone.sim_card.phone_weakref = WEAKREF(phone)
		phones += phone
	var/existing_attack = GLOB.city_business_attacks[FACTION_ANARCHS]
	business.declare_attack(suspect, FACTION_ANARCHS)
	if(business.test_rolls != 1 || length(business.suspect_reports) != 1)
		Fail("A nonmember presenting another faction's credential must produce one false declaration and a clerk report.")
		return
	if(business.attack_faction || business.preparation_ends || business.active_conflict || business.retry_at || GLOB.city_business_attacks[FACTION_ANARCHS] != existing_attack)
		Fail("A false declaration must never reserve an attack slot, start capture, or block a real declaration.")
	for(var/i in 1 to length(phones))
		var/obj/item/smartphone/phone = phones[i]
		if(!!phone.get_conversation("5550199") != (i <= 2))
			Fail("False declarations must notify the owner and claimed faction, never unrelated phones.")
	business.declare_attack(suspect, FACTION_ANARCHS)
	if(business.test_rolls != 1 || length(business.suspect_reports) != 1)
		Fail("The store-wide false-alarm cooldown must stop repeated rolls and message spam.")
	var/datum/city_business_suspect/report = business.suspect_reports[1]
	if(report.id_name != "Borrowed Identity" || !isicon(report.appearance_snapshot) || findtext(report.visible_name, suspect.real_name))
		Fail("The clerk must save the visible ID and appearance without revealing a hidden true name.")
	id.registered_name = "Changed Later"
	suspect.real_name = "Changed Later"
	if(report.id_name != "Borrowed Identity")
		Fail("Changing identity later must not rewrite the clerk's snapshot.")
	if(length(business.get_suspect_reports(owner)) != 1 || !isnull(business.get_suspect_reports(claimed_member)))
		Fail("Only an actual member of the current controlling faction may read clerk reports.")
	allocate(/obj/item/card/city_badge, claimed_member)
	if(!isnull(business.get_suspect_reports(claimed_member)))
		Fail("A stolen owner credential must not reveal reports to a nonmember.")
	business.owner_faction = FACTION_ANARCHS
	if(!isnull(business.get_suspect_reports(owner)) || length(business.get_suspect_reports(claimed_member)) != 1)
		Fail("Report access must follow the current owner, including after capture.")
	business.owner_faction = FACTION_CAMARILLA
	badge.forceMove(run_loc_floor_bottom_left)
	business.false_alarm_ready_at = 0
	if(business.false_challenge(suspect, FACTION_ANARCHS) || business.test_rolls != 1)
		Fail("A bare nonmember cannot claim another faction without presenting its credential.")
	badge.forceMove(suspect)
	business.test_successes = 0
	if(business.false_challenge(suspect, FACTION_ANARCHS) || business.test_rolls != 2 || length(business.suspect_reports) != 1 || business.false_alarm_ready_at <= world.time)
		Fail("A failed false declaration must consume its own cooldown without creating an alarm or report.")

/datum/unit_test/city_business/false_challenge_memory/Run()
	var/obj/structure/city_business/unit_test/false_challenge/business = allocate(/obj/structure/city_business/unit_test/false_challenge)
	var/mob/living/carbon/human/npc/shop/clerk = allocate(/mob/living/carbon/human/npc/shop)
	business.bind_clerk(clerk)
	var/mob/living/carbon/human/business_test/suspect = allocate(/mob/living/carbon/human/business_test)
	allocate(/obj/item/card/city_badge/anarchs, suspect)
	ADD_TRAIT(suspect, TRAIT_UNKNOWN_APPEARANCE, TRAIT_SOURCE_UNIT_TESTS)
	if(!business.false_challenge(suspect, FACTION_ANARCHS))
		Fail("A concealed identity may make a false threat, but the clerk cannot see through it.")
		return
	var/datum/city_business_suspect/report = business.suspect_reports[1]
	if(report.appearance_snapshot || report.id_name != "No visible ID")
		Fail("Unknown appearance must not expose a hidden body or ID in the clerk memory.")
	for(var/i in 1 to 6)
		business.false_alarm_ready_at = 0
		business.false_challenge(suspect, FACTION_ANARCHS)
	if(length(business.suspect_reports) != 5)
		Fail("Clerk memories must retain only the five most recent successful false threats.")
	business.clear_suspect_reports()
	if(length(business.suspect_reports))
		Fail("Removing a business must release its clerk memories and appearance snapshots.")
	REMOVE_TRAIT(suspect, TRAIT_UNKNOWN_APPEARANCE, TRAIT_SOURCE_UNIT_TESTS)
	var/obj/item/card/id/advanced/id = allocate(/obj/item/card/id/advanced, suspect)
	id.registered_name = "Invisible Secret ID"
	suspect.wear_id = id
	ADD_TRAIT(suspect, TRAIT_INVISIBLE_MAN, TRAIT_SOURCE_UNIT_TESTS)
	var/datum/city_business_suspect/invisible_man = allocate(/datum/city_business_suspect, suspect, FACTION_ANARCHS, clerk)
	if(invisible_man.appearance_snapshot || invisible_man.id_name != "No visible ID" || invisible_man.visible_name != "Appearance concealed")
		Fail("An invisible person must not expose a worn ID or name just because the ID itself has no concealment trait.")
	REMOVE_TRAIT(suspect, TRAIT_INVISIBLE_MAN, TRAIT_SOURCE_UNIT_TESTS)
	ADD_TRAIT(id, TRAIT_EXAMINE_SKIP, TRAIT_SOURCE_UNIT_TESTS)
	var/datum/city_business_suspect/hidden_id = allocate(/datum/city_business_suspect, suspect, FACTION_ANARCHS, clerk)
	if(hidden_id.id_name != "No visible ID" || findtext(hidden_id.visible_name, id.registered_name))
		Fail("A hidden ID must not leak through the appearance name's normal ID fallback.")
	REMOVE_TRAIT(id, TRAIT_EXAMINE_SKIP, TRAIT_SOURCE_UNIT_TESTS)
	suspect.invisibility = INVISIBILITY_ABSTRACT
	var/datum/city_business_suspect/unseen = allocate(/datum/city_business_suspect, suspect, FACTION_ANARCHS, clerk)
	if(unseen.appearance_snapshot || unseen.id_name != "No visible ID" || unseen.visible_name != "Appearance concealed")
		Fail("A clerk must not identify a speaker beyond the clerk's own see-invisible level.")
#endif
