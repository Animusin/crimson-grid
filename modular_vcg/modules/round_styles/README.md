# City round styles

The lobby automatically holds one native VotePanel vote before jobs are assigned.
Setup waits for it; an unrelated vote finishes first. The most votes wins. A tie
prefers Eternal Struggle, then Quiet Night. No votes defaults to Eternal Struggle.
The chosen style is fixed before Dynamic's trial occupation pass and cannot be
changed by starting another vote during play.

| Style | Player antagonist capacity | Territory challenges | Save owners |
| --- | --- | --- | --- |
| Спокойная ночь / Quiet Night | 0 | Disabled | Never |
| Вечная Борьба / Eternal Struggle | floor(weight / 15) + 2 | Enabled | Never |
| Война Принцев / War of Princes | floor(weight / 7) + 2 | Enabled | Conditional |

Weight is one per living, connected non-antagonist account, plus one for each
Sheriff, Hound or Bruiser. Antagonists do not contribute weight. Sabbat jobs
(including Tzimisce jobs), all four Hunter jobs and real antagonist datums share
one pool; fake antagonist datums do not count. Multiple jobs/datums on the same
account cost one slot. Converting a non-antagonist removes their old weight before
checking admission. Departure can lower the cap without ejecting existing players.

Ordinary Pack, Bogatyr, Zadruga, Inquisitor and Novice slots scale with the shared
budget. Native map-disabled jobs stay disabled, and heads/specialists retain their
native limits. Roundstart preference allocation, latejoin, role transitions and
antagonist datum assignment all enforce admission. Pure Dynamic job trials leave
no reservations behind. Ordinary assignments establish capacity first; preferred
antagonist candidates wait, then use a requested ordinary fallback if the pool is
full. Leadership roles are never forced to fill the pool. The existing disabled generic TG Dynamic rulesets remain
disabled; this patch controls the native city antagonist jobs and actual antagonist
datums instead of enabling unrelated rulesets.

The separate **Villains** lobby button and login link open a Ratwood-style browser
panel. Before setup it edits saved Never/Low/Medium/High job priorities; players
still press Ready and compete for the shared capacity at roundstart. During play
the same panel shows availability and joins the native job with its normal spawn,
equipment, bans, character requirements and shared cap. Ductus, Priest and Pack
form the crusade; Hunter roles also appear here. The manor's Voivode, Bogatyr and
Zadruga remain in normal job selection with the same dynamic cap. Crusade and
Hunter jobs are excluded from ordinary preferences, latejoin and random jobs;
no antagonist job can be forced through the random roundstart fallback.
All latejoin entry points recheck the queue/population limit, administrative lock,
round state and nonnegative freebie points before spawning. This introduces no
timed storyteller point economy or automatic crusade event waves.
The pregame panel shows and edits native per-job character profiles, including an
explicit reset to the active slot. Latejoin keeps its native active-slot behavior.
Concurrent join requests cannot enter a second spawn while eligibility is yielding.

With the player-quality PR installed, **new player antagonist admissions require
Respect 10**, including manor Tzimisce, hunters and real antagonist datum grants.
The server checks the account before assigning a role or granting its effects;
the panel and latejoin show the reason for a refusal. An already accepted living
antagonist can finish the round after losing Respect, including their normal
outfit and promotions. A dead former antagonist does not reserve that exception
for a new entry. Unowned NPCs and fake helper datums retain their existing policy.
The threshold belongs to progression, independently of the population budget.
The modules communicate through an optional admission signal, so each PR still
builds independently; both are required for the combined Respect-and-cap rule.

Black Spiral Dancer tribe selection and Pentex employment are not automatically
classified as antagonists; that design decision remains open. A real antagonist
datum still charges the shared pool regardless of the character's job. Native
response-team helper datums marked `ANTAG_FAKE` retain their existing exclusion.

War can be selected at any starting population. Ownership saves at normal round
completion only if **40 distinct accounts each earned 40 active minutes** and
every faction with map-seeded territory had an active participant during the round.
Late arrivals may qualify. The activity clock samples connected living characters
with assigned jobs, excludes the lobby, observers, dead characters and clients
flagged AFK by the existing inactivity setting, and counts no reconnect gaps.
Multiple characters on one account share one total. Faction presence uses the
actual job faction, not carried or stolen credentials. Each faction's representative
need not be one of the forty qualifying accounts.

`data/city_territory_owners.json` stores schema-versioned owner mappings separately
for each map path/file. Only known territory IDs and faction IDs load. The map's
original owner set determines required representation even when a previous war
changed those owners. Last saved owners load in all three styles. Eternal captures
and ineligible Wars leave that save untouched. Cash, cooldowns, NPCs and other
business state never persist. Abrupt shutdowns do not commit a war result.

Compile focused regression tests with `-DCBT -DUNIT_TESTS -DROUND_STYLE_TESTS`.
Use `-DBUSINESS_TESTS` as well to run the existing business tests together.
