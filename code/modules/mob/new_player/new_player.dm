/mob/new_player
	var/ready = FALSE
	var/spawning = FALSE	//Referenced when you want to delete the new_player later on in the code.
	var/totalPlayers = 0		 //Player counts for the Lobby tab
	var/totalPlayersReady = 0
	universal_speak = TRUE

	invisibility = 101

	density = FALSE
	stat = DEAD

/mob/new_player/Initialize(mapload)
	SHOULD_CALL_PARENT(FALSE)
	if(initialized)
		stack_trace("Warning: [src]([type]) initialized multiple times!")
	initialized = TRUE
	input_focus = src
	GLOB.mob_list += src
	return INITIALIZE_HINT_NORMAL

/mob/new_player/Destroy()
	if(mind)
		mind.current = null // We best null their mind as well, otherwise /every/ single new player is going to explode the server a little more going in/out of the round
	return ..()

/mob/new_player/proc/new_player_panel()
	if(client.tos_consent || GLOB.configuration.system.external_tos_handler)
		new_player_panel_proc()
	else
		privacy_consent()

/mob/new_player/proc/privacy_consent()
	var/output = "<!DOCTYPE html>[GLOB.join_tos]"
	// Dont blank out the other window. This one is read only.
	if(!GLOB.configuration.system.external_tos_handler)
		src << browse(null, "window=playersetup")
		output += "<p><a href='byond://?src=[UID()];consent_signed=SIGNED'>Я согласен</A>"
		output += "<p><a href='byond://?src=[UID()];consent_rejected=NOTSIGNED'>Я не согласен</A>"
	src << browse(output,"window=privacy_consent;size=500x300")
	var/datum/browser/popup = new(src, "privacy_consent", "<div align='center'>Соглашение о конфиденциальности</div>", 500, 400)
	// Let them close it here, this is a read only pane
	if(!GLOB.configuration.system.external_tos_handler)
		popup.set_window_options("can_close=0")
	popup.set_content(output)
	popup.open(0)
	return

/mob/new_player/proc/new_player_panel_proc()
	set waitfor = FALSE
	var/real_name = client.prefs.active_character.real_name
	if(client.prefs.toggles2 & PREFTOGGLE_2_RANDOMSLOT)
		real_name = "Случайный персонаж"
	var/output = "<center><p><a href='byond://?src=[UID()];show_preferences=1'>Настройка персонажа</A><br /><i>[real_name]</i></p>"

	if(SSticker.current_state <= GAME_STATE_PREGAME)
		if(!ready)
			output += "<p><a href='byond://?src=[UID()];ready=1'>Нажмите, если готовы</A></p>"
		else
			output += "<p><b>Вы готовы</b> (<a href='byond://?src=[UID()];ready=2'>Отмена</A>)</p>"
	else
		output += "<p><a href='byond://?src=[UID()];manifest=1'>Просмотр списка экипажа</A></p>"
		output += "<p><a href='byond://?src=[UID()];late_join=1'>Присоединиться к игре!</A></p>"

	var/list/antags = client.prefs.be_special
	if(length(antags))
		if(!client.skip_antag)
			output += "<p><a href='byond://?src=[UID()];skip_antag=1'>Глобальная настройка антагов</A>"
		else
			output += "<p><a href='byond://?src=[UID()];skip_antag=2'>Global Antag Candidacy</A>"
		output += "<br /><small>Вы <b>[client.skip_antag ? "не готовы" : "готовы"]</b> для всех антаг ролей.</small></p>"

	if(SSticker.current_state == GAME_STATE_STARTUP)
		output += "<p>Наблюдать (Ожидайте...)</p>"
	else
		output += "<p><a href='byond://?src=[UID()];observe=1'>Наблюдать</A></p>"

	if(GLOB.join_tos)
		output += "<p><a href='byond://?src=[UID()];tos=1'>Условия использования</A></p>"

	if(length(GLOB.configuration.system.region_map))
		output += "<p><a href='byond://?src=[UID()];setregion=1'>Set region (reduces ping)</A></p>"

	output += "</center>"

	var/datum/browser/popup = new(src, "playersetup", "<div align='center'>Новый игрок</div>", 240, 340)
	popup.set_window_options("can_close=0")
	popup.set_content(output)
	popup.open(FALSE)

