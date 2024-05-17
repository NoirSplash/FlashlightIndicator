local TorchMoodle = require("FlashlightIndicatorMoodle")

local FlashlightIndicatorIcon = {}
FlashlightIndicatorIcon.torchDisplayTypes = {
	Flashlight = 1,
	Lighter = 1,
}

function FlashlightIndicatorIcon.Activate(playerObject, torchType)
	if FlashlightIndicatorIcon.torchDisplayTypes[torchType] == 1
		or FlashlightIndicatorIcon.torchDisplayTypes[torchType] == 2
	then
		TorchMoodle.Activate(playerObject, torchType)
	else
		TorchMoodle.Hide(playerObject, torchType)
	end
end

function FlashlightIndicatorIcon.Deactivate(playerObject, torchType)
	if FlashlightIndicatorIcon.torchDisplayTypes[torchType] == 1
		or FlashlightIndicatorIcon.torchDisplayTypes[torchType] == 3
	then
		TorchMoodle.Deactivate(playerObject, torchType)
	else
		TorchMoodle.Hide(playerObject, torchType)
	end
end

function FlashlightIndicatorIcon.Hide(playerObject, torchType)
	TorchMoodle.Hide(playerObject, torchType)
end

--TODO: return cached result for icon instead of moodle
function FlashlightIndicatorIcon.IsEnabled(playerObject, torchType)
	return TorchMoodle.Has(playerObject, torchType)
end

function FlashlightIndicatorIcon.SetIcons(useAlternateIcons)
	TorchMoodle.SetIcons(useAlternateIcons)
end

function FlashlightIndicatorIcon.SetBackgroundsEnabled(backgroundsEnabled)
	TorchMoodle.SetBackgroundsEnabled(backgroundsEnabled)
end

return FlashlightIndicatorIcon