local itemMover = {}
local clientPaths = require(game:GetService("ReplicatedStorage").Modules.Utility.ClientPaths)
local utilityModule = require(script.Parent.Utility)
local inputManager = require(clientPaths.ReplicatedStorage.Modules.Utility.InputManager)
local viewPortPointToRay = require(clientPaths.ReplicatedStorage.Modules.Utility.ViewportPointToRay)
local troveModule = require(clientPaths.Shared.Utility.Trove) :: any
local Camera = workspace.CurrentCamera

local getMousePointRayCastParams = RaycastParams.new()
local collidingOverLapParams = OverlapParams.new()

local inputSignal = clientPaths.UserInputService.TouchEnabled and "Touch" or "MouseButton1"

local myMeta = nil
local lastClicked = nil
local clickedCount = 0

local AXIS_DIRECTIONS = {
	X = Vector3.xAxis,
	Y = Vector3.yAxis,
	Z = Vector3.zAxis
}

local function SnapNumber(number: number, customSnapper: number?): number
	local snap = customSnapper or utilityModule.snappingNumber
	return math.round(number / snap) * snap
end

local function GetAxisName(name: string): string
	return name:sub(1, 1)
end

local function Colliding(self: utilityModule.newPlotType)
	local primary = self.Object.PrimaryPart

	local parts = workspace:GetPartsInPart(self.Object.PrimaryPart, collidingOverLapParams)
	return #parts > 0
end

local function plotBorderedPosition(self : utilityModule.newPlotType, movingVector : Vector3)
	local borderedPosition : Vector3 = self.myPlot.Barrier.CFrame:PointToObjectSpace(movingVector)
	local plotCorners = (self.myPlot.Barrier.Size / 2) 

	local vectorFull = {}

	local function clampVectorCoordination(coordinationName : string)
		local coordinationToClamp = plotCorners[coordinationName]
		vectorFull[coordinationName] = math.clamp(borderedPosition[coordinationName], -coordinationToClamp, coordinationToClamp)
	end

	for coordinationName, vector in pairs(AXIS_DIRECTIONS) do 
		clampVectorCoordination(coordinationName)
	end

	return self.myPlot.Barrier.CFrame:PointToWorldSpace(Vector3.new(vectorFull.X, vectorFull.Y, vectorFull.Z))
end

local function CreateDragArrow(self, axis: string, isOpposite: boolean): BasePart
	local arrow = Instance.new("Part")
	arrow.Name = axis .. (isOpposite and "2" or "")
	arrow.Color = utilityModule.Arrows.Colors[axis] or Color3.new(1, 1, 1)
	arrow.Anchored = true
	arrow.CanCollide = false
	arrow.Parent = self.Object

	local cd = Instance.new("ClickDetector")
	cd.MaxActivationDistance = 50
	cd.MouseHoverEnter:Connect(function() self.Arrows[arrow].hovering = true end)
	cd.MouseHoverLeave:Connect(function() self.Arrows[arrow].hovering = false end)
	cd.Parent = arrow

	self.Arrows[arrow] = {hovering = false, held = false}
	self.editingTrove:Add(arrow)
	return arrow
end

local function PrepareArrows(self)
	local primary : BasePart = self.Object.PrimaryPart
	local halfSize = primary.Size / 2

	local ARROW_OFFSET = 5
	local ARROW_SIZE = Vector3.new(1, 1, 5)

	for axis, unitVector in pairs(AXIS_DIRECTIONS) do
		for _, sideMult in ipairs({1, -1}) do
			local isOpposite = (sideMult == -1)
			local arrow = CreateDragArrow(self, axis, isOpposite)

			local localOffset = unitVector * (halfSize[axis] + ARROW_OFFSET) * sideMult

			local worldPos = primary.CFrame:PointToWorldSpace(localOffset)

			arrow.CFrame = CFrame.lookAt(worldPos, worldPos + (primary.CFrame:VectorToWorldSpace(unitVector * sideMult)))
			arrow.Size = ARROW_SIZE
		end
	end
end

local function setOffset(self : utilityModule.newPlotType, coordination : string) : Vector3
	local partAndArrowDistance = (self.Object.PrimaryPart.Position - self.holdingArrow.Position).Magnitude
	local axis = GetAxisName(coordination)

	local negatives = {
		X2 = true,
		Z2 = true,
		Y2 = true,
	}

	local subtractor = negatives[coordination] and 1 or -1
	return AXIS_DIRECTIONS[axis] * (partAndArrowDistance * subtractor)
end

local function getRayPlaneIntersection(rayOrigin: Vector3, rayDirection: Vector3, planePoint: Vector3, planeNormal: Vector3): Vector3?
	local denominator = planeNormal:Dot(rayDirection)

	if math.abs(denominator) > 0.0001 then
		local t = (planePoint - rayOrigin):Dot(planeNormal) / denominator
		if t >= 0 then
			return rayOrigin + rayDirection * t
		end
	end
	return nil
end

