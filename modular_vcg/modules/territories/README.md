# City businesses MVP

This fork starts on Westfield Mall. San Fangcisco and Oakland remain votable.
Ownership is seeded by the map and lasts for the round only. There is no Humanity
rebalance, population gate or ownership persistence in this patch. An optional
progression module can listen to the defense event described below.

## Playing

Four organizations participate: Camarilla, Anarchs, Sabbat (including the existing
Voivode/Bogatyr/Zadruga jobs), and the four human Triad jobs. City jobs in general
are not Triads. Each eligible job receives an additional faction credential in
its backpack, or its hands if the backpack is full.

Talk to the business's cashier with a non-combat empty-hand click, or show the
cashier a faction credential. Every business action targets the cashier; marks,
retail counters and buyer counters do not open business dialogs. A cashier behind
a fixed counter remains usable when visible and its own checkout within four
tiles on the same level is reachable. Reach, action capability and cashier health
are rechecked after the dialog and timed actions. Ordinary purchases still use
the retail counter. Combat clicks and right clicks retain their usual behavior.

A carried credential authorizes collection, including a courier carrying a
stolen card. Actual job membership determines real capture presence, buyer access,
phone recipients and the retail discount. Presenting another faction's stolen
credential can produce a false challenge notice to that faction and the owner,
but creates no real contest and never reserves that faction's real attack slot.
The cashier remembers the suspect's appearance and visible ID at that moment.
Only current members of the owning faction can ask the cashier about these
threats; the report does not reveal a concealed identity or an account name.

- Base collection: one dollar per unique account who joined this round, per
  business every ten minutes. Later income cycles include late arrivals. Repeated
  joins cannot inflate the count; departures do not devalue a ready collection.
  The first income requires ten minutes. Completed cycles accumulate in the
  cashier's till until collected or stolen. Collecting does not restart the
  income clock, and later population changes do not reprice stored cash.
- Collect normally for the base amount, or demand more with Charisma +
  Intimidation, difficulty 6. Each success adds 20%, up to double; zero successes
  or a botch loses the reserved till contents. The dialog explicitly warns that
  demanding more risks the whole accumulated amount. Reserving/debiting happens
  before the roll, so two pending courier dialogs cannot collect the same cash.
- The matching faction plus a matching carried credential receives a 50% retail
  discount. This is checked for cash and bank payments, not only the displayed UI.
- Both buyer sale paths require membership in the owning faction. Fresh cannabis
  cannot be sold; a dried leaf is worth exactly $50, without a fencing multiplier.
  Existing morality effects of selling contraband are unchanged.
- NPC resale of purchased retail goods is capped at their actual purchase price,
  including normal purchases. This closes the unlimited-stock clothing-to-pawn
  money loop, which the faction discount otherwise amplifies. Bundled contents
  have no separate resale allowance. Stack receipts survive splitting; stacks
  with different receipts cannot merge to wash the ceiling. Found/looted goods
  retain their normal fencing roll. Crafting and material transformations are
  outside this receipt check.
- Clerk death/deletion suspends business and collection for fifteen minutes. The
  clerk returns to its mapped home and is rebound to retail/buyer objects. Death
  does not remove the announced attack, change ownership, or reset attack slots.
  Existing till contents survive. Income pauses until recovery without paying
  a backlog for the dead-cashier period.

## Robbery

Any connected, capable human player can rob a cashier, including unaffiliated
characters and members of the owning faction. No credential is needed. The same
Charisma + Intimidation roll at difficulty 6 determines the time and the share
of actual till contents:

| Successes | Threaten the cashier for | Cash stolen |
| --- | ---: | ---: |
| 1 | 60 seconds | 25% |
| 2 | 50 seconds | 40% |
| 3 | 40 seconds | 60% |
| 4 | 30 seconds | 80% |
| 5 or more | 20 seconds | 100% |

The robber must remain on the starting tile and keep access to the same living
cashier. Movement, incapacity, loss of reach, cashier death or an announced contest
interrupts the attempt without withdrawing money. Only one robber can occupy a
store's attempt; courier collections wait while it is active. The current cash
is debited atomically at completion, rounded down to whole dollars; new income
accrued during the threat is included. A shared store cooldown lasts ten minutes
after any rolled attempt ends, including failure or interruption. Changing
robbers cannot reroll it. An empty till or an unavailable cashier cannot start
an attempt.

Every positive-roll threat arms an alarm for ninety seconds after its start.
The alarm survives interruption and cashier death, and reports success or the
interrupted threat to members of the faction that owned the store at the start.
It uses real phone calls, normal ringing/history and accept/decline behavior;
answering displays the recorded report and hangs up. A saved SMS transcript also
covers missed calls and busy phones. Automatic calls never interrupt an existing
call, and release their temporary caller and radio connection after a short bound.

## Contest

A successful Charisma + Intimidation declaration starts preparation lasting
`max(2, 7 - successes)` minutes. There is one outstanding attack per attacking
faction and one per business. A failed declaration or a finished contest puts
that business on a ten-minute declaration cooldown.

