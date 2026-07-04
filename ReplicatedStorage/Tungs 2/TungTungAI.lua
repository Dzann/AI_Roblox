-- @ScriptType: Script
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MazeData = require(ReplicatedStorage.Modules.MazeData)
local AStar = require(ReplicatedStorage.Modules.AStar)

local TungTungAI = {}

-------------------------------------------------------
-- Grid -> World
-------------------------------------------------------

local function GridToWorld(x, y)

	local origin = MazeData.Origin
	local size = MazeData.CellSize

	return Vector3.new(
		origin.X + (x - 0.5) * size,
		3,
		origin.Z + (y - 0.5) * size
	)

end

-------------------------------------------------------
-- Spawn NPC
-------------------------------------------------------

local function SpawnTungTung()

	local npc = ReplicatedStorage["Tungs 2"]:Clone()

	npc.Parent = workspace

	local root = npc:WaitForChild("HumanoidRootPart")

	root.CFrame = CFrame.new(
		GridToWorld(
			MazeData.Start.x,
			MazeData.Start.y
		)
	)

	return npc

end

-------------------------------------------------------
-- Ikuti Path
-------------------------------------------------------

local function FollowPath(npc, path)

	local humanoid = npc:WaitForChild("Humanoid")

	for _,node in ipairs(path) do

		local position = GridToWorld(node.x,node.y)

		humanoid:MoveTo(position)

		humanoid.MoveToFinished:Wait()

	end

end

-------------------------------------------------------
-- Public Function
-------------------------------------------------------

function TungTungAI.Start()

	local npc = SpawnTungTung()

	local path = AStar.FindPath(

		MazeData.Grid,

		MazeData.Start,

		MazeData.Finish

	)

	if not path then

		warn("Path tidak ditemukan!")

		npc:Destroy()

		return

	end

	FollowPath(npc,path)

	print("TungTung Finish!")

	npc:Destroy()

end

return TungTungAI