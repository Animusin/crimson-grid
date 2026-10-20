#if defined(UNIT_TESTS) || defined(SPACEMAN_DMM)

/obj/structure/city_business/unit_test
	var/test_population = 40

/obj/structure/city_business/unit_test/round_population()
	return test_population

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
#ifdef BUSINESS_GEOMETRY
/datum/unit_test/city_business/geometry_export/Run()
	var/list/tiles = list()
	var/list/marks = list()
	var/list/service_tiles = list()
	// Export actual cashier interaction, including checkout reach and visibility.
	// A public mark alone does not make a private office cashier accessible.
	var/mob/living/carbon/human/probe = allocate(/mob/living/carbon/human/dummy/consistent)
	for(var/obj/structure/city_business/business as anything in GLOB.city_businesses)
		if(business.mapped_business)
			marks[business.territory_id] = list(business.x, business.y, business.z)
			var/list/approaches = list()
			service_tiles[business.territory_id] = approaches
			for(var/turf/open/position in range(7, business.clerk))
				if(position.density || isspaceturf(position) || isopenspaceturf(position))
					continue
				// Sample reach without stepping on traps, stairs or other entry
				// triggers. The dummy retains the normal human action/reach checks.
				probe.abstract_move(position)
				if(get_turf(probe) != position || IS_UNCONSCIOUS(probe) || probe.IsIncapacitated())
					Fail("Cashier geometry probe lost its position or action capability at [position] for [business.territory_id].")
					return
				if(business.can_negotiate(probe, business.clerk))
					approaches += list(list(position.x, position.y, position.z))
	qdel(probe)
	for(var/turf/open/tile in world)
		if(isspaceturf(tile) || isopenspaceturf(tile))
			continue
		var/blocked = FALSE
		var/door = FALSE
		var/restricted = FALSE
		var/list/links = list()
		for(var/atom/movable/obstacle in tile)
			if(istype(obstacle, /obj/structure/vampdoor))
				door = TRUE
				var/obj/structure/vampdoor/vampdoor = obstacle
				restricted = vampdoor.locked
			else if(istype(obstacle, /obj/machinery/door))
				door = TRUE
				var/obj/machinery/door/machinery_door = obstacle
				// Permanently open mall shutters are real public passages. Keep
				// closed, bolted and access-controlled doors out of that route.
				restricted = machinery_door.density || machinery_door.locked || !machinery_door.check_access(null)
			else if(!ismob(obstacle) && obstacle.density)
				blocked = TRUE
			if(istype(obstacle, /obj/structure/stairs))
				var/obj/structure/stairs/stair = obstacle
				if(stair.isTerminator() && isopenspaceturf(get_step_multiz(stair, UP)))
					var/turf/landing = get_step_multiz(stair, stair.dir|UP)
					if(landing)
						links += list(list(landing.x, landing.y, landing.z))
			if(istype(obstacle, /obj/structure/ladder))
				var/obj/structure/ladder/ladder = obstacle
				if(ladder.up)
					links += list(list(ladder.up.x, ladder.up.y, ladder.up.z))
				if(ladder.down)
					links += list(list(ladder.down.x, ladder.down.y, ladder.down.z))
		tiles += list(list(tile.x, tile.y, tile.z, blocked, door, links, restricted))
	fdel("data/business_geometry.json")
	WRITE_FILE(file("data/business_geometry.json"), json_encode(list("version" = 2, "tiles" = tiles, "marks" = marks, "service_tiles" = service_tiles)))
#endif