local function MoveObject(self: utilityModule.newPlotType)
	local movingArrow = self.holdingArrow
	if not movingArrow then return end

	local primary = self.Object.PrimaryPart
	local axisName = GetAxisName(movingArrow.Name)
	local moveAxis = AXIS_DIRECTIONS[axisName] 

	local mouseLocation = clientPaths.UserInputService:GetMouseLocation()
	local unitRay = Camera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)

	local planeNormal = (Camera.CFrame.Position - primary.Position).Unit

	local intersection = getRayPlaneIntersection(unitRay.Origin, unitRay.Direction, primary.Position, planeNormal)

	if intersection then
		local localMousePos = primary.CFrame:PointToObjectSpace(intersection)

		local offset = setOffset(self, movingArrow.Name)[axisName]
		local snappedLocalValue = SnapNumber(localMousePos[axisName] + offset)

		local localMoveVector = Vector3.new(
			axisName == "X" and snappedLocalValue or 0,
			axisName == "Y" and snappedLocalValue or 0,
			axisName == "Z" and snappedLocalValue or 0
		)

		local worldTargetPos = primary.CFrame:PointToWorldSpace(localMoveVector)
		local boundedPos = plotBorderedPosition(self, worldTargetPos)

		self.Object:PivotTo(CFrame.new(boundedPos) * primary.CFrame.Rotation)
	end
end

local function Loop(self: utilityModule.newPlotType)
	if not self.looping then return end
	if not self.Object then return end 
	local primary = self.Object.PrimaryPart

	self.troves[self.Object]:Add(inputManager.Signals["MouseMoved"]:Connect(function()
		local ray = viewPortPointToRay.Get3DMousePointToRay(getMousePointRayCastParams)
		local colliding = Colliding(self)

		if colliding then
			self.Object.PrimaryPart.Color = Color3.fromRGB(255, 0, 0)
			self.canPlace = false
		else
			self.canPlace = true
			self.Object.PrimaryPart.Color = Color3.fromRGB(102, 255, 0)
		end
		
		if not ray then return end

		self.mousePosition = ray.Position
		self.movingObjectPosition = primary.Position
		MoveObject(self)
	end),"Disconnect", "MovementLoop")
end

local function getObjectEdges(object:BasePart)
	local corners = {}
	local objectHalfSize = object.Size / 2
	local objectCFrame = object.CFrame

	for x = -1, 1, 2 do
		for y = -1, 1, 2 do
			for z = -1, 1, 2 do
				local localCorner = Vector3.new(objectHalfSize.X * x, objectHalfSize.Y * y, objectHalfSize.Z * z)
				table.insert(corners, objectCFrame:PointToWorldSpace(localCorner))
			end
		end
	end

	return corners
end 

local function Rotate(self: utilityModule.newPlotType)
	self.Object:PivotTo(self.Object:GetPivot() * CFrame.Angles(math.rad(90),0,0))
end

function itemMover.PrepareForMoving(self: utilityModule.newPlotType, Object: Model)
	if not self.troves[Object] then
		self.Object = Object
		Object.PrimaryPart.Transparency = .8
		self.Arrows = {}
		self.troves[Object] = troveModule.new()
		PrepareArrows(self)

		getMousePointRayCastParams.FilterType = Enum.RaycastFilterType.Include
		getMousePointRayCastParams.FilterDescendantsInstances = {workspace}

		collidingOverLapParams.FilterType = Enum.RaycastFilterType.Include
		collidingOverLapParams.FilterDescendantsInstances = {self.myPlot.Objects}

		self.troves[Object]:Add(inputManager.Signals[inputSignal]:Connect(function(params) -- mouse began/ended
			if params.fired then
				for arrow, state in pairs(self.Arrows) do
					if state.hovering then

						state.held = true

						self.holdingArrow = arrow
						self.looping = true

						Loop(self)

						inputManager.inputChangedAllowed = true

						if self.deviceType then
							Camera.CameraType = Enum.CameraType.Scriptable
						end

						break
					end
				end
			else
				if self.holdingArrow then
					local state = self.Arrows[self.holdingArrow]
					if state then state.held = false end

					self.looping = false
					self.holdingArrow = nil
					self.heartBeat = nil 

					if self.troves[Object] then
						self.troves[Object]:Remove("MovementLoop")
					end

					inputManager.inputChangedAllowed = nil
					if self.deviceType then
						Camera.CameraType = Enum.CameraType.Custom
					end
				end
			end
		end))

		self.troves[Object]:Add(inputManager.Signals["R"]:Connect(function(params) -- key R pressed
			if params.fired then
				Rotate(self)
			end
		end))

		self.troves[Object]:Add(inputManager.Signals["X"]:Connect(function(params) -- key X pressed, ending edit mode
			self:EndEditMode()
		end))
	end
end

inputManager.Signals[inputSignal]:Connect(function(params) -- clicking on item
	if itemMover.myMeta and params.fired then
		local plot = itemMover.myMeta.myPlot
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = {plot}
		

		local clickResult : RaycastResult = viewPortPointToRay.Get3DMousePointToRay(params)
		if clickResult then
			local clickInstance = clickResult.Instance
			local model = clickInstance.Parent
			if model:IsA("Model") then
				if model.Parent == plot then
					itemMover.myMeta:StartEditMode(model)
				end
			end
		end
	end
end)

return itemMover
