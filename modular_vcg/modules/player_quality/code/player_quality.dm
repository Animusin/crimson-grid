// PQ measures peer appreciation. RCP records participation; they do not convert.
/datum/config_entry/flag/player_quality_enabled
	default = TRUE

/datum/config_entry/number/rcp_human_reward
	default = 1
	min_val = 0

/datum/config_entry/number/rcp_ghoul_reward
	default = 0.5
	min_val = 0

/datum/config_entry/number/rcp_kinfolk_reward
	default = 0.5
	min_val = 0

/datum/config_entry/number/rcp_minimum_minutes
	default = 45
	min_val = 1

/// Account-level data only. No character age, morality or job gates live here.
/datum/player_quality_store
	var/datum/json_database/database

/datum/player_quality_store/New(path = "data/player_quality.json")
	database = new(path)

/datum/player_quality_store/Destroy()
	QDEL_NULL(database)
	return ..()

/datum/player_quality_store/proc/read(account)
	account = ckey(account)
	if(!account)
		return null
	var/list/record = database.get_key(account)
	return record ? deep_copy_list(record) : list("version" = 1, "pq" = 0, "rcp" = 0, "commends" = list())

/// At most one point from a given account over the recipient's lifetime.
/// Further compliments remain visible in the count without inflating PQ.
/datum/player_quality_store/proc/commend(recipient, giver)
	recipient = ckey(recipient)
	giver = ckey(giver)
	if(!recipient || !giver || recipient == giver)
		return FALSE
	var/list/record = read(recipient)
	var/list/commends = record["commends"]
	var/previous = commends[giver] || 0
	commends[giver] = previous + 1
	if(!previous)
		record["pq"] += 1
	database.set_key(recipient, record)
	return TRUE

/datum/player_quality_store/proc/award_rcp(account, amount, round_token)
	if(!ckey(account) || !isnum(amount) || amount <= 0 || !round_token)
		return FALSE
	var/list/record = read(account)
	if(record["last_rcp_round"] == round_token)
		return FALSE
	record["rcp"] += amount
	record["last_rcp_round"] = round_token
	database.set_key(ckey(account), record)
	return TRUE

/datum/player_quality_store/proc/admin_adjust(account, amount, administrator, reason)
	if(!ckey(account) || !isnum(amount) || !administrator || !length(reason))
		return FALSE
	var/list/record = read(account)
	record["pq"] += amount
	database.set_key(ckey(account), record)
	log_admin("[administrator] adjusted [ckey(account)] PQ by [amount]: [reason]")
	message_admins("[administrator] adjusted [ckey(account)] PQ by [amount]: [html_encode(reason)]")
	return TRUE

/datum/quality_participant
	var/character_name
	var/active_time = 0
	var/list/role_time = list()

SUBSYSTEM_DEF(player_quality)
	name = "Player Quality"
	wait = 10 SECONDS
	runlevels = RUNLEVEL_GAME
	var/datum/player_quality_store/store
	var/list/participants = list()
	var/list/voters = list()
	var/round_ended = FALSE
	var/round_token
	var/last_sample = 0

/datum/controller/subsystem/player_quality/Initialize()
	if(!CONFIG_GET(flag/player_quality_enabled))
		return SS_INIT_NO_NEED
	store = new
	round_token = "[world.realtime]-[rand(1, 1000000)]"
	RegisterSignal(SSdcs, "taxi_ride_completed", PROC_REF(on_taxi_ride_completed))
	RegisterSignal(SSticker, COMSIG_TICKER_ROUND_STARTING, PROC_REF(round_starting))
	RegisterSignal(SSticker, COMSIG_TICKER_ROUND_ENDED, PROC_REF(round_finished))
	return SS_INIT_SUCCESS

/datum/controller/subsystem/player_quality/Recover()
	ss_flags |= SS_NO_INIT
	initialized = SSplayer_quality.initialized
	store = SSplayer_quality.store
	SSplayer_quality.store = null
	participants = SSplayer_quality.participants
	voters = SSplayer_quality.voters
	round_ended = SSplayer_quality.round_ended
	round_token = SSplayer_quality.round_token
	last_sample = SSplayer_quality.last_sample
	if(store)
		RegisterSignal(SSdcs, "taxi_ride_completed", PROC_REF(on_taxi_ride_completed))
		RegisterSignal(SSticker, COMSIG_TICKER_ROUND_STARTING, PROC_REF(round_starting))
		RegisterSignal(SSticker, COMSIG_TICKER_ROUND_ENDED, PROC_REF(round_finished))

/datum/controller/subsystem/player_quality/Destroy()
	QDEL_NULL(store)
	return ..()

/datum/controller/subsystem/player_quality/proc/round_starting()
	SIGNAL_HANDLER
	last_sample = world.time

/datum/controller/subsystem/player_quality/fire(resumed)
	if(!store || round_ended || !SSticker.IsRoundInProgress())
		return
	sample_players()

