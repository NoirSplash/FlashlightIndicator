--[[
	NAME: FlashlightIndicatorUIElement.lua
	AUTHOR: GLICK!
	DATE: May 20, 2024
	UPDATED: May 20, 2024

	This module controls displaying indicator icons and acts as an abstraction
	layer for the mod options so that the main file does not need to consider
	indicator display types nor moodles.
]]

local ICON_DIRECTORIES = {
	Standard = "media/ui/flashlightIndicator/",
	Alternate = "media/ui/flashlightIndicator/alternateTextures/",
}
local TILE_OFFSET_ABOVE_CHARACTER = -2.5
local TILE_OFFSET_BELOW_CHARACTER = 0.75
local ICON_SIZE = 30
local ICON_PADDING = 4

local core = getCore()
local math = math
local getTexture = getTexture
local getNumActivePlayers = getNumActivePlayers
local getPlayerScreenWidth = getPlayerScreenWidth
local getPlayerScreenLeft = getPlayerScreenLeft

local renderPositions = {
	[1] = TILE_OFFSET_ABOVE_CHARACTER,
	[2] = TILE_OFFSET_BELOW_CHARACTER,
}

local function clamp(value, min, max)
	if min > max then
		min, max = max, min
	end
	return math.min(math.max(value, min), max)
end

local FlashlightIndicatorUIElement = ISUIElement:derive("FlashlightIndicatorUIElement")

function FlashlightIndicatorUIElement.new(playerIndex, playerObject)
	local maxX = core:getScreenWidth()
	local maxY = core:getScreenHeight()

	local self = ISUIElement.new(
		FlashlightIndicatorUIElement,
		maxX * 0.5 - (ICON_SIZE * 0.5),
		maxY * 0.5 - (ICON_SIZE * 0.5),
		0,--ICON_SIZE,
		0--ICON_SIZE
	)

	-- Valid render strings are "active", "inactive" and "hidden"
	self.renderTorchTypes = {
		Flashlight = "hidden",
		Lighter = "hidden",
	}
	self.useAlternateIcons = false
	-- 1 = Above, 2 = Below
	self.renderPosition = 1
	self.renderScale = 1
	self.cameraZoom = 1
	self.playerIndex = playerIndex
	self.playerObject = playerObject
	self.iconSize = ICON_SIZE

	-- Internal table to avoid repeating warnings each frame
	self._debugWarnings = {}

	self:initialise()
	self:addToUIManager()
	self:setRenderThisPlayerOnly(self.playerIndex)

	return self
end

function FlashlightIndicatorUIElement:getNumVisibleIcons() --> number
	local visibleIcons = 0
	for _torchType, statusString in pairs(self.renderTorchTypes) do
		if statusString ~= "hidden" then
			visibleIcons = visibleIcons + 1
		end
	end
	return visibleIcons
end

function FlashlightIndicatorUIElement:getMinWidthToHoldNumIcons(numVisibleIcons) --> number
	local cellWidth = self.iconSize + ICON_PADDING
	return cellWidth * numVisibleIcons
end

function FlashlightIndicatorUIElement:activateIcon(torchType)
	if self.renderTorchTypes[torchType] ~= nil then
		self.renderTorchTypes[torchType] = "active"
	end
end

function FlashlightIndicatorUIElement:deactivateIcon(torchType)
	if self.renderTorchTypes[torchType] ~= nil then
		self.renderTorchTypes[torchType] = "inactive"
	end
end

function FlashlightIndicatorUIElement:hideIcon(torchType)
	if self.renderTorchTypes[torchType] ~= nil then
		self.renderTorchTypes[torchType] = "hidden"
	end
end

