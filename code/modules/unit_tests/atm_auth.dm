/// Exercise the real ATM UI actions without trusting which buttons TGUI shows.
/datum/unit_test/atm_auth
	abstract_type = /datum/unit_test/atm_auth
	test_flags = UNIT_TEST_MAP_TEST
#ifdef ATM_AUTH_TESTS
	test_flags = UNIT_TEST_FOCUS
#endif
	var/list/players = list()
	var/obj/machinery/atm/atm
	var/mob/living/carbon/human/customer
	var/obj/item/card/credit/card
	var/datum/bank_account/account
	var/datum/tgui/ui

/datum/unit_test/atm_auth/proc/connect(mob/living/player)
	var/datum/client_interface/mock = allocate(/datum/client_interface)
	mock.mob = player
	player.mock_client = mock
	players += player
	return mock

/datum/unit_test/atm_auth/Destroy()
	for(var/mob/living/player as anything in players)
		if(QDELETED(player))
			continue
		var/datum/client_interface/mock = player.mock_client
		if(mock)
			mock.mob = null
		player.mock_client = null
	return ..()

/datum/unit_test/atm_auth/proc/setup()
	customer = allocate(/mob/living/carbon/human/consistent)
	connect(customer)
	atm = allocate(/obj/machinery/atm)
	atm.total_stored_cash = 5000
	card = allocate(/obj/item/card/credit, customer)
	account = card.registered_account
	allocated += account
	account.account_balance = 500
	account.bank_pin = "0420"
	customer.put_in_hands(card)
	ui = allocate(/datum/tgui, customer, atm, "Atm")
	atm.item_interaction(customer, card, list())

/datum/unit_test/atm_auth/proc/action(action, list/params = list(), mob/living/user = customer, datum/tgui/action_ui = ui)
	var/previous_usr = usr
	usr = user
	. = atm.ui_act(action, params, action_ui, action_ui?.state)
	usr = previous_usr

/datum/unit_test/atm_auth/proc/insert_cash(amount)
	var/obj/item/stack/dollar/cash = allocate(/obj/item/stack/dollar, null, amount, FALSE)
	customer.put_in_hands(cash)
	atm.item_interaction(customer, cash, list())
	return cash

/datum/unit_test/atm_auth/proc/cash_total()
	var/total = 0
	for(var/obj/item/stack/dollar/cash in customer.get_all_contents())
		total += cash.amount
	for(var/obj/item/stack/dollar/cash in get_turf(atm))
		total += cash.amount
	return total

/datum/unit_test/atm_auth/unauthenticated/Run()
	setup()
	// Bypass the helper's default UI to exercise an actually missing datum.
	var/previous_usr = usr
	usr = customer
	var/missing_ui_result = atm.ui_act("withdraw", list("withdraw_amount" = "100"), null, null)
	usr = previous_usr
	TEST_ASSERT(!missing_ui_result, "A raw action with no UI must be safely rejected.")
	var/list/data = atm.ui_data(customer)
	TEST_ASSERT(!data["logged_in"] && data["card"] && isnull(data["account_balance"]), "Swiping selects a card without exposing its account balance or authenticating it.")
	TEST_ASSERT(!("bank_pin" in data), "The ATM must never serialize the account PIN.")
	var/obj/item/stack/dollar/cash = insert_cash(25)
	TEST_ASSERT(!QDELETED(cash) && customer.is_holding(cash) && !atm.inserted_cash, "An unauthenticated cash insertion must leave the physical money intact.")
	// Even a stale staged balance must not permit a raw deposit action.
	atm.inserted_cash = 40
	action("withdraw", list("withdraw_amount" = "100"))
	action("change_pin", list("new_pin" = "9999"))
	action("deposit")
	TEST_ASSERT_EQUAL(account.account_balance, 500, "Raw actions before login must not debit or credit an account.")
	TEST_ASSERT_EQUAL(account.bank_pin, "0420", "A raw PIN change before login must fail.")
	TEST_ASSERT_EQUAL(atm.inserted_cash, 40, "An unauthorized deposit must not consume staged cash.")
	TEST_ASSERT(!atm.dispense_cash(100, customer), "The cash helper must require authentication too.")
	for(var/bad_pin in list("0421", "", "abcd", "123", "12345", 420, 420.5))
		action("login", list("bank_pin" = bad_pin))
		TEST_ASSERT(!atm.logged_in, "An incorrect or malformed PIN must not authenticate: [bad_pin].")
		data = atm.ui_data(customer)
		TEST_ASSERT(!("bank_pin" in data) && isnull(data["account_balance"]), "A failed login must not expose PIN or account details.")

