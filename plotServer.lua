local serverPaths = require(game:GetService("ServerStorage").Modules.Utility.ServerPaths)

local blink = serverPaths.Shared.Blink

local blinkServerModule = require(blink.Server)
local dataManager = require(serverPaths.Modules.DataSaveHandler.DataManager)

local givePlot = {}
givePlot.__index = givePlot
givePlot.playersPlots = {}

local function SearchForFreePlot() : Model
	local plots = workspace.Plots

	for index, plot : Model in pairs(plots:GetChildren()) do 
		if not plot:GetAttribute("occupied") then
			plot:SetAttribute("occupied", true)
			return plot
		end
	end
end

local function spawnObjectsInPlot(self)
	local dataObjects = self.plotData.objects
	
	for itemName : string, informations : {} in pairs(dataObjects) do 
		local objectPackedCFrame = informations.cframe
		local unpackedCFrame = CFrame.new(table.unpack(objectPackedCFrame))
        local worldSpaceCFrame : CFrame = self.plot:GetPivot():ToWorldSpace(unpackedCFrame)
		local item = game.ReplicatedStorage:FindFirstChild(itemName):Clone()
		item.Parent = self.plot
		item:PivotTo(worldSpaceCFrame)
	end
end

function givePlot.New(params)
	local metaTable = {
		player = params.Player,
		plot = SearchForFreePlot(),
		plotData = params.Data.plot
	}

	local self = setmetatable(metaTable, givePlot)

	givePlot.playersPlots[params.Player] = self
	
	spawnObjectsInPlot(self)
	return self
end

function givePlot.UpdatePlot(data)
	local playerPlot = givePlot.playersPlots[data.player]

	if not playerPlot or playerPlot.player ~= data.player then 
		return 
	end

	if not data.itemInstance:IsDescendantOf(playerPlot.plot) then
		return
	end

	local worldCFrame = playerPlot.plot:GetPivot():ToWorldSpace(data.relativeCFrame)
	data.itemInstance:PivotTo(worldCFrame)

	local playerProfile = dataManager.ReturnProfile(data.player)
	if playerProfile then
		playerProfile.Data.plot.objects[data.itemName] = {
			cframe = {data.relativeCFrame:GetComponents()}
		}
	end
end

function givePlot:Remove()
	givePlot.playersPlots[self.player] = nil
	self.plot:SetAttribute("occupied", nil)
	setmetatable(self, {})
end

function givePlot.PlayerAdded(Player:Player)
	local dataLoadedConnection
	local isPlayerEventLoaded : boolean? = false
	dataLoadedConnection = dataManager.signals.OnDataLoaded:Connect(function(loadedPlayer:Player, playerProfile)
		if loadedPlayer == Player then
			dataLoadedConnection:Disconnect()
			
			isPlayerEventLoaded = true
			
			local plotParams = {
				Data = playerProfile.Data,
				Player = loadedPlayer
			}
			local playerPlot = givePlot.New(plotParams)
			
			local paramsDataToSend = {["Plot"] = playerPlot.plot, ["PlotData"] = playerPlot.plotData}
			local paramsToSendSettings = {[1] = "PlotSystem", [2] = 1, [3] = paramsDataToSend}
			
			blinkServerModule.MyEvent.Fire(Player,paramsToSendSettings)
		end
	end)
	
	task.delay(10, function()
		if not isPlayerEventLoaded then
			if dataLoadedConnection then
				dataLoadedConnection:Disconnect()
			end
		end
	end)
end

function givePlot.PlayerRemoving(Player:Player)
	if givePlot.playersPlots[Player] then
		givePlot.playersPlots[Player]:Remove()
	end
end

return givePlot
