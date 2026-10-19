/// Accepted local speech only. Club Worker includes the Stripper alternate title.
/proc/record_club_conversation(mob/living/speaker, message, list/heard)
	if(!club_active_player(speaker))
		return
	for(var/mob/living/worker in view(3, speaker))
		if(worker.mind?.assigned_role?.title != JOB_CLUB_WORKER || !club_active_player(worker))
			continue
		var/datum/component/club_conversation/conversation = worker.GetComponent(/datum/component/club_conversation)
		if(!conversation)
			conversation = worker.AddComponent(/datum/component/club_conversation)
		if(worker == speaker)
			for(var/mob/living/guest in heard)
				conversation.record_line(guest, speaker, message)
		else if(worker in heard)
			conversation.record_line(speaker, speaker, message)

/proc/club_active_player(mob/living/person)
	if(!istype(person) || QDELETED(person))
		return FALSE
	var/client/player_client = GET_CLIENT(person)
	return player_client && taxi_player_account(person) == player_client.ckey && person.stat < SOFT_CRIT && !IS_UNCONSCIOUS(person) && !player_client.is_afk()

/datum/club_conversation_pair
	var/started_at
	var/worker_account
	var/guest_account
	var/list/worker_lines = list()
	var/list/guest_lines = list()

/datum/component/club_conversation
	dupe_mode = COMPONENT_DUPE_UNIQUE
	var/list/guests = list()

/datum/component/club_conversation/Initialize()
	if(!isliving(parent))
		return COMPONENT_INCOMPATIBLE

/datum/component/club_conversation/RegisterWithParent()
	RegisterSignal(parent, COMSIG_MOVABLE_MOVED, PROC_REF(check_distance))
	RegisterSignal(parent, "club_kiss_landed", PROC_REF(on_kiss))

/datum/component/club_conversation/UnregisterFromParent()
	UnregisterSignal(parent, list(COMSIG_MOVABLE_MOVED, "club_kiss_landed"))
	for(var/mob/living/guest as anything in guests.Copy())
		forget_guest(guest)

/datum/component/club_conversation/proc/valid_pair(mob/living/guest)
	var/mob/living/worker = parent
	return club_active_player(worker) && club_active_player(guest) && worker != guest \
		&& worker.mind?.assigned_role?.title == JOB_CLUB_WORKER \
		&& taxi_player_account(worker) != taxi_player_account(guest) \
		&& isturf(worker.loc) && isturf(guest.loc) && (guest in view(3, worker))

/datum/component/club_conversation/proc/forget_guest(mob/living/guest)
	UnregisterSignal(guest, list(COMSIG_MOVABLE_MOVED, COMSIG_QDELETING))
	qdel(guests[guest])
	guests -= guest

/datum/component/club_conversation/proc/check_distance()
	SIGNAL_HANDLER
	for(var/mob/living/guest as anything in guests.Copy())
		var/datum/club_conversation_pair/pair = guests[guest]
		if(!valid_pair(guest) || pair.worker_account != taxi_player_account(parent) || pair.guest_account != taxi_player_account(guest))
			forget_guest(guest)

/datum/component/club_conversation/proc/guest_deleted(mob/living/guest)
	SIGNAL_HANDLER
	forget_guest(guest)

/datum/component/club_conversation/proc/record_line(mob/living/guest, mob/living/speaker, message)
	check_distance()
	if(!valid_pair(guest) || !istext(message))
		return
	var/normalized = LOWER_TEXT(trim(html_decode(strip_html(message))))
	if(!length_char(normalized))
		return
	var/datum/club_conversation_pair/pair = guests[guest]
	if(!pair)
		pair = new
		pair.started_at = world.time
		pair.worker_account = taxi_player_account(parent)
		pair.guest_account = taxi_player_account(guest)
		guests[guest] = pair
		RegisterSignal(guest, COMSIG_MOVABLE_MOVED, PROC_REF(check_distance))
		RegisterSignal(guest, COMSIG_QDELETING, PROC_REF(guest_deleted))
	var/list/lines = speaker == parent ? pair.worker_lines : pair.guest_lines
	if(length(lines) < 2)
		lines[md5(normalized)] = TRUE

/datum/component/club_conversation/proc/on_kiss(datum/source, mob/living/guest)
	SIGNAL_HANDLER
	check_distance()
	var/datum/club_conversation_pair/pair = guests[guest]
	if(!pair || !valid_pair(guest) || world.time - pair.started_at < 2 MINUTES || length(pair.worker_lines) < 2 || length(pair.guest_lines) < 2)
		return
	if(guest.has_status_effect(/datum/status_effect/club_kiss))
		return
	guest.apply_status_effect(/datum/status_effect/club_kiss)
	to_chat(guest, span_notice("A memorable kiss lifts your spirits: +1 die to your next three checks, for up to twenty minutes."))
	forget_guest(guest)

/// Different IDs permit one of each service bonus; each spends its own charges.
/datum/status_effect/club_kiss
	parent_type = /datum/status_effect/taxi_conversation
	id = "club_kiss"
	alert_type = /atom/movable/screen/alert/status_effect/club_kiss

/atom/movable/screen/alert/status_effect/club_kiss
	name = "Memorable kiss"
	desc = "A memorable kiss grants +1 die to your next three checks, for up to twenty minutes. Stacks with a taxi conversation."
	icon = 'icons/mob/simple/animal.dmi'
	icon_state = "heart"
