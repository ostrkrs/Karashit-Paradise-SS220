/datum/job/ai
	title = "AI"
	flag = JOB_AI
	department_flag = JOBCAT_ENGSEC
	total_positions = 0 // Not used for AI, see is_position_available below and modules/mob/living/silicon/ai/latejoin.dm
	spawn_positions = 1
	selection_color = "#ccffcc"
	supervisors = "своими законами"
	department_head = list("Captain")
	req_admin_notify = 1
	minimal_player_age = 30
	exp_map = list(EXP_TYPE_SILICON = 300)
	has_bank_account = FALSE

/datum/job/ai/equip(mob/living/carbon/human/H)
	if(!H)
		return FALSE

/datum/job/ai/is_position_available()
	return (length(GLOB.empty_playable_ai_cores) != 0)

/datum/job/cyborg
	title = "Cyborg"
	flag = JOB_CYBORG
	department_flag = JOBCAT_ENGSEC
	total_positions = 2
	spawn_positions = 2
	supervisors = "своими законами и ИИ"	//Nodrak
	department_head = list("AI")
	selection_color = "#ddffdd"
	minimal_player_age = 21
	exp_map = list(EXP_TYPE_CREW = 300)
	alt_titles = list("Robot")
	has_bank_account = FALSE

/datum/job/cyborg/equip(mob/living/carbon/human/H)
	if(!H)
		return FALSE
	return H.Robotize()
