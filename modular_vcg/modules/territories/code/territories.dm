// Round-local businesses. The floor marker owns the state, never the replaceable clerk.
#define BUSINESS_CYCLE (10 MINUTES)
#define BUSINESS_RECOVERY (15 MINUTES)
#define BUSINESS_NOTICE_RADIUS 15
#define BUSINESS_CAPTURE_RADIUS 4
#define BUSINESS_HOLD_TIME (30 SECONDS)
#define BUSINESS_CAPTURE_WINDOW (2 MINUTES)
#define BUSINESS_SERVICE_NUMBER "5550199"
#define BUSINESS_DEFENSE_TIME (10 SECONDS)

GLOBAL_LIST_EMPTY(city_businesses)
GLOBAL_LIST_EMPTY(city_business_attacks)

/proc/city_business_population(list/joined_accounts = GLOB.joined_player_list)
	var/list/accounts = list()
	for(var/account in joined_accounts)
		if(account)
			accounts[ckey(account)] = TRUE
	return length(accounts)

/datum/job/proc/city_faction()
	if(faction in list(FACTION_CAMARILLA, FACTION_ANARCHS, FACTION_SABBAT, FACTION_GIOVANNI))
		return faction
	if(istype(src, /datum/job/vampire/blue_lantern) || istype(src, /datum/job/vampire/red_pole) || istype(src, /datum/job/vampire/mountain_master) || istype(src, /datum/job/vampire/deputy_mountain_master))
		return "triads"
	return null

/mob/living/proc/city_faction()
	return mind?.assigned_role?.city_faction()

/proc/city_faction_name(faction)
	switch(faction)
		if(FACTION_CAMARILLA)
			return "Camarilla"
		if(FACTION_ANARCHS)
			return "Anarchs"
		if(FACTION_SABBAT)
			return "Sabbat"
		if(FACTION_GIOVANNI)
			return "Giovanni"
		if("triads")
			return "Triads"
	return "Unclaimed"

/mob/living/proc/city_badge_faction()
	for(var/obj/item/card/city_badge/badge in get_all_contents())
		return badge.city_faction
	return null

/mob/living/proc/has_city_badge(faction)
	for(var/obj/item/card/city_badge/badge in get_all_contents())
		if(badge.city_faction == faction)
			return TRUE
	return FALSE

/obj/item/card/city_badge
	name = "faction credential"
	desc = "A credential used to claim protection money and negotiate a change of protection."
	icon = 'modular_vcg/modules/territories/icons/credentials.dmi'
	icon_state = "camarilla"
	slot_flags = ITEM_SLOT_ID | ITEM_SLOT_NECK
	w_class = WEIGHT_CLASS_TINY
	var/city_faction = FACTION_CAMARILLA

/obj/item/card/city_badge/anarchs
	name = "Anarch credential"
	city_faction = FACTION_ANARCHS
	icon_state = "anarchs"

/obj/item/card/city_badge/sabbat
	name = "Sabbat credential"
	city_faction = FACTION_SABBAT
	icon_state = "sabbat"

/obj/item/card/city_badge/triads
	name = "Triad credential"
	city_faction = "triads"
	icon_state = "triads"

/obj/item/card/city_badge/giovanni
	name = "Giovanni credential"
	city_faction = FACTION_GIOVANNI
	icon_state = FACTION_GIOVANNI

/obj/item/card/city_badge/Initialize(mapload)
	. = ..()
	name = "[city_faction_name(city_faction)] credential"

/mob/living/proc/issue_city_badge()
	var/faction = city_faction()
	if(!faction || has_city_badge(faction))
		return
	var/badge_type = /obj/item/card/city_badge
	switch(faction)
		if(FACTION_ANARCHS)
			badge_type = /obj/item/card/city_badge/anarchs
		if(FACTION_SABBAT)
			badge_type = /obj/item/card/city_badge/sabbat
		if("triads")
			badge_type = /obj/item/card/city_badge/triads
		if(FACTION_GIOVANNI)
			badge_type = /obj/item/card/city_badge/giovanni
	var/obj/item/card/city_badge/badge = new badge_type(get_turf(src))
	if(ishuman(src))
		var/mob/living/carbon/human/human = src
		if(!human.back?.atom_storage?.attempt_insert(badge, human, messages = FALSE))
			human.put_in_hands(badge)
	else
		put_in_hands(badge)

/datum/storyteller_roll/business
	applicable_stats = list(STAT_CHARISMA, STAT_INTIMIDATION)
	difficulty = 6
	numerical = TRUE
	bumper_text = "protection"

