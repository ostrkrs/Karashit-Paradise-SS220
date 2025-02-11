/datum/event/meteor_wave
	startWhen		= 5
	endWhen 		= 7
	var/next_meteor = 6
	var/waves = 1
	var/atom/movable/screen/alert/augury/meteor/screen_alert

/datum/event/meteor_wave/setup()
	for(var/mob/dead/observer/O in GLOB.dead_mob_list)
		var/atom/movable/screen/alert/augury/meteor/A = O.throw_alert("\ref[src]_augury", /atom/movable/screen/alert/augury/meteor)
		if(A)
			screen_alert = A

	waves = severity * 2 + rand(0, severity) //4-6 waves on medium. 6-9 waves on major. More consistant.

/datum/event/meteor_wave/announce(false_alarm)
	if(severity == EVENT_LEVEL_MAJOR || (false_alarm && prob(30)))
		GLOB.minor_announcement.Announce("Зафиксировано движение астероидов на встречном со станцией курсе.", "ВНИМАНИЕ: Астероиды.", new_sound = 'sound/AI/meteors.ogg')
	else
		GLOB.minor_announcement.Announce("Станция проходит через скопление астероидов.", "ВНИМАНИЕ: Астероиды.")

//meteor showers are lighter and more common,
/datum/event/meteor_wave/tick()
	// keep observers updated with the alert
	for(var/mob/dead/observer/O in GLOB.dead_mob_list)
		O.throw_alert("\ref[src]_augury", /atom/movable/screen/alert/augury/meteor)
	if(waves && activeFor >= next_meteor)
		INVOKE_ASYNC(GLOBAL_PROC, GLOBAL_PROC_REF(spawn_meteors), get_meteor_count(), get_meteors())
		next_meteor += rand(15, 30) / severity
		waves--
		endWhen = (waves ? next_meteor + 1 : activeFor + 15)

/datum/event/meteor_wave/end()
	for(var/mob/M in GLOB.dead_mob_list)
		M.clear_alert("\ref[src]_augury")
	QDEL_NULL(screen_alert)
	switch(severity)
		if(EVENT_LEVEL_MAJOR)
			GLOB.minor_announcement.Announce("Станция прошла через астероидный пояс", "ВНИМАНИЕ: Астероиды.")
		else
			GLOB.minor_announcement.Announce("Станция прошла через скопление астероидов", "ВНИМАНИЕ: Астероиды.")

/datum/event/meteor_wave/proc/get_meteors()
	switch(severity)
		if(EVENT_LEVEL_MAJOR)
			return GLOB.meteors_catastrophic
		if(EVENT_LEVEL_MODERATE)
			return GLOB.meteors_threatening
		else
			return GLOB.meteors_normal

/datum/event/meteor_wave/proc/get_meteor_count()
	return severity + rand(1, severity) //3 to 4 per wave for medium, 4-6 for major
