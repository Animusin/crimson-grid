/datum/loadout_item/pocket_items/undergarment_underwear
	name = "Underwear (Choose Style)"
	item_path = /obj/item/undergarment/underwear

/datum/loadout_item/pocket_items/undergarment_undershirt
	name = "Bra or Undershirt (Choose Style)"
	item_path = /obj/item/undergarment/undershirt

/datum/loadout_item/pocket_items/undergarment_socks
	name = "Socks or Stockings (Choose Style)"
	item_path = /obj/item/undergarment/socks

/datum/supply_pack/local/underclothing
	name = "Underclothing Assortment"
	desc = "Three underwear items, three bras or undershirts, and three pairs of socks or stockings. Choose a style when first wearing each item."
	cost = 100
	crate_name = "underclothing crate"
	contains = list(
		/obj/item/undergarment/underwear = 3,
		/obj/item/undergarment/undershirt = 3,
		/obj/item/undergarment/socks = 3,
	)
