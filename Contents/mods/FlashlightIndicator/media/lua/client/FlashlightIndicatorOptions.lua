--[[
	NAME: FlashlightIndicatorOptions.lua
	AUTHOR: GLICK!
	DATE: May 12, 2024
	UPDATED: May 19, 2024

	This is an accessory module meant to provide user settings through
	'Mod Config Menu' and 'ModOptions'.

	Only required if 'Mod Config Menu' or 'ModOptions' is being used.
	For the main functionality module, see `client/FlashlightIndicator.lua`
]]

local onSettingAppliedCallback = nil

local function onSettingApplied(...)
	if onSettingAppliedCallback then
		onSettingAppliedCallback(...)
	end
end

-- We use an exclusive condition because if both mods are enabled we want to
-- prioritize MCM
if Mod["IsMCMInstalled_v1"] then
	local indicatorOptions = ModOptionTable:New("FlashlightIndicator", "Flashlight Indicators", false)
	local dropdownItems = {
		[1] = getText("UI_FlashlightIndicator_DropdownOptionBoth"),
		[2] = getText("UI_FlashlightIndicator_DropdownOptionOnlyOn"),
		[3] = getText("UI_FlashlightIndicator_DropdownOptionOnlyOff"),
		[4] = getText("UI_FlashlightIndicator_DropdownOptionDisabled"),
	}

	-- To support both config mods, we're formatting our data from MCM to the
	-- ModOptions format to save us from having to use two handlers
	local function getSettingAppliedHandler(keyName)
		return function(keyValue)
			onSettingApplied({ settings = { options = { [keyName] = keyValue } } })
		end
	end

	-- [Use Alternate Icons]
	-- Swaps between the default and alternate icon images
	indicatorOptions:AddModOption(
		"useAlternateIcons",
		"checkbox",
		false,
		nil,
		getText("UI_FlashlightIndicator_UseAlternateIcons"),
		getText("UI_FlashlightIndicator_UseAlternateIconsTooltip"),
		getSettingAppliedHandler("useAlternateIcons")
	)

	-- [Indicator Position]
	-- Determines if the icon should render above or below the character
	indicatorOptions:AddModOption(
		"indicatorPosition",
		"combobox",
		1,
		{
			[1] = getText("UI_FlashlightIndicator_DropdownOptionAbove"),
			[2] = getText("UI_FlashlightIndicator_DropdownOptionBelow"),
		},
		getText("UI_FlashlightIndicator_IndicatorPosition"),
		getText("UI_FlashlightIndicator_IndicatorPositionTooltip"),
		getSettingAppliedHandler("indicatorPosition")
	)

	-- [Moodle Types]
	-- All "type" settings dictate display conditions for their respective moodle
	indicatorOptions:AddModOption(
		"flashlightDisplayType",
		"combobox",
		1,
		dropdownItems,
		getText("UI_FlashlightIndicator_FlashlightDisplayType"),
		getText("UI_FlashlightIndicator_FlashlightDisplayTypeTooltip"),
		getSettingAppliedHandler("flashlightDisplayType")
	)
	indicatorOptions:AddModOption(
		"lighterDisplayType",
		"combobox",
		1,
		dropdownItems,
		getText("UI_FlashlightIndicator_LighterDisplayType"),
		getText("UI_FlashlightIndicator_LighterDisplayTypeTooltip"),
		getSettingAppliedHandler("lighterDisplayType")
	)

elseif ModOptions and ModOptions.getInstance then
	local SETTINGS = {
		options_data = {
			useAlternateIcons = {
				name = "UI_FlashlightIndicator_UseAlternateIcons",
				tooltip = "UI_FlashlightIndicator_UseAlternateIconsTooltip",
				default = false,
				OnApply = onSettingApplied,
			},
			indicatorPosition = {
				[1] = getText("UI_FlashlightIndicator_DropdownOptionAbove"),
				[2] = getText("UI_FlashlightIndicator_DropdownOptionBelow"),
				name = "UI_FlashlightIndicator_IndicatorPosition",
				tooltip = "UI_FlashlightIndicator_IndicatorPositionTooltip",
				default = 1,
				OnApply = onSettingApplied,
			},
			flashlightDisplayType = { -- mm yummy mixed table :p
				[1] = getText("UI_FlashlightIndicator_DropdownOptionBoth"),
				[2] = getText("UI_FlashlightIndicator_DropdownOptionOnlyOn"),
				[3] = getText("UI_FlashlightIndicator_DropdownOptionOnlyOff"),
				[4] = getText("UI_FlashlightIndicator_DropdownOptionDisabled"),
				name = "UI_FlashlightIndicator_FlashlightDisplayType",
				tooltip = "UI_FlashlightIndicator_FlashlightDisplayTypeTooltip",
				default = 1,
				OnApply = onSettingApplied,
			},
			lighterDisplayType = {
				[1] = getText("UI_FlashlightIndicator_DropdownOptionBoth"),
				[2] = getText("UI_FlashlightIndicator_DropdownOptionOnlyOn"),
				[3] = getText("UI_FlashlightIndicator_DropdownOptionOnlyOff"),
				[4] = getText("UI_FlashlightIndicator_DropdownOptionDisabled"),
				name = "UI_FlashlightIndicator_LighterDisplayType",
				tooltip = "UI_FlashlightIndicator_LighterDisplayTypeTooltip",
				default = 1,
				OnApply = onSettingApplied,
			},
		},
		-- "mod_id" does not need to match the actual mod id (workshop nor folder)
		mod_id = "FlashlightIndicator",
		-- The ModOptions author does not provide an explanation for what
		-- "mod_shortname" is but it seems to be unused. We define it just in case.
		mod_shortname = "Torch Status",
		-- "mod_fullname" seems to determine sort order as well as being displayed
		-- in the section header
		mod_fullname = "Flashlight Indicator",
	}

	-- This function call adds our settings to the manager and mutates our table
	-- values into their true value types so we can call onSettingApplied with it
	-- in the following event handler
	local chunk = ModOptions:getInstance(SETTINGS)

	-- NOTE: A "chunk" in ModOptions is a formatted table representing one setting.
	-- To access the full chunk list, we use chunk.settings
	-- To get to the raw value table, we use chunk.settings.options
	-- This is painful.

	Events.OnGameStart.Add(function()
		onSettingApplied(chunk)
	end)
end

-- Error if we return an anonymous table here so we assign the API to a variable
local pseudo = {
	onSettingApplied = function(callback)
		onSettingAppliedCallback = callback
	end,
}
return pseudo
