# Account progression MVP

PQ, RCP and Karma persist in data/player_quality.json using the existing JSON
database and backup recovery. Back up this file with server data. Version-one/two
records retain scores and giver ledgers, acquiring zero Karma if absent. The next
update writes version three. No historical commendation backfill is automatic.
Scores belong to accounts, not character slots. Character IDs, edit permissions,
learned discipline identities and Path history live in separate character records
inside the same account data. Surgery patient-pair ledgers are account-scoped.

## Respect and Kindred age

All three components can be negative. RCP contributes at one quarter weight:

    Respect = PQ + RCP / 4 + Karma

Examples: (3,4,0) gives 4; (-3,-4,0) gives -4; (3,4,-5) gives -1. Negative
components subtract directly; negative Respect remains negative. The UI
rounds to two decimals; access checks use the unrounded score.

| Age since Embrace | Existing discipline tier | Default minimum Respect |
| --- | --- | --- |
| 0–10 | Fledgling | 10 |
| 11–100 | Neonate | 20 |
| 101–200 | Ancilla | 40 |
| 201–1000 | Elder | 60 |

Below 10 Respect, Kindred are unavailable, including age-zero fledglings. Mortals
and ghouls remain available. The four thresholds are configurable. The UI blocks
Kindred selection and over-cap age edits; jobs reject both unavailable Kindred
and older saved sheets. Direct splat preference application also refuses an
unavailable Kindred. Spawn age caps do not rewrite saved age. Discipline budgets
use the same nonnegative effective age. Ghoul, kinfolk and Corax selection is unaffected;
switching back to Kindred restores the gate. Existing generation, clan, job-age,
trust and diablerist policies remain. A midround score loss changes future
selection, not the existing character's age. Character locks and Path persistence
are described below. Existing discipline budgets and in-round Renown growth remain.

## Antagonist admission

With the separate city round-style/antagonist policy installed, first admission to
any antagonist role requires 10 Respect. Its threshold is independent of Kindred
age and Garou rank. A score loss does not expel an already admitted living
antagonist. NPC minds without an account retain the existing behavior.

This module listens to the optional `city_antagonist_admission` global signal:
arguments are the candidate mind, a trusted continuing-admission flag and a mutable
denial list. The caller supplies its canonical current-client ID in
`denial["account"]`; simple callers may fall back to the mind key. This identity is
constructed on the server, never accepted from UI parameters. The hook supplies
`denial["message"]` when a new account is below the
threshold, preserving any earlier denial. The round-style policy owns emission,
the atomic admission decision and its UI; neither PR has a compile dependency on
the other. Without that caller installed, this hook does not change core roles.

## Garou rank access

Garou have an existing progression ladder: their Auspice calculates rank from
Honor, Glory and Wisdom. Respect limits this starting rank rather than adding
a new age or power system:

| Existing Garou rank | Default minimum Respect |
| --- | --- |
| Cub (0) | 10 |
| Cliath (1) | 20 |
| Fostern (2) | 30 |
| Adren (3) | 40 |
| Athro (4) | 50 |
| Elder (5) | 60 |

Below 10 Respect Garou selection is unavailable. Changes to Renown and Auspice
cannot raise a sheet above its account cap; lowering an old over-limit sheet is
allowed even if several slider reductions are needed. The profile shows both
the saved and allowed ranks. Job eligibility independently rejects unavailable
Garou and over-rank saved/forged sheets. Direct preference application limits
only the body's starting rank, preserving the saved Renown values. Karma respec
previews show the resulting Garou access too.

These checks apply to character selection and starting preference application.
Losing Respect does not lower an existing live Garou, and ordinary in-round
`adjust_renown` gains and losses remain unchanged. Corax use parts of the common
Renown API but have no implemented Auspice/rank ladder, so they receive no new
gate. Humans, ghouls and kinfolk stay free. The defined Legend rank is not
returned by the current Garou calculators and gains no invented seventh tier.

There is no Garou gift point budget in this build: breed, tribe and Auspice grant
fixed gift lists. This change does not invent a gift allocation system, gate
Rage/Gnosis reserves, or activate the old unused `minimal_renown_rank` job field.

## Character records and paid edits