/obj/structure/retail
	var/territory_id
	var/obj/structure/city_business/territory

/obj/lombard
	var/territory_id
	var/obj/structure/city_business/territory

/mob/living/carbon/human/npc
	var/obj/structure/city_business/territory_employer

/obj/structure/city_business
	name = "territory mark"
	desc = "A painted mark identifying the faction protecting a nearby business. Talk to its cashier about protection or the till."
	icon = 'modular_vcg/modules/territories/icons/territories.dmi'
	icon_state = "camarilla"
	anchored = TRUE
	density = FALSE
	resistance_flags = INDESTRUCTIBLE | FIRE_PROOF | ACID_PROOF
	layer = LOW_OBJ_LAYER
	pixel_w = -8
	pixel_z = -8
	var/territory_id
	var/business_name = "Business"
	var/owner_faction = FACTION_CAMARILLA
	/// Clerk home is explicitly mapped, independently of the alley marker.
	var/clerk_offset_x = 0
	var/clerk_offset_y = 0
	var/clerk_offset_z = 0
	var/mob/living/carbon/human/npc/clerk
	var/clerk_type = /mob/living/carbon/human/npc/shop
	var/clerk_role
	var/turf/clerk_home
	var/list/outlets = list()
	var/income_per_cycle
	/// Accumulated till contents; collecting never resets the income clock.
	var/register_cash = 0
	var/collection_started = FALSE
	var/next_collection = 0
	var/robbery_retry_at = 0
	var/datum/city_robbery/robbery
	var/recover_at = 0
	var/attack_faction
	var/preparation_ends = 0
	var/capture_ends = 0
	var/hold_started = 0
	var/retry_at = 0
	var/active_conflict = FALSE
	/// Each active contest can report meaningful defense once per account.
	var/attack_token
	var/list/defense_started = list()
	var/list/defense_reported = list()
	var/list/hud_viewers = list()
	var/mapped_business = FALSE

/obj/structure/city_business/Initialize(mapload)
	. = ..()
	mapped_business = mapload
	GLOB.city_businesses += src
	name = "[business_name] territory"
	update_appearance()
	return INITIALIZE_HINT_LATELOAD

/obj/structure/city_business/LateInitialize()
	// Runtime map loading translates all three axes. Relative coordinates survive it.
	clerk_home = locate(x + clerk_offset_x, y + clerk_offset_y, z + clerk_offset_z)
	if(!territory_id || !clerk_home)
		if(mapped_business)
			stack_trace("Business [src] has no ID or clerk home")
		return
	for(var/obj/structure/retail/store in world)
		if(store.territory_id == territory_id)
			store.territory = src
			outlets += store
	for(var/obj/lombard/buyer in world)
		if(buyer.territory_id == territory_id)
			buyer.territory = src
			outlets += buyer
	var/mob/living/carbon/human/npc/existing = locate() in clerk_home
	if(existing && !existing.territory_employer)
		bind_clerk(existing)
	else
		bind_clerk(new clerk_type(clerk_home))
	START_PROCESSING(SSprocessing, src)

/obj/structure/city_business/proc/bind_clerk(mob/living/carbon/human/npc/new_clerk)
	clerk = new_clerk
	clerk.territory_employer = src
	clerk_type = clerk.type
	if(clerk_role)
		clerk.AssignSocialRole(clerk_role)
	clerk_role = clerk.socialrole?.type
	RegisterSignal(clerk, COMSIG_LIVING_DEATH, PROC_REF(clerk_lost))
	RegisterSignal(clerk, COMSIG_QDELETING, PROC_REF(clerk_lost))
	for(var/atom/outlet as anything in outlets)
		if(istype(outlet, /obj/structure/retail))
			var/obj/structure/retail/store = outlet
			if(store.my_owner)
				store.UnregisterSignal(store.my_owner, COMSIG_QDELETING)
			store.my_owner = clerk
			store.RegisterSignal(clerk, COMSIG_QDELETING, TYPE_PROC_REF(/obj/structure/retail, cleanup_owner))
		else
			var/obj/lombard/buyer = outlet
			if(buyer.owner)
				buyer.UnregisterSignal(buyer.owner, COMSIG_QDELETING)
			buyer.owner = clerk
			buyer.RegisterSignal(clerk, COMSIG_QDELETING, TYPE_PROC_REF(/obj/lombard, cleanup_owner))

