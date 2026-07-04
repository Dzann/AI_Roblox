-- @ScriptType: LocalScript
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

camera.CameraType = Enum.CameraType.Scriptable

-----------------------------------------------------
-- Awalnya mengikuti Player
-----------------------------------------------------

local target = player.Character or player.CharacterAdded:Wait()

player.CharacterAdded:Connect(function(character)

	target = character

end)

-----------------------------------------------------
-- Jika server meminta pindah kamera
-----------------------------------------------------

ReplicatedStorage.RemoteEvents.CameraEvent.OnClientEvent:Connect(function(object)

	target = object

end)

-----------------------------------------------------
-- Update Kamera
-----------------------------------------------------

RunService.RenderStepped:Connect(function()

	-- Don't override camera while menu is open
	if player:GetAttribute("MenuActive") then return end

	if not target then return end

	local root = target:FindFirstChild("HumanoidRootPart")

	if not root then return end

	local height = 20

	camera.CFrame = CFrame.lookAt(

		root.Position + Vector3.new(0,height,0),

		root.Position

	)

end)