/mob/new_player/get_status_tab_items()
	var/list/status_tab_data = ..()
	. = status_tab_data
	if(SSticker)
		if(!SSticker.hide_mode)
			status_tab_data[++status_tab_data.len] = list("Режим:", "[GLOB.master_mode]")
		else
			status_tab_data[++status_tab_data.len] = list("Режим:", "Секрет")

		if(SSticker.current_state == GAME_STATE_PREGAME)
			status_tab_data[++status_tab_data.len] = list("Начало через:", SSticker.ticker_going ? deciseconds_to_time_stamp(SSticker.pregame_timeleft) : "ПАУЗА")
			if(check_rights(R_ADMIN, 0, src))
				status_tab_data[++status_tab_data.len] = list("Готово:", "[totalPlayersReady]")
			totalPlayersReady = 0
			for(var/mob/new_player/player in GLOB.player_list)
				if(check_rights(R_ADMIN, 0, src))
					status_tab_data[++status_tab_data.len] = list("[player.key]", player.ready ? "(В игре)" : "(Не готов)")
				if(player.ready)
					totalPlayersReady++

/mob/new_player/Topic(href, href_list[])
	if(!client)
		return FALSE

	if(usr != src)
		message_admins("[key_name_admin(usr)] may have attempted to href exploit with [key_name_admin(src)]'s new_player mob.")
		return

	if(href_list["consent_signed"])
		var/datum/db_query/query = SSdbcore.NewQuery("REPLACE INTO privacy (ckey, datetime, consent) VALUES (:ckey, Now(), 1)", list(
			"ckey" = ckey
		))
		// If the query fails we dont want them permenantly stuck on being unable to accept TOS
		query.warn_execute()
		qdel(query)
		src << browse(null, "window=privacy_consent")
		client.tos_consent = TRUE
		new_player_panel_proc()
	if(href_list["consent_rejected"])
		client.tos_consent = FALSE
		to_chat(usr, "<span class='warning'>Перед тем как присоединиться, вы должны согласиться с условиями использования!</span>")
		var/datum/db_query/query = SSdbcore.NewQuery("REPLACE INTO privacy (ckey, datetime, consent) VALUES (:ckey, Now(), 0)", list(
			"ckey" = ckey
		))
		// If the query fails we dont want them permenantly stuck on being unable to accept TOS
		query.warn_execute()
		qdel(query)

	if(href_list["show_preferences"])
		client.prefs.ShowChoices(src)
		return TRUE

	if(href_list["ready"])
		if(!client.tos_consent)
			to_chat(usr, "<span class='warning'>Перед тем как присоединиться, вы должны согласиться с условиями использования!</span>")
			return FALSE
		if(client.version_blocked)
			client.show_update_notice()
			return FALSE
		if(!ready && !client.prefs.active_character.check_any_job() && (client.prefs.active_character.alternate_option == RETURN_TO_LOBBY))
			to_chat(usr, "<span class='danger'>Вы не выбрали ни одну должность, а также включена функция возврата в лобби в случае недоступности должности. Это не даёт вам получить раунд-стартовую роль, проверьте ваши настройки должностей.</span>")
			ready = FALSE
			return FALSE

		// SS220 ADDITION START - TTS220
		if(!check_tts_seed_ready())
			return FALSE

		if(!can_use_species(src, client.prefs.active_character.species))
			to_chat(src, alert("You are currently not whitelisted to play [client.prefs.active_character.species]."))
			return FALSE
		// SS220 ADDITION END

		ready = !ready
		new_player_panel_proc()

	if(href_list["skip_antag"])
		client.skip_antag = !client.skip_antag
		new_player_panel_proc()

	if(href_list["refresh"])
		src << browse(null, "window=playersetup") //closes the player setup window
		new_player_panel_proc()

	if(href_list["observe"])
		if(!client.tos_consent)
			to_chat(usr, "<span class='warning'>Перед тем как присоединиться, вы должны согласиться с условиями использования!</span>")
			return FALSE
		if(client.version_blocked)
			client.show_update_notice()
			return FALSE
		if(!SSticker || SSticker.current_state == GAME_STATE_STARTUP)
			to_chat(usr, "<span class='warning'>Вы должны дождаться окончания запуска сервера, прежде чем сможете присоединиться к нему!</span>")
			return FALSE

		if(alert(usr, "Вы уверены, что хотите наблюдать? После этого Вы не сможете присоединиться к раунду!", "Наблюдать", "Да", "Нет") == "Да")
			if(!client)
				return TRUE
			var/mob/dead/observer/observer = new(src)
			src << browse(null, "window=playersetup")
			spawning = TRUE
			stop_sound_channel(CHANNEL_LOBBYMUSIC)
			if(ROUND_TIME <= (GLOB.configuration.general.roundstart_observer_period MINUTES))
				GLOB.roundstart_observer_keys |= ckey
				var/period_human_readable = "within [GLOB.configuration.general.roundstart_observer_period] minute\s"
				if(GLOB.configuration.general.roundstart_observer_period == 0)
					period_human_readable = "before the round started"
				to_chat(src, "<span class='notice'>As you observed [period_human_readable], you can freely toggle antag-hud without losing respawnability, and can freely observe what other players see.</span>")
				if(!check_rights(R_MOD | R_ADMIN | R_MENTOR, FALSE, src))
					// admins always get aobserve
					add_verb(observer, list(/mob/dead/observer/proc/do_observe, /mob/dead/observer/proc/observe))
			observer.started_as_observer = 1
			close_spawn_windows()
			var/obj/spawn_point
			if(SSticker.current_state < GAME_STATE_PLAYING)
				spawn_point = pick(GLOB.roundstart_observer_start)
			else
				spawn_point = locate("landmark*Observer-Start")

			to_chat(src, "<span class='notice'>Телепортация...</span>")
			observer.forceMove(get_turf(spawn_point))
			observer.timeofdeath = world.time // Set the time of death so that the respawn timer works correctly.
			client.prefs.active_character.update_preview_icon(1)
			observer.icon = client.prefs.active_character.preview_icon
			observer.alpha = 127

			if(client.prefs.active_character.be_random_name)
				client.prefs.active_character.real_name = random_name(client.prefs.active_character.gender,client.prefs.active_character.species)
			observer.real_name = client.prefs.active_character.real_name
			observer.name = observer.real_name
			observer.key = key
			ADD_TRAIT(observer, TRAIT_RESPAWNABLE, GHOSTED)
			qdel(src)
			return TRUE
		return FALSE
	if(href_list["tos"])
		privacy_consent()
		return FALSE

	if(href_list["setregion"])
		usr.client.change_region()
		return FALSE

	if(href_list["late_join"])
		if(!client.tos_consent)
			to_chat(usr, "<span class='warning'>Перед тем как присоединиться, вы должны согласиться с условиями использования!</span>")
			return FALSE
		if(client.version_blocked)
			client.show_update_notice()
			return FALSE
		if(!SSticker || SSticker.current_state != GAME_STATE_PLAYING)
			to_chat(usr, "<span class='warning'>Раунд либо не готов, либо уже завершился...</span>")
			return
		if(!can_use_species(src, client.prefs.active_character.species))
			to_chat(src, alert("В настоящее время вы не включены в белый список для игры на [client.prefs.active_character.species]."))
			return FALSE

		if(!check_tts_seed_ready()) // SS220 ADDITION - TTS
			return FALSE

		LateChoices()

	if(href_list["manifest"])
		ViewManifest()

	if(href_list["SelectedJob"])

		if(!GLOB.enter_allowed)
			to_chat(usr, "<span class='notice'>Администратор запретил входить в игру!</span>")
			return

		if(client.prefs.toggles2 & PREFTOGGLE_2_RANDOMSLOT)
			client.prefs.load_random_character_slot(client)

		if(!can_use_species(src, client.prefs.active_character.species))
			to_chat(src, alert("В настоящее время вы не включены в белый список для игры на [client.prefs.active_character.species]."))
			return FALSE

		AttemptLateSpawn(href_list["SelectedJob"])
		return

	if(!ready && href_list["preference"])
		if(client)
			client.prefs.process_link(src, href_list)
	else if(!href_list["late_join"])
		new_player_panel()

