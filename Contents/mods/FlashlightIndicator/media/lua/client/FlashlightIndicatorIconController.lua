--[[
	NAME: FlashlightIndicatorIconController.lua
	AUTHOR: GLICK!
	DATE: May 17, 2024
	UPDATED: May 20, 2024

	This module controls displaying indicator icons and acts as an abstraction
	layer for the mod options so that the main file does not need to consider
	indicator display types nor moodles.
]]

local TorchMoodle = getActivatedMods():contains("FlashlightIndicatorMoodle") and require("FlashlightIndicatorMoodle")

local IndicatorUIElement = require("FlashlightIndicatorUIElement")

local playerStatuses = {}
local playerUIElements = {}

local function activateIcon(playerObject, torchType)
	local element = playerUIElements[playerObject:getPlayerNum()]
	if element then
		element:activateIcon(torchType)
	end
end

local function deactivateIcon(playerObject, torchType)
	local element = playerUIElements[playerObject:getPlayerNum()]
	if element then
		element:deactivateIcon(torchType)
	end
end

local function hideIcon(playerObject, torchType)
	local element = playerUIElements[playerObject:getPlayerNum()]
	if element then
		element:hideIcon(torchType)
	end
end

local function activateMoodle(playerObject, torchType)
	if TorchMoodle ~= false and TorchMoodle.Activate then
		TorchMoodle.Activate(playerObject, torchType)
	end
end

local function deactivateMoodle(playerObject, torchType)
	if TorchMoodle ~= false and TorchMoodle.Deactivate then
		TorchMoodle.Deactivate(playerObject, torchType)
	end
end

local function hideMoodle(playerObject, torchType)
	if TorchMoodle ~= false and TorchMoodle.Hide then
		TorchMoodle.Hide(playerObject, torchType)
	end
end

local function setPlayerStatus(playerObject, torchType, value)
	local playerIndex = playerObject:getPlayerNum()
	if not playerStatuses[playerIndex] then
		playerStatuses[playerIndex] = {}
	end
	playerStatuses[playerIndex][torchType] = value
end

local FlashlightIndicatorIconController = {}
FlashlightIndicatorIconController.torchDisplayTypes = {
	Flashlight = 1,
	Lighter = 1,
}
FlashlightIndicatorIconController.moodleDisplayTypes = {
	Flashlight = 1,
	Lighter = 1,
}
FlashlightIndicatorIconController.useAlternateIcons = false
FlashlightIndicatorIconController.indicatorPosition = 1

function FlashlightIndicatorIconController.Activate(playerObject, torchType)
	if FlashlightIndicatorIconController.torchDisplayTypes[torchType] == 1
		or FlashlightIndicatorIconController.torchDisplayTypes[torchType] == 2
	then
		activateIcon(playerObject, torchType)
	else
		hideIcon(playerObject, torchType)
	end

	if FlashlightIndicatorIconController.moodleDisplayTypes[torchType] == 1
		or FlashlightIndicatorIconController.moodleDisplayTypes[torchType] == 2
	then
		activateMoodle(playerObject, torchType)
	else
		hideMoodle(playerObject, torchType)
	end

	setPlayerStatus(playerObject, torchType, true)
end

function FlashlightIndicatorIconController.Deactivate(playerObject, torchType)
	if FlashlightIndicatorIconController.torchDisplayTypes[torchType] == 1
		or FlashlightIndicatorIconController.torchDisplayTypes[torchType] == 3
	then
		deactivateIcon(playerObject, torchType)
	else
		hideIcon(playerObject, torchType)
	end

	if FlashlightIndicatorIconController.moodleDisplayTypes[torchType] == 1
		or FlashlightIndicatorIconController.moodleDisplayTypes[torchType] == 3
	then
		deactivateMoodle(playerObject, torchType)
	else
		hideMoodle(playerObject, torchType)
	end

	setPlayerStatus(playerObject, torchType, false)
end

function FlashlightIndicatorIconController.Hide(playerObject, torchType)
	hideIcon(playerObject, torchType)
	hideMoodle(playerObject, torchType)
	setPlayerStatus(playerObject, torchType, nil)
end

function FlashlightIndicatorIconController.IsActive(playerObject, torchType)
	local playerIndex = playerObject:getPlayerNum()
	local playerStatus = playerStatuses[playerIndex]
	return playerStatus and playerStatus[torchType] == true
end

function FlashlightIndicatorIconController.IsEnabled(playerObject, torchType)
	local playerIndex = playerObject:getPlayerNum()
	local playerStatus = playerStatuses[playerIndex]
	return playerStatus and playerStatus[torchType] ~= nil
end

function FlashlightIndicatorIconController.SetIcons(useAlternateIcons)
	FlashlightIndicatorIconController.useAlternateIcons = useAlternateIcons
	for _playerIndex, element in pairs(playerUIElements) do
		element.useAlternateIcons = useAlternateIcons
	end
	if TorchMoodle then
		TorchMoodle.SetIcons(useAlternateIcons)
	end
end

function FlashlightIndicatorIconController.SetRenderPosition(indicatorPosition)
	FlashlightIndicatorIconController.indicatorPosition = indicatorPosition
	for _playerIndex, element in pairs(playerUIElements) do
		element.renderPosition = indicatorPosition
	end
end

function FlashlightIndicatorIconController.SetBackgroundsEnabled(showBackgrounds)
	if TorchMoodle then
		TorchMoodle.SetBackgroundsEnabled(showBackgrounds)
	end
end

--[[
	Executes on player added to world. Public in case anyone needs to reference
	the function to remove the connection.

	@param1 <number> playerIndex
	@param2 <IsoPlayer> playerObject
]]
function FlashlightIndicatorIconController._onPlayerCreated(playerIndex, playerObject)
	playerUIElements[playerIndex] = IndicatorUIElement.new(playerIndex, playerObject)
	playerUIElements[playerIndex].renderPosition = FlashlightIndicatorIconController.indicatorPosition
	playerUIElements[playerIndex].useAlternateIcons = FlashlightIndicatorIconController.useAlternateIcons
end
Events.OnCreatePlayer.Add(FlashlightIndicatorIconController._onPlayerCreated)

return FlashlightIndicatorIconController