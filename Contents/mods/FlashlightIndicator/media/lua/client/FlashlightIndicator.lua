--[[
	NAME: FlashlightIndicator.lua
	AUTHOR: GLICK!
	DATE: May 12, 2024
	UPDATED: May 19, 2024

	This module runs a loop at a constant rate which checks for players who have
	active light sources and enables the respective 'lit' icon. It also listens
	to equip events to apply the 'unlit' icon.

	Configurable constants are written in LOUD_CASE! However I wouldn't recommend
	messing with them unless you know what you're doing. That being said,
	"GLICK!" is not a variable constant.

	NOTE: I learn by yapping, I apologize if the excessive comments end up
	hurting readability :P
]]

local IndicatorOptions = require("FlashlightIndicatorOptions")
local IndicatorIconController = require("FlashlightIndicatorIconController")
local MoodleOptions = getActivatedMods():contains("FlashlightIndicatorMoodle") and require("FlashlightIndicatorMoodleOptions")

-- This determines how often we check players for light sources in milliseconds.
-- Lowering this will increase performance impact and responsiveness.
local REFRESH_RATE_MILLIS = 0.250

local FlashlightIndicator = {}
--[[
	# Indicator Options

	[useAlternateIcons]
	If true, icons and moodles will use the alternate icon set. Default false.

	[indicatorPosition]
	Dictates where to render the indicator icon.
	Default 1.
	1-AboveCharacter | 2-BelowCharacter

	[flashlightDisplayType]
	Determines whether to show the icon when your torch is on, off, both or never.
	Default 1.
	1-Both | 2-Only On | 3-Only Off | 4-Disabled

	[lighterDisplayType]
	Determines whether to show the icon when your lighter is on, off, both or never.
	Default 1.
	1-Both | 2-Only On | 3-Only Off | 4-Disabled

	# Moodle Options

	[showBackgrounds]
	Toggles visibility of the moodle background image. Default false.
	
	[flashlightMoodleDisplayType]
	Determines whether to show the moodle when your torch is on, off, both or never.
	Default 1.
	1-Both | 2-Only On | 3-Only Off | 4-Disabled

	[lighterMoodleDisplayType]
	Determines whether to show the moodle when your lighter is on, off, both or never.
	Default 1.
	1-Both | 2-Only On | 3-Only Off | 4-Disabled
]]
FlashlightIndicator.settings = {
	useAlternateIcons = false,
	indicatorPosition = 1,
	flashlightDisplayType = 1,
	lighterDisplayType = 1,

	showBackgrounds = false,
	flashlightMoodleDisplayType = 1,
	lighterMoodleDisplayType = 1,
}
-- Storing the os.time() function locally to avoid having to access the global
-- namespace every tick
local time = os.time
local lastTimestamp = time() - REFRESH_RATE_MILLIS
local playersEquippedItems = {} --:{ [playerIndex<number>]: { [number]: { InventoryItem, TorchType } }

local isTorchType = {
	Flashlight = function(inventoryItem)
		return inventoryItem:isTorchCone() ~= false
	end,
	Lighter = function(inventoryItem)
		return inventoryItem:getTorchDot() > 0
	end,
}

local function forAllPlayers(callback)
	local onlinePlayers = IsoPlayer.getPlayers()
	for playerIndex = 0, (onlinePlayers:size() - 1) do
		local playerObject = onlinePlayers:get(playerIndex)
		if playerObject then
			local result = callback(playerIndex, playerObject)
			if result == "break" then
				break
			end
		end
	end
end

local function filterUnequippedItems(playerObject, itemList)
	for index, itemInfo in ipairs(itemList) do
		local inventoryItem = itemInfo[1]
		local torchType = itemInfo[2]

		local equipped = playerObject:isEquipped(inventoryItem)
		local attached = playerObject:isAttachedItem(inventoryItem)
		if not equipped and not attached then
			IndicatorIconController.Hide(playerObject, torchType)
			table.remove(itemList, index)
		end
	end
end

local function getTorchTypeOfItem(inventoryItem)
	for torchType, isOfType in pairs(isTorchType) do
		if isOfType(inventoryItem) then
			return torchType
		end
	end
	return false
end

-- LightingJNI.java handles lighting updates internally each tick and cannot
-- be forked so unfortunately we poll for active lighting items instead of
-- listening to relevant events.
-- (If you're aware of a better way to do this, please contact me on discord @grimno1re)
local function update()
	local now = time()
	if now - lastTimestamp < REFRESH_RATE_MILLIS then
		return
	end
	lastTimestamp = now

	forAllPlayers(function(playerIndex, playerObject)
		local playerActiveTorchTypes = {}
		-- getActiveLightItems mutates an ArrayList directly instead of
		-- returning one so we are giving it a fresh one
		local activeLightItems = ArrayList.new()
		playerObject:getActiveLightItems(activeLightItems)
		for itemIndex = 0, (activeLightItems:size() - 1) do
			local inventoryItem = activeLightItems:get(itemIndex)
			local torchType = getTorchTypeOfItem(inventoryItem)
			if torchType then
				playerActiveTorchTypes[torchType] = true
			end
		end

		for torchType, _isActiveLight in pairs(isTorchType) do
			if playerActiveTorchTypes[torchType] then
				if not IndicatorIconController.IsActive(playerObject, torchType) then
					IndicatorIconController.Activate(playerObject, torchType)
				end
			elseif IndicatorIconController.IsEnabled(playerObject, torchType)
				and IndicatorIconController.IsActive(playerObject, torchType)
			then
				IndicatorIconController.Deactivate(playerObject, torchType)
			end
		end

		local playerItems = playersEquippedItems[playerIndex]
		if playerItems and not table.isempty(playerItems) then
			filterUnequippedItems(playerObject, playerItems)
		end
	end)
end

local function onItemEquipped(isoGameCharacter, inventoryItem)
	if inventoryItem == nil or not inventoryItem:canEmitLight() then
		return
	end

	local itemTorchType
	for torchType, hasLight in pairs(isTorchType) do
		local result = hasLight(inventoryItem)
		if result == true then
			itemTorchType = torchType
			break
		end
	end

	if itemTorchType then
		forAllPlayers(function(playerIndex, playerObject)
			if isoGameCharacter == playerObject then
				IndicatorIconController.Deactivate(playerObject, itemTorchType)
				if not playersEquippedItems[playerIndex] then
					playersEquippedItems[playerIndex] = {}
				end
				table.insert(playersEquippedItems[playerIndex], { inventoryItem, itemTorchType })

				return "break"
			end
		end)
	end
end

local function onPlayerDied(playerObject)
	playersEquippedItems[playerObject:getPlayerNum()] = {}
	for torchType, _hasLight in pairs(isTorchType) do
		IndicatorIconController.Hide(playerObject, torchType)
	end
end

local function onPlayerCreated(_playerIndex, playerObject)
	IndicatorIconController.SetIcons(FlashlightIndicator.settings.useAlternateIcons)

	-- We enable moodles for players on join based on their equipped items
	local function parseItem(inventoryItem)
		if not inventoryItem then
			return
		end

		for torchType, hasLight in pairs(isTorchType) do
			local result = hasLight(inventoryItem)
			if result == true then
				-- Deactivate() instead of Activate() since our update() loop will
				-- handle activation anyways
				IndicatorIconController.Deactivate(playerObject, torchType)

				local playerIndex = playerObject:getPlayerNum()
				if not playersEquippedItems[playerIndex] then
					playersEquippedItems[playerIndex] = {}
				end
				table.insert(playersEquippedItems[playerIndex], { inventoryItem, torchType })

				break
			end
		end
	end

	parseItem(playerObject:getPrimaryHandItem())
	parseItem(playerObject:getSecondaryHandItem())
	local attachedItems = playerObject:getAttachedItems()
	for index = 0, (attachedItems:size() - 1) do
		parseItem(attachedItems:get(index))
	end
end

if IndicatorOptions or MoodleOptions then
	local settingSideEffects = {
		useAlternateIcons = function(_oldValue, newValue)
			IndicatorIconController.SetIcons(newValue)
		end,
		indicatorPosition = function(_oldValue, newValue)
			IndicatorIconController.SetRenderPosition(newValue)
		end,
		flashlightDisplayType = function(_oldValue, newValue)
			IndicatorIconController.torchDisplayTypes["Flashlight"] = newValue
		end,
		lighterDisplayType = function(_oldValue, newValue)
			IndicatorIconController.torchDisplayTypes["Lighter"] = newValue
		end,

		showBackgrounds = function(_oldValue, newValue)
			IndicatorIconController.SetBackgroundsEnabled(newValue)
		end,
		flashlightMoodleDisplayType = function(_oldValue, newValue)
			IndicatorIconController.moodleDisplayTypes["Flashlight"] = newValue
		end,
		lighterMoodleDisplayType = function(_oldValue, newValue)
			IndicatorIconController.moodleDisplayTypes["Lighter"] = newValue
		end,
	}

	local function applySettings(data)
		local function setValueForKey(settingKey, settingValue)
			if settingSideEffects[settingKey]
				and FlashlightIndicator.settings[settingKey] ~= settingValue
			then
				local oldValue = FlashlightIndicator.settings[settingKey]
				settingSideEffects[settingKey](oldValue, settingValue)
			end
			FlashlightIndicator.settings[settingKey] = settingValue
		end

		local settings = data.settings.options
		for settingKey, settingValue in pairs(settings) do
			setValueForKey(settingKey, settingValue)
		end
	end

	-- Support for ModOptions/MCM through FlashlightIndicatorOptions.lua
	if IndicatorOptions and IndicatorOptions.onSettingApplied then
		print("[DEBUG] Flashlight Indicator Options Initialized")
		IndicatorOptions.onSettingApplied(applySettings)
	end
	-- Support for ModOptions/MCM through FlashlightIndicatorMoodleOptions.lua
	if MoodleOptions and MoodleOptions.onSettingApplied then
		print("[DEBUG] Flashlight Moodle Options Initialized")
		MoodleOptions.onSettingApplied(applySettings)
	end

	applySettings({ settings = { options = FlashlightIndicator.settings } })
end


Events.OnPlayerUpdate.Add(update)
Events.OnEquipPrimary.Add(onItemEquipped)
Events.OnEquipSecondary.Add(onItemEquipped)
Events.OnPlayerDeath.Add(onPlayerDied)
Events.OnCreatePlayer.Add(onPlayerCreated)


return FlashlightIndicator
