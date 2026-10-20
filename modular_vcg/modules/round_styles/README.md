# City round styles

The lobby automatically holds one native VotePanel vote before jobs are assigned.
Setup waits for it; an unrelated vote finishes first. The most votes wins. A tie
prefers Eternal Struggle, then Quiet Night. No votes defaults to Eternal Struggle.
The chosen style is fixed before Dynamic's trial occupation pass and cannot be
changed by starting another vote during play.

| Style | Player antagonist capacity | Territory challenges | Save owners |
| --- | --- | --- | --- |
| Спокойная ночь / Quiet Night | 0 | Disabled | Never |
| Вечная Борьба / Eternal Struggle | floor(weight / 15) | Enabled | Never |
| Война Принцев / War of Princes | floor(weight / 7) | Enabled | Conditional |

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
