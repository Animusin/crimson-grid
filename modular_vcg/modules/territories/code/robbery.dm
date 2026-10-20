#define BUSINESS_ROBBERY_COOLDOWN (10 MINUTES)
#define BUSINESS_ROBBERY_ALARM_DELAY (90 SECONDS)

/mob/living/carbon/human/npc/RangedAttackOn(mob/attacker, list/modifiers)
	// Darkpack also calls RangedAttack after ranged item use. Only the empty
	// hand route belongs here, otherwise a badge can open two dialogs.
	var/mob/living/living_attacker = attacker
	if(territory_employer && istype(living_attacker) && !living_attacker.get_active_held_item() && !living_attacker.combat_mode && !LAZYACCESS(modifiers, RIGHT_CLICK))
		territory_employer.show_contract(living_attacker, null, src)
		return TRUE
	return ..()

/obj/structure/city_business/proc/robbery_duration(successes)
	return (70 - 10 * clamp(successes, 1, 5)) SECONDS

/obj/structure/city_business/proc/robbery_percentage(successes)
	var/list/percentages = list(25, 40, 60, 80, 100)
	return percentages[clamp(successes, 1, 5)]

/obj/structure/city_business/proc/can_rob(mob/living/user)
	return ishuman(user) && GET_CLIENT(user) && !attack_faction && can_negotiate(user, clerk) && !IS_UNCONSCIOUS(clerk)

/obj/structure/city_business/proc/robbery_difficulty(mob/living/user)
	var/difficulty = 8
	for(var/obj/item/weapon in user.held_items)
		if(istype(weapon, /obj/item/gun/ballistic) || istype(weapon, /obj/item/gun/energy))
			var/obj/item/gun/gun = weapon
			if(!(gun.gun_flags & (TOY_FIREARM_OVERLAY | NOT_A_REAL_GUN)) && gun.can_shoot())
				return 6
		if(weapon.force > 0 && (weapon.force >= 10 || weapon.sharpness != NONE))
			difficulty = 7
	return difficulty

/obj/structure/city_business/proc/start_robbery(mob/living/user)
	if(!can_rob(user) || robbery || world.time < robbery_retry_at)
		to_chat(user, span_warning("This cashier cannot be robbed now."))
		return FALSE
	accrue_income()
	if(register_cash <= 0)
		to_chat(user, span_warning("The till is empty."))
		return FALSE
	// One shared retry clock is consumed before the roll, even for a failure.
	robbery_retry_at = world.time + BUSINESS_ROBBERY_COOLDOWN
	var/datum/city_robbery/attempt = new(src, user)
	robbery = attempt
	var/successes = roll_business(user, attempt.threat_difficulty)
	if(successes <= 0)
		attempt.cancel("The cashier refused your threat.")
		if(successes < 0)
			attempt.botched = TRUE
			SEND_SIGNAL(SSdcs, COMSIG_GLOB_REPORT_CRIME, CRIME_BUSINESS_ROBBERY, get_turf(clerk) || get_turf(src))
			attempt.send_alarm()
		else
			qdel(attempt)
		return FALSE
	// A committed threat always reports after 90 seconds, including an interrupted
	// attempt. Walking away or killing the cashier cannot erase the alarm.
	attempt.arm_alarm()
	return attempt.perform_attempt(successes)

/datum/city_robbery
	var/datum/weakref/business_ref
	var/datum/weakref/robber_ref
	var/datum/weakref/clerk_ref
	var/turf/start_turf
	var/started_at
	var/threat_difficulty
	var/botched = FALSE
	var/owner_at_start
	var/business_label
	var/location_label
	var/finished = FALSE
	var/completed = FALSE
	var/stolen_amount = 0
	var/alarm_armed = FALSE
	var/alarm_sent = FALSE
	var/alarm_at
	var/alarm_timer

