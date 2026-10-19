/// A clerk remembers the appearance and visible ID presented at the time of a
/// false challenge. Never resolve a mind, account or concealed real identity.
/datum/city_business_suspect
	var/claimed_faction
	var/visible_name
	var/id_name
	var/icon/appearance_snapshot
	var/reported_at

/datum/city_business_suspect/New(mob/living/carbon/human/suspect, faction, mob/living/witness)
	claimed_faction = faction
	reported_at = world.time
	visible_name = "Appearance concealed"
	id_name = "No visible ID"
	if(HAS_TRAIT(suspect, TRAIT_UNKNOWN_APPEARANCE) || HAS_TRAIT(suspect, TRAIT_INVISIBLE_MAN) || suspect.invisibility > witness.see_invisible)
		return ..()
	// The generic appearance label cannot fall back to a hidden ID's name.
	visible_name = suspect.get_generic_name(prefixed = TRUE, lowercase = TRUE)
	if(suspect.wear_id && !HAS_TRAIT(suspect.wear_id, TRAIT_EXAMINE_SKIP))
		id_name = suspect.get_id_name("No visible ID")
	appearance_snapshot = getFlatIcon(suspect, no_anim = TRUE)
	return ..()

/obj/structure/city_business
	var/list/suspect_reports = list()
	/// False alarms never reserve the real faction attack slot or its cooldown.
	var/false_alarm_ready_at = 0

/obj/structure/city_business/proc/false_challenge_roll(mob/living/user)
	var/datum/storyteller_roll/business/roll = new
	. = roll.st_roll(user, clerk)
	qdel(roll)

/obj/structure/city_business/proc/can_false_challenge(mob/living/user, faction)
	return ishuman(user) && (faction in list(FACTION_CAMARILLA, FACTION_ANARCHS, FACTION_SABBAT, "triads")) \
		&& faction != owner_faction && user.city_faction() != faction \
		&& user.has_city_badge(faction) && can_negotiate(user, clerk)

/obj/structure/city_business/proc/false_challenge(mob/living/user, faction)
	if(!can_false_challenge(user, faction) || world.time < false_alarm_ready_at)
		return FALSE
	// One store-wide false-alarm roll per ten minutes, including failures.
	false_alarm_ready_at = world.time + 10 MINUTES
	var/mob/living/carbon/human/npc/witness = clerk
	var/successes = false_challenge_roll(user)
	if(successes <= 0 || witness != clerk || !can_false_challenge(user, faction))
		return FALSE
	var/datum/city_business_suspect/report = new(user, faction, witness)
	suspect_reports += report
	if(length(suspect_reports) > 5)
		var/datum/city_business_suspect/oldest = suspect_reports[1]
		suspect_reports.Cut(1, 2)
		qdel(oldest)
	false_challenge_notice(faction, max(2, 7 - successes))
	to_chat(user, span_notice("The clerk acknowledges your challenge."))
	log_game("[key_name(user)] made a false [faction] protection challenge at [territory_id].")
	return TRUE

/obj/structure/city_business/proc/false_challenge_notice(faction, minutes_until_contest)
	var/message = "[business_name]: [city_faction_name(faction)] challenged [city_faction_name(owner_faction)]. Contest begins in [minutes_until_contest] minutes. Meet at the territory mark."
	message += " Mark: [get_area_name(src)] ([x], [y], level [z])."
	for(var/obj/item/smartphone/phone as anything in GLOB.phones_list)
		var/mob/living/phone_owner = phone.owner_weakref?.resolve()
		if(!istype(phone_owner) || !(phone_owner.city_faction() in list(owner_faction, faction)) || !phone.sim_card)
			continue
		var/datum/phone_conversation/conversation = phone.get_conversation("5550199")
		if(!conversation)
			conversation = new("City Protection", "5550199")
			phone.conversations += conversation
		conversation.add_message(message, FALSE)
		phone.after_text_received("City Protection", message)
		to_chat(phone_owner, span_notice("SMS — City Protection: [message]"))

/obj/structure/city_business/proc/get_suspect_reports(mob/living/user)
	if(user?.city_faction() != owner_faction || !can_negotiate(user, clerk))
		return null
	return suspect_reports.Copy()

/obj/structure/city_business/proc/report_suspects(mob/living/user)
	var/list/reports = get_suspect_reports(user)
	if(isnull(reports))
		return FALSE
	if(!length(reports))
		to_chat(user, span_notice("The clerk has no suspicious challenges to describe."))
	for(var/datum/city_business_suspect/report as anything in reports)
		var/portrait = report.appearance_snapshot ? icon2html(report.appearance_snapshot, user) : "Appearance concealed."
		to_chat(user, span_notice("The clerk recalls [portrait] [html_encode(report.visible_name)], claiming [city_faction_name(report.claimed_faction)] protection, [round((world.time - report.reported_at) / (1 MINUTES))] minutes ago. ID shown: [html_encode(report.id_name)]."))
	return TRUE

/obj/structure/city_business/proc/clear_suspect_reports()
	QDEL_LIST(suspect_reports)