During preparation and the contest, members of the attacking and owning factions
within thirty tiles receive a personal red mark indicator, a direction arrow and
a top-of-screen countdown. Other characters do not see those contest overlays.
At the deadline, there is a
two-minute window to start and complete a continuous thirty-second hold within
four tiles, with no conscious, capable defending player in that radius. Once a
hold starts, losing all capable attackers or admitting a capable defender ends
the attempt immediately. NPCs and unconscious/dead players do not contest.
Presence also requires a walkable connection within four tiles, respecting glass
and directional barriers. A person in a visible sealed room cannot hold/block it.

Meaningful defense emits the optional global signal `city_business_defended`
with `(defender, territory_id, attack_token, attack_faction)`. Interrupting an
existing attacker hold qualifies immediately; otherwise ten continuous seconds
of capable presence during the active window are required. Each account emits
at most once per contest, and leaving the radius resets its pending ten seconds.
The progression module handles account rewards and its own per-round caps.

## Drying and income scale

One unpowered wooden drying rack is added to the main Anarch growing room on
each map: Westfield, San Fangcisco and Oakland. Oakland's park and caern retain
their existing racks. These five reference sites and their planter/rack
coordinates are in `growing_sites.json`; other small growing rooms share supplies
or build another rack. See the [placement crops](review/drying.png).
No tubs or terrain move. Racks hold 25 items and require loading and toggling
Dry; drying occurs on the machine processing tick, with no electricity needed.
Additional racks can be made from ten planks. Hardware stores already sell
planks for $10 each ($5 with the owner discount); existing remote wood stacks
are no longer the only way to start drying near a farm.

For a stable population and punctual collection, one business pays:

| Unique players | Per 10 minutes | Per 3 hours | Maximum with successful social rolls |
| --- | ---: | ---: | ---: |
| 10 | $10 | $180 | $360 |
| 20 | $20 | $360 | $720 |
| 40 | $40 | $720 | $1,440 |
| 60 | $60 | $1,080 | $2,160 |

These are income ceilings, not guaranteed rewards: robbery, failed negotiations
and clerk death reduce them. Five successes doubles a payout; choosing a risky
roll can also lose it. Unvisited cycles remain in the till. Latejoin growth
changes future accrual rather than retroactively increasing stored cash.

At 40 players, one business's $80 per twenty minutes equals 1.6 dried leaves.
Unmodified cannabis yields three leaves ($150) per harvest. Its base production
is six growth cycles and trays use a 20-second cycle with a strict elapsed-time
check, so repeat harvests require at least seven cycles (over 140 seconds), plus
initial maturation, care and transport. This is a theoretical comparison, not an
observed hourly farm yield: plants age, run out of water/nutrients and can die.
Even with $50 leaves, a tended multi-tub farm earns substantially more than a
single passive business; the $50 price is kept as requested. Territorial income
is deliberately supplementary and scales by the number of stores a faction
actually visits. At 40 players all 26 Westfield businesses together have a base
three-hour ceiling of $18,720; San Fangcisco's 52 have $37,440 and Oakland's 47
have $33,840, before any successful social bonus.

For comparison, Finance 0/1/2/3/4/5 bank incomes are $15/$40/$80/$120/$160/$250
every five minutes ($540/$1,440/$2,880/$4,320/$5,760/$9,000 over three hours), for
characters with a paying bank account. Existing starting balances are separate.
Thus one 40-player shop gives half the Finance 1 recurring salary, or an equal
amount at the maximum social bonus. This review keeps the requested $1/player
shop formula rather than multiplying every shop to match a whole cannabis farm.

At the actual contest, the clerk shouts and stays down. Non-aggressive civilian
NPCs flee the fifteen-tile radius. NPC witnesses inside that radius, and the
business's clerk, do not register new breaches caused inside the contest radius.
This is an explicit abstraction of frightened witnesses, covering both visual
and speech signals. Old breaches and witness-death/memory hooks remain intact.
Player-controlled NPCs and object/phone witnesses are not exempt. Preparation,
out-of-radius activity, and the time after the contest use ordinary Masquerade.
No area is changed to `ZONE_NO_MASQUERADE`.

Actual SMS conversations are stored under service number `5550199`, with visible
notifications and map coordinates for declaration, start, and result. They go to
both involved organizations using actual job membership, not mixed contact networks.
Leaving the radius or ending a contest removes its HUD. Overlapping contests
display the nearest marker's timer.

## Mapping

Placement atlases: [Westfield](review/westfield.png),
[San Fangcisco](review/sanfangsisco.png), [Oakland](review/oakland.png).
These are schematic crops, not in-game sprite renders. White outlines identify
the current mark, faction-colored boxes show neighboring marks, cyan C denotes
a clerk on the same floor, and amber tiles denote doors. Black indicates a
closed turf or live physical blocker; blue indicates water. The JSON manifest
remains the coordinate authority.

