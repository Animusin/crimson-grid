/// Underclothes retain the existing appearance layers and use no equipment slot.
/// Starting preferences materialize only on a real body's clothing interaction.
/mob/living/carbon/human
	var/list/worn_undergarments

/obj/item/undergarment
	abstract_type = /obj/item/undergarment
	name = "undergarment"
	desc = "Use it in hand to choose a style and put it on. Remove covering clothes first."
	icon = 'icons/mob/clothing/underwear.dmi'
	w_class = WEIGHT_CLASS_SMALL
	custom_price = 0
	custom_premium_price = 0
	resistance_flags = FLAMMABLE
	var/garment_category
	var/selected_style
	var/style_color
	var/mob/living/carbon/human/worn_by

/obj/item/undergarment/underwear
	name = "underwear"
	garment_category = "underwear"
	icon_state = "male_briefs"

/obj/item/undergarment/undershirt
	name = "bra or undershirt"
	garment_category = "undershirt"
	icon_state = "sports_bra"

/obj/item/undergarment/socks
	name = "socks or stockings"
	garment_category = "socks"
	icon_state = "black_knee"

/proc/undergarment_registry(category)
	switch(category)
		if("underwear")
			return SSaccessories.underwear_list
		if("undershirt")
			return SSaccessories.undershirt_list
		if("socks")
			return SSaccessories.socks_list
	return null

/mob/living/carbon/human/proc/get_undergarment_style(category)
	switch(category)
		if("underwear")
			return underwear
		if("undershirt")
			return undershirt
		if("socks")
			return socks
	return null

/mob/living/carbon/human/proc/has_undergarment(category)
	var/list/registry = undergarment_registry(category)
	var/datum/sprite_accessory/clothing/accessory = registry?[get_undergarment_style(category)]
	return !!accessory?.icon_state

/mob/living/carbon/human/proc/set_undergarment_style(category, style, new_color)
	switch(category)
		if("underwear")
			underwear = style
			if(!isnull(new_color))
				underwear_color = new_color
		if("undershirt")
			undershirt = style
		if("socks")
			socks = style

/// Style fields are authoritative: wardrobes can change them directly.
/// Refreshing a strip menu updates the same cached object, never a second one.
/mob/living/carbon/human/proc/ensure_undergarment(category)
	if(istype(src, /mob/living/carbon/human/dummy) || !has_undergarment(category))
		return null
	var/obj/item/undergarment/garment = worn_undergarments?[category]
	if(QDELETED(garment) || garment.loc != src || garment.garment_category != category)
		switch(category)
			if("underwear")
				garment = new /obj/item/undergarment/underwear(src)
			if("undershirt")
				garment = new /obj/item/undergarment/undershirt(src)
			if("socks")
				garment = new /obj/item/undergarment/socks(src)
			else
				return null
		LAZYSET(worn_undergarments, category, garment)
	garment.worn_by = src
	garment.configure_style(get_undergarment_style(category), category == "underwear" ? underwear_color : null, physique, bodyshape)
	return garment

/// Returns the actual covering item so both UI and quick actions can explain it.
/mob/living/carbon/human/proc/undergarment_covering_item(category)
	var/covered_part
	switch(category)
		if("underwear")
			covered_part = GROIN
		if("undershirt")
			covered_part = CHEST
		if("socks")
			if(shoes)
				return shoes
			covered_part = LEGS
		else
			return null
	if(wear_suit && (wear_suit.body_parts_covered & covered_part))
		return wear_suit
	if(w_uniform && (w_uniform.body_parts_covered & covered_part))
		return w_uniform
	return null

/mob/living/carbon/human/proc/remove_undergarment(category, mob/recipient)
	if(!has_undergarment(category))
		return null
	if(recipient && !recipient.can_perform_action(src, NEED_HANDS | FORBID_TELEKINESIS_REACH | ALLOW_RESTING))
		return null
	var/obj/item/covering = undergarment_covering_item(category)
	if(covering)
		to_chat(recipient || src, span_warning("Remove [covering] first to reach [category]."))
		return null
	var/atom/destination = drop_location()
	if(!destination)
		return null
	var/obj/item/undergarment/garment = ensure_undergarment(category)
	if(!garment || HAS_TRAIT(garment, TRAIT_NO_STRIP) || HAS_TRAIT(garment, TRAIT_NODROP))
		return null
	worn_undergarments -= category
	garment.worn_by = null
	set_undergarment_style(category, "Nude")
	garment.forceMove(destination)
	if(recipient)
		recipient.put_in_hands(garment)
	update_body()
	return garment