function FlashlightIndicatorUIElement:getIsoWorldPosition(totalWidth, numIcons) --> (number, number)
	local playerObject = self.playerObject
	local y = isoToScreenY(
		self.playerIndex,
		playerObject:getX() + renderPositions[self.renderPosition],
		playerObject:getY() + renderPositions[self.renderPosition],
		playerObject:getZ()
	)
	local x = isoToScreenX(
		self.playerIndex,
		playerObject:getX() + renderPositions[self.renderPosition],
		playerObject:getY() + renderPositions[self.renderPosition],
		playerObject:getZ()
	)
	-- Because our frame isn't anchored in the center, we have to offset the
	-- final X position according to how our frame has expanded to fit the icons
	x = x - (totalWidth * 0.5 ^ numIcons)
	return x, y
end

function FlashlightIndicatorUIElement:getScreenPosition(totalWidth, numIcons)
	--TODO: add option and method to render statically near hotbar
end

function FlashlightIndicatorUIElement:updateRenderPosition(totalWidth, numIcons)
	local xPos, yPos = self:getIsoWorldPosition(totalWidth, numIcons)
	self:setX(xPos)
	self:setY(yPos)
end

function FlashlightIndicatorUIElement:updateYPosition()
	local playerObject = self.playerObject
	local y = isoToScreenY(
		self.playerIndex,
		playerObject:getX() - renderPositions[self.renderPosition],
		playerObject:getY() - renderPositions[self.renderPosition],
		playerObject:getZ()
	)
	self:setY(y)
end

function FlashlightIndicatorUIElement:updateXPosition(totalWidth, numIcons)
	local maxX = getPlayerScreenWidth(self.playerIndex)
	local newXPosition = maxX * 0.5 - (totalWidth * 0.5 ^ numIcons)
	if getNumActivePlayers() > 1 then
		local minX = getPlayerScreenLeft(self.playerIndex)
		newXPosition = newXPosition + minX
	end
	-- I am very poor at math. Pls point out if this sucks.
	self:setX(newXPosition)
end

function FlashlightIndicatorUIElement:render()
	local function renderIconElement(torchType, isActive, xOffset)
		local directoryPrefix do
			if self.useAlternateIcons then
				directoryPrefix = ICON_DIRECTORIES.Alternate
			else
				directoryPrefix = ICON_DIRECTORIES.Standard
			end
		end
		local pathSuffix do
			if isActive then
				pathSuffix = "_On.png"
			else
				pathSuffix = "_Off.png"
			end
		end
		local texturePath = directoryPrefix .. torchType .. pathSuffix
		local texture = getTexture(texturePath)
		if texture then
			self:drawTextureScaledUniform(texture, xOffset, -self.iconSize * 0.5, self.renderScale, 1)
		elseif not self._debugWarnings[texturePath] then
			print("[ERROR] FlashlightIndicator failed to render UI element; Invalid texture path '" .. texturePath .. "'")
			self._debugWarnings[texturePath] = true
		end
	end

	local numVisibleIcons = self:getNumVisibleIcons()
	if numVisibleIcons <= 0 then
		return
	end
	local totalWidth = self:getMinWidthToHoldNumIcons(numVisibleIcons)
	local renderIndex = 0
	for torchType, statusString in pairs(self.renderTorchTypes) do
		if statusString ~= "hidden" then
			renderIndex = renderIndex + 1
			local positionalScale = renderIndex / numVisibleIcons
			local renderXOffset = totalWidth * positionalScale - (totalWidth * 0.5) - (self.iconSize * 0.5)
			--print("[DEBUG] FlashlightIndicator xOffset is now ", renderXOffset, " Width: ",totalWidth, " NumIcons: ",numVisibleIcons, " Index: ",renderIndex)
			local isActive = statusString == "active"
			renderIconElement(torchType, isActive, renderXOffset)
		end
	end

	self.cameraZoom = core:getZoom(self.playerIndex)
	self.renderScale = clamp(1 / self.cameraZoom ^ 1.5, 0.5, 1.75)
	self.iconSize = ICON_SIZE * self.renderScale
	--print("[DEBUG] FlashlightIndicator scale is now ", self.renderScale)
	self:updateRenderPosition(totalWidth, numVisibleIcons)
end

return FlashlightIndicatorUIElement