/datum/unit_test/city_business/economy/Run()
	if(city_business_population(list("Alice", "alice", "Bob", "")) != 2)
		Fail("Population must count unique joined accounts, never reconnects or empty keys.")
	var/mob/living/carbon/human/business_test/customer = allocate(/mob/living/carbon/human/business_test)
	var/obj/structure/city_business/unit_test/business = allocate(/obj/structure/city_business/unit_test)
	var/mob/living/carbon/human/npc/shop/clerk = allocate(/mob/living/carbon/human/npc/shop)
	business.clerk_home = get_turf(clerk)
	business.bind_clerk(clerk)
	var/obj/structure/retail/coffee_shop/store = allocate(/obj/structure/retail/coffee_shop)
	store.territory = business
	business.outlets += store
	store.my_owner = clerk
	var/turf/clerk_start = get_turf(clerk)
	clerk.forceMove(get_step(get_step(get_step(clerk_start, EAST), EAST), EAST))
	business.outlets.Cut()
	if(business.can_negotiate(customer, clerk))
		Fail("A distant cashier without its reachable counter must not be usable.")
	business.outlets += store
	if(!business.can_negotiate(customer, clerk))
		Fail("Clicking the visible cashier must work across its own reachable checkout.")
	if(business.can_negotiate(customer, store))
		Fail("A checkout must never be an interaction target for business actions.")
	var/obj/structure/retail/coffee_shop/unrelated = allocate(/obj/structure/retail/coffee_shop)
	if(business.can_negotiate(customer, unrelated))
		Fail("A nearby checkout from another business must not proxy this clerk.")
	customer.forceMove(get_step(get_step(get_step(clerk_start, NORTH), NORTH), NORTH))
	if(business.can_negotiate(customer, clerk))
		Fail("Walking away from the checkout must revoke the pending negotiation.")
	customer.forceMove(clerk_start)
	clerk.forceMove(clerk_start)
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
	var/obj/item/clothing/under/vampire/brujah/outfit = allocate(/obj/item/clothing/under/vampire/brujah)
	var/datum/component/selling/outfit_sale = outfit.GetComponent(/datum/component/selling)
	outfit.city_record_retail_price(10)
	if(buyer.calculate_sale_price(outfit, customer, outfit_sale, 5) != 10)
		Fail("An unlimited-stock $10 retail purchase must not be pawned for $50.")
	outfit.city_record_retail_price(20)
	if(buyer.calculate_sale_price(outfit, customer, outfit_sale, 5) != 20)
		Fail("The resale ceiling must protect normal retail prices as well as discounts.")
	var/obj/item/stack/sheet/iron/retail_stack = allocate(/obj/item/stack/sheet/iron, run_loc_floor_bottom_left, 10, FALSE)
	retail_stack.city_record_retail_price(50)
	var/obj/item/stack/split = retail_stack.split_stack(2)
	allocated += split
	if(split.city_resale_price(100) != 10 || retail_stack.city_resale_price(100) != 40)
		Fail("Splitting retail stacks must split their NPC resale allowance proportionally.")
	var/obj/item/stack/sheet/iron/loot_stack = allocate(/obj/item/stack/sheet/iron, run_loc_floor_bottom_left, 1, FALSE)
	if(split.can_merge(loot_stack) || loot_stack.can_merge(split))
		Fail("Merging untracked loot must not wash a retail stack receipt.")
	var/obj/item/stack/tile/carpet/fifty/carpet = allocate(/obj/item/stack/tile/carpet/fifty, run_loc_floor_bottom_left, 50, FALSE)
	carpet.city_record_retail_price(10)
	var/obj/item/stack/carpet_split = carpet.split_stack(3)
	allocated += carpet_split
	if(carpet_split.city_resale_price(100) != 0 || carpet.city_resale_price(100) != 9)
		Fail("Fractional stack receipts must round down, never print money on repeated splits.")
	var/obj/item/stack/vended_stack = store.dispense_product(/obj/item/stack/sheet/iron, 10)
	allocated += vended_stack
	if(QDELETED(vended_stack) || vended_stack.city_resale_price(100) != 10 || loot_stack.amount != 1)
		Fail("Actual retail dispensing must stamp stacks before they can auto-merge into loot.")
	var/obj/item/storage/backpack/bag = allocate(/obj/item/storage/backpack)
	var/obj/item/clothing/under/vampire/brujah/contents_outfit = allocate(/obj/item/clothing/under/vampire/brujah, bag)
	bag.city_record_retail_price(100)
	if(contents_outfit.city_resale_price(50) != 0 || bag.city_resale_price(500) != 100)
		Fail("Selling a stocked retail container and its contents must not duplicate the allowance.")

	business.income_per_cycle = 40
	business.test_population = 40
	business.collection_started = TRUE
	business.next_collection = world.time
	badge.forceMove(customer)
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
	business.test_population = 60
	business.next_collection = world.time
	business.collect_income(customer, FACTION_CAMARILLA)
	cash_total = 0
	for(var/obj/item/stack/dollar/cash in get_turf(customer))
		cash_total += cash.amount
	if(cash_total != 100)
		Fail("Late arrivals must increase a later collection from $40 to $60.")
	var/obj/machinery/smartfridge/drying/rack/rack = allocate(/obj/machinery/smartfridge/drying/rack)
	if(!rack.load(leaf, customer))
		Fail("A wooden rack must accept an actual fresh cannabis leaf.")
	rack.toggle_drying(FALSE, customer)
	rack.process(2)
	if(!HAS_TRAIT(leaf, TRAIT_DRIED) || !sale.can_sell())
		Fail("The actual rack process must produce a sellable dried leaf without electricity.")
	business.attack_faction = FACTION_ANARCHS
	business.preparation_ends = world.time + 5 MINUTES
	GLOB.city_business_attacks[FACTION_ANARCHS] = business
	clerk.death()
	if(business.clerk_available() || business.recover_at != world.time + 15 MINUTES || business.attack_faction != FACTION_ANARCHS)
		Fail("Clerk death must disable collection for 15 minutes without cancelling a declaration.")
	if(business.can_negotiate(customer, store))
		Fail("The checkout must not proxy a dead or recovering clerk.")
	business.recover_at = world.time - 1
	business.process(1)
	if(business.clerk == clerk || !business.clerk_available() || store.my_owner != business.clerk || buyer.owner != business.clerk)
		Fail("Recovery must respawn the clerk and rebind both retail and buyer outlets.")
	business.finish_attack(FALSE)