/// Record connected, living, non-AFK play; ghosts and lobby time cannot earn RCP.
/// Each interval keeps its splat, so a late transformation cannot claim an entire
/// vampire round at the human rate. Dead/disconnected players retain earned time.
/datum/controller/subsystem/player_quality/proc/sample_players()
	var/elapsed = last_sample ? clamp(world.time - last_sample, 0, wait) : 0
	last_sample = world.time
	for(var/client/player as anything in GLOB.clients)
		var/mob/living/carbon/human/body = player.mob
		if(!istype(body) || !body.mind?.assigned_role || !body.ckey)
			continue
		var/datum/quality_participant/participant = participants[player.ckey]
		if(!participant)
			participant = new
			participants[player.ckey] = participant
		participant.character_name = body.real_name
		if(body.stat == DEAD || player.is_afk())
			continue
		var/bucket = participation_bucket(body)
		participant.active_time += elapsed
		participant.role_time[bucket] = (participant.role_time[bucket] || 0) + elapsed

/datum/controller/subsystem/player_quality/proc/participation_bucket(mob/living/carbon/human/body)
	if(body.get_splat(/datum/splat/vampire/kindred) || body.get_splat(/datum/splat/werewolf/shifter))
		return "supernatural"
	if(body.get_splat(/datum/splat/vampire/ghoul))
		return "ghoul"
	if(body.get_splat(/datum/splat/werewolf/kinfolk))
		return "kinfolk"
	if(length(body.splats))
		return "supernatural"
	return "human"

/// One configurable grant per completed round, weighted by actual played time.
/datum/controller/subsystem/player_quality/proc/participation_reward(datum/quality_participant/participant)
	if(participant.active_time < CONFIG_GET(number/rcp_minimum_minutes) MINUTES)
		return 0
	var/weighted = (participant.role_time["human"] || 0) * CONFIG_GET(number/rcp_human_reward)
	weighted += (participant.role_time["ghoul"] || 0) * CONFIG_GET(number/rcp_ghoul_reward)
	weighted += (participant.role_time["kinfolk"] || 0) * CONFIG_GET(number/rcp_kinfolk_reward)
	return round(weighted / participant.active_time, 0.01)

/datum/controller/subsystem/player_quality/proc/round_finished()
	SIGNAL_HANDLER
	if(!store || round_ended)
		return
	sample_players()
	round_ended = TRUE
	for(var/account in participants)
		var/datum/quality_participant/participant = participants[account]
		var/reward = participation_reward(participant)
		if(reward)
			store.award_rcp(account, reward, round_token)
	for(var/client/player as anything in GLOB.clients)
		if(participants[player.ckey])
			to_chat(player, span_notice("You can now commend one player through OOC → Commend player. Use Player quality to see your PQ and RCP."))

/datum/controller/subsystem/player_quality/proc/can_vote(account, recipient)
	account = ckey(account)
	recipient = ckey(recipient)
	return store && round_ended && participants[account] && participants[recipient] && account != recipient && !voters[account]

/datum/controller/subsystem/player_quality/proc/submit_vote(account, recipient)
	if(!can_vote(account, recipient))
		return FALSE
	// Reserve before any persistence or UI work; multiple dialogs cannot double-vote.
	voters[ckey(account)] = TRUE
	store.commend(recipient, account)
	log_game("PQ: [ckey(account)] commended [ckey(recipient)].")
	return TRUE

GAME_VERB(/client, commend_player, "Commend player", "OOC")
	if(!SSplayer_quality.store || !SSplayer_quality.round_ended || !SSplayer_quality.participants[ckey] || SSplayer_quality.voters[ckey])
		to_chat(src, span_warning("You may commend one other participant after the round ends."))
		return
	var/list/choices = list()
	var/index = 0
	for(var/account in SSplayer_quality.participants)
		if(account == ckey)
			continue
		var/datum/quality_participant/participant = SSplayer_quality.participants[account]
		choices["[participant.character_name] ([++index])"] = account
	var/selection = tgui_input_list(mob, "Who contributed to your experience this round?", "Commend a player", choices)
	if(!selection)
		return
	if(SSplayer_quality.submit_vote(ckey, choices[selection]))
		to_chat(src, span_notice("Your commendation has been recorded."))

GAME_VERB(/client, player_quality, "Player quality", "OOC")
	if(!SSplayer_quality.store)
		return
	var/list/record = SSplayer_quality.store.read(ckey)
	to_chat(src, span_notice("Player Quality: [record["pq"]]. Round Contribution Points: [record["rcp"]]. These are separate account scores."))

ADMIN_VERB(adjust_player_quality, R_ADMIN, "Adjust player quality", "Adjust an account's PQ with an audited reason.", ADMIN_CATEGORY_GAME)
	if(!SSplayer_quality.store)
		return
	var/account = ckey(tgui_input_text(user.mob, "Account ckey", "Adjust PQ"))
	if(!account)
		return
	var/amount = tgui_input_number(user.mob, "PQ change (negative values remove points)", "Adjust PQ")
	if(isnull(amount))
		return
	var/reason = tgui_input_text(user.mob, "Reason for adjustment", "Adjust PQ", max_length = 500)
	if(!reason || !check_rights_for(user, R_ADMIN))
		return
	SSplayer_quality.store.admin_adjust(account, amount, user.ckey, reason)
