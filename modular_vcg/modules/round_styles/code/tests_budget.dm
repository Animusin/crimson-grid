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

/// Capacity fixtures isolate their subject from optional account-score policy.
/// The admission-signal test below uses the production budget instead.
/datum/city_antag_budget/test_fixture/entry_denial(datum/mind/mind, list/current_accounts, datum/antagonist/restoring)
	return null

/datum/unit_test/city_round_budget
	abstract_type = /datum/unit_test/city_round_budget
	test_flags = UNIT_TEST_MAP_TEST
#ifdef ROUND_STYLE_TESTS
	test_flags = UNIT_TEST_FOCUS
#endif
	var/datum/city_antag_budget/budget
	var/budget_type = /datum/city_antag_budget/test_fixture
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
	budget = allocate(budget_type)
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

/// Exercise the real global-signal contract without depending on a progression
/// module. This late listener is the synthetic score provider ONLY for its own
/// fixture IDs; it never modifies another account's refusal. The progression
/// module separately tests its signed score calculation and canonical identity.
/datum/unit_test/city_round_budget/admission_signal
	budget_type = /datum/city_antag_budget
	var/list/scores = list()
	var/list/continuations = list()
	var/signal_calls = 0
	var/last_account
	var/datum/job/hunter_job
	var/saved_hunter_positions

/datum/unit_test/city_round_budget/admission_signal/New()
	..()
	RegisterSignal(SSdcs, "city_antagonist_admission", PROC_REF(check_admission))

/datum/unit_test/city_round_budget/admission_signal/Destroy()
	UnregisterSignal(SSdcs, "city_antagonist_admission")
	if(hunter_job)
		hunter_job.current_positions = saved_hunter_positions
	return ..()

/datum/unit_test/city_round_budget/admission_signal/proc/check_admission(datum/source, datum/mind/candidate, continuing, list/denial)
	SIGNAL_HANDLER
	var/identifier = denial["account"]
	if(!(identifier in scores))
		return
	signal_calls++
	last_account = identifier
	continuations[identifier] = continuing
	denial["message"] = !continuing && scores[identifier] < 10 ? "Fixture Respect 10 required for antagonist entry." : null

