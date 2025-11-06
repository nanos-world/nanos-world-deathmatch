Package.Require("Config.lua")

-- Deathmatch Settings
DeathmatchSettings = {
	warmup_time = 30,
	preparing_time = 13,
	match_time = 300,
	post_time = 15,
	multikill_time = 6,
	multikill_time_multiplier = 1,
	spawn_locations = Server.GetMapSpawnPoints(),
	weapons_to_use = "default", -- "quaternius"
	mode = GAME_MODE.DEATHMATCH
}

-- Deathmatch Data
Deathmatch = {
	match_state = 0,
	remaining_time = 0,
	first_blood = false,
	sky_hour_time = 9, -- Hour of the day
}


-- Helper for spawning an announcer sound
function SpawnActionSound(location, asset, player)
	-- We make a small delay to sound better
	Timer.SetTimeout(function(_asset)
		if (player) then
			Events.CallRemote("SpawnActionSound", player, location, _asset)
		else
			Events.BroadcastRemote("SpawnActionSound", location, _asset)
		end
	end, 300, asset)
end

-- Function to Add a Kill to the Player's kill count
function AddKill(player, location)
	local current_player_kills = player:GetValue("Kills") or 0
	player:SetValue("Kills", current_player_kills + 1, true)

	-- Updates last kill time
	local last_kill_at = player:GetValue("LastKillAt") or 0
	local now = os.time()
	player:SetValue("LastKillAt", now, true)

	-- Updates kill streak count
	local kill_streak = player:GetValue("KillStreak") or 0
	kill_streak = kill_streak + 1
	player:SetValue("KillStreak", kill_streak, true)

	-- Checks for First Blood
	if (not Deathmatch.first_blood) then
		Deathmatch.first_blood = true
		SpawnActionSound(location, "unreal-tournament-announcer::A_FirstBlood")
	end

	-- Checks for Kill Streak
	if (kill_streak >= 5) then
		local label, sound_asset, score = GetKillStreakLabel(kill_streak)

		Chat.BroadcastMessage("<cyan>" .. player:GetName() .. "</> is on a <red>" .. kill_streak .. "</> kill streak!")

		if (label) then
			-- Adds a score for kill streak
			if (DeathmatchSettings.mode == GAME_MODE.DEATHMATCH) then
				AddScore(player, score, "killingspree", label)
			end

			SpawnActionSound(location, sound_asset)
		end
	end

	local multikill_count = player:GetValue("MultiKillCount") or 0
	local multikill_time = DeathmatchSettings.multikill_time + multikill_count * DeathmatchSettings.multikill_time_multiplier

	-- Checks for Multi Kill
	if (os.difftime(now, last_kill_at) < multikill_time) then
		multikill_count = multikill_count + 1
		player:SetValue("MultiKillCount", multikill_count, true)

		local label, sound_asset, score = GetMultiKillLabel(multikill_count)

		Chat.BroadcastMessage("<cyan>" .. player:GetName() .. "</> made a <red>" .. label .. "</>")

		-- Adds a score for multi kill
		if (DeathmatchSettings.mode == GAME_MODE.DEATHMATCH) then
			AddScore(player, score, "multikill", label)
		end

		-- If is on more than Triple Kill, spawns sound for everyone
		if (multikill_count >= 3) then
			SpawnActionSound(location, sound_asset)
		else
			SpawnActionSound(location, sound_asset, player)
		end
	else
		-- Resets Multi Kill count
		player:SetValue("MultiKillCount", 1, true)
	end

	if (DeathmatchSettings.mode == GAME_MODE.GUNGAME) then
		if ((player:GetValue("Score") or 0) + 1 == #GunGameWeapons) then
			UpdateMatchState(MATCH_STATES.POST_TIME)
			Server:BroadcastChatMessage("<cyan>" .. player:GetName() .. "</> has won!")
			return
		end

		-- Updates accumulated kill
		local accumulated_kills = player:GetValue("AccumulatedKills") or 0

		if (accumulated_kills >= 1) then
			player:SetValue("AccumulatedKills", 0, true)
			-- Adds score for killing
			-- TODO sound
			AddScore(player, 1, "level_up", "LEVEL UP", false, true)

			-- If has a weapon, destroys it
			local character = player:GetControlledCharacter()
			local weapon = character:GetPicked()
			local old_aiming = character:GetWeaponAimMode()

			if (weapon and weapon:IsValid()) then
				weapon:Destroy()
			end

			local new_weapon = SpawnWeapon(player)

			if (new_weapon) then
				character:PickUp(new_weapon)
				character:SetWeaponAimMode(old_aiming)
			end
		else
			player:SetValue("AccumulatedKills", 1, true)
		end
	end
end

-- Function to Add a Death to the Player's death count
function AddDeath(player, instigator)
	local current_player_deaths = player:GetValue("Deaths") or 0
	player:SetValue("Deaths", current_player_deaths + 1, true)

	-- Checks for Kill Streak ending
	if (instigator) then
		local kill_streak = player:GetValue("KillStreak") or 0

		if (kill_streak >= 5) then
			-- Adds score for that
			if (DeathmatchSettings.mode == GAME_MODE.DEATHMATCH) then
				AddScore(instigator, 50, "killstreak_ended", "KILLSTREAK ENDED")
			end

			Chat.BroadcastMessage("<cyan>" .. instigator:GetName() .. "</> ended <cyan>" .. player:GetName() .. "'s</> <red>" .. kill_streak .. "</> streak!")
		end
	end

	-- Resets the Streak
	player:SetValue("KillStreak", 0, true)
end

-- Helper for adding Score to a player
function AddScore(player, score, id, label, use_current_label, silence)
	local current_player_score = player:GetValue("Score") or 0
	player:SetValue("Score", current_player_score + score, true)

	if (not silence) then
		-- Calls the player to notify the Score
		Events.CallRemote("AddScore", player, score, id, label, use_current_label or false)
	end
end

-- Adds score when damaging
Character.Subscribe("TakeDamage", function(character, damage, bone, type, from, instigator, causer)
	-- If it's suicide, ignore it
	if (not instigator or instigator == character:GetPlayer() or character:IsDead()) then
		return
	end

	-- Clamps the damage to Health
	local health = character:GetHealth()
	local true_damage = health < damage and health or damage

	if (DeathmatchSettings.mode == GAME_MODE.DEATHMATCH) then
		AddScore(instigator, true_damage, "enemy_hit", "ENEMY HIT", true)
	end
end)

-- When a character dies, check if I was the last one to do damage on him and displays on the screen as a kill
Character.Subscribe("Death", function(character, last_damage_taken, last_bone_damaged, damage_type_reason, hit_from_direction, instigator)
	local dead_player = character:GetPlayer()

	if (instigator) then
		-- Cannot be suicide
		if (instigator ~= dead_player) then
			local killer_character = instigator:GetControlledCharacter()
			local killer_location = (killer_character and killer_character:GetLocation()) or Vector()

			-- Gets the last hit bone and check if it was a Headshot
			local is_headshot = last_bone_damaged == "head" or last_bone_damaged == "neck_01"
			if (is_headshot) then
				-- If headshot, adds score and spawns an announcer sound for both killed and killer
				if (DeathmatchSettings.mode == GAME_MODE.DEATHMATCH) then
					AddScore(instigator, 20, "headshot", "HEADSHOT")
				end

				SpawnActionSound(killer_location, "unreal-tournament-announcer::A_Headshot", instigator)
				SpawnActionSound(killer_location, "unreal-tournament-announcer::A_Headshot", dead_player)
			end

			-- Adds score for killing

			if (DeathmatchSettings.mode == GAME_MODE.DEATHMATCH) then
				AddScore(instigator, 20, "enemy_kill", "ENEMY KILL", false, true)
			end

			-- Adds one more kill to count
			AddKill(instigator, killer_location)

			-- Spawns a Power Up in the place
			SpawnPowerUp(character:GetLocation())
		end
	end

	if (dead_player) then
		-- Adds a death to count
		AddDeath(dead_player, instigator)

		-- Immediately destroys the weapon
		local weapon = character:GetPicked()

		if (weapon and weapon:IsValid()) then
			weapon:Destroy()
		end

		-- Respawns after 5 seconds
		Timer.Bind(
			Timer.SetTimeout(function(_player)
				if (Deathmatch.match_state ~= MATCH_STATES.POST_TIME) then
					RespawnPlayer(_player)
				end
			end, 5000, dead_player),
			dead_player
		)
	end
end)

-- Destroys weapons if dropped, i.e. when Character dies
Weapon.Subscribe("Drop", function(weapon, character)
	weapon:Destroy()
end)

-- When package load, starts a Warm Up
Package.Subscribe("Load", function()
	Timer.SetTimeout(function()
		UpdateMatchState(MATCH_STATES.WARM_UP)
	end, 100)
end)

-- Helper for updating the match state
function UpdateMatchState(new_state)
	Deathmatch.match_state = new_state

	if (new_state == MATCH_STATES.WARM_UP) then
		Deathmatch.remaining_time = DeathmatchSettings.warmup_time
		Deathmatch.sky_hour_time = math.random(0, 24) -- random time

		Console.Log("Warm-up!")
		Chat.BroadcastMessage("<grey>Warm-up!</>")

		CleanUp()

	elseif (new_state == MATCH_STATES.PREPARING) then
		Deathmatch.remaining_time = DeathmatchSettings.preparing_time

		Events.BroadcastRemote("SpawnSound", Vector(), "unreal-tournament-announcer::A_Prepare", true, 1, 1)

		Console.Log("Preparing!")
		Chat.BroadcastMessage("<grey>Preparing!</>")

		CleanUp()

		-- Freeze all characters
		for k, character in pairs(Character.GetAll()) do
			character:SetInputEnabled(false)
			character:SetFlyingMode(true)
		end

	elseif (new_state == MATCH_STATES.IN_PROGRESS) then
		Deathmatch.remaining_time = DeathmatchSettings.match_time
		Deathmatch.first_blood = false

		Events.BroadcastRemote("SpawnSound", Vector(), "unreal-tournament-announcer::A_Proceed", true, 1, 1)

		Console.Log("Round started!")
		Chat.BroadcastMessage("<grey>Round Started!</>")

		-- Unfreeze all characters
		for k, character in pairs(Character.GetAll()) do
			character:SetInputEnabled(true)
			character:SetFlyingMode(false)
		end

	elseif (new_state == MATCH_STATES.POST_TIME) then
		Deathmatch.remaining_time = DeathmatchSettings.post_time

		-- Freeze all characters
		for k, character in pairs(Character.GetAll()) do
			character:SetInputEnabled(false)
			character:SetFlyingMode(true)
		end

		-- Match summary
		Chat.BroadcastMessage("<green>End of match!</> Scoreboard:")
		Chat.BroadcastMessage("<grey>=============================</>")

		local player_rank = {}

		for k, player in pairs(Player.GetAll()) do
			table.insert(player_rank, player)
		end

		table.sort(player_rank, function(a, b) return (a:GetValue("Score") or 0) > (b:GetValue("Score") or 0) end)

		for rank, player in pairs(player_rank) do
			-- Plays announcer sound if winner or last place
			if (rank == 1) then
				Events.CallRemote("SpawnSound", player, Vector(), "unreal-tournament-announcer::A_Winner", true, 1, 1)
			elseif (rank == #player_rank) then
				Events.CallRemote("SpawnSound", player, Vector(), "unreal-tournament-announcer::A_LastPlace", true, 1, 1)
			end

			local player_score = player:GetValue("Score") or 0

			Chat.BroadcastMessage(tostring(rank) .. "# <cyan>" .. player:GetName() .. "</>: " .. tostring(player_score))

			Events.CallRemote("SubmitScoreToSteamLeaderboard", player, player_score)
		end

		Chat.BroadcastMessage("<grey>=============================</>")

		Console.Log("Post time!")
		Chat.BroadcastMessage("<grey>Post time!</>")
	end

	-- Sends to the player the new match state
	UpdatePlayerMatchState()
end

-- When player joins and/or is ready
Events.SubscribeRemote("PlayerReady", function(player)
	-- If the match is about to end, don't do nothing
	if (Deathmatch.match_state ~= MATCH_STATES.POST_TIME) then
		-- Respawns the character
		local character = RespawnPlayer(player)

		-- If is preparing, freeze him
		if (Deathmatch.match_state == MATCH_STATES.PREPARING) then
			character:SetInputEnabled(false)
			character:SetFlyingMode(true)
		end
	end

	-- Sends him the match state
	UpdatePlayerMatchState(player)

	Chat.BroadcastMessage("<cyan>" .. player:GetName() .. "</> has joined the server")
end)

-- When Player leaves the server
Player.Subscribe("Destroy", function(player)
	-- Destroy it's Character
	local character = player:GetControlledCharacter()
	if (character) then
		character:Destroy()
	end

	Chat.BroadcastMessage("<cyan>" .. player:GetName() .. "</> has left the server")
end)

-- Helper for cleaning up deathmatch data from player
function CleanUp()
	for k, player in pairs(Player.GetAll()) do
		player:SetValue("Kills", 0, true)
		player:SetValue("LastKillAt", 0, true)
		player:SetValue("MultiKillCount", 0, true)
		player:SetValue("Deaths", 0, true)
		player:SetValue("Score", 0, true)
		player:SetValue("KillStreak", 0, true)
		player:SetValue("AccumulatedKills", 0)

		RespawnPlayer(player)
	end
end

-- Helper for spawning/respawning a character for a Player
function RespawnPlayer(player)
	if (not player or not player:IsValid()) then return end

	local character = player:GetControlledCharacter()

	local spawn_point = DeathmatchSettings.spawn_locations[math.random(#DeathmatchSettings.spawn_locations)]
	if (not spawn_point) then spawn_point = { location = Vector(math.random(-3000, 3000), math.random(-3000, 3000), 0), rotation = Rotator(0, math.random(-180, 180), 0) } end

	local spawn_location = spawn_point.location + Vector(0, 0, math.random(5000, 6000))
	local spawn_rotation = spawn_point.rotation or Rotator(0, math.random(-180, 180), 0)

	-- If player already has a character
	if (character) then

		-- If has a weapon, destroys it
		local weapon = character:GetPicked()

		if (weapon and weapon:IsValid()) then
			weapon:Destroy()
		end

		-- Respawns the character
		character:Respawn(spawn_location, spawn_rotation)
	else
		-- Spawns a new character
		local mesh = CharacterMeshes[math.random(#CharacterMeshes)]
		character = Character(spawn_location, spawn_rotation, mesh)

		-- Bad meshes come with mouth open by default
		character:SetMorphTarget("Close_Mouth", 1)

		character:SetCanDrop(false)
		character:SetSpeedMultiplier(1.3)

		player:Possess(character)
	end

	if (Deathmatch.match_state == MATCH_STATES.PREPARING) then
		character:SetInputEnabled(false)
	end

	-- Spawns a new weapon
	local weapon = SpawnWeapon(player)

	if (weapon) then
		character:PickUp(weapon)
	end

	-- Sets the character invulnerable for 3 seconds
	character:SetInvulnerable(true)
	character:SetMaterialColorParameter("Tint", Color.BLUE)

	Timer.Bind(
		Timer.SetTimeout(function(_character)
			_character:SetMaterialColorParameter("Tint", Color.WHITE)
			_character:SetInvulnerable(false)
		end, 3000, character),
		character
	)

	return character
end

-- Helper for spawning weapons
function SpawnWeapon(player)
	local weapon = nil

	if (DeathmatchSettings.mode == GAME_MODE.DEATHMATCH) then
		-- Custom spawn for Quaternius weapons
		if (DeathmatchSettings.weapons_to_use == "quaternius") then
			local weapon_name = QuaterniusWeapons[math.random(#QuaterniusWeapons)]
			weapon = Package.Call("quaternius-tools", weapon_name, {}, false)
		-- Default Weapons
		elseif (DeathmatchSettings.weapons_to_use == "default") then
			local weapon_func = DefaultWeapons[math.random(#DefaultWeapons)]
			weapon = weapon_func()
		end
	elseif (DeathmatchSettings.mode == GAME_MODE.GUNGAME) then
		local player_score = player:GetValue("Score") or 0

		-- Golden Knife
		if (player_score >= #GunGameWeapons) then return nil end

		local weapon_func = GunGameWeapons[player_score]
		weapon = weapon_func()
	end

	weapon:SetAmmoBag(weapon:GetAmmoClip() * 3)

	if (DeathmatchSettings.weapons_to_use == "default") then
		weapon:SetMaterialTextureParameter("PatternTexture", "assets://nanos-world/Textures/Pattern/" .. PatternList[math.random(#PatternList)])
		weapon:SetMaterialScalarParameter("PatternBlend", 1)
		weapon:SetMaterialScalarParameter("PatternTiling", 2)
		weapon:SetMaterialScalarParameter("PatternRoughness", 0.3)
	end

	return weapon
end

-- Helper for spawning a Power Up
function SpawnPowerUp(location)
	local new_location = location + Vector(0, 0, 30)

	-- Spawns 2 props for making a cross
	local powerup_01 = Prop(new_location, Rotator(), "nanos-world::SM_Cube", CollisionType.NoCollision, false, false)
	powerup_01:SetScale(Vector(0.75, 0.25, 0.25))
	powerup_01:SetMaterialColorParameter("Emissive", Color.GREEN * 1)

	local powerup_02 = Prop(new_location, Rotator(), "nanos-world::SM_Cube", CollisionType.NoCollision, false, false)
	powerup_02:SetScale(Vector(0.25, 0.25, 0.75))
	powerup_02:SetMaterialColorParameter("Emissive", Color.GREEN * 1)

	-- Spawns a trigger to activate the power up in a character
	local trigger = Trigger(new_location, Rotator(), Vector(100), TriggerType.Sphere, false, Color.BLACK, { "Character" })

	-- Attaches the PowerUp props, so they get destroyed immediately when trigger is destroyed
	powerup_01:AttachTo(trigger, AttachmentRule.SnapToTarget, "", 0)
	powerup_02:AttachTo(trigger, AttachmentRule.SnapToTarget, "", 0)

	-- If a character overlaps it, he gets the power up
	trigger:Subscribe("BeginOverlap", function(self, object)
		if (object:IsA(Character) and not object:IsDead()) then
			-- Gives Health
			object:SetHealth(math.min(object:GetHealth() + 50, 120))

			-- Gives Ammo
			local weapon = object:GetPicked()
			if (weapon and weapon:IsA(Weapon)) then
				weapon:SetAmmoBag(math.min(weapon:GetAmmoBag() + 50, 100))
			end

			Events.CallRemote("SpawnSound", object:GetPlayer(), Vector(), "nanos-world::A_VR_Open", true, 1, 1)

			self:Destroy()
		end
	end)

	-- Destroys the Power Up after 30 seconds
	trigger:SetLifeSpan(30)
end

-- Helper for updating the player's match state
function UpdatePlayerMatchState(player)
	if (player) then
		Events.CallRemote("UpdateMatchState", player, Deathmatch.match_state, Deathmatch.remaining_time, Deathmatch.sky_hour_time)
	else
		Events.BroadcastRemote("UpdateMatchState", Deathmatch.match_state, Deathmatch.remaining_time, Deathmatch.sky_hour_time)
	end
end

-- Helper for decreasing the current match state
function DecreaseRemainingTime()
	Deathmatch.remaining_time = Deathmatch.remaining_time - 1
	return (Deathmatch.remaining_time <= 0)
end

-- Helper for announcing the current match time
function AnnounceCountdown()
	local announcer = GetCountdownAnnouncer()
	if (not announcer) then return end

	Events.BroadcastRemote("SpawnSound", Vector(), announcer, true, 1, 1)
end

-- Server Tick to check remaining times
Timer.SetInterval(function()
	if (Deathmatch.match_state == MATCH_STATES.WARM_UP) then
		if (DecreaseRemainingTime()) then
			UpdateMatchState(MATCH_STATES.PREPARING)
		end
	elseif (Deathmatch.match_state == MATCH_STATES.PREPARING) then
		if (DecreaseRemainingTime()) then
			UpdateMatchState(MATCH_STATES.IN_PROGRESS)
		else
			AnnounceCountdown()
		end
	elseif (Deathmatch.match_state == MATCH_STATES.IN_PROGRESS) then
		if (DecreaseRemainingTime()) then
			UpdateMatchState(MATCH_STATES.POST_TIME)
		else
			AnnounceCountdown()
		end
	elseif (Deathmatch.match_state == MATCH_STATES.POST_TIME) then
		if (DecreaseRemainingTime()) then
			UpdateMatchState(MATCH_STATES.PREPARING)
		end
	end
end, 1000)