/datum/unit_test/city_business/capture/Run()
	var/obj/structure/city_business/unit_test/business = allocate(/obj/structure/city_business/unit_test)
	var/mob/living/carbon/human/business_test/outsider = allocate(/mob/living/carbon/human/business_test)
	business.declare_attack(outsider, FACTION_ANARCHS)
	if(business.attack_faction || business.retry_at || GLOB.city_business_attacks[FACTION_ANARCHS])
		Fail("A stolen enemy credential must not reserve that faction's attack slot.")
	var/turf/mark_turf = get_turf(business)
	var/turf/east_tile = get_step(get_step(mark_turf, EAST), EAST)
	// An isolated glass box remains visible but must never count as capture presence.
	var/list/barriers = list()
	for(var/direction in GLOB.alldirs)
		var/turf/barrier_tile = get_step(east_tile, direction)
		if(barrier_tile == mark_turf || barrier_tile == east_tile)
			continue
		barriers += allocate(/obj/structure/window/fulltile, barrier_tile)
	if(east_tile in business.connected_capture_tiles())
		Fail("Visible but physically blocked glass tiles must not count for capture.")
	for(var/obj/structure/window/barrier as anything in barriers)
		qdel(barrier)
	if(!(east_tile in business.connected_capture_tiles()))
		Fail("Removing glass must restore capture connectivity.")
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

/datum/unit_test/city_business/defense_event
	var/defense_events = 0
	var/list/last_event

/datum/unit_test/city_business/defense_event/proc/on_defense(datum/source, mob/living/defender, territory_id, attack_token, attacking_faction)
	SIGNAL_HANDLER
	defense_events++
	last_event = list(defender, territory_id, attack_token, attacking_faction)

/datum/unit_test/city_business/defense_event/Run()
	var/obj/structure/city_business/unit_test/business = allocate(/obj/structure/city_business/unit_test)
	business.territory_id = "defense_unit"
	business.attack_token = "defense_unit_contest"
	business.attack_faction = FACTION_ANARCHS
	var/mob/living/carbon/human/business_test/defender = allocate(/mob/living/carbon/human/business_test)
	var/datum/client_interface/mock = allocate(/datum/client_interface)
	mock.ckey = "businessdefender"
	mock.mob = defender
	defender.mock_client = mock
	RegisterSignal(SSdcs, "city_business_defended", PROC_REF(on_defense))
	business.track_defense(list(defender))
	if(defense_events)
		Fail("Merely arriving in the waiting window must not emit a defense reward.")
	business.defense_started[mock.ckey] = world.time - 10 SECONDS
	business.track_defense(list(defender))
	if(defense_events != 1 || last_event[1] != defender || last_event[2] != "defense_unit" || last_event[3] != "defense_unit_contest" || last_event[4] != FACTION_ANARCHS)
		Fail("Ten seconds of defense must emit the connected account and complete four-argument contest event.")
	business.track_defense(list(defender), TRUE)
	if(defense_events != 1)
		Fail("One account must never emit a second defense event in the same contest.")
	business.defense_reported.Cut()
	business.defense_started.Cut()
	business.track_defense(list(defender), TRUE)
	if(defense_events != 2)
		Fail("Actually interrupting a hold must count immediately, before that attack ends.")
	business.defense_reported.Cut()
	business.defense_started.Cut()
	business.track_defense(list(defender))
	business.track_defense(list())
	if(length(business.defense_started))
		Fail("Leaving the defense area must reset pending continuous participation.")
	UnregisterSignal(SSdcs, "city_business_defended")
	mock.mob = null
	defender.mock_client = null

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

/obj/structure/city_business/unit_test/fifth_faction/roll_business(mob/living/user)
	return 2

