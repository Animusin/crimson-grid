# City businesses MVP

This fork starts on Westfield Mall. San Fangcisco and Oakland remain votable.
Ownership is seeded by the map and lasts for the round only. There is no karma,
Humanity rebalance, population gate, victory reward, or persistence in this patch.

## Playing

Four organizations participate: Camarilla, Anarchs, Sabbat (including the existing
Voivode/Bogatyr/Zadruga jobs), and the four human Triad jobs. City jobs in general
are not Triads. Each eligible job receives an additional faction credential in
its backpack, or its hands if the backpack is full.

Show a credential directly to a business's clerk to open the protection dialog.
The credential authorizes collection and declarations, so stolen credentials can
be abused. Actual job membership determines capture presence, buyer access,
phone recipients, and the retail discount; a stolen card alone gives no discount.

- Base collection: one dollar per player who joined at round start, per business
  every ten minutes. The population is frozen on the first processing tick after
  round start. Uncollected cycles do not build an unlimited backlog.
- Collect normally for the base amount, or demand more with Charisma +
  Intimidation, difficulty 6. Each success adds 20%, up to double; zero successes
  or a botch loses the collection cycle. The cycle belongs to the business.
- The matching faction plus a matching carried credential receives a 50% retail
  discount. This is checked for cash and bank payments, not only the displayed UI.
- Both buyer sale paths require membership in the owning faction. Fresh cannabis
  cannot be sold; a dried leaf is worth exactly $50, without a fencing multiplier.
  Existing morality effects of selling contraband are unchanged.
- Clerk death/deletion suspends business and collection for fifteen minutes. The
  clerk returns to its mapped home and is rebound to retail/buyer objects. Death
  does not remove the announced attack, change ownership, or reset attack slots.

## Contest

A successful Charisma + Intimidation declaration starts preparation lasting
`max(2, 7 - successes)` minutes. There is one outstanding attack per attacking
faction and one per business. A failed declaration or a finished contest puts
that business on a ten-minute declaration cooldown.

During preparation the marker has a red ring/light. Participating characters
within fifteen tiles see a top-of-screen countdown. At the deadline, there is a
two-minute window to start and complete a continuous thirty-second hold within
four tiles, with no conscious, capable defending player in that radius. Once a
hold starts, losing all capable attackers or admitting a capable defender ends
the attempt immediately. NPCs and unconscious/dead players do not contest.

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
and rejects terrain, size, or unrelated tile changes. DM integration tests are in
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
