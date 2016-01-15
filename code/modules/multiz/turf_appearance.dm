var/image/open_space_overlay = image('icons/turf/space.dmi', "openspace")
var/list/open_space_cache = list()

/turf/simulated/open/proc/update_appearance()

	if(!need_appearance_update)
		return
	if(!istype(below))
		below = GetBelow(src)
	if(!below)
		return

	need_appearance_update = 0

	overlays.Cut()

	// Shallow layers just show the layer below.
	if(layer_is_shallow(z))
		var/old_lum = luminosity
		appearance = below.appearance
		name = initial(name)
		desc = initial(desc)
		opacity = initial(opacity)
		luminosity = old_lum
		overlays += open_space_overlay
		layer = 0
	// Apply drop icon and fadeout for non-shallow layers.
	else
		var/turf/simulated/open/check_turf = get_step(src, NORTH)
		if(!below.drop_state || istype(check_turf))
			icon_state = "abyss"
		else
			icon_state = below.drop_state

			var/cache_key = "[below.drop_state]-fadeout-[NORTH]"
			if(!ocean_edge_cache[cache_key])
				ocean_edge_cache[cache_key] = image(icon = 'icons/turf/seafloor.dmi', icon_state = "[below.drop_state]-fadeout", dir = NORTH)
			overlays |= ocean_edge_cache[cache_key]

			for(var/checkdir in list(EAST, WEST))
				var/turf/simulated/open/O = get_step(src, checkdir)
				if(!istype(O))
					cache_key = "[below.drop_state]-fadeout-[checkdir]"
					if(!ocean_edge_cache[cache_key])
						ocean_edge_cache[cache_key] = image(icon = 'icons/turf/seafloor.dmi', icon_state = "[below.drop_state]-fadeout", dir = checkdir)
					overlays |= ocean_edge_cache[cache_key]

	// Apply edging and shadowing as appropriate.
	for(var/tempdir in cardinal)
		var/turf/T = get_step(src, tempdir)
		if(istype(T, /turf/unsimulated/ocean))
			var/turf/unsimulated/ocean/O = T
			if(O.blend_with_neighbors)
				var/cache_key = "[O.icon_state]-[tempdir]"
				if(!ocean_edge_cache[cache_key])
					ocean_edge_cache[cache_key] = image(icon = 'icons/turf/seafloor.dmi', icon_state = "[O.icon_state]-edge", dir = tempdir)
				overlays |= ocean_edge_cache[cache_key]
		else if(!istype(T, /turf/simulated/open))
			// Add the black edging that shows depth.
			if(!open_space_cache["[tempdir]"])
				open_space_cache["[tempdir]"] = image(icon= 'icons/turf/space.dmi', icon_state = "openspace_edges", dir = tempdir)
			overlays += open_space_cache["[tempdir]"]

	if(flooded)
		overlays |= get_ocean_overlay()

/turf/initialize()
	..()
	refresh_above()

/turf/proc/refresh_above()
	var/turf/simulated/open/open_space = GetAbove(src)
	if(istype(open_space))
		if(!open_space.need_appearance_update)
			open_space.need_appearance_update = 1
			queue_open_turf_update(open_space)

/turf/simulated/open/refresh_above()
	..()
	if(!need_appearance_update)
		need_appearance_update = 1
		queue_open_turf_update(src)

/turf/Entered(atom/movable/obj)
	. = ..()
	refresh_above()

/turf/Exited(atom/movable/obj)
	. = ..()
	refresh_above()

/atom/movable/lighting_overlay/update_overlay()
	if(..())
		var/turf/T = loc // Checked in ..()
		T.refresh_above()