/obj/structure/city_business/proc/clerk_lost(datum/source)
	SIGNAL_HANDLER
	if(recover_at)
		return
	accrue_income()
	recover_at = world.time + BUSINESS_RECOVERY
	next_collection = recover_at
	robbery?.cancel("The cashier was incapacitated.")
	// Killing your own clerk cannot cancel an announced attack.

/obj/structure/city_business/proc/clerk_available()
	return !recover_at && !QDELETED(clerk) && clerk.stat < HARD_CRIT

/obj/structure/city_business/proc/can_negotiate(mob/living/user, atom/interaction_target)
	if(interaction_target != clerk || QDELETED(src) || QDELETED(user) || !clerk_available())
		return FALSE
	var/action_flags = NEED_HANDS | NEED_DEXTERITY | FORBID_TELEKINESIS_REACH | SILENT_ADJACENCY
	if(user.can_perform_action(clerk, action_flags))
		return TRUE
	// The clicked target remains the visible cashier. Their own reachable till
	// permits speaking across a fixed counter, never interacting with that till.
	if(!(clerk in view(user)))
		return FALSE
	for(var/atom/outlet as anything in outlets)
		if(!QDELETED(outlet) && outlet.z == clerk.z && get_dist(outlet, clerk) <= 4 && user.can_perform_action(outlet, action_flags))
			return TRUE
	return FALSE

/obj/structure/city_business/proc/show_contract(mob/living/user, obj/item/card/city_badge/badge, atom/interaction_target)
	if(!interaction_target)
		interaction_target = clerk
	if(!can_negotiate(user, interaction_target))
		return
	accrue_income()
	var/faction = badge ? badge.city_faction : user.city_badge_faction()
	var/list/choices = list("Rob the till", "Cancel")
	if(faction == owner_faction)
		choices.Insert(1, "Collect", "Demand more")
	else if(faction)
		choices.Insert(1, "Change protection")
	if(user.city_faction() == owner_faction)
		choices.Insert(1, "Ask about threats")
	var/action = choose_business_action(user, choices)
	if(!can_negotiate(user, interaction_target))
		return
	if(action == "Rob the till")
		start_robbery(user)
		return
	if(action == "Ask about threats")
		report_suspects(user)
		return
	if(!faction || !user.has_city_badge(faction))
		return
	if(action == "Collect" || action == "Demand more")
		collect_income(user, faction, action == "Demand more")
	else if(action == "Change protection")
		declare_attack(user, faction)

/obj/structure/city_business/proc/choose_business_action(mob/living/user, list/choices)
	return tgui_input_list(user, "[business_name] is protected by [city_faction_name(owner_faction)]. Till: $[register_cash]. Demanding more risks the entire stored amount.", "Business", choices)

/mob/living/carbon/human/npc/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(territory_employer && istype(tool, /obj/item/card/city_badge) && !user.combat_mode && !LAZYACCESS(modifiers, RIGHT_CLICK))
		territory_employer.show_contract(user, tool)
		return ITEM_INTERACT_SUCCESS
	return ..()

/mob/living/carbon/human/npc/ranged_item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(territory_employer && istype(tool, /obj/item/card/city_badge) && !user.combat_mode && !LAZYACCESS(modifiers, RIGHT_CLICK))
		territory_employer.show_contract(user, tool, src)
		return ITEM_INTERACT_SUCCESS
	return ..()

/mob/living/carbon/human/npc/attack_hand(mob/user, list/modifiers)
	var/mob/living/living_user = user
	if(territory_employer && istype(living_user) && !living_user.combat_mode && !LAZYACCESS(modifiers, RIGHT_CLICK))
		territory_employer.show_contract(living_user, null, src)
		return TRUE
	return ..()

/obj/structure/city_business/proc/collect_income(mob/living/user, faction, demand_more = FALSE)
	accrue_income()
	if(faction != owner_faction || !user.has_city_badge(faction) || !can_negotiate(user, clerk) || active_conflict || robbery || register_cash <= 0)
		to_chat(user, span_warning("This business cannot pay you now."))
		return
	// Reserve the actual accumulated cash before rolling or creating items.
	// Any future income belongs to the next balance, not this transaction.
	var/amount = register_cash
	register_cash = 0
	if(demand_more)
		var/successes = roll_business(user)
		if(successes <= 0)
			to_chat(user, span_warning("The negotiation failed. The reserved $[amount] is lost."))
			return
		amount = round(amount * (1 + min(successes, 5) / 5))
	pay_cash(user, amount)
	log_game("[key_name(user)] collected $[amount] protection money from [territory_id] using a [faction] credential.")
	return amount

