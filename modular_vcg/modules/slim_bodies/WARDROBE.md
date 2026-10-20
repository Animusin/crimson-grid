# Legacy wardrobe access and physical underclothes

The pinned [202-item clothing audit](legacy_clothing_manifest.json) reuses 192
existing types and seven canonical renamed types; only three missing item types
were restored. Their looks now have actual catalogue routes:

| Look | Loadout | Shop | Cargo |
| --- | --- | --- | --- |
| Historical uniform and cap | Uniform / Head | Costume store | Historical Costume Assortment |
| Blue shirt and skirt | Uniform | Clothing store | City Clothing Assortment |
| Police chief duty vest | Outerwear; actual police jobs only | Restricted police equipment counter | Armor (Police Command) |

The chief vest checks the **actual outfit job**, including before mind transfer.
A saved selection or an old police mind cannot grant it to a civilian outfit.
The existing Gothic loadout entry is reused. Other obvious civilian catalogue
gaps reuse their current types: grey attire, the punk rocker outfit, historical
costumes, fatigues, tracksuits, purple/black and slick outfits, and dirty attire.
High and punk boots also join the clothing store. No outfit aliases are
reintroduced as duplicate clothing objects.

The cargo additions are three mixed assortments, rather than a catalogue of
hundreds of single-outfit packs. The source audit also contains abstract item
parents, hoods supplied by their parent robes, professional/faction regalia,
prefilled holsters and combat equipment. Importing their artwork does not make
them unrestricted civilian loadout gear or shop stock; their existing role,
crafting and equipment routes remain in place. The 202 definitions are therefore
not a count of 202 newly purchasable civilian outfits.

## Reusable underwear, bras and stockings

The old underwear sprites previously existed only as appearance choices.
[All 47 legacy selectors](review/legacy_underwear_audit.json) already map to
current choices: 44 actual styles and three Nude entries. Three physical item
classes now expose those existing registries, including the modern styles:

- Underwear: `/obj/item/undergarment/underwear`.
- Bras and undershirts: `/obj/item/undergarment/undershirt`.
- Socks and stockings: `/obj/item/undergarment/socks`.

They are available in the backpack loadout, the clothing and Hot Ishu stores,
and the Underclothing Assortment cargo pack. Retail prices are $10 for underwear
or an undershirt and $5 for socks; the $100 pack contains three of each category.
These are reusable garments, with no pawn component or resale value, rather than
consumable appearance vouchers. There are no additional equipment slots and no
44 duplicate item definitions.

Use a new item in hand to choose its style. A cancelled choice, incompatible
body, dropped item, blocked access or occupied category never consumes it or
replaces the currently worn garment. The original style is retained on the same
object after removal; clicking it in hand, or using it on yourself, puts it back
on. Underwear also retains its selected tint. Undershirt and sock palettes belong
to their existing style definitions, matching the renderer's current fields.

Drag your own character onto itself to open the normal strip panel; its new
underwear, bra/undershirt and socks entries also work through ordinary stripping
of another character. The panel retains its normal action checks and delays.
Middle-click your own sprite with the groin selected for quick removal of the
currently worn underwear and stockings. This leaves the bra/undershirt alone and
respects existing consumed-click signals. Removal and wearing both require
usable hands and access: groin-covering clothing blocks underwear, chest-covering
clothing blocks bras/undershirts, and leg-covering clothing or shoes block socks.
A refusal identifies the clothing that must be removed first.

Starting preference styles remain authoritative. A real body's strip interaction
materializes at most one cached garment per category; repeated menu updates reuse
that object and synchronize direct wardrobe style/tint edits. Dummy/character
previews never create physical items. Removed objects go to a hand or the floor;
moving or deleting a worn object clears its appearance. These actions update the
existing Standard/Slim appearance pipeline and never write to a currently selected
character preference slot. Permanent cosmetics remain in the free preferences
menu.

Focused tests exercise actual catalogue registries, retail inventory and cargo
filling; actual held-item actions, cancellation and changed ownership; the parent
middle-click cancellation contract; cache identity and preview exclusion; and
wear/remove cycles for all 44 non-Nude legacy styles.
