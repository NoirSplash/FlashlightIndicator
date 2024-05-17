--[[
	NAME: FlashlightIndicator.lua
	AUTHOR: GLICK!
	DATE: May 12, 2024
	UPDATED: May 17, 2024

	This module runs a loop at a constant rate which checks for players who have
	active light sources and enables the respective 'lit' icon. It also listens
	to equip events to apply the 'unlit' icon.

	Configurable constants are written in LOUD_CASE! However I wouldn't recommend
	messing with them unless you know what you're doing. That being said,
	"GLICK!" is not a variable constant.

	NOTE: I learn by yapping, I apologize if the excessive comments end up
	hurting readability :P
]]

local IndicatorIcon = require("FlashlightIndicatorIcon")
local IndicatorOptions = require("FlashlightIndicatorOptions")
local Calendar = getGameTime():getCalender()

-- This determines how often we check players for light sources in milliseconds.
-- Lowering this will increase performance impact and responsiveness.
local REFRESH_RATE_MILLIS = 250

local FlashlightIndicator = {}
--[[
	[useAlternateIcons]
	If true, icons and moodles will use the alternate icon set. Default false.

	[showBackgrounds]
	If disabled the moodle backgrounds will be set to nil.

	[flashlightDisplayType]
	Determines if to show the display when your torch is on, off, both or never.
	Default 1.
	1-Both | 2-Only On | 3-Only Off | 4-Disabled

	[lighterDisplayType]
	Determines if to show the display when your lighter is on, off, both or never.
	Default 1.
	1-Both | 2-Only On | 3-Only Off | 4-Disabled
]]
FlashlightIndicator.settings = {
	useAlternateIcons = false,
	showBackgrounds = false,
	flashlightDisplayType = 1,
	lighterDisplayType = 1,
}

local displayTypeActivationMap = { [1] = true, [2] = true, [3] = false, [4] = false }
local lastTimestamp = Calendar:getTimeInMillis() - REFRESH_RATE_MILLIS
local playersEquippedItems = {} --:{ [playerIndex<number>]: { [number]: { InventoryItem, TorchType } }

local function canActivateStatus(torchType)
	local settingKey = string.lower(torchType) .. "DisplayType"
	return displayTypeActivationMap[FlashlightIndicator.settings[settingKey]]
end

local hasLightSource = {
	Flashlight = function(inventoryItem)
		if not canActivateStatus("Flashlight") then
			return nil
		end
		return inventoryItem:isTorchCone() ~= false
	end,
	Lighter = function(inventoryItem)
		if not canActivateStatus("Lighter") then
			return nil
		end
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
			IndicatorIcon.Hide(playerObject, torchType)
			table.remove(itemList, index)
		end
	end
end

-- LightingJNI.java handles lighting updates internally each tick and cannot
-- be forked so unfortunately we poll for active lighting items instead of
-- listening to relevant events.
-- (If you're aware of a better way to do this, please contact me on Steam -GLICK!)
local function update()
	local now = Calendar:getTimeInMillis()
	if lastTimestamp - now > REFRESH_RATE_MILLIS then
		return
	end
	lastTimestamp = now

	forAllPlayers(function(playerIndex, playerObject)
		local validLights = {}
		-- getActiveLightItems mutates an ArrayList directly instead of
		-- returning one so we are giving it a fresh one
		local activeLightItems = ArrayList.new()
		playerObject:getActiveLightItems(activeLightItems)
		for itemIndex = 0, (activeLightItems:size() - 1) do
			local inventoryItem = activeLightItems:get(itemIndex)
			for torchType, hasLight in pairs(hasLightSource) do
				local result = hasLight(inventoryItem)
				if result ~= false then
					validLights[torchType] = result
					if result == true then
						IndicatorIcon.Activate(playerObject, torchType)
					end
					break
				end
			end
		end

		for torchType, _hasLight in pairs(hasLightSource) do
			if not validLights[torchType] and IndicatorIcon.IsEnabled(playerObject, torchType) then
				IndicatorIcon.Deactivate(playerObject, torchType)
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
	for torchType, hasLight in pairs(hasLightSource) do
		local result = hasLight(inventoryItem)
		if result == true then
			itemTorchType = torchType
			break
		end
	end

	if itemTorchType then
		forAllPlayers(function(playerIndex, playerObject)
			if isoGameCharacter == playerObject then
				IndicatorIcon.Deactivate(playerObject, itemTorchType)
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
	for torchType, _hasLight in pairs(hasLightSource) do
		IndicatorIcon.Hide(playerObject, torchType)
	end
end

local function onPlayerCreated(_playerIndex, playerObject)
	IndicatorIcon.SetIcons(FlashlightIndicator.settings.useAlternateIcons)
	IndicatorIcon.SetBackgroundsEnabled(FlashlightIndicator.settings.showBackgrounds)

	-- We enable moodles for players on join based on their equipped items
	local function parseItem(inventoryItem)
		if not inventoryItem then
			return
		end

		for torchType, hasLight in pairs(hasLightSource) do
			local result = hasLight(inventoryItem)
			if result == true then
				-- Deactivate() instead of Activate() since our update() loop will
				-- handle activation anyways
				IndicatorIcon.Deactivate(playerObject, torchType)

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

-- Support for ModOptions/MCM through FlashlightIndicatorOptions.lua
if IndicatorOptions and IndicatorOptions.onSettingApplied then
	local settingSideEffects = {
		useAlternateIcons = function(_oldValue, newValue)
			IndicatorIcon.SetIcons(newValue)
		end,
		showBackgrounds = function(_oldValue, newValue)
			IndicatorIcon.SetBackgroundsEnabled(newValue)
		end,
		flashlightDisplayType = function(_oldValue, newValue)
			IndicatorIcon.enabledTorchTypes["Flashlight"] = newValue
		end,
		lighterDisplayType = function(_oldValue, newValue)
			IndicatorIcon.enabledTorchTypes["Lighter"] = newValue
		end,
	}

	IndicatorOptions.onSettingApplied(function(data)
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
	end)
end

IndicatorIcon.torchDisplayTypes["Flashlight"] = FlashlightIndicator.settings.flashlightDisplayType
IndicatorIcon.torchDisplayTypes["Lighter"] = FlashlightIndicator.settings.lighterDisplayTypeDisplayType

Events.OnPlayerUpdate.Add(update)
Events.OnEquipPrimary.Add(onItemEquipped)
Events.OnEquipSecondary.Add(onItemEquipped)
Events.OnPlayerDeath.Add(onPlayerDied)
Events.OnCreatePlayer.Add(onPlayerCreated)

return FlashlightIndicator
