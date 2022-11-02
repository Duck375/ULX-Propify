local function propifyCheck()
	local remove_timer = true
	local players = player.GetAll()
	for i = 1, #players do
		local ply = players[ i ]
		if ply.propify then
			remove_timer = false
		end
	end

	if remove_timer then
		timer.Remove( "ULXPropify" )
	end
end

hook.Add( "AllowPlayerPickup", "CantTouchYourself", function( ply, ent )
    if ply.propify then
    	return false --Disallow player to pickup himself to avoid flying
    end
    return true
	end )

hook.Add("EntityTakeDamage", "FuniSoundAndUnbreak", function( target, dmginfo )
	if target.notplys then
		target:EmitSound("scientist/sci_pain" .. math.random(1,4) .. ".wav")
		dmginfo:SetDamage(0)
	end
end )

propifyPlayer = function(v, seconds)

    if v:InVehicle() then
		local vehicle = v:GetParent()
		v:ExitVehicle()
		vehicle:Remove()
	end

	if v.physgunned_by then
		for ply, v in pairs( v.physgunned_by ) do
			if ply:IsValid() and ply:GetActiveWeapon():IsValid() and ply:GetActiveWeapon():GetClass() == "weapon_physgun" then
				ply:ConCommand( "-attack" )
			end
		end
	end

	if v:GetMoveType() == MOVETYPE_NOCLIP then -- Take them out of noclip
		v:SetMoveType( MOVETYPE_WALK )
	end

	local pos = v:GetPos()
	local modelTable = {"models/props_lab/cactus.mdl", "models/props_junk/PopCan01a.mdl", "models/props_interiors/pot01a.mdl","models/props_lab/harddrive02.mdl","models/props_lab/monitor01a.mdl","models/props_junk/metal_paintcan001a.mdl","models/props_junk/watermelon01.mdl","models/Gibs/HGIBS.mdl","models/props_c17/doll01.mdl","models/props_c17/tv_monitor01.mdl","models/props_junk/TrafficCone001a.mdl"}
	Prop = ents.Create("prop_physics") -- Create our disguise
    local prop = Prop
	prop:SetModel(table.Random(modelTable)) --Here is our victim model
	local ang = v:GetAngles()
    ang.x = 0 -- The Angles should always be horizontal
    prop:SetAngles(ang)
    prop:SetPos(v:GetPos() + Vector(0,0, 20))
    prop:Spawn()
	prop.notplys = {pos=pos, v=v}

    local phys = prop:GetPhysicsObject()
    if not IsValid(phys) then return end
    phys:SetVelocity(v:GetVelocity())

    -- Spectate it
    v:Spectate(OBS_MODE_CHASE)
    v:SpectateEntity(Prop)
    v:StripWeapons() --Strip physgun to avoid flying
    v:DrawViewModel(false)
    v:DrawWorldModel(false)


	local turnSound = {"scientist/scream05.wav", "scientist/scream07.wav", "scientist/scream22.wav", "scientist/scream23.wav"}
    prop:EmitSound(turnSound[math.random( #turnSound )]) --for some reason table.Random is not working in this case

	local function unpropify()
		if not v:IsValid() or not v.propify or v.propify.key ~= key then -- Nope
			return
		end

		if not v:IsValid() then return end -- Make sure they're still connected

		v:UnSpectate()
		v:Spawn() -- We have to spawn before editing anything

		v:DrawViewModel(true)
		v:DrawWorldModel(true)
		prop.notplys = nil
		if prop:IsValid() then
		prop:Remove() -- Banish our prop, don't if it is disappeared
		end
		prop = nil

		v:DisallowNoclip( false )
		v:DisallowMoving( false ) --allow player to do stuff after propify end
		v:DisallowSpawning( false )
		v:DisallowVehicles( false )

		ulx.clearExclusive( v )
		ulx.setNoDie( v, false )
		v:KillSilent() --Respawn our player as additional punishment and to avoid stucking anywhere
		v:Spawn()
		v.propify = nil
	end

	if seconds > 0 then
		timer.Create(v:Name() .. "unprop", seconds, 0, unpropify ) --Wait for punishment to end and free player from being a prop
	end

	if seconds == 0 then
		timer.Remove(v:Name() .. "unprop")
	end
	v:DisallowNoclip( true )
	v:DisallowMoving( true )
	v:DisallowSpawning( true )
	v:DisallowVehicles( true )
	v.propify = { pos=pos, unpropify=unpropify, key=key }
	if seconds > 0 then
		v.propify.propify_until = CurTime() + seconds
	end
	ulx.setExclusive( v, "in prop state" )
	ulx.setNoDie( v, true )

	timer.Create( "ULXPropify", 1, 0, propifyCheck )
end

local function propifyDisconnectedCheck( ply )
	if ply.propify then
		ply.propify.unpropify()
	end
end
hook.Add( "PlayerDisconnected", "ULXpropifyDisconnectedCheck", propifyDisconnectedCheck, HOOK_MONITOR_HIGH )

function funipropRemoved(ent)
	if ent.notplys then
		local pl = ent.notplys.v
		pl.propify.unpropify()
		local left = timer.TimeLeft(pl:Name() .. "unprop") or 0
		timer.Remove(pl:Name() .. "unprop")
		propifyPlayer(pl, left)
	end
end

hook.Add("EntityRemoved", "Respawn_funi_prop", funipropRemoved)

function ulx.propify( calling_ply, target_plys, seconds, should_unpropify )
	local affected_plys = {}
	for i = 1, #target_plys do
		local v = target_plys[ i ]
		if not should_unpropify then
			if ulx.getExclusive( v, calling_ply ) then
				ULib.tsayError( calling_ply, ulx.getExclusive( v, calling_ply ), true )
			elseif not v:Alive() then
				ULib.tsayError( calling_ply, v:Nick() .. " is dead and cannot be propified!", true )
			else
				propifyPlayer( v, seconds )
				table.insert(affected_plys, v)
			end
		elseif v.propify then
			v.propify.unpropify()
			v.propify = nil
			table.insert(affected_plys, v)
		end
	end

	if not should_unpropify then
		local str = "#A propified #T"
		if seconds > 0 then
			str = str .. " for #i seconds"
		end
		ulx.fancyLogAdmin( calling_ply, str, affected_plys, seconds )
	else
		ulx.fancyLogAdmin( calling_ply, "#A unpropified #T", affected_plys )
	end
end



local propify = ulx.command( "Fun", "ulx propify", ulx.propify, "!propify" )
propify:addParam{ type=ULib.cmds.PlayersArg }
propify:addParam{ type=ULib.cmds.NumArg, min=0, default=0, hint="seconds, 0 is forever", ULib.cmds.round, ULib.cmds.optional }
propify:addParam{ type=ULib.cmds.BoolArg, invisible=true }
propify:defaultAccess( ULib.ACCESS_ADMIN )
propify:help( "Turns target(s) into prop (throw them from a window!)." )
propify:setOpposite( "ulx unpropify", {_, _, _, true}, "!unpropify" ) --Must have or nothing can be done to propified player expect to kick or ban
