#if defined(UNIT_TESTS) || defined(SPACEMAN_DMM)

/datum/antagonist/city_budget_probe
	name = "capacity probe"
	silent = TRUE
	ui_name = null
	replace_banned = FALSE

/datum/antagonist/city_budget_probe/second

/datum/antagonist/city_budget_probe/fake
	antag_flags = ANTAG_FAKE

/// Excluded from automatic job discovery, but admitted explicitly by the test.
/datum/job/city_budget_probe
	abstract_type = /datum/job/city_budget_probe
	title = "Budget ordinary fixture"
	job_flags = NONE
	spawn_positions = -1
	total_positions = -1

/datum/job/city_budget_probe/managed
	abstract_type = /datum/job/city_budget_probe/managed
	title = "Budget antagonist fixture"
	faction = FACTION_SABBAT
	spawn_positions = 10
	total_positions = 10

/datum/unit_test/city_round_budget
	abstract_type = /datum/unit_test/city_round_budget
	test_flags = UNIT_TEST_MAP_TEST
#ifdef ROUND_STYLE_TESTS
	test_flags = UNIT_TEST_FOCUS
#endif
	var/datum/city_antag_budget/budget
	var/datum/city_antag_budget/saved_budget
	var/saved_style
	var/saved_finalized
	var/list/saved_players
	var/list/saved_lobby
	var/list/saved_unassigned
	var/list/saved_jobs

/datum/unit_test/city_round_budget/New()
	..()
	saved_budget = GLOB.city_antag_budget
	budget = allocate(/datum/city_antag_budget)
	GLOB.city_antag_budget = budget
	saved_style = GLOB.city_round_style.style_id
	saved_finalized = GLOB.city_round_style.finalized
	GLOB.city_round_style.style_id = "eternal"
	GLOB.city_round_style.finalized = TRUE
	saved_players = GLOB.player_list
	saved_lobby = GLOB.new_player_list
	saved_unassigned = SSjob.unassigned
	saved_jobs = SSjob.joinable_occupations
	GLOB.player_list = list()
	GLOB.new_player_list = list()
	SSjob.unassigned = list()

/datum/unit_test/city_round_budget/Destroy()
	GLOB.city_antag_budget = saved_budget
	GLOB.city_round_style.style_id = saved_style
	GLOB.city_round_style.finalized = saved_finalized
	GLOB.player_list = saved_players
	GLOB.new_player_list = saved_lobby
	SSjob.unassigned = saved_unassigned
	SSjob.joinable_occupations = saved_jobs
	return ..()

/datum/unit_test/city_round_budget/proc/player(identifier, datum/job/job)
	var/mob/living/carbon/human/body = allocate(/mob/living/carbon/human/consistent)
	body.mind_initialize()
	body.mock_client = allocate(/datum/client_interface, identifier)
	body.mock_client.mob = body
	body.mind.key = identifier
	GLOB.player_list |= body
	if(job)
		body.mind.set_assigned_role(job)
	return body

/datum/unit_test/city_round_budget/proc/ordinary_players(amount, prefix = "ordinary")
	for(var/index in 1 to amount)
		player("[prefix][index]", SSjob.get_job_type(/datum/job/vampire/citizen))

/datum/unit_test/city_round_budget/proc/lobby_player(identifier, list/preferences)
	var/mob/dead/new_player/player = allocate(/mob/dead/new_player)
	player.mind_initialize()
	player.mock_client = allocate(/datum/client_interface, identifier)
	player.mock_client.mob = player
	player.mock_client.prefs = allocate(/datum/preferences, player.mock_client)
	player.mock_client.prefs.job_preferences = preferences
	player.mind.key = identifier
	player.mind.set_assigned_role(SSjob.get_job_type(/datum/job/unassigned))
	player.ready = PLAYER_READY_TO_PLAY
	GLOB.new_player_list |= player
	SSjob.unassigned |= player
	return player

/datum/unit_test/city_round_budget/live_population/Run()
	ordinary_players(13)
	var/mob/living/carbon/human/fighter = player("same_account", SSjob.get_job_type(/datum/job/vampire/hound))
	player("same_account", SSjob.get_job_type(/datum/job/vampire/citizen))
	var/list/counts = budget.totals(budget.accounts())
	if(counts["population"] != 15 || budget.capacity(counts) != 1)
		Fail("Thirteen ordinary accounts and one fighter must weigh 15, even with a second body on the fighter account.")
	fighter.stat = DEAD
	counts = budget.totals(budget.accounts())
	if(counts["population"] != 14 || budget.capacity(counts) != 0)
		Fail("A dead fighter must leave only its live ordinary body, rather than a permanent combat bonus.")
	var/mob/living/disconnected = GLOB.player_list[1]
	disconnected.mock_client = null
	counts = budget.totals(budget.accounts())
	if(counts["population"] != 13)
		Fail("Disconnected bodies must not finance automatic antagonists.")
	GLOB.city_round_style.style_id = "war"
	if(budget.capacity(counts) != 1)
		Fail("War must use floor(weighted non-antagonists/7), without a flat allowance.")
	GLOB.city_round_style.style_id = "quiet"
	if(budget.capacity(counts) != 0)
		Fail("Quiet Night must have zero antagonist capacity.")

