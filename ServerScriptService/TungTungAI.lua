local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MazeData = require(ReplicatedStorage.Modules.MazeData)
local AStar = require(ReplicatedStorage.Modules.AStar)
local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local CameraEvent = RemoteEvents:WaitForChild("CameraEvent")

local TungTungAI = {}

local function GridToWorld(x, y)
	local origin = MazeData.Origin
	local size = MazeData.CellSize
	return Vector3.new(
		origin.X + (x - 0.5) * size,
		3,
		origin.Z + (y - 0.5) * size
	)
end

local function SpawnTungTung()
	local npc = ReplicatedStorage["Tungs 2"]:Clone()
	npc.Parent = workspace
	local root = npc:WaitForChild("HumanoidRootPart")
	root.CFrame = CFrame.new(
		GridToWorld(MazeData.Start.x, MazeData.Start.y)
	)

	-- Sorot kamera semua player ke TungTung
	CameraEvent:FireAllClients(npc)

	return npc
end

local function FollowPath(npc, path)
	local humanoid = npc:WaitForChild("Humanoid")
	for _, node in ipairs(path) do
		local position = GridToWorld(node.x, node.y)
		humanoid:MoveTo(position)
		local reached = humanoid.MoveToFinished:Wait(5)
		if not reached then
			warn("TungTung stuck, skip langkah ini")
		end
	end
end

function TungTungAI.Start()
	local npc = SpawnTungTung()
	local path = AStar.FindPath(MazeData.Grid, MazeData.Start, MazeData.Finish)

	if not path then
		warn("Path tidak ditemukan!")
		npc:Destroy()
		return false
	end

	FollowPath(npc, path)
	print("TungTung Finish!")
	task.wait(2)
	npc:Destroy()
	return true
end

	return TungTungAI