/datum/unit_test/atm_auth/transactions/Run()
	setup()
	action("login", list("bank_pin" = "0420"))
	TEST_ASSERT(atm.is_authenticated(customer), "The correct four-digit PIN, including its leading zero, must authenticate.")
	var/list/data = atm.ui_data(customer)
	TEST_ASSERT(data["account_balance"] == 500 && !("bank_pin" in data), "A successful login may expose the balance, never the PIN.")
	var/obj/item/stack/dollar/cash = insert_cash(50)
	TEST_ASSERT(QDELETED(cash) && atm.inserted_cash == 50 && account.account_balance == 500, "Authenticated insertion must stage the actual cash until Deposit.")
	action("deposit")
	TEST_ASSERT(account.account_balance == 550 && atm.total_stored_cash == 5050 && !atm.inserted_cash, "Deposit must credit the account and ATM exactly once.")
	action("deposit")
	TEST_ASSERT_EQUAL(account.account_balance, 550, "Repeating Deposit with no staged cash must not create money.")
	action("withdraw", list("withdraw_amount" = "125"))
	TEST_ASSERT(account.account_balance == 425 && atm.total_stored_cash == 4925 && cash_total() == 125, "Withdrawal must debit and dispense exactly the same amount.")
	for(var/bad_amount in list("0", "-1", "1.5", "1e3", "100garbage", "Infinity", "99999", -10, 0, 0.5, list("100")))
		action("withdraw", list("withdraw_amount" = bad_amount))
	TEST_ASSERT(account.account_balance == 425 && atm.total_stored_cash == 4925 && cash_total() == 125, "Malformed, nonpositive, fractional and unaffordable withdrawals must leave all money unchanged.")
	for(var/bad_pin in list("", "123", "12345", "abcd", 1234))
		action("change_pin", list("new_pin" = bad_pin))
	TEST_ASSERT_EQUAL(account.bank_pin, "0420", "PIN changes must require four text digits.")
	action("change_pin", list("new_pin" = "0017"))
	TEST_ASSERT_EQUAL(account.bank_pin, "0017", "Valid PIN changes must preserve leading zeroes.")
	action("logout")
	TEST_ASSERT(!atm.logged_in && !atm.logged_account && !atm.selected_card, "Logout must clear authentication and the selected account/card.")
	atm.item_interaction(customer, card, list())
	action("login", list("bank_pin" = "0420"))
	TEST_ASSERT(!atm.logged_in, "The old PIN must no longer authenticate after a change.")
	action("login", list("bank_pin" = "0017"))
	TEST_ASSERT(atm.is_authenticated(customer), "The changed PIN must authenticate through the normal UI action.")
	account.account_balance = 2500
	atm.total_stored_cash = 1500
	action("withdraw", list("withdraw_amount" = "2000"))
	TEST_ASSERT(account.account_balance == 1500 && atm.total_stored_cash == 500 && cash_total() == 1125, "The existing partial-payout limit must debit only the cash actually dispensed.")

/datum/unit_test/atm_auth/other_user/Run()
	setup()
	action("login", list("bank_pin" = "0420"))
	TEST_ASSERT(atm.is_authenticated(customer), "The owner must authenticate before testing cross-user isolation.")
	insert_cash(50)
	TEST_ASSERT_EQUAL(atm.inserted_cash, 50, "The owner's actual cash must be staged before another user's attempted deposit.")
	var/mob/living/carbon/human/other = allocate(/mob/living/carbon/human/consistent)
	connect(other)
	var/datum/tgui/other_ui = allocate(/datum/tgui, other, atm, "Atm")
	var/list/data = atm.ui_data(other)
	TEST_ASSERT(!data["logged_in"] && !data["card"] && isnull(data["account_balance"]) && !("bank_pin" in data), "Another viewer must not inherit authentication or account details.")
	for(var/datum/tgui/attempt_ui as anything in list(ui, other_ui))
		action("withdraw", list("withdraw_amount" = "100"), other, attempt_ui)
		action("change_pin", list("new_pin" = "9999"), other, attempt_ui)
		action("deposit", list(), other, attempt_ui)
		action("logout", list(), other, attempt_ui)
	TEST_ASSERT(account.account_balance == 500 && account.bank_pin == "0420" && atm.inserted_cash == 50 && atm.is_authenticated(customer), "Another user must not transact or log out the original user, even with their UI datum.")
	var/obj/item/stack/dollar/other_cash = allocate(/obj/item/stack/dollar, other, 20, FALSE)
	other.put_in_hands(other_cash)
	atm.item_interaction(other, other_cash, list())
	TEST_ASSERT(!QDELETED(other_cash) && other.is_holding(other_cash) && atm.inserted_cash == 50, "Another user's cash must not enter an authenticated session.")
	var/obj/item/card/credit/other_card = allocate(/obj/item/card/credit, other)
	allocated += other_card.registered_account
	atm.item_interaction(other, other_card, list())
	atm.ui_close(other)
	TEST_ASSERT(atm.selected_card == card && atm.is_authenticated(customer), "An unrelated swipe or UI close must not hijack or reset the current session.")

