#if defined(UNIT_TESTS) || defined(SPACEMAN_DMM)
/datum/unit_test/taxi
	abstract_type = /datum/unit_test/taxi
#ifdef TAXI_TESTS
	test_flags = UNIT_TEST_FOCUS
#endif

/datum/unit_test/taxi/proc/player(account, is_driver = FALSE)
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent/taxi_test)
	// The displacement fixture crosses empty unit-test space; breathing is unrelated.
	ADD_TRAIT(human, TRAIT_NOBREATH, TRAIT_SOURCE_UNIT_TESTS)
	var/datum/client_interface/taxi_test/client = allocate(/datum/client_interface/taxi_test, account)
	human.mock_client = client
	client.mob = human
	human.mind_initialize()
	human.mind.key = client.key
	if(is_driver)
		human.mind.assigned_role = allocate(/datum/job/vampire/taxi)
	return human

/datum/client_interface/taxi_test/proc/is_afk(duration)
	return FALSE

// Hear() supports mock clients, but show_message() requires a real connection.
// Simulate successful delivery to our connected, hearing test participants.
/mob/living/carbon/human/consistent/taxi_test/show_message(msg, type, alt_msg, alt_type, avoid_highlighting = FALSE)
	if(mock_client)
		return TRUE
	return ..()

/datum/unit_test/taxi/proc/conversation(mob/living/driver, mob/living/passenger)
	// The live-speech hook is exercised separately below. These messages represent
	// already accepted, non-forced say logs, not radio-only or emote output.
	SEND_SIGNAL(driver, "taxi_rider_spoke", "Where would you like to go?")
	SEND_SIGNAL(passenger, "taxi_rider_spoke", "Please take me to the city shops.")
	SEND_SIGNAL(driver, "taxi_rider_spoke", "Of course, enjoy the journey.")
	SEND_SIGNAL(passenger, "taxi_rider_spoke", "Thank you for the pleasant conversation.")

/datum/unit_test/taxi/journeys/Run()
	var/datum/player_quality_store/old_store = SSplayer_quality.store
	var/path = "data/taxi-journeys-[world.realtime]-[rand(1, 1000000)].json"
	SSplayer_quality.store = new(path)
	exercise_journeys()
	sleep(2)
	qdel(SSplayer_quality.store)
	SSplayer_quality.store = old_store
	fdel(path)
	fdel("[path].savebac")

