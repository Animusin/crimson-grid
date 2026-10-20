/// Appearance underlayers share the ordinary strip menu, without inventory slot bits.
/datum/strippable_item/undergarment
	abstract_type = /datum/strippable_item/undergarment
	var/garment_category

/datum/strippable_item/undergarment/underwear
	key = "underwear"
	garment_category = "underwear"

/datum/strippable_item/undergarment/undershirt
	key = "undershirt"
	garment_category = "undershirt"

/datum/strippable_item/undergarment/socks
	key = "socks"
	garment_category = "socks"

/datum/strippable_item/undergarment/should_show(atom/source, mob/user)
	if(!ishuman(source) || istype(source, /mob/living/carbon/human/dummy) || HAS_TRAIT(source, TRAIT_NO_UNDERWEAR))
		return FALSE
	var/mob/living/carbon/human/wearer = source
	return garment_category != "socks" || (wearer.num_legs >= 2 && !(wearer.bodyshape & BODYSHAPE_DIGITIGRADE))

/datum/strippable_item/undergarment/get_item(atom/source)
	if(!ishuman(source))
		return null
	var/mob/living/carbon/human/wearer = source
	// Opening an actual body's menu materializes at most its one cached garment.
	// The shared helper refuses character-preview/dummy bodies.
	return wearer.ensure_undergarment(garment_category)

/datum/strippable_item/undergarment/get_obscuring(atom/source)
	if(!ishuman(source))
		return STRIPPABLE_OBSCURING_COMPLETELY
	var/mob/living/carbon/human/wearer = source
	return wearer.undergarment_covering_item(garment_category) ? STRIPPABLE_OBSCURING_INACCESSIBLE : STRIPPABLE_OBSCURING_NONE

/// Used before and after every delay, including the final non-yielding transfer.
/datum/strippable_item/undergarment/proc/can_access(atom/source, mob/user)
	return !QDELETED(source) && !QDELETED(user) \
		&& should_show(source, user) \
		&& isliving(user) && HAS_TRAIT(user, TRAIT_CAN_STRIP) \
		&& get_obscuring(source) == STRIPPABLE_OBSCURING_NONE \
		&& user.can_perform_action(source, NEED_HANDS | FORBID_TELEKINESIS_REACH | ALLOW_RESTING)

/datum/strippable_item/undergarment/try_equip(atom/source, obj/item/equipping, mob/user)
	if(!istype(equipping, /obj/item/undergarment) || !can_access(source, user))
		return FALSE
	var/obj/item/undergarment/garment = equipping
	var/mob/living/carbon/human/wearer = source
	if(garment.garment_category != garment_category || wearer.has_undergarment(garment_category) || !user.is_holding(garment))
		return FALSE
	return ..()

/datum/strippable_item/undergarment/start_equip(atom/source, obj/item/equipping, mob/user)
	if(!..())
		return FALSE
	var/equip_delay = source == user ? equipping.equip_delay_self : equipping.equip_delay_other
	if(equip_delay && !do_after(user, equip_delay, source, interaction_key = REF(equipping)))
		return FALSE
	return !QDELETED(equipping) && can_access(source, user) && user.is_holding(equipping)

/datum/strippable_item/undergarment/finish_equip(atom/source, obj/item/equipping, mob/user)
	if(!istype(equipping, /obj/item/undergarment) || !can_access(source, user))
		return FALSE
	var/obj/item/undergarment/garment = equipping
	if(garment.garment_category != garment_category || !garment.wear_on(source, user))
		return FALSE
	finish_equip_mob(garment, source, user)
	return TRUE

/datum/strippable_item/undergarment/try_unequip(atom/source, mob/user)
	return can_access(source, user) && ..()

/datum/strippable_item/undergarment/start_unequip(atom/source, mob/user)
	var/obj/item/undergarment/garment = get_item(source)
	if(!garment || !..() || !start_unequip_mob(garment, source, user))
		return FALSE
	return !QDELETED(garment) && can_access(source, user) && get_item(source) == garment

/datum/strippable_item/undergarment/finish_unequip(atom/source, mob/user)
	if(!can_access(source, user))
		return FALSE
	var/mob/living/carbon/human/wearer = source
	var/obj/item/undergarment/garment = get_item(source)
	if(!garment || HAS_TRAIT(garment, TRAIT_NO_STRIP) || HAS_TRAIT(garment, TRAIT_NODROP))
		return FALSE
	if(wearer.remove_undergarment(garment_category, user) != garment)
		return FALSE
	user.log_message("has stripped [key_name(source)] of [garment].", LOG_ATTACK, color="red")
	source.log_message("has been stripped of [garment] by [key_name(user)].", LOG_VICTIM, color="orange", log_globally=FALSE)
	return TRUE