/datum/unit_test/atm_auth/card_changes/Run()
	setup()
	action("login", list("bank_pin" = "0420"))
	TEST_ASSERT(atm.is_authenticated(customer), "Card changes must begin with a successful authorization.")
	insert_cash(45)
	TEST_ASSERT_EQUAL(atm.inserted_cash, 45, "Actual cash must enter the original card's session before the swap.")
	var/obj/item/card/credit/replacement = allocate(/obj/item/card/credit, customer)
	var/datum/bank_account/replacement_account = replacement.registered_account
	allocated += replacement_account
	replacement_account.bank_pin = "7777"
	replacement_account.account_balance = 800
	atm.item_interaction(customer, replacement, list())
	TEST_ASSERT(!atm.logged_in && atm.logged_account == replacement_account && !atm.inserted_cash && cash_total() == 45, "Changing cards must require a new PIN and return the previous account's uncommitted cash.")
	action("withdraw", list("withdraw_amount" = "100"))
	action("deposit")
	TEST_ASSERT(account.account_balance == 500 && replacement_account.account_balance == 800, "A replacement account must not inherit the previous authentication or staged deposit.")
	action("login", list("bank_pin" = "7777"))
	TEST_ASSERT(atm.is_authenticated(customer), "The replacement card's own PIN must authenticate.")
	replacement.forceMove(get_turf(atm))
	TEST_ASSERT(!atm.logged_in && !atm.logged_account, "Losing the swiped physical card must immediately clear the session.")
	atm.item_interaction(customer, card, list())
	action("login", list("bank_pin" = "0420"))
	card.set_account(replacement_account)
	action("withdraw", list("withdraw_amount" = "100"))
	TEST_ASSERT(!atm.logged_in && !atm.logged_account && account.account_balance == 500 && replacement_account.account_balance == 800, "Rebinding the same physical card to another account must invalidate authorization before a transaction.")

/datum/unit_test/atm_auth/session_end/Run()
	setup()
	action("login", list("bank_pin" = "0420"))
	TEST_ASSERT(atm.is_authenticated(customer), "Cleanup tests must begin with an authenticated session.")
	insert_cash(40)
	TEST_ASSERT_EQUAL(atm.inserted_cash, 40, "The close test must refund money actually accepted by the ATM.")
	atm.ui_close(customer)
	TEST_ASSERT(!atm.logged_account && !atm.logged_in && !atm.inserted_cash && cash_total() == 40 && account.account_balance == 500, "Closing the UI must log out and refund uncommitted cash once.")
	atm.ui_close(customer)
	TEST_ASSERT_EQUAL(cash_total(), 40, "Repeated cleanup must not duplicate the refund.")
	atm.item_interaction(customer, card, list())
	action("login", list("bank_pin" = "0420"))
	TEST_ASSERT(atm.is_authenticated(customer), "The movement test must start from an active new login.")
	var/turf/origin = get_turf(customer)
	customer.forceMove(locate(origin.x + 3, origin.y, origin.z))
	TEST_ASSERT(!atm.logged_account && !atm.logged_in, "Moving out of physical reach must immediately end the session.")
	customer.forceMove(origin)
	atm.item_interaction(customer, card, list())
	action("login", list("bank_pin" = "0420"))
	TEST_ASSERT(atm.is_authenticated(customer), "The logout test must start from an active new login.")
	SEND_SIGNAL(customer, COMSIG_MOB_LOGOUT)
	TEST_ASSERT(!atm.logged_account && !atm.logged_in, "Losing the user connection must immediately log out.")
	atm.item_interaction(customer, card, list())
	action("login", list("bank_pin" = "0420"))
	TEST_ASSERT(atm.is_authenticated(customer), "The client-transfer test must start from an active new login.")
	connect(customer)
	action("withdraw", list("withdraw_amount" = "100"))
	TEST_ASSERT(!atm.logged_account && !atm.logged_in && account.account_balance == 500, "A different client controlling the same body must not inherit authentication.")
	atm.item_interaction(customer, card, list())
	action("login", list("bank_pin" = "0420"))
	TEST_ASSERT(atm.is_authenticated(customer), "The deletion test must start from an active new login.")
	qdel(card)
	TEST_ASSERT(!atm.logged_account && !atm.logged_in, "Deleting the swiped card must immediately end the session.")