/obj/item/undergarment/proc/available_styles(mob/living/carbon/human/wearer)
	var/list/styles = list()
	if(!ishuman(wearer) || HAS_TRAIT(wearer, TRAIT_NO_UNDERWEAR))
		return styles
	if(garment_category == "socks" && (wearer.num_legs < 2 || (wearer.bodyshape & BODYSHAPE_DIGITIGRADE)))
		return styles
	var/list/registry = undergarment_registry(garment_category)
	for(var/style in registry)
		var/datum/sprite_accessory/clothing/accessory = registry[style]
		if(accessory?.icon_state)
			styles += style
	return sort_list(styles)

/obj/item/undergarment/proc/configure_style(style, new_color, physique, bodyshape)
	var/list/registry = undergarment_registry(garment_category)
	var/datum/sprite_accessory/clothing/accessory = registry?[style]
	if(!accessory?.icon_state)
		return FALSE
	selected_style = style
	style_color = garment_category == "underwear" ? new_color : null
	name = "[style] ([garment_category])"
	var/mutable_appearance/preview = accessory.make_appearance(style_color, physique, bodyshape)
	if(preview)
		icon = preview.icon
		icon_state = preview.icon_state
		color = preview.color
	return TRUE

/obj/item/undergarment/attack_self(mob/user, modifiers)
	. = ..()
	if(.)
		return
	if(!ishuman(user))
		return FALSE
	var/mob/living/carbon/human/wearer = user
	if(isnull(selected_style))
		var/list/styles = available_styles(wearer)
		if(!length(styles))
			return FALSE
		var/style = choose_style(wearer, styles)
		if(isnull(style) || QDELETED(src) || QDELETED(wearer) || !wearer.is_holding(src) || !(style in available_styles(wearer)))
			return FALSE
		configure_style(style, garment_category == "underwear" ? wearer.underwear_color : null, wearer.physique, wearer.bodyshape)
	return wear_on(wearer, wearer)

/obj/item/undergarment/proc/choose_style(mob/living/carbon/human/wearer, list/styles)
	return tgui_input_list(wearer, "Choose a style for this garment.", name, styles)

/obj/item/undergarment/attack(mob/living/target, mob/living/user, params)
	if(target == user)
		return attack_self(user, params)
	return ..()

/// A strip UI may equip another person; a held-item click equips its user.
/// Recheck all conditions after any selection or strip delay has yielded.
/obj/item/undergarment/proc/wear_on(mob/living/carbon/human/wearer, mob/user)
	user ||= wearer
	if(QDELETED(src) || QDELETED(wearer) || !ishuman(wearer) || !user?.is_holding(src) || !user.can_perform_action(wearer, NEED_HANDS | FORBID_TELEKINESIS_REACH | ALLOW_RESTING))
		return FALSE
	if(!(selected_style in available_styles(wearer)))
		return FALSE
	if(wearer.has_undergarment(garment_category))
		to_chat(user, span_warning("Remove the currently worn [garment_category] first."))
		return FALSE
	var/obj/item/covering = wearer.undergarment_covering_item(garment_category)
	if(covering)
		to_chat(user, span_warning("Remove [covering] first to put on [src]."))
		return FALSE
	if(!user.temporarilyRemoveItemFromInventory(src))
		return FALSE
	// A wardrobe may have cleared the appearance field directly. Retire its
	// old cached representation instead of leaving a second hidden garment.
	var/obj/item/undergarment/previous = wearer.worn_undergarments?[garment_category]
	if(previous && previous != src)
		previous.detach_wearer()
		qdel(previous)
	forceMove(wearer)
	worn_by = wearer
	LAZYSET(wearer.worn_undergarments, garment_category, src)
	wearer.set_undergarment_style(garment_category, selected_style, style_color)
	wearer.update_body()
	return TRUE

/// Forced movement or deletion must not leave a phantom worn appearance.
/obj/item/undergarment/proc/detach_wearer()
	var/mob/living/carbon/human/wearer = worn_by
	worn_by = null
	if(QDELETED(wearer) || wearer.worn_undergarments?[garment_category] != src)
		return
	wearer.worn_undergarments -= garment_category
	wearer.set_undergarment_style(garment_category, "Nude")
	wearer.update_body()

/obj/item/undergarment/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change)
	. = ..()
	if(worn_by && loc != worn_by)
		detach_wearer()

/obj/item/undergarment/Destroy(force)
	detach_wearer()
	return ..()

/mob/living/carbon/human/MiddleClickOn(atom/target, params)
	// The base returns its signal flags through '.', including its bare return
	// in the cancelled branch. Dispatch once and preserve that cancellation.
	. = ..()
	if(. & COMSIG_MOB_CANCEL_CLICKON)
		return
	if(target != src || zone_selected != BODY_ZONE_PRECISE_GROIN)
		return
	if(!can_perform_action(src, NEED_HANDS | FORBID_TELEKINESIS_REACH | ALLOW_RESTING))
		return
	for(var/category in list("underwear", "socks"))
		remove_undergarment(category, src)