/obj/structure/city_business/proc/pay_cash(mob/living/user, amount)
	while(amount > 0)
		// Initializing a $1 stack on top of existing cash auto-merges before its
		// payout amount is assigned. Construct the complete stack before placing it.
		var/obj/item/stack/dollar/cash = new(null, 1, FALSE)
		cash.amount = min(amount, cash.max_amount)
		amount -= cash.amount
		cash.update_appearance()
		cash.forceMove(get_turf(user))

/obj/structure/city_business/proc/roll_business(mob/living/user)
	var/datum/storyteller_roll/business/roll = new
	. = roll.st_roll(user, clerk)
	qdel(roll)

/// Completed ten-minute cycles accumulate; a collection never moves the clock.
/obj/structure/city_business/proc/accrue_income(current_time = world.time)
	income_per_cycle = max(1, round_population())
	if(!collection_started)
		collection_started = TRUE
		next_collection = current_time + BUSINESS_CYCLE
		return
	if(recover_at || current_time < next_collection)
		return
	var/cycles = FLOOR((current_time - next_collection) / BUSINESS_CYCLE, 1) + 1
	register_cash += income_per_cycle * cycles
	next_collection += BUSINESS_CYCLE * cycles

/obj/structure/city_business/proc/declare_attack(mob/living/user, faction)
	if(!faction || !user.has_city_badge(faction) || !can_negotiate(user, clerk) || faction == owner_faction || attack_faction || GLOB.city_business_attacks[faction] || world.time < retry_at)
		to_chat(user, span_warning("A protection challenge is not available now."))
		return
	if(user.city_faction() != faction)
		false_challenge(user, faction)
		return
	var/successes = roll_business(user)
	retry_at = world.time + BUSINESS_CYCLE
	if(successes <= 0)
		to_chat(user, span_warning("The clerk refuses your proposal."))
		return
	attack_faction = faction
	robbery?.cancel("A protection contest was announced.")
	attack_token = "[REF(src)]-[world.time]"
	defense_started.Cut()
	defense_reported.Cut()
	GLOB.city_business_attacks[faction] = src
	preparation_ends = world.time + max(2, 7 - successes) MINUTES
	notify_factions("[business_name]: [city_faction_name(faction)] challenged [city_faction_name(owner_faction)]. Contest begins in [round((preparation_ends - world.time) / (1 MINUTES))] minutes. Meet at the territory mark.")
	update_appearance()
	update_hud()

/obj/structure/city_business/proc/notify_factions(message)
	message += " Mark: [get_area_name(src)] ([x], [y], level [z])."
	for(var/obj/item/smartphone/phone as anything in GLOB.phones_list)
		var/mob/living/phone_owner = phone.owner_weakref?.resolve()
		if(!istype(phone_owner) || !(phone_owner.city_faction() in list(owner_faction, attack_faction)) || !phone.sim_card)
			continue
		var/datum/phone_conversation/conversation = phone.get_conversation(BUSINESS_SERVICE_NUMBER)
		if(!conversation)
			conversation = new("City Protection", BUSINESS_SERVICE_NUMBER)
			phone.conversations += conversation
		conversation.add_message(message, FALSE)
		phone.after_text_received("City Protection", message)
		to_chat(phone_owner, span_notice("SMS — City Protection: [message]"))

/obj/structure/city_business/process(seconds_per_tick)
	if(!SSticker.HasRoundStarted())
		return
	if(recover_at && world.time >= recover_at)
		if(!QDELETED(clerk))
			UnregisterSignal(clerk, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING))
			clerk.territory_employer = null
		bind_clerk(new clerk_type(clerk_home))
		recover_at = 0
	accrue_income()
	if(attack_faction)
		if(!active_conflict && world.time >= preparation_ends)
			active_conflict = TRUE
			capture_ends = world.time + BUSINESS_CAPTURE_WINDOW
			if(clerk_available())
				clerk.say("Get out! There is going to be a fight!")
			notify_factions("[business_name]: the contest has started. Hold the mark for 30 seconds, with no defenders within 4 tiles.")
			update_appearance()
		if(active_conflict)
			if(clerk_available())
				clerk.Knockdown(3 SECONDS)
			var/attackers = FALSE
			var/defenders = FALSE
			var/list/current_defenders = list()
			var/list/capture_tiles = connected_capture_tiles()
			// Visibility alone also counts people through glass. Require a walkable
			// connection inside the capture radius, respecting directional barriers.
			for(var/mob/living/participant in view(BUSINESS_CAPTURE_RADIUS, src))
				if(!GET_CLIENT(participant) || participant.stat >= SOFT_CRIT || IS_UNCONSCIOUS(participant) || participant.IsIncapacitated() || !(get_turf(participant) in capture_tiles))
					continue
				if(participant.city_faction() == attack_faction)
					attackers = TRUE
				if(participant.city_faction() == owner_faction)
					defenders = TRUE
					current_defenders += participant
			track_defense(current_defenders, attackers && hold_started)
			advance_capture(attackers, defenders)
			if(attack_faction && world.time >= capture_ends)
				finish_attack(FALSE)
	update_hud()