/datum/unit_test/taxi/journeys/proc/exercise_journeys()
	var/obj/darkpack_car/taxi/car = allocate(/obj/darkpack_car/taxi, run_loc_floor_bottom_left)
	var/mob/living/driver = player("taxidriver", TRUE)
	var/mob/living/passenger = player("taxipassenger")
	var/turf/pickup = get_turf(car)
	var/turf/destination = locate(pickup.x + 12, pickup.y, pickup.z)
	car.driver_enter(driver)
	car.passenger_enter(passenger)
	var/datum/taxi_journey/journey = car.taxi_journeys[passenger]
	if(!journey)
		Fail("Real taxi entry must create a journey: driver=[car.is_taxi_driver(driver)] passenger=[car.is_taxi_player(passenger)] role=[driver.mind.assigned_role?.title] accounts=[taxi_player_account(driver)]/[taxi_player_account(passenger)] loc=[driver.loc == car]/[passenger.loc == car].")
		return
	conversation(driver, passenger)
	car.forceMove(destination)
	car.empty_occupent(passenger)
	if(passenger.has_status_effect(/datum/status_effect/taxi_conversation))
		Fail("A short ride cannot provide a bonus, even with dialogue and travel.")

	car.forceMove(pickup)
	car.passenger_enter(passenger)
	journey = car.taxi_journeys[passenger]
	journey.started_at = world.time - 2 MINUTES
	conversation(driver, passenger)
	car.empty_occupent(passenger)
	if(passenger.has_status_effect(/datum/status_effect/taxi_conversation))
		Fail("Sitting in a stationary taxi must not qualify as a journey.")

	car.passenger_enter(passenger)
	journey = car.taxi_journeys[passenger]
	journey.started_at = world.time - 2 MINUTES
	SEND_SIGNAL(driver, "taxi_rider_spoke", "Hello")
	SEND_SIGNAL(driver, "taxi_rider_spoke", "HELLO")
	SEND_SIGNAL(passenger, "taxi_rider_spoke", "Good evening")
	SEND_SIGNAL(passenger, "taxi_rider_spoke", "Thank you")
	car.forceMove(destination)
	car.empty_occupent(passenger)
	if(passenger.has_status_effect(/datum/status_effect/taxi_conversation))
		Fail("Two copies of one normalized line cannot meet the dialogue requirement.")

	car.forceMove(pickup)
	car.passenger_enter(passenger)
	journey = car.taxi_journeys[passenger]
	journey.started_at = world.time - 2 MINUTES
	conversation(driver, passenger)
	car.empty_occupent(driver)
	if(length(car.taxi_journeys))
		Fail("Losing the driver must cancel every pending journey.")
	car.driver_enter(driver)
	journey = car.taxi_journeys[passenger]
	if(!journey || length(journey.driver_lines) || length(journey.passenger_lines) || journey.started_at < world.time - 1)
		Fail("A replacement/re-entered driver must start fresh time and dialogue.")
	journey.started_at = world.time - 2 MINUTES
	conversation(driver, passenger)
	car.forceMove(destination)
	car.empty_occupent(passenger)
	var/datum/status_effect/taxi_conversation/bonus = passenger.has_status_effect(/datum/status_effect/taxi_conversation)
	if(!bonus || bonus.remaining_checks != 3 || bonus.duration != 20 MINUTES)
		Fail("A qualifying journey must grant three checks for twenty minutes on exit.")
		return
	var/list/record = SSplayer_quality.store.read("taxidriver")
	if(abs(record["rcp"] - CONFIG_GET(number/taxi_rcp_reward)) > 0.001)
		Fail("An actual qualified journey must grant its driver persistent RCP.")
	bonus.remaining_checks = 2
	bonus.duration = 5 MINUTES
	car.forceMove(pickup)
	car.passenger_enter(passenger)
	journey = car.taxi_journeys[passenger]
	journey.started_at = world.time - 2 MINUTES
	conversation(driver, passenger)
	car.forceMove(destination)
	car.empty_occupent(passenger)
	if(passenger.has_status_effect(/datum/status_effect/taxi_conversation) != bonus || bonus.remaining_checks != 2 || bonus.duration != 5 MINUTES)
		Fail("Another journey must not stack, refill or refresh an existing bonus.")
	record = SSplayer_quality.store.read("taxidriver")
	if(abs(record["rcp"] - CONFIG_GET(number/taxi_rcp_reward)) > 0.001)
		Fail("Delivering the same actual passenger again cannot grant extra RCP.")

/datum/unit_test/taxi/speech/Run()
	var/obj/darkpack_car/taxi/car = allocate(/obj/darkpack_car/taxi, run_loc_floor_bottom_left)
	var/mob/living/driver = player("taxitalker", TRUE)
	var/mob/living/passenger = player("taxilistener")
	car.driver_enter(driver)
	car.passenger_enter(passenger)
	var/datum/taxi_journey/journey = car.taxi_journeys[passenger]
	if(!journey)
		Fail("Speech fixture must create a real taxi journey first.")
		return
	driver.say("A pleasant evening for a drive.")
	passenger.say("Yes, please take me across town.")
	if(length(journey.driver_lines) != 1 || length(journey.passenger_lines) != 1)
		Fail("Actual local say output inside the taxi must reach the journey tracker.")
	driver.say("A forced cry must not count.", forced = "taxi test")
	if(length(journey.driver_lines) != 1)
		Fail("Forced speech cannot qualify taxi dialogue.")
	car.empty_occupent(passenger)
	passenger.say("Speech after leaving must not count.")
	if(length(car.taxi_journeys))
		Fail("Exiting must remove the listener and journey immediately.")

/datum/storyteller_roll/taxi_test
	roll_output_type = NONE
	var/last_dice

/datum/storyteller_roll/taxi_test/using_dice(mob/living/roller, atom/target)
	return 3

/datum/storyteller_roll/taxi_test/roll_dice(dice_amount, auto_success_amount)
	last_dice = dice_amount
	return list(6)

