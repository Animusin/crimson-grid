/datum/config_entry/number/taxi_rcp_reward
	default = 0.1
	min_val = 0

/datum/config_entry/number/taxi_rcp_round_cap
	default = 0.5
	min_val = 0

/// Taxi earnings are separate from the once-per-round participation grant.
/// The pair ledger and cap persist across reconnects, reloads and body swaps.
/datum/player_quality_store/proc/award_taxi_rcp(account, passenger, amount, round_cap, round_token)
	account = ckey(account)
	passenger = ckey(passenger)
	if(!account || !passenger || account == passenger || !isnum(amount) || amount <= 0 || !isnum(round_cap) || round_cap <= 0 || !round_token)
		return FALSE
	var/list/record = read(account)
	if(record["taxi_round"] != round_token || !islist(record["taxi_passengers"]) || !isnum(record["taxi_rcp"]))
		record["taxi_round"] = round_token
		record["taxi_passengers"] = list()
		record["taxi_rcp"] = 0
	var/list/served = record["taxi_passengers"]
	if(served[passenger] || record["taxi_rcp"] >= round_cap)
		return FALSE
	var/earned = round(min(amount, round_cap - record["taxi_rcp"]), 0.01)
	if(earned <= 0)
		return FALSE
	served[passenger] = TRUE
	record["taxi_rcp"] = round(record["taxi_rcp"] + earned, 0.01)
	record["rcp"] = round(record["rcp"] + earned, 0.01)
	database.set_key(account, record)
	log_game("Taxi RCP: [account] +[earned] for delivering [passenger] (round [round_token]).")
	return earned

/datum/controller/subsystem/player_quality/proc/on_taxi_ride_completed(datum/source, mob/living/driver, mob/living/passenger)
	SIGNAL_HANDLER
	if(!store || round_ended || !SSticker.IsRoundInProgress() || driver?.mind?.assigned_role?.title != JOB_TAXI_DRIVER)
		return
	var/earned = store.award_taxi_rcp(taxi_player_account(driver), taxi_player_account(passenger), CONFIG_GET(number/taxi_rcp_reward), CONFIG_GET(number/taxi_rcp_round_cap), round_token)
	if(earned)
		to_chat(driver, span_notice("Your passenger's completed journey earned you [earned] RCP."))