A saved GUID identifies a character independently of its editable name or slot
number. The first successful player possession of an actual job body creates
and locks its account-owned record; opening preferences, rendering a preview or
failing to possess a constructed body does not create that lock. Settings
remain free before that first spawn. Cosmetic edits remain free afterward,
including appearance, clothing, voice and flavor text. Mechanical fields such as
splat, clan, generation and morality do not become cosmetic merely because the
existing interface places them beside appearance controls.

The lobby's Character record panel offers stats and abilities, including quirks
and discipline allocation, for 3 Karma, or other editable identity settings for
5 Karma. Upgrading an unused stats permission
to full permission costs another 2, for a total of 5. The checked debit and
permission are saved atomically; insufficient funds or repeated purchases do not
charge again. Permission lasts until the next successful player possession,
which locks the record again and consumes it; previews and failed spawns consume
nothing. The purchase edits a future sheet rather than the current live body.
The panel shows the resulting Respect and age access before
purchase: spent Karma immediately reduces Respect, so ordinary age, clan and
other validity checks still apply.

Respec does not erase learned Paths or disciplines. Successful existing discipline
teaching persists the discipline's identity at level zero. It remains available
as a choice after a discipline reset; positive allocations still use the ordinary
age/clan budget. This creates neither free dots nor a second XP pool. A paid full
edit also does not bypass the current character's saved Path and initiation rules.
New learned identities and Path progress follow the existing canonical-round save
policy: the player must control the original body, with its original slot and
matching character GUID selected. EORG, noncanon characters and transferred bodies
cannot write this progress. Existing discipline teaching and live morality changes
still run; saved knowledge remains intact. A noncanon Path lesson is not credited,
and initiation rechecks eligibility after its vulnerable interval.
Deleting an old character and creating a replacement is free. Deletion removes
that character's record and learned Paths/disciplines; the replacement receives
a fresh GUID and starts without those learned identities. Account PQ, RCP and
Karma remain. The new sheet is free until its first successful spawn and still
uses the account's ordinary Respect access checks.
Deleting a sheet already used in the current round requires returning to the
lobby first.

## Persistent Paths and initiation

At the first actual Kindred spawn, the authoritative job supplies the faction.
Alternative initial Paths require Elder age (over 200 years since Embrace) or a
Sabbat role; other Kindred begin on Humanity. Existing selection restrictions
still apply. The current Path, its rating, learned history and training persist
with the character. Later preference changes cannot replace the saved Path.
Real morality changes update its persisted rating; this PR does not rewrite sin
tables or add new automatic growth rewards.

IC → Offer Path Lesson lets an adjacent teacher offer their current Path to
another Kindred. Both players must be connected, capable and on different
accounts, and the student must accept. The teacher must have at least one dot
and know that Path. One mutually agreed lesson counts per round. Initiation
requires three distinct rounds with the same teacher account and character ID;
training cannot be replaced by offering a different teacher or Path. There is no
extra time-spent grind attached to lesson credits.

During training the student must abandon the original Path through an actual
negative morality event reaching zero. Lessons never manufacture degeneration,
protect a minimum rating or lower morality for free. Once the lessons and real
renunciation are complete, the same valid nearby teacher initiates a 15-second
frenzy. The teacher rolls Charisma + Leadership at difficulty 6. Its saved result
sets the new Path to 1–3 dots, capped by the teacher's current rating. Interrupted
attempts retain both lessons and that roll; retrying requires the same teacher
and does not reroll. Completion persists the new Path and clears training. The
lesson count, frenzy duration and difficulty are configurable defaults.

## PQ and RCP

After a round, OOC → Commend player permits one other eligible account. Both need
five active minutes; lobby-only accounts, brief logins, self-votes and repeat
submissions are rejected. Death/disconnection preserves earned eligibility.
Unique list entries disambiguate duplicate character names. The first lifetime
praise from a giver adds 1 PQ while the recipient is below 100 PQ; repeat praise
then only increments its recorded count. At or above 100 PQ, a new giver adds
0.5 and a repeat giver adds 0.05. Automatic praise saturates at 500 PQ. These
bands follow Ratwood-2.0's `add_commend` rework; the older Ratwood-Keep donor only
rewarded the first lifetime commend. Admin reductions retain giver counts, and
admin overrides/existing scores are not clamped by the automatic ceiling.
Alternative accounts are not identified by IP.

