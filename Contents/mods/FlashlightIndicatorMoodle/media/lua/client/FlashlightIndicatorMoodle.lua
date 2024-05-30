--[[
	NAME: FlashlightIndicatorMoodle.lua
	AUTHOR: GLICK!
	DATE: May 12, 2024
	UPDATED: May 19, 2024

	This module provides an interface for FlashlightIndicator.lua to access
	MoodleFramework. It aims to support expandability and allow the option to
	not require MoodleFramework in the future (such as if MoodleFramework stops
	being supported or if we want to use an icon instead of a moodle.)
]]

require("MF_ISMoodle")
local MoodleFramework = MF

local NOOP = function() end

local TorchMoodle = {
	playerMoodles = {},
	Activate = NOOP,
	Deactivate = NOOP,
	Hide = NOOP,
	Has = NOOP,
	SetIcons = NOOP,
	SetBackgroundsEnabled = NOOP,
}

if not MoodleFramework then
	print("[ERROR] FlashlightIndicatorMoodle failed to initialize; Missing mod dependency 'MoodleFramework', did you forget to enable it?")
	return TorchMoodle
end

-- Since we are abstracting moodle values into "states" to manipulate them,
-- we define the mapped values in this dictionary.
local MOODLE_STATES = {
	Inactive = 0,
	Disabled = 0.5,
	Active = 1,
}
local MOODLE_ICON_DIRECTORIES = {
	Standard = "media/ui/flashlightIndicator/",
	Alternate = "media/ui/flashlightIndicator/alternateTextures/",
}
-- A list of all the moodles in our mod. This is the SSoT for our moodles.
local MOODLE_NAMES = {
	"Flashlight",
	"Lighter",
}
-- Definitions of each moodle threshold value, as a functable.
-- As MoodleFramework's setThresholds method takes a tuple, this table can be
-- called as a function to return the results as such.
local MOODLE_THRESHOLDS = setmetatable({
	bad4 = nil,
	bad3 = nil,
	bad2 = -1,
	bad1 = 0,
	good1 = 1,
	good2 = 2,
	good3 = nil,
	good4 = nil,
}, {
	__call = function(t, ...)
		return t.bad4, t.bad3, t.bad2, t.bad1, t.good1, t.good2, t.good3, t.good4
	end,
})

local function getMoodle(moodleName, playerObject)
	-- If the provided arg is a valid moodleName it will have a positive index
	if luautils.indexOf(MOODLE_NAMES, moodleName) > 0 then
		-- getMoodle arg #2 is optional (if you hate multiplayer)
		local playerIndex
		do
			if playerObject then
				playerIndex = playerObject:getPlayerNum()
			end
		end
		local moodle = MoodleFramework.getMoodle(moodleName, playerIndex)
		-- getMoodle will return nil if it has not initialized
		if moodle then
			return moodle
		end
	end
	return nil
end

local function setMoodleValue(moodleName, playerObject, value)
	local moodle = getMoodle(moodleName, playerObject)
	if moodle then
		moodle:setValue(value)
	end
end

local function updateMoodleThresholds(moodleName, playerObject)
	local moodle = getMoodle(moodleName, playerObject)
	if moodle then
		moodle:setThresholds(MOODLE_THRESHOLDS())
	end
end

local function makeMoodle(name)
	MoodleFramework.createMoodle(name)
	updateMoodleThresholds(name)
end

local function onPlayerCreated(_playerIndex, _playerObject)
	for _, moodleName in ipairs(MOODLE_NAMES) do
		updateMoodleThresholds(moodleName)
	end
end

--NOTE: API argument order is purposefully swapped to incentivize providing
-- a playerObject. Methods will still work without one but it is not
-- recommended for the sake of multiplayer and splitscreen.

--[[
	If the provided moodleName corresponds to a moodle, sets the moodle
	value to the "good" threshold.

	@param1 <IsoPlayer> playerObject
	@param2 <string> moodleName
]]
function TorchMoodle.Activate(playerObject, moodleName)
	setMoodleValue(moodleName, playerObject, MOODLE_STATES.Active)
end

--[[
	If the provided moodleName corresponds to a moodle, sets the moodle
	value to the "bad" threshold.

	@param1 <IsoPlayer> playerObject
	@param2 <string> moodleName
]]
function TorchMoodle.Deactivate(playerObject, moodleName)
	setMoodleValue(moodleName, playerObject, MOODLE_STATES.Inactive)
end

--[[
	Handles moodle visibility by setting the moodle to neutral (0.5) or
	inactive (0) if not already visible.

	@param1 <IsoPlayer> playerObject
	@param2 <string> moodleName
	@param3 <boolean> isVisible
]]
function TorchMoodle.Hide(playerObject, moodleName)
	setMoodleValue(moodleName, playerObject, MOODLE_STATES.Disabled)
