/datum/component/selling/cannabis/can_sell()
	return HAS_TRAIT(parent, TRAIT_DRIED)

/datum/component/selling/cannabis/sale_fail_message()
	return span_warning("Only dried cannabis leaves can be sold.")

/obj/item
	/// NPC resale cannot turn an unlimited retail purchase into new money. For
	/// stacks this is a per-unit ceiling, preserved by splitting and merging.
	var/city_retail_unit_price

/obj/item/proc/city_record_retail_price(price)
	city_retail_unit_price = price
	if(isstack(src))
		var/obj/item/stack/stack = src
		city_retail_unit_price /= stack.amount
	// A stocked bag/kit cannot be sold once intact and again as separate contents.
	// Its allowance belongs to the purchased outer item only.
	for(var/obj/item/inside in get_all_contents())
		if(inside != src)
			inside.city_retail_unit_price = 0

/obj/item/proc/city_resale_price(proposed_price)
	if(isnull(city_retail_unit_price))
		return proposed_price
	var/ceiling = city_retail_unit_price
	if(isstack(src))
		var/obj/item/stack/stack = src
		ceiling *= stack.amount
	return min(proposed_price, FLOOR(ceiling, 1))

/obj/structure/retail/proc/dispense_product(product_path, purchase_price)
	var/obj/item/purchased
	if(ispath(product_path, /obj/item/stack))
		var/obj/item/stack/stack_type = product_path
		purchased = new product_path(null, initial(stack_type.amount), FALSE)
	else
		purchased = new product_path(null)
	// Initializing/moving a stack on the counter normally auto-merges it. Set
	// the receipt first so merging cannot erase it into an untracked floor stack.
	purchased.city_record_retail_price(purchase_price)
	purchased.forceMove(loc)
	return purchased

/obj/structure/retail/proc/business_price(mob/living/user, base_price)
	if(territory && user?.city_faction() == territory.owner_faction && user.has_city_badge(territory.owner_faction))
		return CEILING(base_price / 2, 1)
	return base_price

/obj/lombard/proc/business_can_sell(mob/living/user)
	if(!territory)
		return TRUE
	if(!territory.clerk_available() || territory.active_conflict)
		to_chat(user, span_warning("The buyer is not available."))
		return FALSE
	if(user.city_faction() != territory.owner_faction)
		to_chat(user, span_warning("This buyer only trades with [city_faction_name(territory.owner_faction)]."))
		return FALSE
	return TRUE