/datum/city_robbery/New(obj/structure/city_business/business, mob/living/user)
	. = ..()
	business_ref = WEAKREF(business)
	robber_ref = WEAKREF(user)
	clerk_ref = WEAKREF(business.clerk)
	start_turf = get_turf(user)
	started_at = world.time
	threat_difficulty = business.robbery_difficulty(user)
	owner_at_start = business.owner_faction
	business_label = business.business_name
	location_label = "[get_area_name(business.clerk)] ([business.clerk.x], [business.clerk.y], level [business.clerk.z])"

/datum/city_robbery/proc/valid()
	var/obj/structure/city_business/business = business_ref.resolve()
	var/mob/living/user = robber_ref.resolve()
	return !finished && business && user && business.robbery == src \
		&& business.clerk == clerk_ref.resolve() && get_turf(user) == start_turf \
		&& !IS_UNCONSCIOUS(user) && user.stat < SOFT_CRIT && !user.IsIncapacitated() \
		&& business.robbery_difficulty(user) <= threat_difficulty \
		&& business.can_rob(user)

/datum/city_robbery/proc/arm_alarm()
	alarm_armed = TRUE
	alarm_at = started_at + BUSINESS_ROBBERY_ALARM_DELAY
	alarm_timer = addtimer(CALLBACK(src, PROC_REF(send_alarm)), max(0, alarm_at - world.time), TIMER_STOPPABLE | TIMER_DELETE_ME)

/datum/city_robbery/proc/perform_attempt(successes)
	var/obj/structure/city_business/business = business_ref.resolve()
	var/mob/living/user = robber_ref.resolve()
	if(!valid())
		cancel("The robbery was interrupted.")
		return FALSE
	var/duration = business.robbery_duration(successes)
	to_chat(user, span_warning("Keep threatening the cashier for [duration / (1 SECONDS)] seconds to take [business.robbery_percentage(successes)]% of the till."))
	if(!do_after(user, duration, business.clerk, interaction_key = REF(business), extra_checks = CALLBACK(src, PROC_REF(valid))))
		cancel("The robbery was interrupted.")
		return FALSE
	return settle(successes)

/// No yielding between reading the actual cash and debiting it. New income and
/// another courier cannot spend the same snapshot, even across two pending UIs.
/datum/city_robbery/proc/settle(successes)
	if(!valid())
		cancel("The robbery was interrupted.")
		return FALSE
	var/obj/structure/city_business/business = business_ref.resolve()
	var/mob/living/user = robber_ref.resolve()
	business.accrue_income()
	stolen_amount = FLOOR(business.register_cash * business.robbery_percentage(successes) / 100, 1)
	business.register_cash -= stolen_amount
	finished = TRUE
	completed = TRUE
	business.robbery_retry_at = max(business.robbery_retry_at, world.time + BUSINESS_ROBBERY_COOLDOWN)
	business.robbery = null
	business.pay_cash(user, stolen_amount)
	to_chat(user, span_notice("You took $[stolen_amount] from [business_label]."))
	log_game("[key_name(user)] robbed [business.territory_id] of $[stolen_amount] after [successes] successes.")
	if(alarm_sent)
		qdel(src)
	return TRUE

/datum/city_robbery/proc/cancel(reason)
	if(finished)
		return
	finished = TRUE
	var/obj/structure/city_business/business = business_ref.resolve()
	if(business?.robbery == src)
		business.robbery = null
		business.robbery_retry_at = max(business.robbery_retry_at, world.time + BUSINESS_ROBBERY_COOLDOWN)
	var/mob/living/user = robber_ref.resolve()
	if(user)
		to_chat(user, span_warning(reason))
	if(alarm_sent)
		qdel(src)

