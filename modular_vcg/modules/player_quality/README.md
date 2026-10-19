# Player Quality and participation MVP

Account scores persist in `data/player_quality.json`, using the existing JSON
database and its backup recovery. They do not belong to a character slot or name.
Back up this file with server data. This module does not import foreign saves.

## Player Quality (PQ)

After the round ends, a participant can use **OOC → Commend player** once.
The recipient must also have played a character that round; lobby spectators,
self-votes and repeat submissions are rejected on the server. Dead and
disconnected participants remain eligible recipients. The list uses character
names with unique entries, so duplicate character names cannot redirect a vote.

The first commendation from an account gives its recipient 1 PQ. Later
commendations from that same account increment the praise count but award no
additional PQ, including in later rounds. The saturation ledger persists through
restarts. Administrative reductions do not reset that ledger. This deliberately
uses a finite per-giver limit rather than Ratwood's later repeat-praise accrual.

**OOC → Player quality** displays both account scores. Administrators with R_ADMIN
receive **Adjust player quality**, with a required reason and an admin audit log.
There are no automatic role, discipline, age, morality or Path restrictions.

## Round Contribution Points (RCP)

Once a completed round ends, eligible accounts receive an independent RCP grant.
The initial defaults are 1 for humans, 0.5 for ghouls/kinfolk and 0 for other
supernaturals. Play must total at least 45 connected, living, non-AFK minutes.
Time is sampled every ten game seconds. Ghosts, lobby time, disconnection and
AFK intervals do not accrue time; earned time remains after death/disconnection.
This is participation time, not a measure of roleplay quality or absence of harm.

If a character transforms during the round, rewards are weighted by time spent
in each category. Changing to human at the end cannot turn a full supernatural
round into a human reward. The account receives one grant, rather than one per
body/respawn. Repeated round-end callbacks cannot duplicate it. RCP never
automatically converts into PQ. Faction leadership currently adds no bonus.

Server configuration (normal numeric config syntax):

```text
PLAYER_QUALITY_ENABLED 1
RCP_HUMAN_REWARD 1
RCP_GHOUL_REWARD 0.5
RCP_KINFOLK_REWARD 0.5
RCP_MINIMUM_MINUTES 45
```

Set `PLAYER_QUALITY_ENABLED 0` to disable the module. These values are MVP tuning,
not finalized progression thresholds. Scores are awarded only on round end;
an interrupted/crashed round does not grant partial RCP.

## Sources and validation

Adapted from Animusin/Ratwood-2.0: `code/modules/admin/playerquality.dm`,
`code/modules/client/client_procs.dm` and `code/__HELPERS/roundend.dm`.
The donor contributes commendations, per-giver diminishing returns, account
storage and the 45-minute participation concept. Modern Crimson uses its own
verb dispatcher, JSON database, splats and round-end signal. No Ratwood jobs,
triumph spending, curses, rank restrictions or automatic RCP-to-PQ conversion
are imported.

Focused BYOND tests cover persisted saturation, ckey normalization, self-vote
rejection, reloads, round-grant idempotency, voting eligibility, verb registration,
configured rewards, short sessions and midround category changes. Compile with
`UNIT_TESTS` and `PLAYER_QUALITY_TESTS` to run only this group.

Open progression and Humanity decisions are recorded in [DECISIONS.md](DECISIONS.md).