/mob/new_player/proc/IsJobAvailable(rank)
	var/datum/job/job = SSjobs.GetJob(rank)
	if(!job)
		return FALSE
	if(!job.is_position_available())
		return FALSE
	if(jobban_isbanned(src, rank))
		return FALSE
	if(!job.player_old_enough(client))
		return FALSE
	if(job.admin_only && !check_rights(R_EVENT, FALSE))
		return FALSE
	if(job.get_exp_restrictions(client))
		return FALSE
	if(job.mentor_only && !check_rights(R_MENTOR | R_ADMIN, FALSE))
		return FALSE

	if(GLOB.configuration.jobs.assistant_limit)
		if(job.title == "Assistant")
			var/count = 0
			var/datum/job/officer = SSjobs.GetJob("Security Officer")
			var/datum/job/warden = SSjobs.GetJob("Warden")
			var/datum/job/hos = SSjobs.GetJob("Head of Security")
			count += (officer.current_positions + warden.current_positions + hos.current_positions)
			if(job.current_positions > (GLOB.configuration.jobs.assistant_security_ratio * count))
				if(count >= 5) // if theres more than 5 security on the station just let assistants join regardless, they should be able to handle the tide
					return 1
				return 0
	return 1

/mob/new_player/proc/IsAdminJob(rank)
	var/datum/job/job = SSjobs.GetJob(rank)
	if(job.admin_only)
		return 1
	else
		return 0

