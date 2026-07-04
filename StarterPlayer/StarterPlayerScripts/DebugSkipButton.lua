-- @ScriptType: LocalScript
local Players = game:GetService("Players")
local player = Players.LocalPlayer

----------------------------------------------------------------
-- BUAT GUI TOMBOL
----------------------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DebugSkipGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local button = Instance.new("TextButton")
button.Name = "SkipToFinishButton"
button.Size = UDim2.new(0, 200, 0, 50)
button.Position = UDim2.new(1, -220, 1, -70)
button.AnchorPoint = Vector2.new(0, 0)
button.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
button.TextColor3 = Color3.fromRGB(255, 255, 255)
button.Font = Enum.Font.GothamBold
button.TextScaled = true
button.Text = "TELEPORT KE FINISH"
button.AutoButtonColor = true
button.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = button

----------------------------------------------------------------
-- LOGIKA TELEPORT
----------------------------------------------------------------
local debounce = false

local function skipToFinish()
	if debounce then return end
	debounce = true

	local character = player.Character or player.CharacterAdded:Wait()
	local hrp = character:WaitForChild("HumanoidRootPart", 5)

	local mazeFolder = workspace:FindFirstChild("Maze")
	local finishPart = mazeFolder and mazeFolder:FindFirstChild("Finish")

	if not hrp or not finishPart then
		warn("[DebugSkip] Finish belum siap (mungkin maze lagi regenerate), coba lagi sebentar.")
		task.wait(1)
		debounce = false
		return
	end

	-- teleport tepat di atas pad Finish biar langsung Touched
	hrp.CFrame = finishPart.CFrame + Vector3.new(0, 5, 0)
	hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)

	task.wait(1) -- cegah spam klik sebelum server sempat proses Touched
	debounce = false
end

button.MouseButton1Click:Connect(skipToFinish)