/datum/unit_test/city_round_budget/admission_signal/Run()
	hunter_job = SSjob.get_job_type(/datum/job/vampire/inquisitor)
	saved_hunter_positions = hunter_job.current_positions
	var/mob/dead/new_player/candidate = lobby_player("City Signal Role", list(hunter_job.title = JP_HIGH))
	var/datum/preferences/preferences = candidate.mock_client.prefs
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/splats], SPLAT_NONE)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/numeric/age], 30)
	var/role_account = budget.account(candidate, candidate.mind)
	candidate.mind.key = "stale-mind-identity"
	scores[role_account] = 9
	var/datum/job/old_role = candidate.mind.assigned_role
	GLOB.city_round_style.finalized = FALSE
	if(budget.can_set_role(candidate.mind, hunter_job))
		Fail("An unfinished round-style vote must not bypass an installed account admission policy.")
	GLOB.city_round_style.finalized = TRUE
	if(SSjob.assign_role(candidate, hunter_job, TRUE, FALSE) || candidate.mind.assigned_role != old_role || hunter_job.current_positions != saved_hunter_positions)
		Fail("A score-provider refusal must stop the actual atomic role boundary even when its caller skips eligibility checks.")
	if(last_account != ckey(candidate.mock_client.ckey) || continuations[role_account])
		Fail("Admission must supply the canonical actual-client account, not a stale mind key or a prospective continuation.")
	if(candidate.IsJobUnavailable(hunter_job.title, latejoin = TRUE) == JOB_AVAILABLE)
		Fail("The actual latejoin eligibility check must reject a new antagonist at score nine.")
	var/old_state = SSticker.current_state
	SSticker.current_state = GAME_STATE_PLAYING
	var/html = candidate.city_villain_choices_html()
	SSticker.current_state = old_state
	if(!findtext(html, "Fixture Respect 10 required") || findtext(html, "city_villain_join="))
		Fail("The actual panel must explain the score refusal and offer no antagonist join link.")
	var/mob/living/carbon/human/actor = player("City Signal Datum", SSjob.get_job_type(/datum/job/vampire/citizen))
	var/datum/mind/actor_mind = actor.mind
	var/datum/job/actor_role = actor_mind.assigned_role
	var/datum/antagonist/refused = allocate(/datum/antagonist/city_budget_probe)
	var/datum/antagonist/added
	var/datum/antagonist/second_added
	var/datum/mind/candidate_mind = candidate.mind
	var/actor_account = budget.account(actor, actor_mind)
	scores[actor_account] = 9
	if(actor_mind.add_antag_datum(refused) || length(actor_mind.antag_datums) || actor_mind.assigned_role != actor_role)
		Fail("A score-provider refusal must stop the real antagonist-datum grant without changing role or owner lists.")
	var/mob/living/carbon/human/npc = allocate(/mob/living/carbon/human/consistent)
	npc.mind_initialize()
	npc.mind.key = null
	var/calls_before_npc = signal_calls
	if(!npc.mind.add_antag_datum(/datum/antagonist/city_budget_probe) || signal_calls != calls_before_npc)
		Fail("An unowned NPC must not acquire an account-score requirement or emit an account admission signal.")
	var/datum/brain_trauma/special/obsessed/trauma = allocate(/datum/brain_trauma/special/obsessed)
	trauma.obsession = npc
	var/calls_before_trauma = signal_calls
	if(actor.gain_trauma(trauma) || !QDELETED(trauma) || actor.has_trauma_type(/datum/brain_trauma/special/obsessed) \
		|| actor_mind.has_antag_datum(/datum/antagonist/obsessed) || signal_calls <= calls_before_trauma)
		Fail("A refused real Obsessed trauma must cleanly abort its brain gain path without a null dereference or leftover trauma.")
	actor.adjust_brute_loss(5)
	var/old_health = actor.health
	var/old_max_health = actor.maxHealth
	if(actor.apply_status_effect(/datum/status_effect/ghoul, 50) || actor.has_status_effect(/datum/status_effect/ghoul) \
		|| actor.health != old_health || actor.maxHealth != old_max_health || HAS_TRAIT(actor, TRAIT_HERETIC_SUMMON))
		Fail("A refused real flesh-ghoul status must leave health, max health, summon traits and status effects unchanged.")
	var/datum/dynamic_ruleset/midround/from_ghosts/paradox_clone/paradox = allocate(/datum/dynamic_ruleset/midround/from_ghosts/paradox_clone)
	if(paradox.assign_role(actor_mind, npc) != FALSE || actor_mind.current != actor)
		Fail("A refused Paradox Clone must fail before copying or transferring the candidate's mind.")
	scores[role_account] = 10
	if(candidate.IsJobUnavailable(hunter_job.title, latejoin = TRUE) != JOB_AVAILABLE || !SSjob.assign_role(candidate, hunter_job, TRUE) || candidate_mind.assigned_role != hunter_job)
		Fail("Score ten must allow the real latejoin eligibility and native atomic role assignment.")
	scores[actor_account] = 10
	added = actor_mind.add_antag_datum(/datum/antagonist/city_budget_probe)
	if(!added || added.owner != actor_mind)
		Fail("Score ten must allow a real antagonist datum with its normal owner assignment.")
	check_stored_admission(actor, added)
	scores[role_account] = 9
	scores[actor_account] = 9
	if(!candidate_mind.add_antag_datum(/datum/antagonist/city_budget_probe))
		Fail("An already admitted role must still receive its outfit antagonist datum after its score drops.")
	second_added = actor_mind.add_antag_datum(/datum/antagonist/city_budget_probe/second)
	actor_mind.set_assigned_role(hunter_job)
	if(!second_added || actor_mind.assigned_role != hunter_job || !continuations[role_account] || !continuations[actor_account])
		Fail("Existing admitted accounts must continue after a score drop without consuming another entry.")
	var/list/counts = budget.totals(budget.accounts())
	if(counts["antagonists"] != 2 || budget.remaining())
		Fail("Roles, repeated datums and an unowned NPC must leave exactly two occupied account slots.")
	var/old_stat = actor.stat
	actor.stat = DEAD
	if(!budget.entry_denial(actor_mind) || continuations[actor_account])
		Fail("A dead former antagonist must not be treated as a live continuing admission.")
	actor.stat = old_stat
	GLOB.city_round_style.style_id = "quiet"
	if(budget.can_gain_antagonist(actor_mind, second_added))
		Fail("Continuation must not reopen antagonist admission during Quiet Night.")