/mob/new_player/proc/IsERTSpawnJob(rank)
	var/datum/job/job = SSjobs.GetJob(rank)
	if(job.spawn_ert)
		return 1
	else
		return 0

/mob/new_player/proc/IsSyndicateCommand(rank)
	var/datum/job/job = SSjobs.GetJob(rank)
	if(job.syndicate_command)
		return 1
	else
		return 0

/mob/new_player/proc/AttemptLateSpawn(rank)
	if(src != usr)
		return 0
	if(!SSticker || SSticker.current_state != GAME_STATE_PLAYING)
		to_chat(usr, "<span class='warning'>Раунд либо не готов, либо уже завершился...</span>")
		return 0
	if(!GLOB.enter_allowed)
		to_chat(usr, "<span class='notice'>Администратор запретил входить в игру!</span>")
		return 0
	if(!IsJobAvailable(rank))
		to_chat(src, alert("[rank] не доступен. Попробуйте другую должность."))
		return 0
	var/datum/job/thisjob = SSjobs.GetJob(rank)
	if(thisjob.barred_by_disability(client))
		to_chat(src, alert("[rank] недоступен из-за инвалидности вашего персонажа. Попробуйте другую должность."))
		return 0
	if(thisjob.barred_by_missing_limbs(client))
		to_chat(src, alert("[rank] недоступен из-за того, что у вашего персонажа ампутированы конечности и отсутствуют протезы. Попробуйте другую должность."))
		return 0

	SSjobs.job_selector.latejoin_assign(src, thisjob)

	var/mob/living/character = create_character()	//creates the human and transfers vars and mind
	character = SSjobs.AssignRank(character, rank, TRUE)					//equips the human

	// AIs don't need a spawnpoint, they must spawn at an empty core
	if(character.mind.assigned_role == "AI")
		var/mob/living/silicon/ai/ai_character = character.AIize() // AIize the character, but don't move them yet

		// IsJobAvailable for AI checks that there is an empty core available in this list
		ai_character.moveToEmptyCore()
		AnnounceCyborg(ai_character, rank, "has been downloaded to the empty core in \the [get_area(ai_character)]")

		SSticker.mode.latespawn(ai_character)
		qdel(src)
		return

	//Find our spawning point.
	var/join_message

	if(IsAdminJob(rank))
		if(IsERTSpawnJob(rank))
			character.loc = pick(GLOB.ertdirector)
		else if(IsSyndicateCommand(rank))
			character.loc = pick(GLOB.syndicateofficer)
		else
			character.forceMove(pick(GLOB.aroomwarp))
		join_message = "прибыл[character.gender == FEMALE ? "а" : ""]"
	else
		character.forceMove(pick(GLOB.latejoin))
		join_message = "прибыл[character.gender == FEMALE ? "а" : ""] на станцию"

	character.lastarea = get_area(loc)
	// Moving wheelchair if they have one
	if(character.buckled && istype(character.buckled, /obj/structure/chair/wheelchair))
		character.buckled.forceMove(character.loc)
		character.buckled.dir = character.dir

	character = SSjobs.EquipRank(character, rank, 1)					//equips the human
	SSticker.equip_cuis(character) // Gives them their CUIs

	SSticker.mode.latespawn(character)

	if(character.mind.assigned_role == "Cyborg")
		AnnounceCyborg(character, rank, join_message)
	else
		SSticker.minds += character.mind//Cyborgs and AIs handle this in the transform proc.	//TODO!!!!! ~Carn
		if(!IsAdminJob(rank))
			GLOB.data_core.manifest_inject(character)
			AnnounceArrival(character, rank, join_message)

			if(length(GLOB.current_pending_diseases) && character.ForceContractDisease(GLOB.current_pending_diseases[1], TRUE, TRUE))
				popleft(GLOB.current_pending_diseases)
			if(GLOB.summon_guns_triggered)
				give_guns(character)
			if(GLOB.summon_magic_triggered)
				give_magic(character)

	if(!thisjob.is_position_available() && (thisjob in SSjobs.prioritized_jobs))
		SSjobs.prioritized_jobs -= thisjob
	qdel(src)


