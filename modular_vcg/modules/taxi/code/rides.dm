/// Use a player mind, never an NPC's assigned role, to identify the account.
/proc/taxi_player_account(mob/living/player)
	return istype(player) ? ckey(player.mind?.key) : null

/// One continuous driver/passenger pair. Speech before this passenger joined
/// cannot qualify their journey; changing driver cancels all current journeys.
/datum/taxi_journey
	var/mob/living/driver
	var/mob/living/passenger
	var/driver_account
	var/passenger_account
	var/started_at
	var/turf/origin
	var/list/driver_lines = list()
	var/list/passenger_lines = list()

/datum/taxi_journey/New(obj/darkpack_car/taxi/car, mob/living/rider)
	driver = car.driver
	passenger = rider
	driver_account = taxi_player_account(driver)
	passenger_account = taxi_player_account(rider)
	started_at = world.time
	origin = get_turf(car)

/datum/taxi_journey/Destroy()
	driver = null
	passenger = null
	origin = null
	return ..()

/datum/taxi_journey/proc/record_speech(mob/living/speaker, message)
	if(!istext(message))
		return
	var/normalized = LOWER_TEXT(trim(html_decode(strip_html(message))))
	if(!length_char(normalized))
		return
	var/list/lines = speaker == driver ? driver_lines : passenger_lines
	if(length(lines) < 2)
		lines[md5(normalized)] = TRUE

/datum/taxi_journey/proc/qualifies(obj/darkpack_car/taxi/car)
	var/turf/destination = get_turf(car)
	return world.time - started_at >= 2 MINUTES \
		&& origin && destination && origin.z == destination.z && get_dist(origin, destination) >= 10 \
		&& length(driver_lines) >= 2 && length(passenger_lines) >= 2 \
		&& driver == car.driver && driver.loc == car \
		&& car.is_taxi_driver(driver) && car.is_taxi_player(passenger) \
		&& driver_account == taxi_player_account(driver) && passenger_account == taxi_player_account(passenger)

/obj/darkpack_car/taxi
	var/list/taxi_journeys = list()
	var/mob/living/journey_driver

/obj/darkpack_car/taxi/Initialize(mapload)
	. = ..()
	RegisterSignal(src, COMSIG_ATOM_ENTERED, PROC_REF(on_taxi_entered))
	RegisterSignal(src, COMSIG_ATOM_EXITED, PROC_REF(on_taxi_exited))

/obj/darkpack_car/taxi/Destroy()
	cancel_taxi_journeys()
	return ..()

/obj/darkpack_car/taxi/proc/is_taxi_player(mob/living/player)
	if(!istype(player))
		return FALSE
	var/account = taxi_player_account(player)
	var/client/player_client = GET_CLIENT(player)
	return account && player_client && player_client.ckey == account \
		&& player.stat < SOFT_CRIT && !IS_UNCONSCIOUS(player) && !player_client.is_afk()

/obj/darkpack_car/taxi/proc/is_taxi_driver(mob/living/player)
	return is_taxi_player(player) && player.mind.assigned_role?.title == JOB_TAXI_DRIVER

/obj/darkpack_car/taxi/proc/cancel_taxi_journeys()
	if(journey_driver)
		UnregisterSignal(journey_driver, "taxi_rider_spoke")
	journey_driver = null
	for(var/mob/living/rider as anything in taxi_journeys)
		UnregisterSignal(rider, "taxi_rider_spoke")
		qdel(taxi_journeys[rider])
	taxi_journeys.Cut()

/obj/darkpack_car/taxi/proc/on_taxi_entered(datum/source, atom/movable/arrived)
	SIGNAL_HANDLER
	if(journey_driver != driver)
		cancel_taxi_journeys()
	if(!driver || driver.loc != src || !is_taxi_driver(driver))
		return
	if(!journey_driver)
		journey_driver = driver
		RegisterSignal(driver, "taxi_rider_spoke", PROC_REF(on_taxi_speech))
	for(var/mob/living/rider as anything in passengers)
		if(rider.loc != src || taxi_journeys[rider] || !is_taxi_player(rider) || taxi_player_account(rider) == taxi_player_account(driver))
			continue
		taxi_journeys[rider] = new /datum/taxi_journey(src, rider)
		RegisterSignal(rider, "taxi_rider_spoke", PROC_REF(on_taxi_speech))

