/datum/component/selling/cannabis/can_sell()
	return HAS_TRAIT(parent, TRAIT_DRIED)

/datum/component/selling/cannabis/sale_fail_message()
	return span_warning("Only dried cannabis leaves can be sold.")

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