end

--[[
	Simple helper function to check if the specified moodle is set to active
	(good) for the player.

	@param1 <IsoPlayer> playerObject
	@param2 <string> moodleName
]]
function TorchMoodle.IsActive(playerObject, moodleName)
	local moodle = getMoodle(moodleName, playerObject)
	if moodle then
		return moodle:getValue() == MOODLE_STATES.Active
	end
	return false
end

--[[
	Simple helper function to check if the player has the specified moodle
	enabled. Primarily used as part of the logic controller's
	(FlashlightIndicator.lua) evaluation cycle.

	@param1 <IsoPlayer> playerObject
	@param2 <string> moodleName
]]
function TorchMoodle.Has(playerObject, moodleName)
	local moodle = getMoodle(moodleName, playerObject)
	if moodle then
		-- In this context, '0' means 'Neutral' and 'Neutral' means 'nil'
		return moodle:getGoodBadNeutral() ~= 0
	end
	return false
end

--[[
	Switches between the two icon sets defined in MOODLE_ICON_DIRECTORIES.
	Called from FlashlightIndicator.lua when a setting is updated.

	@param1 <boolean> useAlternateIcons
]]
function TorchMoodle.SetIcons(useAlternateIcons)
	local iconDirectory	do
		if useAlternateIcons then
			iconDirectory = MOODLE_ICON_DIRECTORIES["Alternate"]
		else
			iconDirectory = MOODLE_ICON_DIRECTORIES["Standard"]
		end
	end

	local function setMoodleIcon(moodle, moodleName)
		-- arg#1 is goodBadNeutral (Neutral = 0, Good = 1, Bad = 2)
		-- arg#2 is moodleLevel, we only use '1' because our moodles are binary
		moodle:setPicture(1, 1, getTexture(iconDirectory .. moodleName .. "_On.png"))
		moodle:setPicture(2, 1, getTexture(iconDirectory .. moodleName .. "_Off.png"))
		moodle:setTitle(1, 1, getText("Moodles_" .. moodleName .. "_Good_lvl1"))
		moodle:setTitle(2, 1, getText("Moodles_" .. moodleName .. "_Bad_lvl1"))
		moodle:setDescription(1, 1, getText("Moodles_" .. moodleName .. "_Good_desc_lvl1"))
		moodle:setDescription(2, 1, getText("Moodles_" .. moodleName .. "_Bad_desc_lvl1"))
	end

	local function setMoodleIconsForPlayer(playerObject)
		for index = 1, #MOODLE_NAMES do
			local moodleName = MOODLE_NAMES[index]
			local moodle = getMoodle(moodleName, playerObject)
			if moodle then
				setMoodleIcon(moodle, moodleName)
			end
		end
	end

	-- Moodles are created per player so we need to set each instance individually
	local onlinePlayers = IsoPlayer.getPlayers()
	for index = 0, (onlinePlayers:size() - 1) do
		local playerObject = onlinePlayers:get(index)
		if playerObject then
			setMoodleIconsForPlayer(playerObject)
		end
	end
end

--[[
	Sets the background moodle image to the default image (true) or nil (false).

	@param1 <boolean> showBackgrounds
]]
function TorchMoodle.SetBackgroundsEnabled(showBackgrounds)
	local function setMoodleBackground(moodle)
		if showBackgrounds then
			moodle:setBackground(1, 1, getTexture("media/ui/Moodle_Bkg_Good_1.png"))
			moodle:setBackground(2, 1, getTexture("media/ui/Moodle_Bkg_Bad_1.png"))
		else
			moodle:setBackground(1, 1, getTexture("media/ui/cursor_blank.png"))
			moodle:setBackground(2, 1, getTexture("media/ui/cursor_blank.png"))
		end
	end

	local function setMoodleBackgroundsForPlayer(playerObject)
		for index = 1, #MOODLE_NAMES do
			local moodleName = MOODLE_NAMES[index]
			local moodle = getMoodle(moodleName, playerObject)
			if moodle then
				setMoodleBackground(moodle)
			end
		end
	end

	local onlinePlayers = IsoPlayer.getPlayers()
	for index = 0, (onlinePlayers:size() - 1) do
		local playerObject = onlinePlayers:get(index)
		if playerObject then
			setMoodleBackgroundsForPlayer(playerObject)
		end
	end
end

for _, moodleName in ipairs(MOODLE_NAMES) do
	makeMoodle(moodleName)
end

Events.OnCreatePlayer.Add(onPlayerCreated)

return TorchMoodle
