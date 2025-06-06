/datum/buildmode_mode/fill
	key = "fill"

	use_corner_selection = TRUE
	var/objholder = null

/datum/buildmode_mode/fill/show_help(mob/user)
	to_chat(user, "<span class='notice'>***********************************************************</span>")
	to_chat(user, "<span class='notice'>Left Mouse Button on turf/obj/mob      = Select corner</span>")
	to_chat(user, "<span class='notice'>Left Mouse Button + Alt on turf/obj/mob = Delete region</span>")
	to_chat(user, "<span class='notice'>Right Mouse Button on buildmode button = Select object type</span>")
	to_chat(user, "<span class='notice'>Left Mouse Button + alt on turf/obj    = Copy object type")
	to_chat(user, "<span class='notice'>***********************************************************</span>")

/datum/buildmode_mode/fill/change_settings(mob/user)
	var/target_path = tgui_input_text(user, "Enter typepath:" , "Typepath", "/obj/structure/closet")
	objholder = text2path(target_path)
	if(!ispath(objholder))
		objholder = pick_closest_path(target_path)
		if(!objholder)
			tgui_alert(user, "No path has been selected")
			return
		else if(ispath(objholder, /area))
			objholder = null
			tgui_alert(user, "Area paths are not supported for this mode, use the area edit mode instead")
			return
	deselect_region()

/datum/buildmode_mode/fill/handle_click(mob/user, params, obj/object)
	var/list/pa = params2list(params)
	var/alt_click = pa.Find("alt")
	var/left_click = pa.Find("left")
	if(left_click && alt_click)
		if(isturf(object) || isobj(object) || ismob(object))
			objholder = object.type
			to_chat(user, "<span class='notice'>[initial(object.name)] ([object.type]) selected.</span>")
		else
			to_chat(user, "<span class='notice'>[initial(object.name)] is not a turf, object, or mob! Please select again.</span>")
	if(isnull(objholder))
		to_chat(user, "<span class='warning'>Select an object type first.</span>")
		deselect_region()
		return
	..()

/datum/buildmode_mode/fill/handle_selected_region(mob/user, params)
	var/list/pa = params2list(params)
	var/left_click = pa.Find("left")
	var/alt_click = pa.Find("alt")

	if(left_click) //rectangular
		if(alt_click)
			empty_region(block(cornerA,cornerB))
		else
			for(var/turf/T in block(cornerA,cornerB))
				if(ispath(objholder,/turf))
					T.ChangeTurf(objholder)
				else
					var/obj/A = new objholder(T)
					A.setDir(BM.build_dir)
