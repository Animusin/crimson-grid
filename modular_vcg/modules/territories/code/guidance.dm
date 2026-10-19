#define BUSINESS_GUIDANCE_RADIUS 30

/obj/structure/city_business
	/// Client-specific rings and pointers never enter the mark's public overlays.
	var/list/guidance_viewers = list()

/atom/movable/screen/business_pointer
	name = "contested business"
	icon = 'icons/testing/turf_analysis.dmi'
	icon_state = "red_arrow"
	screen_loc = "CENTER,TOP:-52"
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	layer = SCREENTIP_LAYER
	maptext_width = 280
	maptext_height = 24
	maptext_x = -124
	maptext_y = -20

/// This deliberately uses job membership rather than a transferable credential.
/obj/structure/city_business/proc/guidance_visible_to(mob/living/user)
	if(!attack_faction || QDELETED(user) || !GET_CLIENT(user))
		return FALSE
	var/turf/user_turf = get_turf(user)
	var/turf/mark_turf = get_turf(src)
	return user_turf && mark_turf && user_turf.z == mark_turf.z && get_dist(user_turf, mark_turf) <= BUSINESS_GUIDANCE_RADIUS && (user.city_faction() in list(owner_faction, attack_faction))

/// Several simultaneous defenses may concern one faction; use its nearest mark.
/obj/structure/city_business/proc/guidance_is_nearest(mob/living/user)
	var/distance = get_dist(user, src)
	for(var/obj/structure/city_business/other as anything in GLOB.city_businesses)
		if(other == src || !other.guidance_visible_to(user))
			continue
		var/other_distance = get_dist(user, other)
		if(other_distance < distance || (other_distance == distance && GLOB.city_businesses.Find(other) < GLOB.city_businesses.Find(src)))
			return FALSE
	return TRUE

/// Called by the normal business HUD update, including completion of a contest.
/obj/structure/city_business/proc/update_guidance()
	if(!attack_faction || QDELETED(src))
		clear_guidance()
		return
	var/list/current_viewers = list()
	for(var/mob/living/user in GLOB.player_list)
		if(!guidance_visible_to(user))
			continue
		var/client/viewer = GET_CLIENT(user)
		if(viewer.mob != user)
			continue
		current_viewers += viewer
		var/datum/business_guidance/guidance = guidance_viewers[viewer]
		if(guidance && guidance.user != user)
			qdel(guidance)
			guidance = null
		if(!guidance)
			guidance = new(src, user, viewer)
			guidance_viewers[viewer] = guidance
		guidance.refresh()
	for(var/client/viewer as anything in guidance_viewers.Copy())
		if(!(viewer in current_viewers))
			remove_guidance(viewer)

/obj/structure/city_business/proc/remove_guidance(client/viewer)
	var/datum/business_guidance/guidance = guidance_viewers[viewer]
	guidance_viewers -= viewer
	qdel(guidance)

/// Also called from Destroy, so no client retains a deleted mark or pointer.
/obj/structure/city_business/proc/clear_guidance()
	for(var/client/viewer as anything in guidance_viewers.Copy())
		remove_guidance(viewer)

/datum/business_guidance
	var/obj/structure/city_business/business
	var/mob/living/user
	var/client/viewer
	var/image/ring
	var/atom/movable/screen/business_pointer/pointer

/datum/business_guidance/New(obj/structure/city_business/business, mob/living/user, client/viewer)
	..()
	src.business = business
	src.user = user
	src.viewer = viewer
	ring = image(icon = business.icon, loc = get_turf(business), icon_state = "contested", layer = business.layer + 0.1)
	ring.pixel_w = business.pixel_w
	ring.pixel_z = business.pixel_z
	viewer.images += ring
	pointer = new
	RegisterSignal(user, COMSIG_MOVABLE_MOVED, PROC_REF(on_move))
	RegisterSignals(user, list(COMSIG_MOB_LOGOUT, COMSIG_QDELETING), PROC_REF(on_departure))

/datum/business_guidance/proc/refresh()
	if(QDELETED(business) || QDELETED(user) || !viewer || GET_CLIENT(user) != viewer || viewer.mob != user || !business.guidance_visible_to(user))
		business?.remove_guidance(viewer)
		return
	ring.loc = get_turf(business)
	ring.pixel_w = business.pixel_w
	ring.pixel_z = business.pixel_z
	pointer.dir = get_dir(get_turf(user), get_turf(business)) || NORTH
	pointer.maptext = "<div style='text-align:center;color:#ff7777'>[html_encode(business.business_name)] — [get_dist(user, business)] tiles</div>"
	if(business.guidance_is_nearest(user))
		viewer.screen |= pointer
	else
		viewer.screen -= pointer

/datum/business_guidance/proc/on_move(datum/source)
	SIGNAL_HANDLER
	refresh()

/datum/business_guidance/proc/on_departure(datum/source)
	SIGNAL_HANDLER
	business?.remove_guidance(viewer)

/datum/business_guidance/Destroy()
	if(!QDELETED(user))
		UnregisterSignal(user, list(COMSIG_MOVABLE_MOVED, COMSIG_MOB_LOGOUT, COMSIG_QDELETING))
	if(viewer)
		viewer.images -= ring
		viewer.screen -= pointer
	qdel(pointer)
	ring = null
	pointer = null
	viewer = null
	user = null
	business = null
	return ..()

#undef BUSINESS_GUIDANCE_RADIUS
