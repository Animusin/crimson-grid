#if defined(UNIT_TESTS) || defined(SPACEMAN_DMM)
/obj/structure/city_business/unit_test/robbery
	var/test_successes = 1
	var/test_action
	var/action_menus = 0

/obj/structure/city_business/unit_test/robbery/roll_business(mob/living/user)
	return test_successes

/obj/structure/city_business/unit_test/robbery/robbery_duration(successes)
	return 2

/obj/structure/city_business/unit_test/robbery/choose_business_action(mob/living/user, list/choices)
	action_menus++
	return test_action

/datum/unit_test/city_business/proc/till_fixture()
	var/obj/structure/city_business/unit_test/robbery/business = allocate(/obj/structure/city_business/unit_test/robbery)
	var/mob/living/carbon/human/npc/shop/clerk = allocate(/mob/living/carbon/human/npc/shop)
	business.clerk_home = get_turf(clerk)
	business.bind_clerk(clerk)
	business.collection_started = TRUE
	business.next_collection = world.time + 10 MINUTES
	return business

/datum/unit_test/city_business/proc/robber_fixture()
	var/mob/living/carbon/human/business_test/user = allocate(/mob/living/carbon/human/business_test)
	user.test_faction = null
	var/datum/client_interface/client = allocate(/datum/client_interface)
	client.mob = user
	user.mock_client = client
	return user

/datum/unit_test/city_business/proc/cash_at(atom/location)
	var/amount = 0
	for(var/obj/item/stack/dollar/cash in get_turf(location))
		amount += cash.amount
	return amount

/datum/unit_test/city_business/till_income/Run()
	var/obj/structure/city_business/unit_test/robbery/business = till_fixture()
	var/mob/living/carbon/human/business_test/user = robber_fixture()
	var/obj/item/card/city_badge/badge = allocate(/obj/item/card/city_badge, user)
	// Three elapsed cycles are retained even when nobody visited the cashier.
	business.next_collection = world.time - 20 MINUTES
	business.accrue_income()
	if(business.register_cash != 120)
		Fail("Three missed 40-player income cycles must accumulate $120 in the till.")
	var/next_income = business.next_collection
	if(business.collect_income(user, FACTION_CAMARILLA) != 120 || business.register_cash || cash_at(user) != 120 || business.next_collection != next_income)
		Fail("Collection must atomically pay all stored cash without resetting the next income deadline.")
	business.collect_income(user, FACTION_CAMARILLA)
	if(cash_at(user) != 120)
		Fail("A second pending courier action must not spend the same till balance again.")
	business.test_population = 60
	business.next_collection = world.time
	business.accrue_income()
	if(business.register_cash != 60)
		Fail("Late arrivals must affect the new cycle without rerating already collected cycles.")
	business.test_successes = 0
	business.collect_income(user, FACTION_CAMARILLA, TRUE)
	if(business.register_cash || cash_at(user) != 120)
		Fail("A failed demand must consume its reserved cash without spawning a payout.")
	// The actual cashier route works across its bound, reachable checkout.
	var/obj/structure/retail/coffee_shop/outlet = allocate(/obj/structure/retail/coffee_shop)
	outlet.territory = business
	business.outlets += outlet
	business.clerk.forceMove(get_step(get_step(get_step(get_turf(user), EAST), EAST), EAST))
	business.register_cash = 80
	business.test_action = "Collect"
	user.put_in_active_hand(badge)
	business.clerk.ranged_item_interaction(user, badge, list())
	if(business.action_menus != 1 || cash_at(user) != 200)
		Fail("Clicking the cashier with a badge across the correct counter must collect exactly once.")
	// Darkpack invokes this too after ranged item use; it must not open twice.
	business.clerk.RangedAttackOn(user, list())
	if(business.action_menus != 1)
		Fail("A ranged badge click must not open a second empty-hand business dialog.")
	if(business.can_negotiate(user, outlet) || business.can_negotiate(user, business))
		Fail("Neither a till nor an alley mark may be a business action target.")

/datum/unit_test/city_business/till_robbery/Run()
	var/obj/structure/city_business/unit_test/robbery/business = till_fixture()
	var/obj/structure/city_business/plain = allocate(/obj/structure/city_business/unit_test)
	var/list/durations = list(60, 50, 40, 30, 20)
	var/list/percentages = list(25, 40, 60, 80, 100)
	for(var/successes in 1 to 5)
		if(plain.robbery_duration(successes) != durations[successes] SECONDS || plain.robbery_percentage(successes) != percentages[successes])
			Fail("The robbery duration/percentage table must match the accepted 1–5 success tiers.")
	if(plain.robbery_percentage(9) != 100 || plain.robbery_duration(9) != 20 SECONDS)
		Fail("Five or more successes must cap at 20 seconds and 100%.")
	var/mob/living/carbon/human/business_test/user = robber_fixture()
	business.register_cash = 100
	if(!business.start_robbery(user) || business.register_cash != 75 || cash_at(user) != 25 || business.robbery)
		Fail("An unaffiliated player must complete the real timed robbery and steal 25% once.")
	var/retry_deadline = business.robbery_retry_at
	if(retry_deadline != world.time + 10 MINUTES)
		Fail("A successful robbery must leave ten minutes of cooldown after completion.")
	if(business.start_robbery(user) || business.register_cash != 75 || cash_at(user) != 25 || business.robbery_retry_at != retry_deadline)
		Fail("A repeated robbery must not withdraw money or move the existing retry deadline.")
	var/mob/living/carbon/human/business_test/other = robber_fixture()
	if(business.start_robbery(other) || cash_at(other) != 25)
		Fail("Changing robbers must not bypass the store-wide cooldown.")
	business.robbery_retry_at = 0
	business.test_successes = 0
	user.test_faction = business.owner_faction
	if(business.start_robbery(user) || business.robbery_retry_at != world.time + 10 MINUTES || business.register_cash != 75)
		Fail("Even an owner-faction robber's zero-success attempt must reserve the cooldown but take no cash.")