/// Use the real detach/restore and mind-transfer APIs, retaining the same single
/// admission-signal test group and its isolated score provider.
/datum/unit_test/city_round_budget/admission_signal/proc/check_stored_admission(mob/living/carbon/human/actor, datum/antagonist/antagonist)
	var/datum/mind/actor_mind = actor.mind
	var/actor_account = budget.account(actor, actor_mind)
	scores[actor_account] = 9
	if(!antagonist.store_datum() || !budget.entry_denial(actor_mind) || !antagonist.restore_datum(actor_mind))
		Fail("The same admitted living account must restore its sole detached datum after losing Respect, even when the live ledger no longer lists that datum.")
	if(!antagonist.store_datum())
		Fail("The restoration fixture must detach its real datum for a new account.")
	var/mob/living/carbon/human/other = player("City Signal Restore", SSjob.get_job_type(/datum/job/vampire/citizen))
	var/other_account = budget.account(other, other.mind)
	scores[other_account] = 9
	if(antagonist.restore_datum(other.mind) || antagonist.owner || length(other.mind.antag_datums))
		Fail("A different account at nine must not receive a detached real antagonist or mutate its owner list.")
	scores[other_account] = 10
	if(!antagonist.restore_datum(other.mind) || antagonist.owner != other.mind)
		Fail("A different account at ten must pass ordinary admission before receiving the stored datum.")
	if(!antagonist.store_datum() || antagonist.restore_datum(actor_mind))
		Fail("Successful transfer must replace the old continuation proof rather than preserve an earlier account's exception.")
	scores[actor_account] = 10
	if(!antagonist.restore_datum(actor_mind) || !antagonist.store_datum())
		Fail("The original account must pass fresh admission at ten before the dead-body regression.")
	var/mob/living/carbon/human/replacement = allocate(/mob/living/carbon/human/consistent)
	var/datum/client_interface/actor_client = actor.mock_client
	var/old_stat = actor.stat
	actor.stat = DEAD
	actor.mock_client = null
	replacement.mock_client = actor_client
	actor_client.mob = replacement
	GLOB.player_list |= replacement
	actor_mind.transfer_to(replacement)
	scores[actor_account] = 9
	if(antagonist.restore_datum(actor_mind) || antagonist.owner || length(actor_mind.antag_datums))
		Fail("A dead captured body must not grant continuation retroactively after its mind moves to a different live body.")
	actor_mind.transfer_to(actor)
	replacement.mock_client = null
	actor.mock_client = actor_client
	actor_client.mob = actor
	actor.stat = old_stat
	scores[actor_account] = 10
	if(!antagonist.restore_datum(actor_mind))
		Fail("Fresh valid admission must still restore after a denied attempt without losing the stored datum.")
	actor.stat = DEAD
	if(!antagonist.store_datum())
		Fail("The dead-store regression must detach the real datum.")
	actor.stat = old_stat
	scores[actor_account] = 9
	if(antagonist.restore_datum(actor_mind))
		Fail("Storing while already dead must not create a continuation proof that becomes usable after revival.")
	scores[actor_account] = 10
	if(!antagonist.restore_datum(actor_mind))
		Fail("A dead-store refusal must retain the datum for a later fresh valid admission.")