/datum/unit_test/taxi/checks/Run()
	var/mob/living/human = player("taxiroller")
	var/datum/status_effect/taxi_conversation/bonus = human.apply_status_effect(/datum/status_effect/taxi_conversation)
	if(!bonus.linked_alert || bonus.linked_alert.icon_state != "driver" || !icon_exists(bonus.linked_alert.icon, "driver") || !findtext(bonus.linked_alert.maptext, "20m"))
		Fail("The actual HUD alert must show the existing steering-wheel icon and readable countdown.")
	var/datum/storyteller_roll/taxi_test/roll = allocate(/datum/storyteller_roll/taxi_test)
	roll.reroll_cooldown = 1 MINUTES
	roll.st_roll(human)
	if(roll.last_dice != 4 || bonus.remaining_checks != 2)
		Fail("The first real check must add exactly one die and spend one charge.")
	if(!findtext(bonus.linked_alert.maptext, "×2"))
		Fail("The HUD charge counter must update after a check.")
	roll.st_roll(human)
	if(bonus.remaining_checks != 2)
		Fail("A cached roll must not spend another charge.")
	roll.roll_use_last_result = FALSE
	roll.st_roll(human)
	if(bonus.remaining_checks != 2)
		Fail("A cooldown-blocked check must not spend another charge.")
	roll.reroll_cooldown = null
	for(var/i in 1 to 2)
		roll.st_roll(human)
		if(roll.last_dice != 4)
			Fail("Both remaining real checks must receive exactly one extra die.")
	if(human.has_status_effect(/datum/status_effect/taxi_conversation))
		Fail("The third real check must remove the bonus.")
	roll.st_roll(human)
	if(roll.last_dice != 3)
		Fail("The fourth real check must receive no taxi bonus.")
	bonus = human.apply_status_effect(/datum/status_effect/taxi_conversation)
	bonus.duration = 0
	roll.st_roll(human)
	if(roll.last_dice != 3)
		Fail("An expired effect cannot add dice before its next subsystem cleanup.")

/datum/unit_test/taxi/kiss/Run()
	var/mob/living/worker = player("clubworker")
	worker.mind.assigned_role = allocate(/datum/job/vampire/club_worker)
	var/mob/living/guest = player("clubguest")
	worker.forceMove(run_loc_floor_bottom_left)
	guest.forceMove(get_step(worker, NORTH))
	worker.say("Welcome to the club.")
	guest.say("Thank you, it is a lovely evening.")
	worker.say("I hope you enjoy your visit.")
	guest.say("I am glad I came here.")
	var/datum/component/club_conversation/conversation = worker.GetComponent(/datum/component/club_conversation)
	var/datum/club_conversation_pair/pair = conversation?.guests[guest]
	if(!pair || length(pair.worker_lines) != 2 || length(pair.guest_lines) != 2)
		Fail("Accepted club dialogue: component=[!!conversation] pair=[!!pair] worker=[length(pair?.worker_lines)] guest=[length(pair?.guest_lines)].")
		return
	var/obj/projectile/kiss/kiss = allocate(/obj/projectile/kiss, get_turf(worker))
	kiss.firer = worker
	kiss.harmless_on_hit(guest)
	if(guest.has_status_effect(/datum/status_effect/club_kiss))
		Fail("A kiss before two minutes cannot grant a bonus.")
	pair.started_at = world.time - 2 MINUTES
	kiss.harmless_on_hit(guest)
	var/datum/status_effect/club_kiss/bonus = guest.has_status_effect(/datum/status_effect/club_kiss)
	if(!bonus || bonus.remaining_checks != 3 || bonus.duration != 20 MINUTES)
		Fail("A qualified ordinary kiss must grant three checks for twenty minutes.")
		return
	if(!bonus.linked_alert || bonus.linked_alert.icon_state != "heart" || !icon_exists(bonus.linked_alert.icon, "heart"))
		Fail("The kiss effect must have a native heart status icon.")
	var/datum/status_effect/taxi_conversation/taxi = guest.apply_status_effect(/datum/status_effect/taxi_conversation)
	var/datum/storyteller_roll/taxi_test/roll = allocate(/datum/storyteller_roll/taxi_test)
	roll.st_roll(guest)
	if(roll.last_dice != 5 || bonus.remaining_checks != 2 || taxi.remaining_checks != 2)
		Fail("Taxi and kiss must add two dice together and each spend one charge.")
	// Another fully qualified conversation must not refresh an existing kiss.
	conversation.record_line(guest, worker, "Another welcome")
	conversation.record_line(guest, worker, "Another pleasant evening")
	conversation.record_line(guest, guest, "Another reply")
	conversation.record_line(guest, guest, "Another thank you")
	pair = conversation.guests[guest]
	pair.started_at = world.time - 2 MINUTES
	bonus.duration = 5 MINUTES
	kiss.harmless_on_hit(guest)
	if(bonus.remaining_checks != 2 || bonus.duration != 5 MINUTES)
		Fail("Repeated kisses must not stack, refill or refresh the same effect.")
	guest.forceMove(locate(worker.x + 5, worker.y, worker.z))
	if(length(conversation.guests))
		Fail("Leaving the conversation radius must discard time and dialogue.")
	// Expiration/removal of one service effect must not unsubscribe the other.
	taxi.remaining_checks = 1
	roll.st_roll(guest)
	if(roll.last_dice != 5 || guest.has_status_effect(/datum/status_effect/taxi_conversation) || bonus.remaining_checks != 1)
		Fail("Exhausting the taxi effect must leave the kiss effect and its listener intact.")
	roll.st_roll(guest)
	if(roll.last_dice != 4 || guest.has_status_effect(/datum/status_effect/club_kiss))
		Fail("The independent last kiss charge must still work after taxi removal.")