/datum/unit_test/city_business/till_interruptions/Run()
	var/obj/structure/city_business/unit_test/robbery/business = till_fixture()
	var/mob/living/carbon/human/business_test/user = robber_fixture()
	business.register_cash = 100
	var/datum/city_robbery/attempt = allocate(/datum/city_robbery, business, user)
	business.robbery = attempt
	attempt.arm_alarm()
	if(!attempt.alarm_timer || attempt.alarm_at != attempt.started_at + 90 SECONDS)
		Fail("The committed threat must schedule an actual alarm timer exactly 90 seconds from its start.")
	var/mob/living/carbon/human/business_test/other = robber_fixture()
	if(business.start_robbery(other))
		Fail("A second robber must never enter an already occupied business attempt.")
	user.forceMove(get_step(get_turf(user), NORTH))
	if(attempt.settle(5) || business.register_cash != 100 || business.robbery || !attempt.alarm_armed)
		Fail("Movement must cancel settlement without taking money or erasing the delayed alarm.")
	user.forceMove(get_turf(business))
	var/datum/city_robbery/disabled = allocate(/datum/city_robbery, business, user)
	business.robbery = disabled
	ADD_TRAIT(user, TRAIT_HANDS_BLOCKED, TRAIT_SOURCE_UNIT_TESTS)
	if(disabled.settle(5) || business.register_cash != 100)
		Fail("An incapacitated robber must not settle a stored cash snapshot.")
	REMOVE_TRAIT(user, TRAIT_HANDS_BLOCKED, TRAIT_SOURCE_UNIT_TESTS)
	var/datum/city_robbery/contested = allocate(/datum/city_robbery, business, user)
	business.robbery = contested
	business.attack_faction = FACTION_ANARCHS
	if(contested.settle(5) || business.register_cash != 100)
		Fail("An announced contest must cancel robbery settlement.")
	business.attack_faction = null
	var/datum/city_robbery/death = allocate(/datum/city_robbery, business, user)
	business.robbery = death
	business.clerk.death()
	if(!death.finished || business.robbery || business.register_cash != 100 || !business.recover_at)
		Fail("Cashier death must cancel the active robbery, preserve its till, and start recovery.")

/datum/unit_test/city_business/till_alarm/Run()
	var/obj/structure/city_business/unit_test/robbery/business = till_fixture()
	var/mob/living/carbon/human/business_test/user = robber_fixture()
	var/mob/living/carbon/human/business_test/owner = robber_fixture()
	owner.test_faction = FACTION_CAMARILLA
	var/obj/item/smartphone/phone = allocate(/obj/item/smartphone, owner)
	phone.owner_weakref = WEAKREF(owner)
	var/datum/city_robbery/attempt = allocate(/datum/city_robbery, business, user)
	business.robbery = attempt
	attempt.arm_alarm()
	attempt.cancel("Test interruption")
	attempt.send_alarm()
	var/obj/item/smartphone/business_alarm/alarm_caller
	for(var/obj/item/smartphone/business_alarm/candidate in GLOB.phones_list)
		if(candidate.recipient_ref?.resolve() == phone)
			alarm_caller = candidate
	var/list/phone_state = phone.ui_data(owner)
	if(!alarm_caller || !phone_state["phone_ringing"] || !length(phone.phone_history_list) || !phone.get_conversation("5550199"))
		Fail("An interrupted attempt must still create a real incoming call, call history and durable transcript.")
		return
	var/obj/effect/abstract/shared_particle_holder/ringing_holder = locate() in phone.vis_contents
	if(!ringing_holder || !(ringing_holder.particle_flags & PARTICLE_ATTACH_MOB))
		Fail("A real ringing phone must attach its correctly keyed particle holder to the carrier.")
	var/caller_number = alarm_caller.sim_card.phone_number
	phone.accept_phone_call(owner)
	if(!alarm_caller.played || !phone.secure_frequency || phone.incoming_phone_number != caller_number)
		Fail("The alarm must be answerable through the actual two-phone secure connection.")
	alarm_caller.play_recording()
	var/frequency = phone.secure_frequency
	var/obj/item/smartphone/business_alarm/busy = allocate(/obj/item/smartphone/business_alarm)
	if(busy.place_alarm(phone, "A second alarm") || phone.secure_frequency != frequency || phone.incoming_phone_number != caller_number)
		Fail("A busy owner phone must retain its current call instead of being hijacked by another alarm.")
	alarm_caller.close_alarm()
	if(phone.incoming_phone_number || phone.secure_frequency || (frequency in SSphones.frequencies_in_use))
		Fail("Closing the automatic alarm must release the receiving phone and secure radio frequency.")
	if(ringing_holder in phone.vis_contents)
		Fail("Ending the call must remove the same custom-key ringing particle holder.")
#endif
