/// Missing legacy looks only. Existing outfits, footwear and renamed holsters
/// are reused; the complete type mapping is in legacy_clothing_manifest.json.
/obj/item/clothing/under/vampire/bogatyr/female
	icon_state = "bogatyr_f"
	icon = 'modular_vcg/modules/slim_bodies/icons/legacy_missing_inventory.dmi'
	ONFLOOR_ICON_HELPER('modular_vcg/modules/slim_bodies/icons/legacy_missing_floor.dmi')

/obj/item/clothing/under/vampire/nazi
	name = "historical uniform"
	desc = "Some historical clothes."
	icon_state = "nazi"
	icon = 'modular_vcg/modules/slim_bodies/icons/legacy_missing_inventory.dmi'
	worn_icon = 'modular_vcg/modules/slim_bodies/icons/legacy_missing_worn.dmi'
	ONFLOOR_ICON_HELPER('modular_vcg/modules/slim_bodies/icons/legacy_missing_floor.dmi')

/obj/item/clothing/head/vampire/nazi
	name = "german bad guy hat"
	desc = "A historical uniform cap."
	icon_state = "ss"
	icon = 'modular_vcg/modules/slim_bodies/icons/legacy_missing_inventory.dmi'
	worn_icon = 'modular_vcg/modules/slim_bodies/icons/legacy_missing_worn.dmi'
	ONFLOOR_ICON_HELPER('modular_vcg/modules/slim_bodies/icons/legacy_missing_floor.dmi')
	armor_type = /datum/armor/none

/obj/item/clothing/suit/vampire/vest/police/chief
	name = "police chief duty vest"
	desc = "Composite bulletproof vest with SFPD markings, tailored for improved protection. This one has captain insignia on it."
	icon_state = "chiefvest"
	icon = 'modular_vcg/modules/slim_bodies/icons/legacy_missing_inventory.dmi'
	worn_icon = 'modular_vcg/modules/slim_bodies/icons/legacy_missing_worn.dmi'
	ONFLOOR_ICON_HELPER('modular_vcg/modules/slim_bodies/icons/legacy_missing_floor.dmi')
	armor_type = /datum/armor/highly_protective_vest