/mob/new_player/proc/AnnounceArrival(mob/living/carbon/human/character, rank, join_message)
	if(SSticker.current_state == GAME_STATE_PLAYING)
		var/ailist[] = list()
		for(var/mob/living/silicon/ai/A in GLOB.ai_list)
			if(A.stat != DEAD && A.announce_arrivals)
				ailist += A
		if(length(ailist))
			var/mob/living/silicon/ai/announcer = pick(ailist)
			if(character.mind)
				if((character.mind.assigned_role != "Cyborg") && (character.mind.assigned_role != character.mind.special_role))
					if(character.mind.role_alt_title)
						rank = character.mind.role_alt_title
					var/arrivalmessage = announcer.arrivalmsg
					arrivalmessage = replacetext(arrivalmessage,"$name",character.real_name)
					arrivalmessage = replacetext(arrivalmessage,"$rank",rank ? "[rank]" : "visitor")
					arrivalmessage = replacetext(arrivalmessage,"$species",character.dna.species.name)
					arrivalmessage = replacetext(arrivalmessage,"$age",num2text(character.age))
					// Account for genderless mobs
					var/target_gender = "genderless"
					switch(character.gender)
						if(MALE)
							target_gender = "male"
						if(FEMALE)
							target_gender = "female"
					arrivalmessage = replacetext(arrivalmessage,"$gender",target_gender)
					announcer.say(";[arrivalmessage]", ignore_languages = TRUE, automatic = TRUE)
		else
			if(character.mind)
				if((character.mind.assigned_role != "Cyborg") && (character.mind.assigned_role != character.mind.special_role))
					if(character.mind.role_alt_title)
						rank = character.mind.role_alt_title
					GLOB.global_announcer.autosay("[character.real_name],[rank ? " [rank]," : ", посетитель," ] [join_message ? join_message : "прибыл на станцию"].", "Оповещение О Прибытии", follow_target_override = character)

/mob/new_player/proc/AnnounceCyborg(mob/living/character, rank, join_message)
	if(SSticker.current_state == GAME_STATE_PLAYING)
		var/ailist[] = list()
		for(var/mob/living/silicon/ai/A in GLOB.ai_list)
			ailist += A
		if(length(ailist))
			var/mob/living/silicon/ai/announcer = pick(ailist)
			if(character.mind)
				if(character.mind.assigned_role != character.mind.special_role)
					var/arrivalmessage = "Новый[rank ? " [rank]" : ", посетитель," ] [join_message ? join_message : "прибыл на станцию"]."
					announcer.say(";[arrivalmessage]", ignore_languages = TRUE, automatic = TRUE)
		else
			if(character.mind)
				if(character.mind.assigned_role != character.mind.special_role)
					// can't use their name here, since cyborg namepicking is done post-spawn, so we'll just say "A new Cyborg has arrived"/"A new Android has arrived"/etc.
					GLOB.global_announcer.autosay("Новый[rank ? " [rank]" : ", посетитель," ] [join_message ? join_message : "прибыл на станцию"].", "Оповещение О Прибытии", follow_target_override = character)

