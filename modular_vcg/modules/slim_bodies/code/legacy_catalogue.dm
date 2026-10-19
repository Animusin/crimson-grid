/// Reuse canonical item paths from the legacy audit; do not duplicate outfits.
/datum/loadout_item/uniform/legacy_historical
	name = "Historical Uniform"
	item_path = /obj/item/clothing/under/vampire/nazi

/datum/loadout_item/head/legacy_historical
	name = "Historical Uniform Cap"
	item_path = /obj/item/clothing/head/vampire/nazi

/datum/loadout_item/uniform/legacy_blue_skirt
	name = "Blue Shirt and Skirt"
	item_path = /obj/item/clothing/under/vampire/bogatyr/female

/datum/loadout_item/uniform/legacy_blue_shirt
	name = "Blue Shirt"
	item_path = /obj/item/clothing/under/vampire/bogatyr

/datum/loadout_item/uniform/legacy_grey_attire
	name = "Grey Attire"
	item_path = /obj/item/clothing/under/vampire/salubri

/datum/loadout_item/uniform/legacy_grey_attire_female
	name = "Grey Attire (Skirt)"
	item_path = /obj/item/clothing/under/vampire/salubri/female

/datum/loadout_item/uniform/legacy_punk_rocker
	name = "Punk Rocker Outfit"
	item_path = /obj/item/clothing/under/vampire/punk

/datum/loadout_item/uniform/legacy_emperor
	name = "French Emperor Suit"
	item_path = /obj/item/clothing/under/vampire/napoleon

/datum/loadout_item/head/legacy_admiral
	name = "French Admiral Hat"
	item_path = /obj/item/clothing/head/vampire/napoleon

/datum/loadout_item/uniform/legacy_fatigues
	name = "Military Fatigues"
	item_path = /obj/item/clothing/under/vampire/military_fatigues

/datum/loadout_item/uniform/legacy_tracksuit
	name = "Tracksuit"
	item_path = /obj/item/clothing/under/vampire/sport

/datum/loadout_item/uniform/legacy_purple_black
	name = "Purple and Black Outfit"
	item_path = /obj/item/clothing/under/vampire/sexy

/datum/loadout_item/uniform/legacy_slickback
	name = "Slick Outfit"
	item_path = /obj/item/clothing/under/vampire/slickback

/datum/loadout_item/uniform/legacy_dirty_attire
	name = "Dirty Attire"
	item_path = /obj/item/clothing/under/vampire/homeless

/datum/loadout_item/uniform/legacy_dirty_attire_female
	name = "Dirty Attire (Skirt)"
	item_path = /obj/item/clothing/under/vampire/homeless/female

/datum/loadout_item/suit/legacy_police_chief
	name = "Police Chief Duty Vest (Police Jobs Only)"
	item_path = /obj/item/clothing/suit/vampire/vest/police/chief

/// The real outfit's job controls armor grants, including before mind transfer.
/// A cosmetic preview or a civilian role must never receive free police armor.
/datum/loadout_item/suit/legacy_police_chief/insert_path_into_outfit(datum/outfit/outfit, mob/living/carbon/human/equipper, visuals_only = FALSE)
	if(!istype(outfit, /datum/outfit/job))
		return FALSE
	var/datum/outfit/job/job_outfit = outfit
	var/datum/job/job = SSjob.get_job_type(job_outfit.jobtype)
	if(!job || !(/datum/job_department/police in job.departments_list))
		return FALSE
	return ..()

/// A small city assortment, rather than one cargo entry for every sprite.
/datum/supply_pack/local/city_clothes
	name = "City Clothing Assortment"
	desc = "Eight everyday garments: punk and grey outfits, a blue skirt, a tracksuit, and two pairs of boots."
	cost = 150
	crate_name = "city clothing crate"
	contains = list(
		/obj/item/clothing/under/vampire/brujah,
		/obj/item/clothing/under/vampire/brujah/female,
		/obj/item/clothing/under/vampire/salubri,
		/obj/item/clothing/under/vampire/salubri/female,
		/obj/item/clothing/under/vampire/bogatyr/female,
		/obj/item/clothing/under/vampire/sport,
		/obj/item/clothing/shoes/vampire/jackboots = 2,
	)

/datum/supply_pack/local/historical_costumes
	name = "Historical Costume Assortment"
	desc = "Two historical uniforms with caps and one French emperor costume with an admiral hat."
	cost = 150
	crate_name = "historical costume crate"
	contains = list(
		/obj/item/clothing/under/vampire/nazi = 2,
		/obj/item/clothing/head/vampire/nazi = 2,
		/obj/item/clothing/under/vampire/napoleon,
		/obj/item/clothing/head/vampire/napoleon,
	)

/datum/supply_pack/weapons/armorpolice/chief
	name = "Armor (Police Command)"
	desc = "One police chief duty vest and one police helmet."
	cost = 1500
	contains = list(
		/obj/item/clothing/suit/vampire/vest/police/chief,
		/obj/item/clothing/head/vampire/helmet,
	)