One RCP grant follows a completed round after 45 connected, living, non-AFK
minutes: default 1 for humans, 0.5 for ghouls/kinfolk, 0 for other supernaturals.
Ten-second samples preserve category/time splits through transformation. Ghosts,
disconnection and AFK time do not accrue; crashes grant no partial RCP. Duplicate
round-end callbacks cannot repeat a grant. Leadership has no extra bonus yet.
The donor's additional RCP-to-PQ conversion is not imported: RCP already enters
Respect directly at one quarter weight, so it is not counted again inside PQ.

OOC → Player quality shows all components, Respect and the Kindred age cap.
R_ADMIN's Adjust player quality can view another account, then adjust any
component with a required reason and an administrative audit log/message.
The store also exposes a checked Karma debit with a persistent optional
transaction token. Exact retries return success without charging again; invalid
requests, insufficient funds or conflicting retries leave the record unchanged.
Character unlocks persist payment and edit permission together in one
account-record write.

## Karma events

| Source | Default | Account limits |
| --- | --- | --- |
| Attributed death of a player character outside a matching murder objective | −1 | Once per real death; no penalty cap |
| Distinct locally witnessed say-log/custom-emote text | +0.1 | 1500 characters, 5-minute interval, at most 10 awards/round |
| Medical packs restore another player | +0.1 | 20 real limb damage, once/patient/round; shares 10 medical awards/round |
| Completed restorative surgery on another player | +0.1 / (1 + prior pair awards) | Persistent 1-hour surgeon/patient cooldown; shares 10 medical awards/round |
| Defense of a contested business | +1 | Once/point/opposing faction/round, at most 2 awards/round |

Karma saves during play; RCP saves at round end. Current-round event tokens
prevent duplicate persistence, including database reloads. Account limits survive
reconnects/body transfers and subsystem recovery.

Kills use actual non-stamina item/projectile, unarmed, thrown, overfeeding and
known-owner direct offensive discipline damage. Bound animal/basic-mob attacks
credit the explicit summoner rather than an NPC account. Beastmaster minions,
guardians, heretic monsters/stargazers and soulstone-created constructs use their
real binding APIs; release clears that binding. Ownership changes the damage
actor only: killing or treating an owned NPC does not count as affecting its
player owner. Explicit living-player executions
also identify the actor: Baali sacrifices, diablerie/drinking dry, perfect-gargoyle
ritual consumption and destruction of a Serpentis heart urn. Processing an already
dead corpse does not count again. Self-execution rituals clear earlier attribution.
Player mind/key identifies both
accounts, including disconnected characters and roles without a human job. NPC
minds without a player key do not count. Death settles next tick so a synchronous
lethal hit can supply its actual source; account data survives gibbing. Self-harm
clears an earlier opponent's attribution; corpse hits cannot create new events;
revival clears previous-life attribution without undoing a real kill. Explicit
suicides and hits older than two minutes do not penalize a prior attacker. This is
a direct-damage heuristic: poison, traps and uninstrumented indirect deaths may
remain unassigned. Faction war alone does not waive a penalty.

An explicit antagonist murder objective waives the penalty only for its matching
target or typed victim set. A bound minion's own explicit goal authorizes that
minion's action under its owner's account; the owner's direct attacks and sibling
summons cannot use that minion-specific authorization. Other player kills still
cost Karma. Victim identity and eligible objectives are captured at death, so
gibbing or later retargeting
cannot rewrite the result. Finite sacrifice objectives claim quota slots at
settlement and observe trusted existing progress; simultaneous deaths cannot
turn the last slot into unlimited waivers. Custom text, protection/theft goals
and antagonist status alone grant no exception. Positive Karma for completing
objectives remains design-only. The full objective and summon audit is in
[EVENT_AUDIT.md](EVENT_AUDIT.md).

Text rewards require an active conscious speaker and another active conscious
player visible locally. Forced speech, solo text, exact normalized repeats and
messages shorter than 20 characters earn nothing. Each message contributes at
most 300 characters; hashes/counts are bounded. Speech/custom emotes share the
allowance. This measures bounded activity, not literary quality; semantically
repeated text and collusion are not fully solved.

