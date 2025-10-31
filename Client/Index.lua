
-- Spawns HUD
MainHUD = WebUI("Deathmatch HUD", "file:///UI/index.html")
ScoreboardToggled = false

-- Spawns Sun
Sky.Spawn()
Sky.SetTimeOfDay(9, 30)
Sky.SetAnimateTimeOfDay(false)

-- Disable Debug settings
Client.SetDebugEnabled(false)

-- Deathmatch data
Deathmatch = {
	remaining_time = 0
}

-- Updates Battlefield Kill UI configuration
KillHUDUIConfiguration.enable_auto_damage_score = true
KillHUDUIConfiguration.kill_auto_score = 20
KillHUDUIConfiguration.headshot_auto_score = 20


-- Input
Input.Register("Scoreboard", "Tab", "Toggles the Scoreboard")

-- Toggles the Scoreboard
Input.Bind("Scoreboard", InputEvent.Released, function()
	if (Deathmatch.match_state == MATCH_STATES.POST_TIME) then return end

	MainHUD:CallEvent("ToggleScoreboard", false)
	ScoreboardToggled = false
end)

Input.Bind("Scoreboard", InputEvent.Pressed, function()
	if (Deathmatch.match_state == MATCH_STATES.POST_TIME) then return end

	MainHUD:CallEvent("ToggleScoreboard", true)
	ScoreboardToggled = true
	UpdateAllPlayersScoreboard()
end)

-- Updates someone's scoreboard data
function UpdatePlayerScoreboard(player)
	MainHUD:CallEvent("UpdatePlayer", player:GetID(), true, player:GetSteamID(), player:GetName(), player:GetValue("Score") or 0, player:GetValue("Kills") or 0, player:GetValue("Deaths") or 0, player:GetPing())
end

--  Adds someone to the scoreboard
Player.Subscribe("Spawn", function(player)
	UpdatePlayerScoreboard(player)
end)

function UpdateAllPlayersScoreboard()
	for k, player in pairs(Player.GetAll()) do
		UpdatePlayerScoreboard(player)
	end
end

-- Updates the scoreboards data every 1 seconds
Timer.SetInterval(function()
	UpdateAllPlayersScoreboard()
end, 1000)

-- When LocalPlayer spawns, sets an event on it to trigger when we possesses a new character, to store the local controlled character locally. This event is only called once, see Package.Subscribe("Load") to load it when reloading a package
Client.Subscribe("SpawnLocalPlayer", function(local_player)
	local_player:Subscribe("Possess", function(player, character)
		UpdateLocalCharacter(character)
	end)
end)

-- When package loads, verify if LocalPlayer already exists (eg. when reloading the package), then try to get and store it's controlled character
Package.Subscribe("Load", function()
	Timer.SetTimeout(function()
		Events.CallRemote("PlayerReady")
	end, 200)

	if (Client.GetLocalPlayer() ~= nil) then
		UpdateLocalCharacter(Client.GetLocalPlayer():GetControlledCharacter())
		Client.GetLocalPlayer():Subscribe("Possess", function(player, character)
			UpdateLocalCharacter(character)
		end)
	end

	-- Updates all existing Players
	UpdateAllPlayersScoreboard()
end)