/datum/unit_test/taxi/club_roles/Run()
	var/mob/living/worker = player("clubroles")
	var/mob/living/guest = player("clubrolesguest")
	var/datum/job/vampire/club_worker/job = allocate(/datum/job/vampire/club_worker)
	for(var/title in job.alt_titles)
		worker.mind.set_assigned_role_with_greeting(job, null, title)
		if(worker.mind.assigned_alt_title != title || club_kiss_provider(worker) != (title != "Club Bouncer"))
			Fail("Spawned club title [title] has incorrect kiss eligibility.")
	worker.mind.set_assigned_role_with_greeting(job, null, "Club Bouncer")
	worker.forceMove(run_loc_floor_bottom_left)
	guest.forceMove(get_step(worker, NORTH))
	worker.say("Good evening, please keep the entrance clear.")
	if(worker.GetComponent(/datum/component/club_conversation))
		Fail("A spawned Club Bouncer cannot begin a buff conversation.")
	worker.mind.set_assigned_role_with_greeting(job, null, "Stripper")
	worker.say("Welcome to the club.")
	var/datum/component/club_conversation/conversation = worker.GetComponent(/datum/component/club_conversation)
	if(!conversation?.guests[guest])
		Fail("A spawned Stripper must be able to begin a conversation.")
		return
	// Loss of eligibility must invalidate an existing conversation at delivery too.
	var/datum/club_conversation_pair/pair = conversation.guests[guest]
	pair.started_at = world.time - 2 MINUTES
	conversation.record_line(guest, worker, "Enjoy your visit")
	conversation.record_line(guest, guest, "Thank you")
	conversation.record_line(guest, guest, "It is a lovely evening")
	worker.mind.set_assigned_role_with_greeting(job, null, "Club Bouncer")
	SEND_SIGNAL(worker, "club_kiss_landed", guest)
	if(guest.has_status_effect(/datum/status_effect/club_kiss) || length(conversation.guests))
		Fail("A Club Bouncer cannot deliver a previously prepared kiss bonus.")
	worker.mind.set_assigned_role_with_greeting(job, null, "Stripper")
	conversation.record_line(guest, worker, "Let us talk again")
	guest.Unconscious(10 SECONDS)
	conversation.process(2)
	guest.SetUnconscious(0)
	if(length(conversation.guests))
		Fail("Idle conversations must reset when a participant loses consciousness.")

/datum/unit_test/taxi/rcp/Run()
	var/path = "data/taxi-unit-[world.realtime]-[rand(1, 1000000)].json"
	var/datum/player_quality_store/store = new(path)
	if(store.award_taxi_rcp("driver", "DRIVER", 0.1, 0.5, "one"))
		Fail("Normalized self-delivery must be rejected.")
	for(var/i in 1 to 7)
		store.award_taxi_rcp("Driver", "rider[i]", 0.1, 0.5, "one")
	var/list/record = store.read("driver")
	if(abs(record["rcp"] - 0.5) > 0.001)
		Fail("Different passengers must earn RCP only up to the round cap.")
	sleep(2)
	qdel(store)
	store = new(path)
	if(store.award_taxi_rcp("driver", "rider8", 0.1, 0.5, "one"))
		Fail("Reloading persistence must not reset the taxi cap.")
	store.award_rcp("driver", 1, "one")
	store.award_taxi_rcp("driver", "rider1", 0.1, 0.5, "two")
	if(store.award_taxi_rcp("driver", "RIDER1", 0.1, 0.5, "two"))
		Fail("Repeated delivery of one passenger cannot earn another RCP grant.")
	record = store.read("driver")
	if(abs(record["rcp"] - 1.6) > 0.001)
		Fail("Taxi rewards must coexist with ordinary participation and reset next round.")
	sleep(2)
	qdel(store)
	fdel(path)
	fdel("[path].savebac")
#endif