/mob/new_player/proc/LateChoices()
	var/mills = ROUND_TIME // 1/10 of a second, not real milliseconds but whatever
	//var/secs = ((mills % 36000) % 600) / 10 //Not really needed, but I'll leave it here for refrence.. or something
	var/mins = (mills % 36000) / 600
	var/hours = mills / 36000

	var/dat = "<html><meta charset='utf-8'><body><center>"
	dat += "Round Duration: [round(hours)]h [round(mins)]m<br>"
	dat += "<b>The station alert level is: [SSsecurity_level.get_colored_current_security_level_name()]</b><br>"

	if(SSshuttle.emergency.mode >= SHUTTLE_ESCAPE)
		dat += "<font color='red'><b>The station has been evacuated.</b></font><br>"
	else if(SSshuttle.emergency.mode >= SHUTTLE_CALL)
		dat += "<font color='red'>The station is currently undergoing evacuation procedures.</font><br>"

	if(length(SSjobs.prioritized_jobs))
		dat += "<font color='lime'>The station has flagged these jobs as high priority: "
		var/amt = length(SSjobs.prioritized_jobs)
		var/amt_count
		for(var/datum/job/a in SSjobs.prioritized_jobs)
			amt_count++
			if(amt_count != amt)
				dat += " [a.title], "
			else
				dat += " [a.title]. </font><br>"


	var/num_jobs_available = 0
	var/list/activePlayers = list()
	var/list/categorizedJobs = list(
		"Command" = list(jobs = list(), titles = GLOB.command_positions, color = "#aac1ee"),
		"Engineering" = list(jobs = list(), titles = GLOB.engineering_positions, color = "#ffd699"),
		"Security" = list(jobs = list(), titles = GLOB.active_security_positions, color = "#ff9999"),
		"Miscellaneous" = list(jobs = list(), titles = list(), color = "#ffffff", colBreak = 1),
		"Synthetic" = list(jobs = list(), titles = GLOB.nonhuman_positions, color = "#ccffcc"),
		"Support / Service" = list(jobs = list(), titles = GLOB.service_positions, color = "#cccccc"),
		"Medical" = list(jobs = list(), titles = GLOB.medical_positions, color = "#99ffe6", colBreak = 1),
		"Science" = list(jobs = list(), titles = GLOB.science_positions, color = "#e6b3e6"),
		"Supply" = list(jobs = list(), titles = GLOB.supply_positions, color = "#ead4ae"),
		)
	for(var/datum/job/job in SSjobs.occupations)
		if(job && IsJobAvailable(job.title) && !job.barred_by_disability(client) && !job.barred_by_missing_limbs(client))
			num_jobs_available++
			activePlayers[job] = 0
			var/categorized = 0
			// Only players with the job assigned and AFK for less than 10 minutes count as active
			for(var/mob/M in GLOB.player_list) if(M.mind && M.client && M.mind.assigned_role == job.title && M.client.inactivity <= 10 MINUTES)
				activePlayers[job]++
			for(var/jobcat in categorizedJobs)
				var/list/jobs = categorizedJobs[jobcat]["jobs"]
				if(job.title in categorizedJobs[jobcat]["titles"])
					categorized = 1
					if(jobcat == "Command") // Put captain at top of command jobs
						if(job.title == "Captain")
							jobs.Insert(1, job)
						else
							jobs += job
					else // Put heads at top of non-command jobs
						if(job.title in GLOB.command_positions)
							jobs.Insert(1, job)
						else
							jobs += job
			if(!categorized)
				categorizedJobs["Miscellaneous"]["jobs"] += job

	if(num_jobs_available)
		dat += "Выберите одну из следующих открытых вакансий:<br><br>"
		dat += "<table><tr><td valign='top'>"
		for(var/jobcat in categorizedJobs)
			if(categorizedJobs[jobcat]["colBreak"])
				dat += "</td><td valign='top'>"
			if(length(categorizedJobs[jobcat]["jobs"]) < 1)
				continue
			var/color = categorizedJobs[jobcat]["color"]
			dat += "<fieldset style='border: 2px solid [color]; display: inline'>"
			dat += "<legend align='center' style='color: [color]'>[jobcat]</legend>"
			for(var/datum/job/job in categorizedJobs[jobcat]["jobs"])
				if(job in SSjobs.prioritized_jobs)
					dat += "<a href='byond://?src=[UID()];SelectedJob=[job.title]'><font color='lime'><B>[job.title] ([job.current_positions]) (Active: [activePlayers[job]])</B></font></a><br>"
				else
					dat += "<a href='byond://?src=[UID()];SelectedJob=[job.title]'>[job.title] ([job.current_positions]) (Active: [activePlayers[job]])</a><br>"
			dat += "</fieldset><br>"

		dat += "</td></tr></table></center>"
	else
		dat += "<br><br><center>К сожалению, в настоящее время свободных вакансий нет.<BR>Попробуйте снова через несколько минут<BR>Или попробуйте понаблюдать за раундом.</center>"
	// Removing the old window method but leaving it here for reference
