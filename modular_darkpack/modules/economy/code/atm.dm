/obj/machinery/atm
	name = "\improper ATM machine"
	desc = "Check your balance or make a transaction."
	icon = 'modular_darkpack/modules/economy/icons/atm.dmi'
	icon_state = "atm"
	anchored = TRUE

	max_integrity = 250
	damage_deflection = 50 // CRIMSON EDIT CHANGE - ORIGINAL: damage_deflection = 20

	light_color = COLOR_GREEN
	light_range = 2

	circuit = /obj/item/circuitboard/machine/atm

	var/logged_in = FALSE
	var/total_stored_cash = 0
	var/inserted_cash = 0
	/// A swipe selects an account; only this user can authenticate or transact.
	var/datum/bank_account/logged_account
	var/obj/item/card/credit/selected_card
	var/mob/living/session_user
	var/client/session_client

/obj/machinery/atm/Initialize(mapload)
	. = ..()
	if(mapload)
		total_stored_cash = rand(1000, 10000)

/obj/machinery/atm/Destroy()
	reset_session()
	return ..()

/obj/machinery/atm/on_deconstruction(disassembled)
	dump_cash()
	SEND_SIGNAL(SSdcs, COMSIG_GLOB_REPORT_CRIME, CRIME_ATM_TAMPERING, get_turf(src))

/obj/machinery/atm/examine(mob/user)
	. = ..()
	if(logged_account)
		. += span_notice("The screen is active with an account logged in.")

/obj/machinery/atm/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	validate_session()
	if(!can_use_atm(user))
		return ITEM_INTERACT_BLOCKING
	if(is_creditcard(tool))
		var/obj/item/card/credit/card = tool
		if(session_user && session_user != user)
			to_chat(user, span_notice("Someone is already logged in."))
			return ITEM_INTERACT_BLOCKING
		if(QDELETED(card.registered_account) || !(card in user.get_all_contents()))
			return ITEM_INTERACT_BLOCKING
		reset_session()
		selected_card = card
		logged_account = card.registered_account
		session_user = user
		session_client = GET_CLIENT(user)
		RegisterSignal(user, COMSIG_MOVABLE_MOVED, PROC_REF(on_session_moved))
		RegisterSignals(user, list(COMSIG_MOB_LOGOUT, COMSIG_QDELETING), PROC_REF(on_session_lost))
		RegisterSignal(card, COMSIG_MOVABLE_MOVED, PROC_REF(on_session_moved))
		RegisterSignal(card, COMSIG_QDELETING, PROC_REF(on_session_lost))
		RegisterSignal(logged_account, COMSIG_QDELETING, PROC_REF(on_session_lost))
		to_chat(user, span_notice("Card swiped."))
		return ITEM_INTERACT_SUCCESS
	else if(iscash(tool))
		if(!is_authenticated(user))
			to_chat(user, span_notice("You need to be logged in."))
			return ITEM_INTERACT_BLOCKING
		var/value = tool.get_item_credit_value()
		if(!IS_FINITE(value) || value <= 0 || value != round(value) || !IS_FINITE(inserted_cash + value) || !user.is_holding(tool) || !user.temporarilyRemoveItemFromInventory(tool))
			return ITEM_INTERACT_BLOCKING
		inserted_cash += value
		to_chat(user, span_notice("You have inserted [value] [MONEY_NAME] into [src]. [src] now holds [inserted_cash] [MONEY_NAME] ready to deposit."))
		qdel(tool)
		return ITEM_INTERACT_SUCCESS
	return ..()

/// Client identity, physical access and the exact swiped card/account are all
/// authoritative. A different UI viewer never inherits a shared logged_in flag.
/obj/machinery/atm/proc/can_use_atm(mob/living/user)
	if(!istype(user) || QDELETED(user))
		return FALSE
	var/client/player_client = GET_CLIENT(user)
	return player_client && player_client.mob == user && user.can_perform_action(src, NEED_HANDS | NEED_DEXTERITY | FORBID_TELEKINESIS_REACH | SILENT_ADJACENCY)

/obj/machinery/atm/proc/validate_session()
	if(!session_user)
		return FALSE
	if(QDELETED(selected_card) || QDELETED(logged_account) || GET_CLIENT(session_user) != session_client || !can_use_atm(session_user) || selected_card.registered_account != logged_account || !(selected_card in session_user.get_all_contents()))
		reset_session()
		return FALSE
	return TRUE

/obj/machinery/atm/proc/is_authenticated(mob/user)
	return validate_session() && user == session_user && logged_in

/obj/machinery/atm/proc/on_session_moved(datum/source)
	SIGNAL_HANDLER
	validate_session()

/obj/machinery/atm/proc/on_session_lost(datum/source)
	SIGNAL_HANDLER
	reset_session()

/obj/machinery/atm/proc/reset_session()
	var/mob/living/previous_user = session_user
	if(session_user)
		UnregisterSignal(session_user, list(COMSIG_MOVABLE_MOVED, COMSIG_MOB_LOGOUT, COMSIG_QDELETING))
	if(selected_card)
		UnregisterSignal(selected_card, list(COMSIG_MOVABLE_MOVED, COMSIG_QDELETING))
	if(logged_account)
		UnregisterSignal(logged_account, COMSIG_QDELETING)
	logged_in = FALSE
	logged_account = null
	selected_card = null
	session_user = null
	session_client = null
	// Uncommitted cash belongs to the ending session, never the next card.
	var/refund = inserted_cash
	inserted_cash = 0
	if(refund > 0)
		give_cash(refund, QDELETED(previous_user) ? null : previous_user)