/obj/darkpack_car/taxi/proc/on_taxi_speech(mob/living/speaker, message)
	SIGNAL_HANDLER
	if(speaker.loc != src || !is_taxi_player(speaker))
		return
	for(var/mob/living/rider as anything in taxi_journeys)
		var/datum/taxi_journey/journey = taxi_journeys[rider]
		if(rider.loc == src && journey.driver == driver && driver.loc == src && (speaker == driver || speaker == rider))
			journey.record_speech(speaker, message)

/obj/darkpack_car/taxi/proc/on_taxi_exited(datum/source, atom/movable/leaving)
	SIGNAL_HANDLER
	if(leaving == journey_driver)
		cancel_taxi_journeys()
		return
	var/datum/taxi_journey/journey = taxi_journeys[leaving]
	if(!journey)
		return
	taxi_journeys -= leaving
	UnregisterSignal(leaving, "taxi_rider_spoke")
	if(journey.qualifies(src))
		var/mob/living/rider = journey.passenger
		if(!rider.has_status_effect(/datum/status_effect/taxi_conversation))
			rider.apply_status_effect(/datum/status_effect/taxi_conversation)
			to_chat(rider, span_notice("The conversation on your journey leaves you refreshed: +1 die to your next three checks, for up to twenty minutes."))
		SEND_GLOBAL_SIGNAL("taxi_ride_completed", journey.driver, rider)
	qdel(journey)

/// The normal PRE_DICE signal is sent only after cooldown/cache checks, for all
/// real Storyteller checks, including combat. Exactly one additional die.
/datum/status_effect/taxi_conversation
	id = "taxi_conversation"
	duration = 20 MINUTES
	tick_interval = STATUS_EFFECT_NO_TICK
	status_type = STATUS_EFFECT_UNIQUE
	alert_type = /atom/movable/screen/alert/status_effect/taxi_conversation
	show_duration = TRUE
	processing_speed = STATUS_EFFECT_NORMAL_PROCESS
	var/remaining_checks = 3

/datum/status_effect/taxi_conversation/on_apply()
	RegisterSignal(owner, COMSIG_LIVING_PRE_DICE_ROLLED, PROC_REF(on_taxi_check))
	return TRUE

/datum/status_effect/taxi_conversation/proc/on_taxi_check(mob/living/roller, datum/storyteller_roll/roll, atom/target, atom/using_item, bonus, difficulty)
	SIGNAL_HANDLER
	if(duration <= 0 || remaining_checks <= 0)
		return
	*bonus += 1
	remaining_checks--
	if(linked_alert)
		linked_alert.desc = "[linked_alert.name] grants +1 die to your next [remaining_checks] checks."
	if(!remaining_checks)
		qdel(src)
	else
		update_shown_duration()

/// Ratwood-style readable countdown, using this build's native alert API.
/datum/status_effect/taxi_conversation/update_shown_duration()
	if(!linked_alert || !show_duration)
		return
	var/time_left = duration >= 1 MINUTES ? "[CEILING(duration / (1 MINUTES), 1)]m" : "[CEILING(duration / (1 SECONDS), 1)]s"
	linked_alert.maptext = MAPTEXT_TINY_UNICODE("<span style='text-align:center'>+1 ×[remaining_checks]<br>[time_left]</span>")

/datum/status_effect/taxi_conversation/on_remove()
	UnregisterSignal(owner, COMSIG_LIVING_PRE_DICE_ROLLED)

/atom/movable/screen/alert/status_effect/taxi_conversation
	name = "Taxi conversation"
	desc = "A good taxi conversation grants +1 die to your next three checks, for up to twenty minutes."
	icon = 'modular_darkpack/modules/cars/icons/car_actions.dmi'
	icon_state = "driver"