Healing uses actual restored limb damage, not item use count or nominal power.
Self-treatment, dead/NPC patients, no-op use, recent self-harm and a patient
previously harmed by the healer earn nothing. Surgery runs after successful
effects of a notable restorative operation and requires measurable benefit:
organ repair, restoration of a missing/damaged limb, surgical revival, moth-wing
repair or removal of toxin reagent by stomach pumping. The patient must be a
live connected player after completion. Failed, harmful, preparatory, cosmetic
and no-op operations earn nothing. Organ insertion and routine non-notable
bone/wound steps are outside this MVP award hook.

Surgery uses the same self-harm/healer-harm checks and ten-medical-awards round
ceiling as packs. Its account-pair repeat count and one-hour real-time cooldown
survive reconnects, rounds and database reloads; reward and ledger update commit
atomically. Rewards round to cents and stop if the result becomes zero. Passive
regeneration, arbitrary reagents, blood bags and nonsurgical revival have no
positive attribution yet. Third-party injure/heal collusion remains a limitation.

The business PR emits city_business_defended(defender, territory_id, attack_token,
attacking_faction) after ten seconds of eligible physical defense or when a
defender interrupts an existing hold. The listener checks an active conscious
player and account limits. The string signal keeps each PR independently
buildable; both are needed for defense rewards. Taxi, cleaning and cargo rewards
remain proposals pending meaningful outcome rules.

## Configuration

    PLAYER_QUALITY_ENABLED 1
    RCP_HUMAN_REWARD 1
    RCP_GHOUL_REWARD 0.5
    RCP_KINFOLK_REWARD 0.5
    RCP_MINIMUM_MINUTES 45
    PQ_COMMEND_SOFTCAP 100
    PQ_COMMEND_CAP 500
    KARMA_PLAYER_KILL_PENALTY 1
    KARMA_ROLEPLAY_REWARD 0.1
    KARMA_HELP_REWARD 0.1
    KARMA_DEFENSE_REWARD 1
    RESPECT_ANTAGONIST_THRESHOLD 10
    RESPECT_AGE_GATES 1
    RESPECT_FLEDGLING_THRESHOLD 10
    RESPECT_NEONATE_THRESHOLD 20
    RESPECT_ANCILLA_THRESHOLD 40
    RESPECT_ELDER_THRESHOLD 60
    RESPECT_GAROU_RANK_GATES 1
    RESPECT_GAROU_CUB_THRESHOLD 10
    RESPECT_GAROU_CLIATH_THRESHOLD 20
    RESPECT_GAROU_FOSTERN_THRESHOLD 30
    RESPECT_GAROU_ADREN_THRESHOLD 40
    RESPECT_GAROU_ATHRO_THRESHOLD 50
    RESPECT_GAROU_ELDER_THRESHOLD 60
    PATH_TRAINING_ROUNDS 3
    PATH_INITIATION_FRENZY_SECONDS 15
    PATH_TEACHING_DIFFICULTY 6

PLAYER_QUALITY_ENABLED 0 disables scoring/gates. RESPECT_AGE_GATES 0 disables only
Kindred age gates; RESPECT_GAROU_RANK_GATES 0 disables only Garou starting-rank
gates. Setting a Karma source to zero disables its award value.

PQ/RCP draw on Animusin/Ratwood-2.0's playerquality.dm, client_procs.dm and
roundend.dm. The commend policy was checked against local Ratwood-2.0 at
`addbd953bf8bde05ece1153fc2c9ae2e53e6f8c5` and Ratwood-Keep at
`2263360e980f206659de86cf23db66f4d16c920a`; original code remains AGPL-3.0.
Old Animusin/World-of-Darkness-13 accumulated total_erp in living_say.dm
and awarded XP in city_time.dm; this port uses bounded Karma. Focused engine tests
(UNIT_TESTS, PLAYER_QUALITY_TESTS) cover persistence, weighted arithmetic, donor
commend bands, automatic saturation, idempotent checked debits,
RCP, contribution limits, actual lethal damage, summon ownership, target/quota
exceptions (including a minion's own actor-specific orders), same-tick corpse
dismemberment, self-harm/revival, medical packs, surgical completion and persisted
cooldowns, character edit accounting, age gates, Garou rank/selection/job/direct
application gates, Auspice-switch bypasses, Corax/kinfolk exclusions, unaffected
live Renown growth, Path training and optional
business integration. Test definitions describe coverage; compilation/runtime
results must be recorded for the exact tested source. See
[DECISIONS.md](DECISIONS.md).
