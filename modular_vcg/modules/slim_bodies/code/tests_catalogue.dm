#if defined(UNIT_TESTS) || defined(SPACEMAN_DMM)
/datum/unit_test/slim_catalogue
#ifdef SLIM_BODY_TESTS
	test_flags = UNIT_TEST_FOCUS
#endif

/datum/unit_test/slim_catalogue/Run()
	var/list/expected = list(
		/obj/item/clothing/under/vampire/nazi,
		/obj/item/clothing/head/vampire/nazi,
		/obj/item/clothing/under/vampire/bogatyr/female,
		/obj/item/clothing/under/vampire/bogatyr,
		/obj/item/clothing/under/vampire/salubri,
		/obj/item/clothing/under/vampire/salubri/female,
		/obj/item/clothing/under/vampire/punk,
		/obj/item/clothing/under/vampire/napoleon,
		/obj/item/clothing/head/vampire/napoleon,
		/obj/item/clothing/under/vampire/military_fatigues,
		/obj/item/clothing/under/vampire/sport,
		/obj/item/clothing/under/vampire/sexy,
		/obj/item/clothing/under/vampire/slickback,
		/obj/item/clothing/under/vampire/homeless,
		/obj/item/clothing/under/vampire/homeless/female,
		/obj/item/clothing/suit/vampire/vest/police/chief,
		// Crimson's existing entry is reused rather than registered a second time.
		/obj/item/clothing/under/vampire/gothic,
	)
	for(var/item_path in expected)
		var/loadout_entries = 0
		for(var/datum/loadout_category/category as anything in GLOB.all_loadout_categories)
			for(var/datum/loadout_item/entry as anything in category.associated_items)
				if(entry.item_path == item_path)
					loadout_entries++
		if(loadout_entries != 1)
			Fail("Legacy look [item_path] must have exactly one canonical loadout entry, got [loadout_entries].")
	var/obj/structure/retail/costume_store/costumes = allocate(/obj/structure/retail/costume_store)
	var/obj/structure/retail/clothing_store/clothes = allocate(/obj/structure/retail/clothing_store)
	var/obj/structure/retail/police_equipment/police = allocate(/obj/structure/retail/police_equipment)
	assert_product(costumes, /obj/item/clothing/under/vampire/nazi)
	assert_product(costumes, /obj/item/clothing/head/vampire/nazi)
	assert_product(clothes, /obj/item/clothing/under/vampire/bogatyr/female)
	assert_product(police, /obj/item/clothing/suit/vampire/vest/police/chief)
	for(var/datum/data/vending_product/product as anything in clothes.products_list + costumes.products_list)
		if(product.product_path == /obj/item/clothing/suit/vampire/vest/police/chief)
			Fail("Police armor must not enter unrestricted civilian clothing stores.")
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	human.mind_initialize()
	human.mind.assigned_role = SSjob.get_job_type(/datum/job/vampire/citizen)
	if(police.can_shop(human))
		Fail("A civilian must not purchase from the police equipment shop.")
	human.mind.assigned_role = SSjob.get_job_type(/datum/job/vampire/police_officer)
	if(!police.can_shop(human))
		Fail("An actual police job must retain access to its equipment store.")
	var/datum/loadout_item/vest = GLOB.all_loadout_datums[/obj/item/clothing/suit/vampire/vest/police/chief]
	var/datum/outfit/job/civilian_outfit = new()
	civilian_outfit.jobtype = /datum/job/vampire/citizen
	// Deliberately leave a police mind on the body: the actual outfit's job wins.
	vest.insert_path_into_outfit(civilian_outfit, human)
	if(civilian_outfit.suit == vest.item_path || (vest.item_path in civilian_outfit.backpack_contents))
		Fail("A police mind must not smuggle a chief vest into a civilian job outfit.")
	var/datum/outfit/job/police_outfit = new()
	police_outfit.jobtype = /datum/job/vampire/police_officer
	human.mind.assigned_role = SSjob.get_job_type(/datum/job/vampire/citizen)
	vest.insert_path_into_outfit(police_outfit, human)
	if(police_outfit.suit != vest.item_path)
		Fail("The actual police outfit must receive the selected vest even before mind transfer.")
	qdel(civilian_outfit)
	qdel(police_outfit)
	var/list/packs = list(
		/datum/supply_pack/local/city_clothes = /obj/item/clothing/under/vampire/bogatyr/female,
		/datum/supply_pack/local/historical_costumes = /obj/item/clothing/under/vampire/nazi,
		/datum/supply_pack/weapons/armorpolice/chief = /obj/item/clothing/suit/vampire/vest/police/chief,
	)
	for(var/pack_type in packs)
		var/datum/supply_pack/pack = new pack_type()
		var/obj/structure/closet/crate/crate = allocate(/obj/structure/closet/crate)
		pack.fill(crate)
		var/expected_item = packs[pack_type]
		if(!(locate(expected_item) in crate.contents))
			Fail("The actual cargo fill path must deliver [expected_item] from [pack_type].")
		if(pack.cost < CARGO_CRATE_VALUE * 1.4)
			Fail("New apparel packs must retain the cargo crate minimum price.")
		qdel(pack)

/datum/unit_test/slim_catalogue/proc/assert_product(obj/structure/retail/store, item_path)
	var/entries = 0
	for(var/datum/data/vending_product/product as anything in store.products_list)
		if(product.product_path == item_path)
			entries++
	if(entries != 1)
		Fail("[store.type] must vend exactly one [item_path] entry, got [entries].")
#endif
