/obj/machinery/chemical_dispenser
	name = "chemical dispenser"
	icon = 'icons/obj/chemical.dmi'
	icon_state = "dispenser"

	var/list/spawn_cartridges = null // Set to a list of types to spawn one of each on New()

	var/list/cartridges = list() // Associative, label -> cartridge
	var/obj/item/weapon/reagent_containers/container = null

	var/ui_title = "Chemical Dispenser"

	var/accept_drinking = 0
	var/amount = 30

	use_power = 1
	idle_power_usage = 100
	density = 1
	anchored = 1
	waterproof = 0

/obj/machinery/chemical_dispenser/New()
	..()

	if(spawn_cartridges)
		for(var/type in spawn_cartridges)
			add_cartridge(new type(src))

/obj/machinery/chemical_dispenser/initialize()
	..()

	for(var/obj/item/weapon/reagent_containers/chem_disp_cartridge/C in cartridges)
		C.initialize()

/obj/machinery/chemical_dispenser/examine(mob/user)
	..()
	user << "It has [cartridges.len] cartridges installed, and has space for [DISPENSER_MAX_CARTRIDGES - cartridges.len] more."

/obj/machinery/chemical_dispenser/proc/add_cartridge(obj/item/weapon/reagent_containers/chem_disp_cartridge/C, mob/user)
	if(!istype(C))
		if(user)
			user << "<span class='warning'>\The [C] will not fit in \the [src]!</span>"
		return

	if(cartridges.len >= DISPENSER_MAX_CARTRIDGES)
		if(user)
			user << "<span class='warning'>\The [src] does not have any slots open for \the [C] to fit into!</span>"
		return

	if(!C.label)
		if(user)
			user << "<span class='warning'>\The [C] does not have a label!</span>"
		return

	if(cartridges[C.label])
		if(user)
			user << "<span class='warning'>\The [src] already contains a cartridge with that label!</span>"
		return

	if(user)
		user.drop_from_inventory(C)
		user << "<span class='notice'>You add \the [C] to \the [src].</span>"

	C.loc = src
	cartridges[C.label] = C
	cartridges = sortAssoc(cartridges)
	if(tguiProcess)
		tguiProcess.update_uis(src)

/obj/machinery/chemical_dispenser/proc/remove_cartridge(label)
	. = cartridges[label]
	cartridges -= label
	tguiProcess.update_uis(src)

/obj/machinery/chemical_dispenser/attackby(obj/item/weapon/W, mob/user)
	if(istype(W, /obj/item/weapon/wrench))
		playsound(src.loc, 'sound/items/Ratchet.ogg', 50, 1)
		user << "<span class='notice'>You begin to [anchored ? "un" : ""]fasten \the [src].</span>"
		if (do_after(user, 20))
			user.visible_message(
				"<span class='notice'>\The [user] [anchored ? "un" : ""]fastens \the [src].</span>",
				"<span class='notice'>You have [anchored ? "un" : ""]fastened \the [src].</span>",
				"You hear a ratchet.")
			anchored = !anchored
		else
			user << "<span class='notice'>You decide not to [anchored ? "un" : ""]fasten \the [src].</span>"

	else if(istype(W, /obj/item/weapon/reagent_containers/chem_disp_cartridge))
		add_cartridge(W, user)

	else if(istype(W, /obj/item/weapon/screwdriver))
		var/label = input(user, "Which cartridge would you like to remove?", "Chemical Dispenser") as null|anything in cartridges
		if(!label) return
		var/obj/item/weapon/reagent_containers/chem_disp_cartridge/C = remove_cartridge(label)
		if(C)
			user << "<span class='notice'>You remove \the [C] from \the [src].</span>"
			C.loc = loc

	else if(istype(W, /obj/item/weapon/reagent_containers/glass) || istype(W, /obj/item/weapon/reagent_containers/food))
		if(container)
			user << "<span class='warning'>There is already \a [container] on \the [src]!</span>"
			return

		var/obj/item/weapon/reagent_containers/RC = W

		if(!accept_drinking && istype(RC,/obj/item/weapon/reagent_containers/food))
			user << "<span class='warning'>This machine only accepts beakers!</span>"
			return

		if(!RC.is_open_container())
			user << "<span class='warning'>You don't see how \the [src] could dispense reagents into \the [RC].</span>"
			return

		container =  RC
		user.drop_from_inventory(RC)
		RC.loc = src
		user << "<span class='notice'>You set \the [RC] on \the [src].</span>"
		tguiProcess.update_uis(src) // update all UIs attached to src

	else
		return ..()

/obj/machinery/chemical_dispenser/ui_interact(mob/user, ui_key = "main", datum/tgui/ui = null, force_open = 0, \
											datum/tgui/master_ui = null, datum/ui_state/state = default_state)
	ui = tguiProcess.try_update_ui(user, src, ui_key, ui, force_open)
	if(!ui)
		ui = new(user, src, ui_key, "chem_dispenser", name, 550, 550, master_ui, state)
		ui.open()

/obj/machinery/chemical_dispenser/ui_data()
	var/data = list()
	data["amount"] = amount
	data["isBeakerLoaded"] = container ? 1 : 0
	data["containerType"] = (container ? capitalize(container.name) : (accept_drinking ? "Glass" : "Beaker"))

	var/list/beakerContents = list()
	var/beakerCurrentVolume = 0
	if(container && container.reagents && container.reagents.reagent_list.len)
		for(var/datum/reagent/R in container.reagents.reagent_list)
			beakerContents.Add(list(list("name" = R.name, "volume" = R.volume))) // list in a list because Byond merges the first list...
			beakerCurrentVolume += R.volume
	data["beakerContents"] = beakerContents

	if (container)
		data["beakerCurrentVolume"] = beakerCurrentVolume
		data["beakerMaxVolume"] = container.volume
		data["beakerTransferAmounts"] = container.possible_transfer_amounts
	else
		data["beakerCurrentVolume"] = null
		data["beakerMaxVolume"] = null
		data["beakerTransferAmounts"] = null

	var chemicals[0]
	for(var/label in cartridges)
		var/obj/item/weapon/reagent_containers/chem_disp_cartridge/C = cartridges[label]
		chemicals.Add(list(list("label" = label, "amount" = C.reagents.total_volume)))
	data["chemicals"] = chemicals
	return data

/obj/machinery/chemical_dispenser/ui_act(action, params)
	if(..())
		return
	switch(action)
		if("amount")
			var/target = text2num(params["target"])
			if(target in container.possible_transfer_amounts)
				amount = target
				. = TRUE
		if("dispense")
			var/label = params["reagent"]
			if(cartridges[label] && container && container.is_open_container())
				var/obj/item/weapon/reagent_containers/chem_disp_cartridge/C = cartridges[label]
				C.reagents.trans_to(container, amount)
				. = TRUE
		if("remove")
			var/amount = text2num(params["amount"])
			if(container && amount in container.possible_transfer_amounts)
				container.reagents.remove_any(amount)
				. = TRUE
		if("eject")
			if(container)
				container.forceMove(loc)
				container = null
				. = TRUE

/obj/machinery/chemical_dispenser/attack_ai(mob/user as mob)
	ui_interact(user)

/obj/machinery/chemical_dispenser/attack_hand(mob/user as mob)
	ui_interact(user)
