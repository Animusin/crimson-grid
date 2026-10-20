/obj/ritual_rune/thaumaturgy/selfgib
	name = "self destruction"
	desc = "Meet the Final Death."
	icon_state = "rune2"
	word = "CHNGE DA'WORD, GDBE"

/obj/ritual_rune/thaumaturgy/selfgib/complete()
	. = ..()
	SSplayer_quality?.record_execution(last_activator, last_activator)
	last_activator.death()