/obj/structure/city_business/unit_test/fifth_faction/false_challenge_roll(mob/living/user)
	return 2

/// Real jobs and minds deliberately bypass the business_test faction override.
/datum/unit_test/city_business/proc/giovanni_member_fixture(job_type = /datum/job/vampire/capo)
	var/mob/living/carbon/human/member = allocate(/mob/living/carbon/human/consistent)
	member.mind_initialize()
	member.mind.assigned_role = allocate(job_type)
	return member

/datum/unit_test/city_business/giovanni_membership/Run()
	for(var/job_type in list(/datum/job/vampire/capo, /datum/job/vampire/nonni, /datum/job/vampire/squadra, /datum/job/vampire/famiglia))
		var/mob/living/carbon/human/member = giovanni_member_fixture(job_type)
		if(member.mind.assigned_role.city_faction() != FACTION_GIOVANNI || member.city_faction() != FACTION_GIOVANNI)
			Fail("Each real Giovanni role must participate as Giovanni rather than an unclaimed city job: [job_type].")
		member.issue_city_badge()
		member.issue_city_badge()
		var/badge_count = 0
		for(var/obj/item/card/city_badge/badge in member.get_all_contents())
			badge_count++
			if(!istype(badge, /obj/item/card/city_badge/giovanni) || badge.city_faction != FACTION_GIOVANNI || badge.icon_state != FACTION_GIOVANNI || badge.name != "Giovanni credential")
				Fail("Issuing a real Giovanni job's ID must use its own credential, faction, label and symbol.")
			if(!(badge.icon_state in icon_states(badge.icon)))
				Fail("The issued Giovanni ID must reference a compiled, existing icon state.")
		if(badge_count != 1 || !member.has_city_badge(FACTION_GIOVANNI))
			Fail("Issuing a Giovanni ID twice must produce exactly one usable carried credential.")
	var/obj/structure/city_business/unit_test/business = allocate(/obj/structure/city_business/unit_test)
	business.owner_faction = FACTION_GIOVANNI
	business.update_icon_state()
	if(city_faction_name(FACTION_GIOVANNI) != "Giovanni" || business.icon_state != FACTION_GIOVANNI || !(business.icon_state in icon_states(business.icon)))
		Fail("Giovanni ownership must have a faction name and an actual matching territory symbol.")

/datum/unit_test/city_business/giovanni_business/Run()
	var/obj/structure/city_business/unit_test/fifth_faction/business = allocate(/obj/structure/city_business/unit_test/fifth_faction)
	var/mob/living/carbon/human/npc/shop/clerk = allocate(/mob/living/carbon/human/npc/shop)
	business.bind_clerk(clerk)
	var/mob/living/carbon/human/member = giovanni_member_fixture()
	member.issue_city_badge()
	var/mob/living/carbon/human/business_test/owner = allocate(/mob/living/carbon/human/business_test)
	var/mob/living/carbon/human/business_test/bystander = allocate(/mob/living/carbon/human/business_test)
	bystander.test_faction = FACTION_SABBAT
	var/obj/item/smartphone/member_phone = allocate(/obj/item/smartphone, member)
	member_phone.owner_weakref = WEAKREF(member)
	var/obj/item/smartphone/owner_phone = allocate(/obj/item/smartphone, owner)
	owner_phone.owner_weakref = WEAKREF(owner)
	var/obj/item/smartphone/bystander_phone = allocate(/obj/item/smartphone, bystander)
	bystander_phone.owner_weakref = WEAKREF(bystander)
	var/previous_attack = GLOB.city_business_attacks[FACTION_GIOVANNI]
	if(previous_attack)
		Fail("The isolated Giovanni capture fixture requires a free faction attack slot.")
		return
	business.declare_attack(member, FACTION_GIOVANNI)
	if(business.attack_faction != FACTION_GIOVANNI || GLOB.city_business_attacks[FACTION_GIOVANNI] != business || business.preparation_ends <= world.time)
		Fail("A real Giovanni member with its issued ID must declare and reserve its faction's actual capture slot.")
	if(!member_phone.get_conversation("5550199") || !owner_phone.get_conversation("5550199") || bystander_phone.get_conversation("5550199"))
		Fail("An actual Giovanni declaration must send normal SMS to Giovanni and the owner, excluding unrelated factions.")
	business.active_conflict = TRUE
	business.hold_started = world.time - 30 SECONDS
	business.advance_capture(TRUE, FALSE)
	if(business.owner_faction != FACTION_GIOVANNI || business.attack_faction || GLOB.city_business_attacks[FACTION_GIOVANNI])
		Fail("Completing a Giovanni hold must transfer the business and release the same faction attack slot.")
	var/obj/structure/retail/coffee_shop/store = allocate(/obj/structure/retail/coffee_shop)
	store.territory = business
	var/obj/lombard/buyer = allocate(/obj/lombard)
	buyer.territory = business
	if(store.business_price(member, 100) != 50 || !buyer.business_can_sell(member) || store.business_price(owner, 100) != 100 || buyer.business_can_sell(owner))
		Fail("Captured Giovanni stores must use the common owner discount and sale gates with actual Giovanni job membership.")
	// Reuse the real issued ID for an outsider's false declaration, rather than
	// manufacturing membership or copying the generic false-challenge fixture.
	var/obj/structure/city_business/unit_test/fifth_faction/false_business = allocate(/obj/structure/city_business/unit_test/fifth_faction)
	var/mob/living/carbon/human/npc/shop/other_clerk = allocate(/mob/living/carbon/human/npc/shop)
	false_business.bind_clerk(other_clerk)
	var/mob/living/carbon/human/business_test/suspect = allocate(/mob/living/carbon/human/business_test)
	suspect.test_faction = FACTION_ANARCHS
	for(var/obj/item/card/city_badge/badge in member.get_all_contents())
		badge.forceMove(suspect)
	var/datum/phone_conversation/conversation = member_phone.get_conversation("5550199")
	var/messages_before = length(conversation?.messages)
	false_business.declare_attack(suspect, FACTION_GIOVANNI)
	if(length(false_business.suspect_reports) != 1 || false_business.attack_faction || false_business.preparation_ends || false_business.retry_at || GLOB.city_business_attacks[FACTION_GIOVANNI])
		Fail("A stolen Giovanni ID must use the normal false-declaration/report path without starting a capture or claiming its faction slot.")
	if(length(conversation?.messages) != messages_before + 1 || bystander_phone.get_conversation("5550199"))
		Fail("The common false-alarm notification must include Giovanni members while excluding unrelated phones.")