/datum/unit_test/city_round_budget/quiet_and_classification/Run()
	var/mob/living/carbon/human/actor = player("quiet_actor", SSjob.get_job_type(/datum/job/vampire/citizen))
	GLOB.city_round_style.style_id = "quiet"
	var/datum/job/old_role = actor.mind.assigned_role
	for(var/job_type in list(/datum/job/vampire/sabbatductus, /datum/job/vampire/sabbatpriest, /datum/job/vampire/sabbatpack, \
		/datum/job/vampire/voivode, /datum/job/vampire/bogatyr, /datum/job/vampire/zadruga, \
		/datum/job/vampire/abbe, /datum/job/vampire/condottieri, /datum/job/vampire/inquisitor, /datum/job/vampire/novice))
		var/datum/job/job = SSjob.get_job_type(job_type)
		if(!budget.managed_job(job) || actor.mind.set_assigned_role(job) || actor.mind.assigned_role != old_role || budget.job_limit(job, TRUE) != 0)
			Fail("Quiet Night must refuse [job_type] through the actual mind setter, preserve the old role, and hide latejoin capacity.")
	if(actor.mind.add_antag_datum(/datum/antagonist/city_budget_probe))
		Fail("Quiet Night must stop the real generic antagonist grant boundary.")
	if(!actor.mind.add_antag_datum(/datum/antagonist/city_budget_probe/fake))
		Fail("Non-antagonist helper datums marked ANTAG_FAKE must retain their normal behavior.")
	if(budget.fighter_job(SSjob.get_job_type(/datum/job/vampire/sweeper)) || budget.fighter_job(SSjob.get_job_type(/datum/job/vampire/baron)) \
		|| !budget.fighter_job(SSjob.get_job_type(/datum/job/vampire/sheriff)) || !budget.fighter_job(SSjob.get_job_type(/datum/job/vampire/bruiser)))
		Fail("The extra combatant weight must be limited to Sheriff, Hound and Bruiser.")

/datum/unit_test/city_round_budget/shared_grants/Run()
	ordinary_players(15)
	var/mob/living/carbon/human/member = player("member", null)
	var/datum/job/pack = SSjob.get_job_type(/datum/job/vampire/sabbatpack)
	member.mind.set_assigned_role(pack)
	if(member.mind.assigned_role != pack || !member.mind.add_antag_datum(/datum/antagonist/city_budget_probe) \
		|| !member.mind.add_antag_datum(/datum/antagonist/city_budget_probe/second))
		Fail("A paid Sabbat job must accept its outfit datum and a second datum without charging the same account twice.")
	var/list/counts = budget.totals(budget.accounts())
	if(counts["population"] != 15 || counts["antagonists"] != 1 || budget.remaining() != 0)
		Fail("A job and multiple antagonist datums must occupy one shared account slot and never also finance themselves.")
	var/mob/living/carbon/human/hunter = player("hunter", null)
	var/datum/job/old_role = hunter.mind.assigned_role
	if(hunter.mind.set_assigned_role(SSjob.get_job_type(/datum/job/vampire/inquisitor)))
		Fail("A hunter must not bypass the slot already occupied by a Sabbat member.")
	if(hunter.mind.assigned_role != old_role)
		Fail("A refused hunter role must preserve the original character role.")
	ordinary_players(14, "extra") // The prospective hunter leaves 30 ordinary accounts.
	hunter.mind.set_assigned_role(SSjob.get_job_type(/datum/job/vampire/inquisitor))
	counts = budget.totals(budget.accounts())
	if(counts["population"] != 30 || counts["antagonists"] != 1)
		Fail("A second antagonist must still be refused at only 29 prospective ordinary accounts.")
	ordinary_players(1, "threshold")
	hunter.mind.set_assigned_role(SSjob.get_job_type(/datum/job/vampire/inquisitor))
	counts = budget.totals(budget.accounts())
	if(counts["population"] != 30 || counts["antagonists"] != 2)
		Fail("At thirty ordinary accounts, a hunter and a Sabbat member must share exactly two slots.")

/datum/unit_test/city_round_budget/conversion_threshold/Run()
	ordinary_players(14)
	var/mob/living/carbon/human/convert = player("convert", SSjob.get_job_type(/datum/job/vampire/citizen))
	if(convert.mind.add_antag_datum(/datum/antagonist/city_budget_probe))
		Fail("Conversion at 15 total ordinary accounts must fail: it would leave only 14 to support the antagonist.")
	ordinary_players(1, "newarrival")
	if(!convert.mind.add_antag_datum(/datum/antagonist/city_budget_probe))
		Fail("A real conversion must succeed when fifteen other ordinary accounts remain.")
	var/list/counts = budget.totals(budget.accounts())
	if(counts["population"] != 15 || counts["antagonists"] != 1)
		Fail("A converted account must move out of the funding population atomically.")