/obj/machinery/atm/proc/valid_pin(pin)
	var/static/regex/digits = regex("^\[0-9]{4}$")
	return istext(pin) && length(pin) == 4 && digits.Find(pin)

/obj/machinery/atm/proc/withdrawal_amount(raw_amount)
	if(istext(raw_amount))
		var/static/regex/digits = regex("^\[0-9]+$")
		if(!digits.Find(raw_amount))
			return null
		raw_amount = text2num(raw_amount)
	if(!IS_FINITE(raw_amount) || raw_amount <= 0 || raw_amount != round(raw_amount))
		return null
	return raw_amount

/obj/machinery/atm/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "Atm", name)
		ui.open()

/obj/machinery/atm/ui_close(mob/user)
	. = ..()
	if(user == session_user)
		reset_session()

/obj/machinery/atm/ui_data(mob/user)
	var/selected_for_user = validate_session() && user == session_user
	var/authenticated = selected_for_user && logged_in
	var/list/data = list()
	data["logged_in"] = authenticated
	data["card"] = selected_for_user
	data["inserted_cash"] = authenticated ? inserted_cash : 0
	data["atm_balance"] = authenticated ? total_stored_cash : null
	if(authenticated)
		data["account_balance"] = logged_account.account_balance
		data["account_holder"] = logged_account.account_holder
		data["account_id"] = logged_account.account_id
	else
		data["account_balance"] = null
		data["account_holder"] = null
		data["account_id"] = null

	return data

/obj/machinery/atm/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	// Machinery's parent also dereferences ui, so reject malformed calls first.
	if(!ui || !islist(params))
		return FALSE
	. = ..()
	if(.)
		return
	var/mob/living/user = usr
	if(user != ui.user || ui.src_object != src || !validate_session() || user != session_user)
		to_chat(usr, span_notice("You need to swipe your card before interacting with [src]."))
		return FALSE
	switch(action)
		if("login")
			logged_in = valid_pin(params["bank_pin"]) && params["bank_pin"] == logged_account.bank_pin
			if(!logged_in)
				to_chat(user, span_warning("Incorrect PIN. Enter four digits."))
			return TRUE
		if("logout")
			reset_session()
			return TRUE
	if(!is_authenticated(user))
		return FALSE
	switch(action)
		if("withdraw")
			var/amount = withdrawal_amount(params["withdraw_amount"])
			if(isnull(amount))
				return FALSE
			dispense_cash(amount, user)
			return TRUE
		if("change_pin")
			var/new_pin = params["new_pin"]
			if(!valid_pin(new_pin))
				return FALSE
			logged_account.bank_pin = new_pin
			to_chat(user, span_notice("Your PIN has been updated."))
			return TRUE
		if("deposit")
			if(inserted_cash > 0)
				logged_account.adjust_money(inserted_cash, "ATM: Deposit")
				to_chat(user, span_notice("You have deposited [inserted_cash] [MONEY_NAME] into your card. Your new balance is [logged_account.account_balance] [MONEY_NAME]."))
				total_stored_cash += inserted_cash
				inserted_cash = 0
				return TRUE
			else
				to_chat(usr, span_notice("[src] is empty. Nothing to deposit."))
				return TRUE

/obj/machinery/atm/proc/dispense_cash(amount, mob/user)
	if(!is_authenticated(user) || isnull(withdrawal_amount(amount)))
		return FALSE
	if(logged_account.account_balance < amount)
		to_chat(user, span_notice("Insufficient funds."))
		return FALSE
	// Retain the ATM's existing whole-stack partial payout limit. Debit the
	// actual payout before creating cash, with no input or yield in between.
	var/amount_drawn = amount <= total_stored_cash ? amount : FLOOR(total_stored_cash / 1000, 1) * 1000
	if(amount_drawn <= 0)
		to_chat(user, span_notice("[src] has maxed out its withdraw limit."))
		return FALSE
	if(!logged_account.adjust_money(-amount_drawn, "ATM: Withdraw"))
		return FALSE
	total_stored_cash -= amount_drawn
	give_cash(amount_drawn, user)
	to_chat(user, span_notice("You have withdrawn [amount_drawn] [MONEY_NAME]."))
	return amount_drawn

/obj/machinery/atm/proc/give_cash(amount, mob/living/user)
	while(amount > 0)
		var/drop_amount = min(amount, 1000)
		var/obj/item/stack/dollar/cash = new(null, drop_amount, FALSE)
		if(user && !QDELETED(user))
			try_put_in_hand(cash, user)
		else
			cash.forceMove(drop_location())
		// put_in_hands may report a partial merge as success. Keep any
		// surviving remainder physical instead of leaving it in nullspace.
		if(!QDELETED(cash) && isnull(cash.loc))
			cash.forceMove(drop_location())
		amount -= drop_amount

/obj/machinery/atm/proc/dump_cash()
	while(total_stored_cash > 0)
		var/drop_amount = min(total_stored_cash, 1000)
		new /obj/item/stack/dollar(loc, drop_amount)
		total_stored_cash -= drop_amount

/obj/item/circuitboard/machine/atm
	name = "\improper ATM Machine"
	greyscale_colors = CIRCUIT_COLOR_GENERIC
	build_path = /obj/machinery/atm
	req_components = list(
		/obj/item/stack/sheet/glass = 1,
		/datum/stock_part/servo = 2,
	)