/datum/unit_test/city_business/westfield_no_triads/Run()
	if(SSmapping.current_map.map_name != "Westfield Mall")
		return
	for(var/job_type in list(/datum/job/vampire/mountain_master, /datum/job/vampire/deputy_mountain_master, /datum/job/vampire/red_pole, /datum/job/vampire/blue_lantern))
		var/datum/job/triad_job = allocate(job_type)
		if(triad_job.spawn_positions != 0 || triad_job.total_positions != 0 || triad_job.map_check() || SSjob.get_job_type(job_type))
			Fail("Westfield must disable both roundstart and latejoin Triad slots through the actual map job configuration: [job_type].")
	for(var/obj/effect/landmark/start/start in GLOB.start_landmarks_list)
		if(istype(start, /obj/effect/landmark/start/darkpack/triad) && is_station_level(start.z))
			Fail("Westfield must not retain a mapped Triad station spawn: [start.type].")
	for(var/obj/structure/city_business/business as anything in GLOB.city_businesses)
		if(business.mapped_business && business.owner_faction == "triads")
			Fail("Westfield must not start with a business seeded to an unavailable Triad faction: [business.territory_id].")

/datum/unit_test/city_business/map_links/Run()
	var/list/ids = list()
	var/giovanni_banks = 0
	for(var/obj/structure/city_business/business as anything in GLOB.city_businesses)
		if(!business.mapped_business)
			continue
		if(business.business_name == "Giovanni Bank" && business.owner_faction == FACTION_GIOVANNI)
			giovanni_banks++
		if(!business.territory_id || business.territory_id in ids)
			Fail("Every mapped business must have a unique ID: [business.territory_id]")
		ids += business.territory_id
		if(!istype(get_turf(business), /turf/open/floor))
			Fail("[business.territory_id] must be on a dry floor.")
		for(var/atom/movable/obstacle in get_turf(business))
			if(obstacle.density && !ismob(obstacle))
				Fail("[business.territory_id] overlaps dense [obstacle.type].")
		for(var/obj/structure/city_business/other as anything in GLOB.city_businesses)
			if(other != business && other.z == business.z && get_dist(other, business) < 2)
				Fail("[business.territory_id] has an overlapping 48px mark: [other.territory_id].")
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
	if((SSmapping.current_map.map_name in list("Westfield Mall", "San Fangcisco", "Oakland")) && giovanni_banks != 1)
		Fail("Each supported city map must contain exactly one mapped Giovanni Bank initially protected by Giovanni.")

#endif
