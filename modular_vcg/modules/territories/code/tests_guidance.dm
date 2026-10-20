#if defined(UNIT_TESTS) || defined(SPACEMAN_DMM)

/// Only the mock adds this field; real clients already provide BYOND images.
/datum/client_interface/business_guidance
	var/list/images = list()

/datum/unit_test/city_business/guidance
	var/list/mock_players = list()

/datum/unit_test/city_business/guidance/proc/connect(mob/living/player)
	var/datum/client_interface/business_guidance/mock = allocate(/datum/client_interface/business_guidance)
	mock.mob = player
	player.mock_client = mock
	GLOB.player_list |= player
	mock_players += player
	return mock

/datum/unit_test/city_business/guidance/Destroy()
	for(var/mob/living/player as anything in mock_players)
		GLOB.player_list -= player
		var/datum/client_interface/mock = player.mock_client
		if(mock)
			mock.mob = null
		player.mock_client = null
	return ..()

/datum/unit_test/city_business/guidance/Run()
	var/turf/origin = run_loc_floor_bottom_left
	var/eastward = origin.x + 31 <= world.maxx ? 1 : -1
	var/turf/boundary = locate(origin.x + 30 * eastward, origin.y, origin.z)
	var/turf/outside = locate(origin.x + 31 * eastward, origin.y, origin.z)
	var/turf/northward = locate(origin.x, origin.y + (origin.y < world.maxy ? 1 : -1), origin.z)
	var/turf/other_level = locate(origin.x, origin.y, origin.z == 1 ? 2 : 1)
	if(!boundary || !outside || !northward || !other_level)
		return Fail("The guidance fixture needs a 31-tile boundary and a second map level.", __FILE__, __LINE__)
	var/obj/structure/city_business/unit_test/business = allocate(/obj/structure/city_business/unit_test, origin)
	business.owner_faction = FACTION_CAMARILLA
	business.attack_faction = FACTION_ANARCHS
	var/mob/living/carbon/human/business_test/defender = allocate(/mob/living/carbon/human/business_test, boundary)
	var/mob/living/carbon/human/business_test/attacker = allocate(/mob/living/carbon/human/business_test, origin)
	attacker.test_faction = FACTION_ANARCHS
	var/mob/living/carbon/human/business_test/bystander = allocate(/mob/living/carbon/human/business_test, origin)
	bystander.test_faction = FACTION_SABBAT
	var/mob/living/carbon/human/business_test/disconnected = allocate(/mob/living/carbon/human/business_test, origin)
	var/datum/client_interface/business_guidance/defender_client = connect(defender)
	var/datum/client_interface/business_guidance/attacker_client = connect(attacker)
	var/datum/client_interface/business_guidance/bystander_client = connect(bystander)
	// A carried defender credential does not make a bystander a participant.
	allocate(/obj/item/card/city_badge, bystander)
	business.update_guidance()
	var/datum/business_guidance/defense = business.guidance_viewers[defender_client]
	var/datum/business_guidance/attack = business.guidance_viewers[attacker_client]
	if(!defense || !attack || length(business.guidance_viewers) != 2 || length(bystander_client.images) || length(bystander_client.screen) || business.guidance_visible_to(disconnected))
		return Fail("Only connected actual owner/attacker members may see guidance, including the 30-tile boundary.", __FILE__, __LINE__)
	if(!(defense.ring in defender_client.images) || !(defense.pointer in defender_client.screen) || !(attack.ring in attacker_client.images) || defense.ring == attack.ring)
		return Fail("Each participant must receive a personal ring and top HUD pointer.", __FILE__, __LINE__)
	if(defense.pointer.dir != (eastward == 1 ? WEST : EAST))
		return Fail("The boundary pointer must face the business from the player's position.", __FILE__, __LINE__)
	defender.forceMove(northward)
	if(defense.pointer.dir != get_dir(northward, origin))
		return Fail("Actual movement must immediately turn the existing HUD pointer.", __FILE__, __LINE__)
	defender.forceMove(outside)
	if(business.guidance_viewers[defender_client] || length(defender_client.images) || length(defender_client.screen))
		return Fail("Moving to 31 tiles must remove both personal visuals immediately.", __FILE__, __LINE__)
	defender.forceMove(other_level)
	business.update_guidance()
	if(business.guidance_viewers[defender_client])
		return Fail("A nearby coordinate on another z level must never receive guidance.", __FILE__, __LINE__)
	defender.forceMove(boundary)
	business.update_guidance()
	if(!business.guidance_viewers[defender_client])
		return Fail("Returning to the boundary must restore the eligible participant's guidance.", __FILE__, __LINE__)
	defender.test_faction = FACTION_SABBAT
	business.update_guidance()
	if(business.guidance_viewers[defender_client] || length(defender_client.images) || length(defender_client.screen))
		return Fail("A faction change must revoke the personal ring and pointer.", __FILE__, __LINE__)
	var/obj/structure/city_business/unit_test/other = allocate(/obj/structure/city_business/unit_test, northward)
	other.owner_faction = FACTION_SABBAT
	other.attack_faction = FACTION_ANARCHS
	attacker.forceMove(northward)
	other.update_guidance()
	var/datum/business_guidance/nearer = other.guidance_viewers[attacker_client]
	if(!nearer || (attack.pointer in attacker_client.screen) || !(nearer.pointer in attacker_client.screen) || !(attack.ring in attacker_client.images) || !(nearer.ring in attacker_client.images))
		return Fail("Overlapping relevant contests must keep personal rings but display only the nearest pointer.", __FILE__, __LINE__)
	other.attack_faction = null
	other.update_guidance()
	business.update_guidance()
	SEND_SIGNAL(attacker, COMSIG_MOB_LOGOUT)
	if(business.guidance_viewers[attacker_client] || length(attacker_client.images) || length(attacker_client.screen))
		return Fail("Logout must immediately remove the old body's guidance.", __FILE__, __LINE__)
	business.update_guidance()
	business.finish_attack(FALSE)
	business.update_guidance()
	if(length(business.guidance_viewers) || length(attacker_client.images) || length(attacker_client.screen))
		return Fail("Finishing an announced contest must remove all personal visuals.", __FILE__, __LINE__)
	// Clearing is idempotent and also covers deletion before the next process tick.
	business.attack_faction = FACTION_ANARCHS
	business.update_guidance()
	if(!business.guidance_viewers[attacker_client])
		return Fail("A subsequent announced contest must create fresh guidance.", __FILE__, __LINE__)
	business.clear_guidance()
	business.clear_guidance()
	if(length(business.guidance_viewers) || length(attacker_client.images) || length(attacker_client.screen))
		return Fail("Repeated cleanup must leave no stale client images or screen objects.", __FILE__, __LINE__)
	business.update_guidance()
	// Exercise the caller's real Destroy hook, without finish_attack doing cleanup.
	business.attack_faction = null
	qdel(business)
	if(length(attacker_client.images) || length(attacker_client.screen))
		return Fail("Deleting a business must clear personal visuals without waiting for another process tick.", __FILE__, __LINE__)
#endif