`businesses.json` lists every marker, clerk home, outlet coordinate, and initial
owner. The DMMs are TGM formatted for individual tile edits. A checkout and its
clerk are linked using offsets relative to the marker, so runtime map translation
does not put the replacement clerk on another floor or in space. A checkout and its
buyer/retail objects share a business only when they already share a clerk;
separate stores remain separate. Public police/clinic equipment, Endron's internal
service and the Church pantry are excluded. Primogen offices, the Voivode's office,
the Westfield dojo, and strip clubs are included; offices without a suitable NPC
receive a shop NPC at an adjacent open tile.

On Westfield, common mall/service passages stand in for street alleys. The Triad
jobs have start landmarks in the existing dojo. Upper-floor venues can use a
public passage below, with clerk offsets retaining the connection to the office.
Six private locations have documented `public_approach` reference points:
the San Fangcisco Toreador office, Oakland's warren shop and Nosferatu office,
and its upper Banu Haqim, Lasombra and Ventrue offices. Their contests stay on
the public side of the private premises; the approach reference is not a claim
that the private clerk can walk there through the public pedestrian graph.

Placement was reviewed against exported, live BYOND density, unlocked doors and
actual stairs/manhole links, including walkable sewer water on approach routes.
Stairs with a solid ceiling above are rejected, rather than treated as working
connections. Surface shops retain surface marks; upper-floor and basement
businesses can use another level at their public approach.
Marks themselves occupy dry floor with no furniture, random flora or doorway.
Centers are at least two tiles apart so 48px paintings do not overlap, and at
least two tiles from asphalt. They connect to the main public pedestrian
component without crossing locked doors. Clerk/customer routes can cross doors
and start beside counters. Physical access and setbacks are checked here;
multiplayer testing still needs to assess combat balance in nearby corridors.

To move a point, edit its TGM tile and keep its manifest coordinate in sync. Do
not change the outlet's `territory_id` when moving the marker. `plan_maps.py` is a
one-time seed tool against the base maps, and deliberately refuses to overwrite
maps which already have markers. It never changes terrain. Review the manifest
and minimap before adopting new seed positions. The seed tool now refuses a
missing flat route instead of guessing an unconnected tile or floor.

To repeat the geometry review, compile with `UNIT_TESTS`, `BUSINESS_TESTS` and
`BUSINESS_GEOMETRY`, run each map and archive its `data/business_geometry.json`
as `data/territory_geometry/<map>.json` (`westfield`, `sanfangsisco`, `oakland`).
`python tools/territories/review_placement.py` writes a proposed review report;
`--apply` changes only marker tiles, their clerk offsets and the manifest. The
export records live locks and physical blockers, rather than guessing density
from object path names. `python tools/territories/render_review.py` renders
schematic crop atlases. Normal tests do not export world geometry.

Capture presence uses visible range, so an opaque neighboring room cannot hold
or block a point through a wall. Retail prices now update while the UI is open;
PIN-based purchases recheck stock, reach, the card and business state after input.

Validation from the repository root (Python 3 + `bidict`):

```
python tools/territories/check_maps.py
```

The check compares with `origin/master`, verifies every eligible outlet is linked,
checks every listed rack and rejects terrain, size, or unrelated tile changes. DM integration tests are in
`code/tests.dm`: economy/drying, capture interruption/completion, witness scope,
and map/clerk/outlet bindings. For a focused local run compile with `CBT`,
`UNIT_TESTS`, and `BUSINESS_TESTS`; ordinary CI does not define `BUSINESS_TESTS`.

## Sprite sources

The Camarilla, Anarch and Sabbat frames are preserved from
`Animusin/World-of-Darkness-13`, revision
`340b7385e54ee614fd0fee8c5d1031858af586c8`,
`code/modules/wod13/48x48.dmi`, states `Camarilla`, `Anarch`, `Sabbat`.
The Triad frame was generated using the built-in ImageGen tool, then cropped and
pixelized using nearest-neighbor downsampling to the same 48px footprint. The
other generated sheet variants are not used. `icons/territories.dmi` holds the
four owner states plus a contested ring; `icons/credentials.dmi` holds 32px cards
using those emblems. `icons/preview.png` previews the four final floor symbols.

Generation prompt (only the bottom-right result is used):

> Create ONE game sprite reference sheet on a transparent background, square,
> four equal symbols in 2 by 2 grid, no letters, no words, no shadows outside
> symbols. Intended to be downsampled to 32x32 pixel-art floor territory markers
> for a dark urban vampire game. Each emblem should be flat, very bold simple
> silhouette, centered with lots of empty margin, same circular footprint and
> readable at tiny size. TOP LEFT Camarilla: silver ivory heraldic tower enclosed
> in a ring. TOP RIGHT Anarchs: red anarchy circle with stylized A glyph symbol
> (not text label). BOTTOM LEFT Sabbat including Tzimisce: violet black ritual
> sword with skeletal wings. BOTTOM RIGHT Triads: jade green coiled dragon
> silhouette in ring. Top-down painted stencil graffiti, distressed edges kept
> minimal, no background tiles, no lighting or mockup. Four distinct silhouettes,
> limited palette each, crisp high contrast shapes suitable for nearest-neighbor
> pixelization.
