--[[
	NAME: FlashlightIndicatorIcon.lua
	AUTHOR: GLICK!
	DATE: May 17, 2024
	UPDATED: May 19 2024

	This module controls displaying indicator icons and acts as an abstraction
	layer for the mod options so that the main file does not need to consider
	indicator display types nor moodles.
]]

local TorchMoodle = require("FlashlightIndicatorMoodle")

local playerStatuses = {}

local function setPlayerStatus(playerObject, torchType, status)
	local playerIndex = playerObject:getPlayerNum()
	if not playerStatuses[playerIndex] then
		playerStatuses[playerIndex] = {}
	end
	playerStatuses[playerIndex][torchType] = status
end

local FlashlightIndicatorIcon = {}
FlashlightIndicatorIcon.torchDisplayTypes = {
	Flashlight = 1,
	Lighter = 1,
}

function FlashlightIndicatorIcon.Activate(playerObject, torchType)
	print("Activating moodle", torchType, FlashlightIndicatorIcon.torchDisplayTypes[torchType])
	if FlashlightIndicatorIcon.torchDisplayTypes[torchType] == 1
		or FlashlightIndicatorIcon.torchDisplayTypes[torchType] == 2
	then
		TorchMoodle.Activate(playerObject, torchType)
	else
		FlashlightIndicatorIcon.Hide(playerObject, torchType)
	end
	setPlayerStatus(playerObject, torchType, true)
end

function FlashlightIndicatorIcon.Deactivate(playerObject, torchType)
	print("Deactivating moodle", torchType, FlashlightIndicatorIcon.torchDisplayTypes[torchType])
	if FlashlightIndicatorIcon.torchDisplayTypes[torchType] == 1
		or FlashlightIndicatorIcon.torchDisplayTypes[torchType] == 3
	then
		TorchMoodle.Deactivate(playerObject, torchType)
	else
		FlashlightIndicatorIcon.Hide(playerObject, torchType)
	end
	setPlayerStatus(playerObject, torchType, false)
end

function FlashlightIndicatorIcon.Hide(playerObject, torchType)
	print("Hiding moodle", torchType, FlashlightIndicatorIcon.torchDisplayTypes[torchType])
	TorchMoodle.Hide(playerObject, torchType)
	setPlayerStatus(playerObject, torchType, nil)
end

function FlashlightIndicatorIcon.IsActive(playerObject, torchType)
	local playerIndex = playerObject:getPlayerNum()
	local playerStatus = playerStatuses[playerIndex]
	return playerStatus and playerStatus[torchType] == true
end

function FlashlightIndicatorIcon.IsEnabled(playerObject, torchType)
	local playerIndex = playerObject:getPlayerNum()
	local playerStatus = playerStatuses[playerIndex]
	return playerStatus and playerStatus[torchType] ~= nil
end

function FlashlightIndicatorIcon.SetIcons(useAlternateIcons)
	TorchMoodle.SetIcons(useAlternateIcons)
end

function FlashlightIndicatorIcon.SetBackgroundsEnabled(backgroundsEnabled)
	TorchMoodle.SetBackgroundsEnabled(backgroundsEnabled)
end

return FlashlightIndicatorIcon