/obj/structure/city_business/proc/round_population()
	// Unique accounts who joined this round include late arrivals. Reconnecting
	// cannot multiply the population, and a disconnect cannot devalue a ready cycle.
	return city_business_population()

/obj/structure/city_business/proc/connected_capture_tiles()
	var/list/reached = list(get_turf(src))
	var/datum/can_pass_info/pass_info = new(no_id = TRUE)
	for(var/index = 1, index <= length(reached), index++)
		var/turf/current = reached[index]
		for(var/direction in GLOB.alldirs)
			var/turf/next = get_step(current, direction)
			if(!next || next.z != z || get_dist(src, next) > BUSINESS_CAPTURE_RADIUS || (next in reached) || isgroundlessturf(next) || next.density || current.LinkBlockedWithAccess(next, pass_info))
				continue
			reached += next
	qdel(pass_info)
	return reached

/obj/structure/city_business/proc/track_defense(list/defenders, interrupted_hold = FALSE)
	var/list/present = list()
	for(var/mob/living/defender as anything in defenders)
		var/client/player_client = GET_CLIENT(defender)
		var/account = player_client?.ckey
		if(!account)
			continue
		present += account
		if(defense_reported[account])
			continue
		if(isnull(defense_started[account]))
			defense_started[account] = world.time
		if(!interrupted_hold && world.time < defense_started[account] + BUSINESS_DEFENSE_TIME)
			continue
		defense_reported[account] = TRUE
		// Optional progression modules consume this event; territories stand alone.
		SEND_GLOBAL_SIGNAL("city_business_defended", defender, territory_id, attack_token, attack_faction)
	for(var/account in defense_started.Copy())
		if(!(account in present))
			defense_started -= account

/obj/structure/city_business/proc/advance_capture(attackers, defenders)
	if(!active_conflict || !attack_faction)
		return
	if(hold_started && (!attackers || defenders))
		finish_attack(FALSE)
	else if(attackers && !defenders)
		if(!hold_started)
			hold_started = world.time
		if(world.time >= hold_started + BUSINESS_HOLD_TIME)
			finish_attack(TRUE)

/obj/structure/city_business/proc/finish_attack(won)
	if(!attack_faction)
		return
	notify_factions("[business_name]: [won ? "captured by [city_faction_name(attack_faction)]" : "defended by [city_faction_name(owner_faction)]"].")
	if(won)
		owner_faction = attack_faction
	GLOB.city_business_attacks -= attack_faction
	attack_faction = null
	active_conflict = FALSE
	defense_started.Cut()
	defense_reported.Cut()
	attack_token = null
	hold_started = 0
	preparation_ends = 0
	capture_ends = 0
	retry_at = world.time + BUSINESS_CYCLE
	update_appearance()
	update_hud()

/obj/structure/city_business/update_icon_state()
	. = ..()
	icon_state = owner_faction

/obj/structure/city_business/examine(mob/user)
	. = ..()
	. += span_notice("Protecting faction: [city_faction_name(owner_faction)]. Clerk: [clerk_available() ? "available" : "recovering"].")
	if(attack_faction)
		. += span_warning("Challenged by [city_faction_name(attack_faction)].")

/atom/movable/screen/business_timer
	screen_loc = "CENTER:16,TOP:-100"
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	maptext_width = 440
	maptext_height = 60
	maptext_x = -220
	layer = SCREENTIP_LAYER