/datum/city_robbery/proc/send_alarm()
	if(alarm_sent)
		return
	alarm_sent = TRUE
	if(alarm_timer)
		deltimer(alarm_timer)
		alarm_timer = null
	var/outcome = botched ? "the cashier raised an alarm after a botched robbery attempt" : (completed ? "the cashier was robbed of $[stolen_amount]" : (finished ? "a robbery was attempted and interrupted" : "the cashier is being threatened by a robber"))
	var/message = "[business_label]: [outcome]. Cashier: [location_label]."
	for(var/obj/item/smartphone/phone as anything in GLOB.phones_list.Copy())
		var/mob/living/phone_owner = phone.owner_weakref?.resolve()
		if(!phone.sim_card || !istype(phone_owner) || phone_owner.city_faction() != owner_at_start)
			continue
		// A durable transcript also covers busy phones and a missed ten-second ring.
		var/datum/phone_conversation/conversation = phone.get_conversation("5550199")
		if(!conversation)
			conversation = new("City Protection", "5550199")
			phone.conversations += conversation
		conversation.add_message(message, FALSE)
		phone.after_text_received("City Protection", message)
		var/obj/item/smartphone/business_alarm/alarm_caller = new(get_turf(phone))
		alarm_caller.place_alarm(phone, message)
	if(finished)
		qdel(src)

/// A real, short-lived caller with a SIM, normal ringing/history, and normal
/// accept/decline handling. A fabricated incoming number cannot be answered.
/obj/item/smartphone/business_alarm
	name = "City Protection"
	invisibility = INVISIBILITY_ABSTRACT
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	anchored = TRUE
	var/datum/weakref/recipient_ref
	var/datum/phonecontact/alarm_contact
	var/recording
	var/played = FALSE

/obj/item/smartphone/business_alarm/proc/place_alarm(obj/item/smartphone/recipient, message)
	recipient_ref = WEAKREF(recipient)
	recording = message
	alarm_contact = new(name, sim_card.phone_number)
	recipient.contacts += alarm_contact
	var/mob/living/phone_owner = recipient.owner_weakref?.resolve()
	if(!start_phone_call(phone_owner, recipient.sim_card.phone_number))
		qdel(src)
		return FALSE
	addtimer(CALLBACK(src, PROC_REF(close_alarm)), TIME_TO_RING + 2 SECONDS)
	return TRUE

/obj/item/smartphone/business_alarm/process(seconds_per_tick)
	// The recipient uses the normal ringtone. An invisible automatic caller
	// should not play the outbound paging tone into the surrounding room.
	return

/obj/item/smartphone/business_alarm/set_phone_state(new_state)
	. = ..()
	if(new_state == PHONE_IN_CALL && !played)
		played = TRUE
		// Never relay ambient speech from the automatic caller's location.
		phone_radio.set_broadcasting(FALSE)
		phone_radio.set_listening(FALSE)
		addtimer(CALLBACK(src, PROC_REF(play_recording)), 1)

/obj/item/smartphone/business_alarm/proc/play_recording()
	var/obj/item/smartphone/recipient = recipient_ref?.resolve()
	if(recipient?.incoming_phone_number != sim_card?.phone_number)
		return
	var/mob/living/phone_owner = recipient.owner_weakref?.resolve()
	if(phone_owner)
		to_chat(phone_owner, span_notice("Phone call — City Protection: [recording]"))
	addtimer(CALLBACK(src, PROC_REF(close_alarm)), 2 SECONDS)

/obj/item/smartphone/business_alarm/proc/close_alarm()
	var/obj/item/smartphone/recipient = recipient_ref?.resolve()
	if(recipient?.incoming_phone_number == sim_card?.phone_number)
		if(secure_frequency)
			end_phone_call()
		else
			hang_up_phone_call(recipient.sim_card.phone_number)
	qdel(src)

/obj/item/smartphone/business_alarm/Destroy(force)
	STOP_PROCESSING(SSprocessing, src)
	// The other phone can be destroyed mid-call; the base termination returns
	// early then, so release this automatic call's frequency ourselves.
	if(secure_frequency)
		SSphones.free_secure_frequency(secure_frequency)
		secure_frequency = null
	var/obj/item/smartphone/recipient = recipient_ref?.resolve()
	if(recipient)
		recipient.contacts -= alarm_contact
	QDEL_NULL(alarm_contact)
	return ..()

#undef BUSINESS_ROBBERY_COOLDOWN
#undef BUSINESS_ROBBERY_ALARM_DELAY
