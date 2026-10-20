# Karma event review

This review covers the compiled antagonist objectives and surgical operations in
this branch. Positive Karma for objective completion remains a design question;
there is no objective-completion reward in this implementation.

## Damage actors and victims

Victim identity always uses the actual player mind's account. NPCs, including a
player's owned animals or zombies, do not become player victims by ownership.
Disconnected player bodies still count as players.

Damage actors use explicit summon bindings. The common Darkpack beastmaster API
covers Animalism animals, Necromancy zombies, Abyss guardians/shades, blood
guardians, and the werewolf/gargoyle allies using that API. Releasing or rebinding
a minion updates its owner. The normal animal/basic-mob melee path now passes the
actual actor through damage attribution, including a successful dismemberment.

The additional TG bindings are guardian `set_summoner`/`cut_summoner`, heretic
monster `set_owner` and body-transfer effects, the stargazer's master, and the
creator passed to `make_new_construct`. A construct's generic `construct_master`
field is **not** used as an ownership test: harvesters also use it as a victim or
navigation target. Friendship, faction membership and generic pet affection are
not ownership. An independent slaughter demon may have its creator as its own
assassination target; creation alone does not make it a controlled minion.

Relevant sources:

- `modular_darkpack/modules/beastmaster/code/beastmaster_minion_management.dm`
- `code/modules/mob/living/basic/guardian/guardian.dm`
- `code/modules/antagonists/heretic/heretic_monsters.dm`
- `code/modules/mob/living/basic/heretic/star_gazer.dm`
- `code/modules/antagonists/wizard/equipment/soulstone.dm`
- `code/modules/mob/living/living_defense.dm`

## Murder objective authorization

An antagonist flag never waives a kill penalty. The responsible account must own
an explicit matching objective, directly or through a team it actually belongs
to. A bound minion's own explicit objective also authorizes that minion's damage
under the responsible owner's account. This authorization captures the actual
minion actor, so neither the owner's direct attacks nor a sibling summon inherit
it. The victim and authorized accounts are captured at death, before gibbing,
mind removal or retargeting can change that decision. The actual lethal actor
can still be corrected by the damage callback in the same tick.

| Objective family | Authorized victim set |
| --- | --- |
| `assassinate`, including obsession/jealousy and captain replacement | Explicit target mind; laughter demons' reused hug objective is excluded |
| `mutiny`, `maroon`, `debrain`, `destroy`, cult `sacrifice` | Explicit target mind |
| `accept_no_substitutes` | The objective's actual named clone target |
| Heretic `minor_sacrifice` | Current sacrifice targets, until the finite objective quota is exhausted |
| Heretic `major_sacrifice` | Current command sacrifice targets, until its finite quota is exhausted |
| `blood_worm/kill` | Station command, matching its prevent-escape goal |
| `destroy_nation` | Members of the explicit enemy nation/department |
| `elimination` | People actually blocking elimination on the emergency shuttle; brig and nonblocking allies excluded |
| `elimination/highlander` | Other nonbrain shuttle occupants |
| `block` | Organic player shuttle occupants |
| `purge` | Nonhuman humanoid player shuttle occupants |
| Server-created slaughter-everyone goal | Other players; slaughter demon only, excluding laughter demons |
| Server-created ascended-heretic crew-cull goal | Station human crew outside the heretic/monster alliance |
| Server-created heretic-arena escape goal | Other participants in the same active arena |

For a finite quota, a death captures an authorization rather than reserving a
slot. Eligible death settlement claims the slot synchronously. Thus two deaths
in the same tick cannot both claim the final slot. The quota also observes the
objective's trusted existing sacrifice counters; completed objectives stop
authorizing new deaths. A death matching both sacrifice goals consumes both
applicable quotas, so overlap cannot create extra free kills. Suicides, stale
attribution and nonplayer deaths consume no quota.

The three formerly generic server-created kill goals now have explicit types.
Arbitrary explanation text, custom objectives and player-editable flavor do not
authorize murder. Other objective classes retain the normal penalty: protection,
survival, escape/hijack navigation, martyrdom, stealing, kidnapping/detaining,
contracts, genome extraction/absorption, experiments, conversion, nuclear or blob
infrastructure, blood consumption, heretic research/summoning, revenant essence,
and their flavor objectives. These do not identify an intended player murder
target. Soultrapped-heretic and lunatic flavor is likewise not a blanket waiver.

Primary objective sources are `code/game/gamemodes/objective.dm`, the cult,
separatist and blood-worm objective files, `heretic_antag.dm`, `slaughter_antag.dm`,
`heretic/structures/lock_final.dm`, and `datums/proximity_monitor/fields/heretic_arena.dm`.
The policy predicates live in `code/objective_events.dm` in this module.

## Completed restorative surgery

The hook runs after a successful operation's effects, rather than on the generic
finished signal (which also fires for failures). It requires an upstream
`OPERATION_NOTABLE` operation and a measurable restorative result:

- Organ repair: less organ damage, fewer brain traumas, or restored sight/hearing.
- Limb replacement: a missing limb restored or actual limb damage reduced.
- Revival: a dead patient is alive after the procedure.
- Moth wing repair: burnt wings restored.
- Stomach pumping: less toxin reagent, rather than merely removing medicine.

The patient must be a live connected player after completion. The surgeon must
be a capable active player, treating somebody else. Damage previously inflicted
by that surgeon and recent patient self-harm block rewards, as for medical packs.
Failed attempts, no-ops, preparatory incisions, amputations, organ removal,
brainwashing, cosmetic operations and healthy augmentations earn nothing.
Organ insertion is excluded to avoid remove/reinsert loops. Routine bone/wound
steps are not tagged notable upstream and are outside this MVP award hook.

An eligible completion awards `karma_help_reward / (1 + prior_pair_awards)`,
rounded to cents; the default first awards are +0.10, +0.05, +0.03. A zero rounded
reward earns nothing. Each surgeon-account/patient-account pair has a persistent
one-hour real-time cooldown and lifetime repeat count. Both survive reconnects,
new rounds and database reloads. Reward, repeat count and cooldown are committed
in one synchronous account-record update. Surgery shares the existing ceiling
of ten medical rewards per account per round with medical packs.

The hook is in `code/modules/surgery/operations/_operation.dm`; the benefit and
accounting logic lives in this module's `code/progression_events.dm`.

Regression coverage in `code/tests_events.dm` exercises real bound basic-mob
combat, NPC-victim exclusion, same-tick corpse dismemberment, source-specific
minion objectives, explicit target/non-target deaths, retargeting,
free-text rejection, simultaneous finite-quota settlement, persisted cooldowns,
diminishing rewards and an actual successful/failed organ operation.
