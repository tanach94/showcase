--!strict
-- Location requires
local clientPaths = require(game:GetService("ReplicatedStorage").Modules.Utility.ClientPaths)
-- Locations
local plotSystemFolder = script.Parent

-- Systems requires
local itemMoverModule = require(plotSystemFolder.ItemMover) :: any

-- Utility requires
local utilityModule = require(script.Parent.Utility)
local troveModule = require(clientPaths.Shared.Utility.Trove) :: any

local blink = clientPaths.Shared.Blink
local blinkClientModule = require(blink.Client)

local newPlot = {}
newPlot.__index = newPlot

function newPlot.New(Params : utilityModule.newPlotRequiredType) : utilityModule.newPlotType
	local newPlotTable : utilityModule.newPlotType  = {
		myPlot = Params.Plot;
		Arrows = {},
		editingTrove = troveModule.new(),
		holdingArrow = nil,
		deviceType = clientPaths.UserInputService.TouchEnabled,
		mousePosition = nil,
		movingObjectPosition = nil,
		troves = {},
		canPlace = true,
		editing = false,
	}  

	local self  = setmetatable(newPlotTable, newPlot) 

	itemMoverModule.myMeta = self
	return self
end

function newPlot:StartEditMode(Object : Model?)
	if not Object then return end
	if not Object.PrimaryPart then return end 
	if self.editing then return end 
	self.editing = true
	itemMoverModule.PrepareForMoving(self, Object)
end

function newPlot:EndEditMode()
	if self.canPlace then
		self.editing = false
		local objectPivot = self.Object:GetPivot()
		local plotPivot = self.myPlot:GetPivot()
		local relativeCFrame = plotPivot:ToObjectSpace(objectPivot)

		local dataToSend = {
			itemName = self.Object.Name,
			itemInstance = self.Object,
			relativeCFrame = relativeCFrame
		}

		blinkClientModule.UpdatePlacement.Fire(dataToSend)

		self.Object.PrimaryPart.Transparency = 1
		for obj, trove in pairs(self.troves) do
			trove:Destroy() 
		end
		self.troves = {} 

		if self.editingTrove then
			self.editingTrove:Clean()
		end

		self.Object = nil
		self.holdingArrow = nil
		self.looping = nil 

		self.Arrows = {}
	end
end


return newPlot