-- Function to set all needed events on local character (to update the UI when it takes damage or dies)
function UpdateLocalCharacter(character)
	-- Verifies if character is not nil (eg. when GetControllerCharacter() doesn't return a character)
	if (character == nil) then return end

	-- Updates the UI with the current character's health
	UpdateHealth(character:GetHealth())

	-- Sets on character an event to update the health's UI
	character:Subscribe("HealthChange", function(charac, old_health, new_health)
		UpdateHealth(new_health)
	end)

	-- Try to get if the character is holding any weapon
	local current_picked_item = character:GetPicked()

	-- If so, update the UI
	if (current_picked_item and current_picked_item:IsA(Weapon) and not current_picked_item:GetValue("ToolGun")) then
		UpdateAmmo(true, current_picked_item:GetAmmoClip(), current_picked_item:GetAmmoBag())
	end

	-- Sets on character an event to update his grabbing weapon (to show ammo on UI)
	character:Subscribe("PickUp", function(charac, object)
		if (object:IsA(Weapon) and not object:GetValue("ToolGun")) then
			UpdateAmmo(true, object:GetAmmoClip(), object:GetAmmoBag())

			-- Sets on character an event to update the UI when the ammo changes
			object:Subscribe("AmmoClipChange", function(weapon, old_ammo_clip, new_ammo_clip)
				UpdateAmmo(true, new_ammo_clip, weapon:GetAmmoBag())
			end)

			object:Subscribe("AmmoBagChange", function(weapon, old_ammo_bag, new_ammo_bag)
				UpdateAmmo(true, weapon:GetAmmoClip(), new_ammo_bag)
			end)
		end
	end)

	-- Sets on character an event to remove the ammo ui when he drops it's weapon
	character:Subscribe("Drop", function(charac, object)
		UpdateAmmo(false)
		object:Unsubscribe("AmmoClipChange")
		object:Unsubscribe("AmmoBagChange")
	end)
end

-- Function to update the Ammo's UI
function UpdateAmmo(enable_ui, ammo, ammo_bag)
	MainHUD:CallEvent("UpdateWeaponAmmo", enable_ui, ammo, ammo_bag)
end

-- Function to update the Health's UI
function UpdateHealth(health)
	MainHUD:CallEvent("UpdateHealth", health)
end

-- VOIP UI
Player.Subscribe("VOIP", function(player, is_talking)
	MainHUD:CallEvent("ToggleVoice", player:GetName(), is_talking)
end)

Player.Subscribe("Destroy", function(player)
	MainHUD:CallEvent("UpdatePlayer", player:GetID(), false)
end)

-- Receives from server the current match_state and remaining_time
Events.SubscribeRemote("UpdateMatchState", function(match_state, remaining_time, sky_hour_time)
	Deathmatch.match_state = match_state
	Deathmatch.remaining_time = remaining_time - 1

	local label = ""

	if (Deathmatch.match_state == MATCH_STATES.WARM_UP) then
		MainHUD:CallEvent("ToggleScoreboard", false)
		label = "WARM UP "

	elseif (Deathmatch.match_state == MATCH_STATES.PREPARING) then
		MainHUD:CallEvent("ToggleScoreboard", false)
		label = "STARTING IN "

	elseif (Deathmatch.match_state == MATCH_STATES.IN_PROGRESS) then
		label = ""

	elseif (Deathmatch.match_state == MATCH_STATES.POST_TIME) then
		-- Forces the Scoreboard to appear
		MainHUD:CallEvent("ToggleScoreboard", true)
		UpdateAllPlayersScoreboard()
		label = "POST TIME "

	end

	-- Calls UI to display the current match status and current remaining_time
	MainHUD:CallEvent("UpdateMatchStatus", label, Deathmatch.remaining_time)

	Sky.SetTimeOfDay(sky_hour_time, 0)
end)

-- Helpers for spawning sounds
Events.SubscribeRemote("SpawnSound", function(location, sound_asset, is_2D, volume, pitch)
	Sound(location, sound_asset, is_2D, true, SoundType.SFX, volume, pitch)
end)

Events.SubscribeRemote("SpawnActionSound", function(location, sound_asset)
	Sound(location, sound_asset, false, true, SoundType.SFX, 1, 1, 400, 10000, AttenuationFunction.LogReverse)
end)


-- Steam Scoreboard
Steam.FindLeaderboard("deathmatch")
Client.SetEscapeMenuLeaderboard(true, "deathmatch", "Deathmatch Top Players Leaderboard")

Events.SubscribeRemote("SubmitScoreToSteamLeaderboard", function(score)
	Steam.IncrementLeaderboardScore("deathmatch", score)
end)