/obj/structure/city_business/proc/update_hud()
	update_guidance()
	var/list/current_viewers = list()
	if(attack_faction)
		for(var/mob/living/user in range(BUSINESS_NOTICE_RADIUS, src))
			if(!user.client || !(user.city_faction() in list(owner_faction, attack_faction)))
				continue
			// Overlapping contests use the nearest mark, rather than stacking text.
			var/nearest = TRUE
			for(var/obj/structure/city_business/other as anything in GLOB.city_businesses)
				if(other != src && other.attack_faction && (user.city_faction() in list(other.owner_faction, other.attack_faction)) && other.z == user.z && (get_dist(user, other) < get_dist(user, src) || (get_dist(user, other) == get_dist(user, src) && GLOB.city_businesses.Find(other) < GLOB.city_businesses.Find(src))))
					nearest = FALSE
					break
			if(!nearest)
				continue
			current_viewers += user.client
			var/atom/movable/screen/business_timer/timer = hud_viewers[user.client]
			if(!timer)
				timer = new
				hud_viewers[user.client] = timer
				user.client.screen += timer
			var/status = "Begins in [max(0, CEILING((preparation_ends - world.time) / (1 SECONDS), 1))]s"
			if(active_conflict)
				status = hold_started ? "Capture: [max(0, CEILING((hold_started + BUSINESS_HOLD_TIME - world.time) / (1 SECONDS), 1))]s" : "Enter within 4 tiles • [max(0, CEILING((capture_ends - world.time) / (1 SECONDS), 1))]s left"
			timer.maptext = "<div style='text-align:center;color:#ff7777;font-size:14px'>[html_encode(business_name)] — [status]</div>"
	for(var/client/viewer as anything in hud_viewers.Copy())
		if(viewer in current_viewers)
			continue
		var/atom/movable/screen/business_timer/timer = hud_viewers[viewer]
		if(viewer)
			viewer.screen -= timer
		qdel(timer)
		hud_viewers -= viewer

/obj/structure/city_business/Destroy()
	clear_guidance()
	clear_suspect_reports()
	STOP_PROCESSING(SSprocessing, src)
	robbery?.cancel("The business is no longer available.")
	if(attack_faction)
		finish_attack(FALSE)
	for(var/client/viewer as anything in hud_viewers)
		var/atom/movable/screen/business_timer/timer = hud_viewers[viewer]
		if(viewer)
			viewer.screen -= timer
		qdel(timer)
	if(!QDELETED(clerk))
		UnregisterSignal(clerk, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING))
		clerk.territory_employer = null
	for(var/atom/outlet as anything in outlets)
		if(istype(outlet, /obj/structure/retail))
			var/obj/structure/retail/store = outlet
			store.territory = null
		else
			var/obj/lombard/buyer = outlet
			buyer.territory = null
	GLOB.city_businesses -= src
	return ..()

/// Only protects local NPC witnesses during the actual contest, not the preparation.
/proc/city_conflict_hides_breach(atom/observer, atom/breacher)
	if(!observer || !breacher)
		return FALSE
	if(!istype(observer, /mob/living/carbon/human/npc))
		return FALSE
	var/mob/living/carbon/human/npc/witness = observer
	if(witness.client || witness.mind)
		return FALSE
	for(var/obj/structure/city_business/business as anything in GLOB.city_businesses)
		if(!business.active_conflict || get_dist(breacher, business) > BUSINESS_NOTICE_RADIUS || breacher.z != business.z)
			continue
		if(witness.territory_employer == business || (witness.z == business.z && get_dist(witness, business) <= BUSINESS_NOTICE_RADIUS))
			return TRUE
	return FALSE

/mob/living/carbon/human/npc/proc/flee_city_conflict()
	if(client || mind || stat >= HARD_CRIT)
		return FALSE
	for(var/obj/structure/city_business/business as anything in GLOB.city_businesses)
		if(!business.active_conflict)
			continue
		if(territory_employer == business)
			GLOB.move_manager.stop_looping(src)
			return TRUE
		if(z == business.z && get_dist(src, business) <= BUSINESS_NOTICE_RADIUS && !hostile && !aggressive)
			GLOB.move_manager.move_away(src, business, BUSINESS_NOTICE_RADIUS + 2, cached_multiplicative_slowdown)
			return TRUE
	return FALSE

#undef BUSINESS_CYCLE
#undef BUSINESS_RECOVERY
#undef BUSINESS_NOTICE_RADIUS
#undef BUSINESS_CAPTURE_RADIUS
#undef BUSINESS_HOLD_TIME
#undef BUSINESS_CAPTURE_WINDOW
#undef BUSINESS_SERVICE_NUMBER
#undef BUSINESS_DEFENSE_TIME
