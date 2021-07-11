Package.RequirePackage("NanosWorldWeapons")

-- List of the Default Weapons
DefaultWeapons = {
	NanosWorldWeapons.AK47,
	NanosWorldWeapons.AK74U,
	NanosWorldWeapons.GE36,
	NanosWorldWeapons.Glock,
	NanosWorldWeapons.DesertEagle,
	NanosWorldWeapons.AR4,
	NanosWorldWeapons.Moss500,
	NanosWorldWeapons.AP5,
	NanosWorldWeapons.SMG11,
	NanosWorldWeapons.ASVal,
}

-- List of Quaternius Weapons
QuaterniusWeapons = {
	"SpawnAssaultRifle_01",
	"SpawnAssaultRifle_02",
	"SpawnAssaultRifle_03",
	"SpawnAssaultRifle_04",
	"SpawnAssaultRifle_05",
	"SpawnAssaultRifle_06",
	"SpawnAssaultRifle_07",
	"SpawnAssaultRifle_08",
	"SpawnAssaultRifle_09",

	"SpawnBullpup_01",
	"SpawnBullpup_02",
	"SpawnBullpup_03",

	"SpawnPistol_01",
	"SpawnPistol_02",
	"SpawnPistol_03",
	"SpawnPistol_04",
	"SpawnPistol_05",
	"SpawnPistol_06",

	"SpawnRevolver_01",
	"SpawnRevolver_02",
	"SpawnRevolver_03",
	"SpawnRevolver_04",
	"SpawnRevolver_05",

	"SpawnSubmachineGun_01",
	"SpawnSubmachineGun_02",
	"SpawnSubmachineGun_03",
	"SpawnSubmachineGun_04",
	"SpawnSubmachineGun_05",

	"SpawnShotgun_01",
	"SpawnShotgun_02",
	"SpawnShotgun_03",
	"SpawnShotgun_04",
	"SpawnShotgun_05",

	"SpawnShotgun_SawedOff",

	"SpawnSniperRifle_01",
	"SpawnSniperRifle_02",
	"SpawnSniperRifle_03",
	"SpawnSniperRifle_04",
	"SpawnSniperRifle_05",
}

-- Deathmatch Settings
DeathmatchSettings = {
	warmup_time = 30,
	preparing_time = 13,
	match_time = 300,
	post_time = 15,
	multikill_time = 6,
	multikill_time_multiplier = 1,
	spawn_locations = {
		Vector(-100, -100, 100)
	},
	weapons_to_use = "Default" -- "Default"
}

-- Deathmatch Data
Deathmatch = {
	match_state = 0,
	remaining_time = 0,
	first_blood = false,
}

-- Helper for getting the correct announcer and label from kill count multi kill
function GetMultiKillLabel(kill_count)
	if (kill_count == 2) then return "DOUBLE KILL", "unreal-tournament-announcer::A_DoubleKill", 25 end
	if (kill_count == 3) then return "TRIPLE KILL", "unreal-tournament-announcer::A_TripleKill", 50 end
	if (kill_count == 4) then return "MULTI KILL", "unreal-tournament-announcer::A_MultiKill", 100 end
	if (kill_count == 5) then return "MEGA KILL!", "unreal-tournament-announcer::A_MegaKill", 200 end
	if (kill_count == 6) then return "ULTRA KILL!!", "unreal-tournament-announcer::A_UltraKill", 300 end

	return "MONSTER KILL!!!", "unreal-tournament-announcer::A_MonsterKill", 500
end

-- Helper for getting the correct announcer and label from kill count kill streak
function GetKillStreakLabel(kill_count)
	if (kill_count == 5) then return "KILLING SPREE", "unreal-tournament-announcer::A_KillingSpree", 100 end
	if (kill_count == 10) then return "RAMPAGE!", "unreal-tournament-announcer::A_Rampage", 200 end
	if (kill_count == 15) then return "DOMINATING!!", "unreal-tournament-announcer::A_Dominating", 300 end
	if (kill_count == 20) then return "UNSTOPPABLE!!!", "unreal-tournament-announcer::A_Unstoppable", 400 end
	if (kill_count >= 25) then return "GODLIKE!!!!!", "unreal-tournament-announcer::A_Godlike", 500 end

	return nil