/datum/unit_test/city_round_budget/latejoin_and_limits/Run()
	ordinary_players(15)
	var/datum/job/managed = allocate(/datum/job/city_budget_probe/managed)
	var/mob/dead/new_player/first = lobby_player("firstjoin", list())
	var/mob/dead/new_player/second = lobby_player("secondjoin", list())
	if(!SSjob.assign_role(first, managed, TRUE, FALSE) || SSjob.assign_role(second, managed, TRUE, FALSE) || managed.current_positions != 1)
		Fail("Two real latejoin assignments must compete for one slot, even with eligibility checks skipped by their caller.")
	var/datum/job/pack = allocate(/datum/job/vampire/sabbatpack)
	pack.current_positions = 3
	pack.spawn_positions = 3
	pack.total_positions = 3
	if(budget.job_limit(pack, TRUE) != 3)
		Fail("A filled shared budget must expose no extra latejoin pack places.")
	ordinary_players(15, "newpopulation")
	if(budget.job_limit(pack, TRUE) != 4)
		Fail("Rank-and-file pack capacity must grow past its old fixed three places when the shared budget grows.")
	var/datum/job/leader = allocate(/datum/job/city_budget_probe/managed)
	leader.total_positions = 1
	leader.spawn_positions = 1
	if(budget.job_limit(leader, TRUE) != 1)
		Fail("Leadership must retain its native ceiling instead of scaling like pack membership.")
	pack.total_positions = 0
	pack.spawn_positions = 0
	if(budget.job_limit(pack, TRUE) != 0 || budget.can_set_role(second.mind, pack))
		Fail("Shared scaling must never reopen a map/config-disabled job.")

/datum/unit_test/city_round_budget/pure_assignment/Run()
	ordinary_players(15)
	var/datum/job/job = allocate(/datum/job/city_budget_probe/managed)
	var/mob/dead/new_player/candidate = lobby_player("purecandidate", list())
	budget.begin_assignment(TRUE)
	budget.defer_jobs = FALSE // The same final phase used by finish_deferred_assignments.
	if(!SSjob.assign_role(candidate, job, FALSE, FALSE) || budget.remaining() != 0)
		Fail("A pure trial must reserve its assigned antagonist while that trial is running.")
	budget.end_assignment()
	if(budget.assignment_active || length(budget.deferred_players) || budget.remaining() != 1)
		Fail("A finished pure Dynamic trial must leave no reservations, even before reset_occupations discards its provisional roles.")
	budget.reset_assignment()
	candidate.mind.set_assigned_role(SSjob.get_job_type(/datum/job/unassigned))
	budget.begin_assignment(FALSE)
	budget.defer_jobs = FALSE
	if(!SSjob.assign_role(candidate, job, FALSE, FALSE))
		Fail("The real assignment must remain available after a discarded pure trial.")
	budget.end_assignment()
	if(budget.remaining() != 0)
		Fail("Real roundstart assignments must keep their reservation until character transfer.")
	var/old_state = SSticker.current_state
	SSticker.current_state = GAME_STATE_PLAYING
	var/mob/dead/new_player/unfinished = lobby_player("unfinishedordinary", list())
	unfinished.mind.set_assigned_role(SSjob.get_job_type(/datum/job/vampire/citizen))
	var/list/counts = budget.totals(budget.accounts())
	if(counts["population"] != 15 || counts["antagonists"] != 1)
		Fail("After roundstart, an assigned lobby character must never finance antagonists; pending antagonist admission must still reserve its slot.")
	SSticker.current_state = old_state

/datum/unit_test/city_round_budget/deferred_preferences/Run()
	ordinary_players(15)
	var/datum/job/ordinary = allocate(/datum/job/city_budget_probe)
	var/datum/job/managed = allocate(/datum/job/city_budget_probe/managed)
	SSjob.joinable_occupations = list(ordinary, managed)
	var/mob/dead/new_player/first = lobby_player("deferredfirst", list(managed.title = JP_HIGH, ordinary.title = JP_LOW))
	var/mob/dead/new_player/second = lobby_player("deferredsecond", list(managed.title = JP_HIGH, ordinary.title = JP_LOW))
	budget.begin_assignment(FALSE)
	if(!budget.defer_player(first, JP_HIGH) || !budget.defer_player(second, JP_HIGH) || SSjob.assign_role(first, managed, FALSE, FALSE))
		Fail("Requested antagonist jobs must wait for normal jobs, and direct assignment must not bypass that phase.")
	budget.finish_deferred_assignments(TRUE)
	if(first.mind.assigned_role != managed || second.mind.assigned_role != ordinary || managed.current_positions != 1 || ordinary.current_positions != 1)
		Fail("After ordinary population is known, one preferred antagonist and one ordinary fallback must fit a single shared slot.")
	budget.end_assignment()

#endif