//		src << browse(dat, "window=latechoices;size=300x640;can_close=1")
	// Added the new browser window method
	var/datum/browser/popup = new(src, "latechoices", "Выберите должность", 900, 600)
	popup.add_stylesheet("playeroptions", 'html/browser/playeroptions.css')
	popup.add_script("delay_interactivity", 'html/browser/delay_interactivity.js')
	popup.set_content(dat)
	popup.open(0) // 0 is passed to open so that it doesn't use the onclose() proc

/mob/new_player/proc/create_character()
	spawning = TRUE
	close_spawn_windows()

	check_prefs_are_sane()
	var/mob/living/carbon/human/new_character = new(loc)
	new_character.lastarea = get_area(loc)
	client.prefs.active_character.copy_to(new_character)
	if(SSticker.random_players)
		var/mob/living/carbon/human/H = new_character
		scramble(1, H, 100)
		H.real_name = random_name(H.gender, H.dna.species.name)
		H.sync_organ_dna(assimilate = 1)
		H.update_body()
		H.reset_hair()
		H.reset_markings()
		H.dna.ResetUIFrom(H)
		H.flavor_text = ""
	stop_sound_channel(CHANNEL_LOBBYMUSIC)


	if(mind)
		mind.active = FALSE					//we wish to transfer the key manually
		// Clowns and mimes get appropriate default names, and the chance to pick a custom one.
		if(mind.assigned_role == "Clown")
			new_character.rename_character(new_character.real_name, pick(GLOB.clown_names))
			new_character.rename_self("clown")
		else if(mind.assigned_role == "Mime")
			new_character.rename_character(new_character.real_name, pick(GLOB.mime_names))
			new_character.rename_self("mime")
		mind.set_original_mob(new_character)
		mind.transfer_to(new_character)					//won't transfer key since the mind is not active


	new_character.key = key		//Manually transfer the key to log them in

	return new_character

// This is to check that the player only has preferences set that they're supposed to
/mob/new_player/proc/check_prefs_are_sane()
	var/datum/species/chosen_species
	if(client.prefs.active_character.species)
		chosen_species = GLOB.all_species[client.prefs.active_character.species]
	if(!(chosen_species && (is_species_whitelisted(chosen_species) || has_admin_rights())))
		// Have to recheck admin due to no usr at roundstart. Latejoins are fine though.
		stack_trace("[src] had species [client.prefs.active_character.species], though they weren't supposed to. Setting to Human.")
		client.prefs.active_character.species = "Human"

	var/datum/language/chosen_language
	if(client.prefs.active_character.language)
		chosen_language = GLOB.all_languages[client.prefs.active_character.language]
	if((chosen_language == null && client.prefs.active_character.language != "None") || (chosen_language && chosen_language.flags & RESTRICTED))
		stack_trace("[src] had language [client.prefs.active_character.language], though they weren't supposed to. Setting to None.")
		client.prefs.active_character.language = "None"

/mob/new_player/proc/ViewManifest()
	GLOB.generic_crew_manifest.ui_interact(usr)

/mob/new_player/Move()
	return 0


/mob/new_player/proc/close_spawn_windows()
	src << browse(null, "window=latechoices") //closes late choices window
	src << browse(null, "window=playersetup") //closes the player setup window
	src << browse(null, "window=preferences") //closes job selection
	src << browse(null, "window=mob_occupation")
	src << browse(null, "window=latechoices") //closes late job selection


/mob/new_player/proc/has_admin_rights()
	return check_rights(R_ADMIN, 0, src)

/mob/new_player/proc/is_species_whitelisted(datum/species/S)
	if(!S)
		return TRUE // Allow null species?
	return can_use_species(src, S.name)

/mob/new_player/get_gender()
	if(!client || !client.prefs) ..()
	return client.prefs.active_character.gender

/mob/new_player/is_ready()
	return ready && ..()

// No hearing announcements
/mob/new_player/can_hear()
	return 0
