#if defined(UNIT_TESTS) || defined(SPACEMAN_DMM)

/obj/structure/city_business/unit_test

/obj/structure/city_business/unit_test/LateInitialize()
	return

/mob/living/carbon/human/business_test
	var/test_faction = FACTION_CAMARILLA

/mob/living/carbon/human/business_test/city_faction()
	return test_faction

/datum/unit_test/city_business
	abstract_type = /datum/unit_test/city_business
	test_flags = UNIT_TEST_MAP_TEST
#ifdef BUSINESS_TESTS
	test_flags = UNIT_TEST_FOCUS
#endif

/datum/unit_test/city_business/economy/Run()
	var/mob/living/carbon/human/business_test/customer = allocate(/mob/living/carbon/human/business_test)
	var/obj/structure/city_business/unit_test/business = allocate(/obj/structure/city_business/unit_test)
	var/mob/living/carbon/human/npc/shop/clerk = allocate(/mob/living/carbon/human/npc/shop)
	business.clerk_home = get_turf(clerk)
	business.bind_clerk(clerk)
	var/obj/structure/retail/coffee_shop/store = allocate(/obj/structure/retail/coffee_shop)
	store.territory = business
	business.outlets += store
	store.my_owner = clerk
	if(store.business_price(customer, 100) != 100)
		Fail("Membership without a credential must not receive a discount.")
	var/obj/item/card/city_badge/badge = allocate(/obj/item/card/city_badge, customer)
	if(store.business_price(customer, 100) != 50)
		Fail("Members with the matching credential must pay half price.")
	customer.test_faction = FACTION_ANARCHS
	if(store.business_price(customer, 100) != 100)
		Fail("A stolen credential alone must not grant a retail discount.")
	badge.forceMove(run_loc_floor_bottom_left)

	var/obj/lombard/buyer = allocate(/obj/lombard)
	buyer.territory = business
	business.outlets += buyer
	buyer.owner = clerk
	if(buyer.business_can_sell(customer))
		Fail("Non-owners must be rejected by both the single and bulk sale gate.")
	customer.test_faction = FACTION_CAMARILLA
	if(!buyer.business_can_sell(customer))
		Fail("Members of the current owner must be allowed to sell.")
	var/obj/item/food/grown/cannabis/leaf = allocate(/obj/item/food/grown/cannabis)
	var/datum/component/selling/sale = leaf.GetComponent(/datum/component/selling)
	if(sale.can_sell())
		Fail("A fresh cannabis leaf must not be sellable.")
	ADD_TRAIT(leaf, TRAIT_DRIED, TRAIT_SOURCE_UNIT_TESTS)
	if(!sale.can_sell() || buyer.calculate_sale_price(leaf, customer, sale, 9) != 50)
		Fail("A dried leaf must sell for exactly $50 regardless of fencing successes.")
	REMOVE_TRAIT(leaf, TRAIT_DRIED, TRAIT_SOURCE_UNIT_TESTS)
	if(length(buyer.sell_multiple_items(list(leaf), customer)))
		Fail("Bulk selling must not bypass the drying requirement.")

	business.income_per_cycle = 40
	business.next_collection = 0
	business.collect_income(customer, FACTION_CAMARILLA)
	var/cash_total = 0
	for(var/obj/item/stack/dollar/cash in get_turf(customer))
		cash_total += cash.amount
	if(cash_total != 40)
		Fail("A 40-player business cycle must pay $40 in physical cash.")
	business.collect_income(customer, FACTION_CAMARILLA)
	cash_total = 0
	for(var/obj/item/stack/dollar/cash in get_turf(customer))
		cash_total += cash.amount
	if(cash_total != 40)
		Fail("A second collection in the same business cycle must not print more money.")
	business.attack_faction = FACTION_ANARCHS
	business.preparation_ends = world.time + 5 MINUTES
	GLOB.city_business_attacks[FACTION_ANARCHS] = business
	clerk.death()
	if(business.clerk_available() || business.recover_at != world.time + 15 MINUTES || business.attack_faction != FACTION_ANARCHS)
		Fail("Clerk death must disable collection for 15 minutes without cancelling a declaration.")
	business.recover_at = world.time - 1
	business.process(1)
	if(business.clerk == clerk || !business.clerk_available() || store.my_owner != business.clerk || buyer.owner != business.clerk)
		Fail("Recovery must respawn the clerk and rebind both retail and buyer outlets.")
	business.finish_attack(FALSE)

/datum/unit_test/city_business/capture/Run()
	var/obj/structure/city_business/unit_test/business = allocate(/obj/structure/city_business/unit_test)
	business.attack_faction = FACTION_ANARCHS
	business.active_conflict = TRUE
	GLOB.city_business_attacks[FACTION_ANARCHS] = business
	business.hold_started = world.time - 30 SECONDS
	business.advance_capture(TRUE, FALSE)
	if(business.owner_faction != FACTION_ANARCHS || business.attack_faction || GLOB.city_business_attacks[FACTION_ANARCHS])
		Fail("A completed hold must transfer ownership and release the faction's attack slot.")
	business.attack_faction = FACTION_CAMARILLA
	business.active_conflict = TRUE
	business.hold_started = world.time
	GLOB.city_business_attacks[FACTION_CAMARILLA] = business
	business.advance_capture(TRUE, TRUE)
	if(business.owner_faction != FACTION_ANARCHS || business.attack_faction || GLOB.city_business_attacks[FACTION_CAMARILLA])
		Fail("A defender interrupting a hold must end the attempt without changing ownership.")

/datum/unit_test/city_business/witnesses/Run()
	var/obj/structure/city_business/unit_test/business = allocate(/obj/structure/city_business/unit_test)
	var/mob/living/carbon/human/npc/shop/witness = allocate(/mob/living/carbon/human/npc/shop)
	var/mob/living/carbon/human/breacher = allocate(/mob/living/carbon/human)
	if(city_conflict_hides_breach(witness, breacher))
		Fail("Preparation must not disable NPC witnesses.")
	business.active_conflict = TRUE
	if(!city_conflict_hides_breach(witness, breacher))
		Fail("Local NPCs must not register new breaches during a contest.")
	var/atom/movable/object_witness = allocate(/obj/item/smartphone)
	if(city_conflict_hides_breach(object_witness, breacher))
		Fail("A contest must not exempt phone/object witnesses.")
	business.active_conflict = FALSE
	if(city_conflict_hides_breach(witness, breacher))
		Fail("Witnesses must resume immediately when the contest ends.")

/datum/unit_test/city_business/map_links/Run()
	var/list/ids = list()
	for(var/obj/structure/city_business/business as anything in GLOB.city_businesses)
		if(!business.mapped_business)
			continue
		if(!business.territory_id || business.territory_id in ids)
			Fail("Every mapped business must have a unique ID: [business.territory_id]")
		ids += business.territory_id
		if(QDELETED(business.clerk) || business.clerk.territory_employer != business)
			Fail("[business.territory_id] must have a bound living clerk.")
		for(var/atom/outlet as anything in business.outlets)
			if(business.clerk && (outlet.z != business.clerk.z || get_dist(outlet, business.clerk) > 4))
				Fail("[business.territory_id] has a clerk outside trading distance; check map-load offsets.")
			if(istype(outlet, /obj/structure/retail))
				var/obj/structure/retail/store = outlet
				if(store.territory != business || store.my_owner != business.clerk)
					Fail("[business.territory_id] has a broken retail link.")
			else
				var/obj/lombard/buyer = outlet
				if(buyer.territory != business || buyer.owner != business.clerk)
					Fail("[business.territory_id] has a broken buyer link.")

#endif