/datum/unit_test/city_round_budget/live_population/Run()
	ordinary_players(13)
	var/mob/living/carbon/human/fighter = player("same_account", SSjob.get_job_type(/datum/job/vampire/hound))
	player("same_account", SSjob.get_job_type(/datum/job/vampire/citizen))
	var/list/counts = budget.totals(budget.accounts())
	if(counts["population"] != 15 || budget.capacity(counts) != 3)
		Fail("Thirteen ordinary accounts and one fighter must weigh 15, even with a second body on the fighter account.")
	fighter.stat = DEAD
	counts = budget.totals(budget.accounts())
	if(counts["population"] != 14 || budget.capacity(counts) != 2)
		Fail("A dead fighter must leave only its live ordinary body, rather than a permanent combat bonus.")
	var/mob/living/disconnected = GLOB.player_list[1]
	disconnected.mock_client = null
	counts = budget.totals(budget.accounts())
	if(counts["population"] != 13)
		Fail("Disconnected bodies must not finance automatic antagonists.")
	GLOB.city_round_style.style_id = "war"
	if(budget.capacity(counts) != 3)
		Fail("War must add floor(weighted non-antagonists/7) to its two base slots.")
	GLOB.city_round_style.style_id = "quiet"
	if(budget.capacity(counts) != 0)
		Fail("Quiet Night must have zero antagonist capacity.")

/datum/unit_test/city_round_budget/base_capacity/Run()
	var/mob/living/carbon/human/first = player("basefirst", null)
	var/mob/living/carbon/human/second = player("basesecond", null)
	if(!first.mind.add_antag_datum(/datum/antagonist/city_budget_probe) || !second.mind.add_antag_datum(/datum/antagonist/city_budget_probe))
		Fail("Two base slots must admit real antagonists without a supporting ordinary population.")
	var/mob/living/carbon/human/third = player("basethird", null)
	if(third.mind.add_antag_datum(/datum/antagonist/city_budget_probe))
		Fail("The two base slots must not admit a third antagonist without supporting population.")
	GLOB.city_round_style.style_id = "war"
	ordinary_players(6)
	if(third.mind.add_antag_datum(/datum/antagonist/city_budget_probe))
		Fail("A War conversion must not count its own ordinary weight toward the seven-account threshold.")
	ordinary_players(1, "warthreshold")
	if(!third.mind.add_antag_datum(/datum/antagonist/city_budget_probe))
		Fail("Seven other ordinary accounts must open War's third antagonist slot.")
	var/list/counts = budget.totals(budget.accounts())
	if(counts["population"] != 7 || counts["antagonists"] != 3 || budget.remaining())
		Fail("War's third admission must consume its new slot and remove the candidate's funding weight.")

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
	for(var/index in 1 to 2)
		var/mob/living/carbon/human/other = player("occupied[index]", null)
		if(!other.mind.add_antag_datum(/datum/antagonist/city_budget_probe))
			Fail("Fifteen ordinary accounts must support three shared slots including the two base slots.")
	var/list/counts = budget.totals(budget.accounts())
	if(counts["population"] != 15 || counts["antagonists"] != 3 || budget.remaining() != 0)
		Fail("A job and multiple antagonist datums must occupy one shared account slot and never also finance themselves.")
	var/mob/living/carbon/human/hunter = player("hunter", null)
	var/datum/job/old_role = hunter.mind.assigned_role
	if(hunter.mind.set_assigned_role(SSjob.get_job_type(/datum/job/vampire/inquisitor)))
		Fail("A hunter must not bypass a shared pool already filled by Sabbat and other antagonists.")
	if(hunter.mind.assigned_role != old_role)
		Fail("A refused hunter role must preserve the original character role.")
	ordinary_players(14, "extra") // Conversion would leave only 29 ordinary accounts.
	hunter.mind.set_assigned_role(SSjob.get_job_type(/datum/job/vampire/inquisitor))
	counts = budget.totals(budget.accounts())
	if(counts["population"] != 30 || counts["antagonists"] != 3)
		Fail("A fourth antagonist must still be refused at only 29 prospective ordinary accounts.")
	ordinary_players(1, "threshold")
	hunter.mind.set_assigned_role(SSjob.get_job_type(/datum/job/vampire/inquisitor))
	counts = budget.totals(budget.accounts())
	if(counts["population"] != 30 || counts["antagonists"] != 4)
		Fail("At thirty ordinary accounts, a hunter, Sabbat member and other antagonists must share exactly four slots.")