end

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

		Server.BroadcastChatMessage("<cyan>" .. player:GetName() .. "</> is on a <red>" .. kill_streak .. "</> kill streak!")

		if (label) then
			-- Adds a score for kill streak
			AddScore(player, score, "killingspree", label)
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

		Server.BroadcastChatMessage("<cyan>" .. player:GetName() .. "</> made a <red>" .. label .. "</>")

		-- Adds a score for multi kill
		AddScore(player, score, "multikill", label)

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
			AddScore(instigator, 50, "killstreak_ended", "KILLSTREAK ENDED")

			Server.BroadcastChatMessage("<cyan>" .. instigator:GetName() .. "</> ended <cyan>" .. player:GetName() .. "'s</> <red>" .. kill_streak .. "</> streak!")
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
Character.Subscribe("TakeDamage", function(character, damage, bone, type, from, instigator)
	-- If it's suicide, ignore it
	if (not instigator or instigator == character:GetPlayer()) then
		return
	end

	local old_health = character:GetHealth()
	local real_damage = damage

	if (old_health - damage < 0) then
		real_damage = old_health
	end

	AddScore(instigator, real_damage, "enemy_hit", "ENEMY HIT", true)
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
				AddScore(instigator, 20, "headshot", "HEADSHOT")

				SpawnActionSound(killer_location, "unreal-tournament-announcer::A_Headshot", instigator)
				SpawnActionSound(killer_location, "unreal-tournament-announcer::A_Headshot", dead_player)
			end

			-- Adds score for killing
			AddScore(instigator, 20, "enemy_kill", "ENEMY KILL", false, true)

			-- Adds one more kill to count
			AddKill(instigator, killer_location)

			-- Spawns a Power Up in the place
			SpawnPowerUp(character:GetLocation())
		end
	end

	if (dead_player) then
		-- Adds a death to count
		AddDeath(dead_player, instigator)

		-- Immediately destroys the wepaon
		local weapon = dead_player:GetValue("Weapon")

		if (weapon and weapon:IsValid()) then
			weapon:Destroy()
		end

		-- Respawns after 5 seconds
		Timer.SetTimeout(function(_player)
			if (Deathmatch.match_state ~= MATCH_STATES.POST_TIME) then
				RespawnPlayer(_player)
			end
		end, 5000, dead_player)
	end
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

		Package.Log("[Deathmatch] Warm-up!")
		Server.BroadcastChatMessage("<grey>Warm-up!</>")

		CleanUp()

	elseif (new_state == MATCH_STATES.PREPARING) then
		Deathmatch.remaining_time = DeathmatchSettings.preparing_time

		Events.BroadcastRemote("SpawnSound", Vector(), "unreal-tournament-announcer::A_Prepare", true, 1, 1)

		Package.Log("[Deathmatch] Preparing!")
		Server.BroadcastChatMessage("<grey>Preparing!</>")

		CleanUp()

		-- Freeze all characters
		for k, character in pairs(Client.GetAll()) do
			character:SetMovementEnabled(false)
			character:SetFlyingMode(true)
		end

	elseif (new_state == MATCH_STATES.IN_PROGRESS) then
		Deathmatch.remaining_time = DeathmatchSettings.match_time
		Deathmatch.first_blood = false

		Events.BroadcastRemote("SpawnSound", Vector(), "unreal-tournament-announcer::A_Proceed", true, 1, 1)

		Package.Log("[Deathmatch] Round started!")
		Server.BroadcastChatMessage("<grey>Round Started!</>")

		-- Unfreeze all characters
		for k, character in pairs(Client.GetAll()) do
			character:SetMovementEnabled(true)
			character:SetFlyingMode(false)
		end

	elseif (new_state == MATCH_STATES.POST_TIME) then
		Deathmatch.remaining_time = DeathmatchSettings.post_time

		-- Freeze all characters
		for k, character in pairs(Client.GetAll()) do
			character:SetMovementEnabled(false)
			character:SetFlyingMode(true)
		end

		-- Match summary
		Server.BroadcastChatMessage("<green>End of match!</> Scoreboard:")
		Server.BroadcastChatMessage("<grey>=============================</>")

		local player_rank = {}

		for k, player in pairs(Player.GetAll()) do
			table.insert(player_rank, player)
		end

		table.sort(player_rank, function(a, b) return a:GetValue("Score") > b:GetValue("Score") end)

		for rank, player in pairs(player_rank) do
			-- Plays announcer sound if winner or last place
			if (rank == 1) then
				Events.CallRemote("SpawnSound", player, Vector(), "unreal-tournament-announcer::A_Winner", true, 1, 1)
			elseif (rank == #player_rank) then
				Events.CallRemote("SpawnSound", player, Vector(), "unreal-tournament-announcer::A_LastPlace", true, 1, 1)
			end

			Server.BroadcastChatMessage(tostring(rank) .. "# <cyan>" .. player:GetName() .. "</>: " .. tostring(player:GetValue("Score") or 0))
		end

		Server.BroadcastChatMessage("<grey>=============================</>")

		Package.Log("[Deathmatch] Post time!")
		Server.BroadcastChatMessage("<grey>Post time!</>")
	end

	-- Sends to the player the new match state
	UpdatePlayerMatchState()
end

-- When player joins and/or is ready
Events.Subscribe("PlayerReady", function(player)
	-- If the match is about to end, don't do nothing
	if (Deathmatch.match_state ~= MATCH_STATES.POST_TIME) then
		-- Respawns the character
		local character = RespawnPlayer(player)

		-- If is preparing, freeze him
		if (Deathmatch.match_state == MATCH_STATES.PREPARING) then
			character:SetMovementEnabled(false)
			character:SetFlyingMode(true)
		end
	end

	-- Sends him the match state
	UpdatePlayerMatchState(player)

	Server.BroadcastChatMessage("<cyan>" .. player:GetName() .. "</> has joined the server")
end)

-- When Player leaves the server
Player.Subscribe("Destroy", function(player)
	-- Destroy it's Character
	local character = player:GetControlledCharacter()
	if (character) then
		character:Destroy()
	end

	Server.BroadcastChatMessage("<cyan>" .. player:GetName() .. "</> has left the server")
end)

-- Helper for cleaning up deathmatch data from player
function CleanUp()
	for k, player in pairs(Player.GetAll()) do
		RespawnPlayer(player)

		player:SetValue("Kills", 0, true)
		player:SetValue("LastKillAt", 0, true)
		player:SetValue("MultiKillCount", 0, true)
		player:SetValue("Deaths", 0, true)
		player:SetValue("Score", 0, true)
		player:SetValue("KillStreak", 0, true)
		player:SetValue("Weapon", nil)
	end
end

-- Helper for spawning/respawning a character for a Player
function RespawnPlayer(player)
	if (not player or not player:IsValid()) then return end

	local character = player:GetControlledCharacter()

	local spawn_location = DeathmatchSettings.spawn_locations[math.random(#DeathmatchSettings.spawn_locations)] + Vector(0, 0, 5000)

	-- If player already has a character
	if (character) then

		-- If has a weapon, destroys it
		local weapon = player:GetValue("Weapon")

		if (weapon and weapon:IsValid()) then
			weapon:Destroy()
		end

		-- Respawns the character
		character:SetInitialLocation(spawn_location)
		character:Respawn()
	else
		-- character = Character(spawn_location.location, spawn_location.rotation, "NanosWorld::SK_Mannequin")
		-- Spawns a new character
		character = Character(spawn_location, Rotator(), "NanosWorld::SK_Mannequin")
		player:Possess(character)
	end

	-- Spawns a new weapon
	local weapon = SpawnWeapon()
	weapon:SetAmmoBag(weapon:GetAmmoClip() * 3)

	player:SetValue("Weapon", weapon)
	character:PickUp(weapon)

	-- Sets the character invulnerable for 3 seconds
	character:SetInvulnerable(true)
	character:SetMaterialColorParameter("Tint", Color.BLUE)

	Timer.SetTimeout(function(_character)
		if (_character and _character:IsValid()) then
			character:SetMaterialColorParameter("Tint", Color.WHITE)
			_character:SetInvulnerable(false)
		end
	end, 3000, character)

	return character
end

-- Helper for spawning weapons
function SpawnWeapon()
	-- Custom spawn for Quaternius weapons
	if (DeathmatchSettings.weapons_to_use == "quaternius") then
		local weapon_name = QuaterniusWeapons[math.random(#QuaterniusWeapons)]
		local weapon = Package.Call("quaternius-tools", weapon_name, {}, false)

		if (weapon) then
			return weapon
		end
	end

	-- If custom weapons didn't work or the default weapon is NanosWorldDefault weapons, spawns it
	local weapon_func = DefaultWeapons[math.random(#DefaultWeapons)]
	return weapon_func()
end

-- Helper for spawning a Power Up
function SpawnPowerUp(location)
	local new_location = location + Vector(0, 0, 30)

	-- Spawns 2 props for making a cross
	local powerup_01 = Prop(new_location, Rotator(), "NanosWorld::SM_Cube", CollisionType.NoCollision, false, false)
	powerup_01:SetScale(Vector(0.75, 0.25, 0.25))
	powerup_01:SetMaterialColorParameter("Emissive", Color.GREEN * 100)

	local powerup_02 = Prop(new_location, Rotator(), "NanosWorld::SM_Cube", CollisionType.NoCollision, false, false)
	powerup_02:SetScale(Vector(0.25, 0.25, 0.75))
	powerup_02:SetMaterialColorParameter("Emissive", Color.GREEN * 100)

	-- Spawns a trigger to activate the power up in a character
	local trigger = Trigger(new_location, Rotator(), Vector(100), TriggerType.Sphere, false)
	trigger:SetValue("Prop_01", powerup_01)
	trigger:SetValue("Prop_02", powerup_02)

	-- If a character overlaps it, he gets the power up
	trigger:Subscribe("BeginOverlap", function(self, object)
		if (NanosUtils.IsA(object, Character) and object:GetHealth() > 0) then
			self:GetValue("Prop_01"):Destroy()
			self:GetValue("Prop_02"):Destroy()

			-- Gives Health
			object:SetHealth(math.min(object:GetHealth() + 50, 120))

			-- Gives Ammo
			local weapon = object:GetPicked()
			if (weapon and NanosUtils.IsA(weapon, Weapon)) then
				weapon:SetAmmoBag(math.min(weapon:GetAmmoBag() + 50, 100))
			end

			-- Calls remote to force the player to update the Health/Ammo HUD
			Events.CallRemote("PickedUpPowerUp", object:GetPlayer())

			self:Destroy()
		end
	end)

	-- Destroys the Power Up after 30 seconds
	Timer.SetTimeout(function(_trigger)
		if (_trigger and _trigger:IsValid()) then
			_trigger:GetValue("Prop_01"):Destroy()
			_trigger:GetValue("Prop_02"):Destroy()
			_trigger:Destroy()
		end
	end, 30000, trigger)
end

-- Helper for updating the player's match state
function UpdatePlayerMatchState(player)
	local data = { Deathmatch.match_state, Deathmatch.remaining_time }

	if (player) then
		Events.CallRemote("UpdateMatchState", player, data)
	else
		Events.BroadcastRemote("UpdateMatchState", data)
	end
end

-- Helper for decreasing the current match state
function DecreaseRemainingTime()
	Deathmatch.remaining_time = Deathmatch.remaining_time - 1
	return (Deathmatch.remaining_time <= 0)
end

-- Helper for announcing the current match time
function AnnounceCountdown()
	if (Deathmatch.remaining_time == 300) then Events.BroadcastRemote("SpawnSound", Vector(), "unreal-tournament-announcer::A_Countdown_05_Minutes", true, 1, 1) return end
	if (Deathmatch.remaining_time == 180) then Events.BroadcastRemote("SpawnSound", Vector(), "unreal-tournament-announcer::A_Countdown_03_Minutes", true, 1, 1) return end
	if (Deathmatch.remaining_time == 60) then Events.BroadcastRemote("SpawnSound", Vector(), "unreal-tournament-announcer::A_Countdown_01_Minute", true, 1, 1) return end
	if (Deathmatch.remaining_time == 30) then Events.BroadcastRemote("SpawnSound", Vector(), "unreal-tournament-announcer::A_Countdown_30_Seconds", true, 1, 1) return end
	if (Deathmatch.remaining_time == 10) then Events.BroadcastRemote("SpawnSound", Vector(), "unreal-tournament-announcer::A_Countdown_10", true, 1, 1) return end
	if (Deathmatch.remaining_time == 9) then Events.BroadcastRemote("SpawnSound", Vector(), "unreal-tournament-announcer::A_Countdown_09", true, 1, 1) return end
	if (Deathmatch.remaining_time == 8) then Events.BroadcastRemote("SpawnSound", Vector(), "unreal-tournament-announcer::A_Countdown_08", true, 1, 1) return end
	if (Deathmatch.remaining_time == 7) then Events.BroadcastRemote("SpawnSound", Vector(), "unreal-tournament-announcer::A_Countdown_07", true, 1, 1) return end
	if (Deathmatch.remaining_time == 6) then Events.BroadcastRemote("SpawnSound", Vector(), "unreal-tournament-announcer::A_Countdown_06", true, 1, 1) return end
	if (Deathmatch.remaining_time == 5) then Events.BroadcastRemote("SpawnSound", Vector(), "unreal-tournament-announcer::A_Countdown_05", true, 1, 1) return end
	if (Deathmatch.remaining_time == 4) then Events.BroadcastRemote("SpawnSound", Vector(), "unreal-tournament-announcer::A_Countdown_04", true, 1, 1) return end
	if (Deathmatch.remaining_time == 3) then Events.BroadcastRemote("SpawnSound", Vector(), "unreal-tournament-announcer::A_Countdown_03", true, 1, 1) return end
	if (Deathmatch.remaining_time == 2) then Events.BroadcastRemote("SpawnSound", Vector(), "unreal-tournament-announcer::A_Countdown_02", true, 1, 1) return end
	if (Deathmatch.remaining_time == 1) then Events.BroadcastRemote("SpawnSound", Vector(), "unreal-tournament-announcer::A_Countdown_01", true, 1, 1) return end
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

-- Catches a custom event "MapLoaded" to override this script spawn locations
Events.Subscribe("MapLoaded", function(map_custom_spawn_locations)
	DeathmatchSettings.spawn_locations = map_custom_spawn_locations
end)