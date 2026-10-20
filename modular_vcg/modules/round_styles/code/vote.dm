/datum/vote/city_round_style
	name = "Стиль раунда"
	default_choices = list("Спокойная ночь", "Вечная Борьба", "Война Принцев")
	default_message = "Спокойная ночь: без антагонистов и захватов. Вечная Борьба: антагонисты и временные захваты. Война Принцев: больше антагонистов; сохранение при 40 участниках с 40 активными минутами у каждого и участии всех фракций с территориями."

/datum/vote/city_round_style/can_be_initiated(forced)
	. = ..()
	if(. != VOTE_AVAILABLE)
		return .
	if(GLOB.city_round_style.finalized || SSticker.current_state != GAME_STATE_PREGAME)
		return "Стиль выбирается один раз перед началом раунда."
	return VOTE_AVAILABLE

/datum/vote/city_round_style/get_vote_result(list/non_voters)
	var/total = 0
	for(var/choice in choices)
		total += choices[choice]
	return total ? ..() : list()

/datum/vote/city_round_style/tiebreaker(list/winners)
	// Prefer the default on a tie; otherwise prefer the quieter tied style.
	for(var/choice in list("Вечная Борьба", "Спокойная ночь", "Война Принцев"))
		if(choice in winners)
			return choice

/datum/vote/city_round_style/finalize_vote(winning_option)
	var/selected = "eternal"
	switch(winning_option)
		if("Спокойная ночь")
			selected = "quiet"
		if("Война Принцев")
			selected = "war"
	GLOB.city_round_style.finalize_style(selected)