/datum/unit_test/city_round_budget/conversion_threshold/Run()
	for(var/index in 1 to 2)
		var/mob/living/carbon/human/base_member = player("base[index]", null)
		if(!base_member.mind.add_antag_datum(/datum/antagonist/city_budget_probe))
			Fail("The conversion threshold fixture must occupy both base antagonist slots.")
	ordinary_players(14)
	var/mob/living/carbon/human/convert = player("convert", SSjob.get_job_type(/datum/job/vampire/citizen))
	if(convert.mind.add_antag_datum(/datum/antagonist/city_budget_probe))
		Fail("A third conversion at 15 ordinary accounts must fail: it would leave only 14 to fund the first scaled slot.")
	ordinary_players(1, "newarrival")
	if(!convert.mind.add_antag_datum(/datum/antagonist/city_budget_probe))
		Fail("A real conversion must succeed when fifteen other ordinary accounts remain.")
	var/list/counts = budget.totals(budget.accounts())
	if(counts["population"] != 15 || counts["antagonists"] != 3)
		Fail("A converted account must move out of the funding population atomically.")

/datum/unit_test/city_round_budget/latejoin_and_limits/Run()
	ordinary_players(15)
	var/datum/job/managed = allocate(/datum/job/city_budget_probe/managed)
	var/mob/dead/new_player/first = lobby_player("firstjoin", list())
	var/mob/dead/new_player/second = lobby_player("secondjoin", list())
	var/mob/dead/new_player/third = lobby_player("thirdjoin", list())
	var/mob/dead/new_player/fourth = lobby_player("fourthjoin", list())
	if(!SSjob.assign_role(first, managed, TRUE, FALSE) || !SSjob.assign_role(second, managed, TRUE, FALSE) \
		|| !SSjob.assign_role(third, managed, TRUE, FALSE) || SSjob.assign_role(fourth, managed, TRUE, FALSE) || managed.current_positions != 3)
		Fail("Four real latejoin assignments must compete for three slots, even with eligibility checks skipped by their caller.")
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
	if(budget.job_limit(pack, TRUE) != 0 || budget.can_set_role(fourth.mind, pack))
		Fail("Shared scaling must never reopen a map/config-disabled job.")

/datum/unit_test/city_round_budget/pure_assignment/Run()
	ordinary_players(15)
	var/datum/job/job = allocate(/datum/job/city_budget_probe/managed)
	var/mob/dead/new_player/candidate = lobby_player("purecandidate", list())
	budget.begin_assignment(TRUE)
	budget.defer_jobs = FALSE // The same final phase used by finish_deferred_assignments.
	if(!SSjob.assign_role(candidate, job, FALSE, FALSE) || budget.remaining() != 2)
		Fail("A pure trial must reserve its assigned antagonist while that trial is running.")
	budget.end_assignment()
	if(budget.assignment_active || length(budget.deferred_players) || budget.remaining() != 3)
		Fail("A finished pure Dynamic trial must leave no reservations, even before reset_occupations discards its provisional roles.")
	budget.reset_assignment()
	candidate.mind.set_assigned_role(SSjob.get_job_type(/datum/job/unassigned))
	budget.begin_assignment(FALSE)
	budget.defer_jobs = FALSE
	if(!SSjob.assign_role(candidate, job, FALSE, FALSE))
		Fail("The real assignment must remain available after a discarded pure trial.")
	budget.end_assignment()
	if(budget.remaining() != 2)
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
	var/mob/dead/new_player/third = lobby_player("deferredthird", list(managed.title = JP_HIGH, ordinary.title = JP_LOW))
	var/mob/dead/new_player/fourth = lobby_player("deferredfourth", list(managed.title = JP_HIGH, ordinary.title = JP_LOW))
	budget.begin_assignment(FALSE)
	if(!budget.defer_player(first, JP_HIGH) || !budget.defer_player(second, JP_HIGH) \
		|| !budget.defer_player(third, JP_HIGH) || !budget.defer_player(fourth, JP_HIGH) || SSjob.assign_role(first, managed, FALSE, FALSE))
		Fail("Requested antagonist jobs must wait for normal jobs, and direct assignment must not bypass that phase.")
	budget.finish_deferred_assignments(TRUE)
	if(first.mind.assigned_role != managed || second.mind.assigned_role != managed || third.mind.assigned_role != managed \
		|| fourth.mind.assigned_role != ordinary || managed.current_positions != 3 || ordinary.current_positions != 1)
		Fail("After ordinary population is known, three preferred antagonists and one ordinary fallback must fit the shared budget.")
	budget.end_assignment()

#endif
