-- @ScriptType: Script
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MazeData = require(ReplicatedStorage.Modules.MazeData)
local ServerScriptService = game:GetService("ServerScriptService")

local TungTungAI = require(ServerScriptService.TungTungAI)


----------------------------------------------------------------
-- KONFIGURASI DASAR
----------------------------------------------------------------
local CELL_SIZE      = 10     -- ukuran 1 sel dalam studs
local WALL_HEIGHT    = 10     -- tinggi dinding
local WALL_THICKNESS = 1      -- ketebalan dinding
local WALL_COLOR     = BrickColor.new("Grey")
local FLOOR_COLOR    = BrickColor.new("Medium stone grey")
local BUILD_FLOOR    = false  -- true jika ingin lantai otomatis dibuat
local ORIGIN         = Vector3.new(0, 0, 0) -- titik awal maze di dunia

-- START & FINISH (warna & ukuran pad)
local START_COLOR     = BrickColor.new("Bright green")
local FINISH_COLOR    = BrickColor.new("Bright red")
local MARKER_SIZE      = CELL_SIZE * 0.8
local MARKER_THICKNESS = 0.5
local BUILD_START_PAD  = true
local BUILD_FINISH_PAD = true

-- TINGGI START & FINISH (BISA DINAIK/TURUNKAN)
-- Ubah angka ini untuk menaikkan (+) atau menurunkan (-) posisi pad
-- dari ORIGIN.Y, atau panggil BindableFunction SetStartHeightOffset /
-- SetFinishHeightOffset dari script lain saat game berjalan.
local START_Y_OFFSET  = 0
local FINISH_Y_OFFSET = 0


----------------------------------------------------------------
-- KONFIGURASI LEVEL & KESULITAN
----------------------------------------------------------------
local BASE_WIDTH             = 7   -- ukuran maze di level 1
local BASE_HEIGHT            = 7
local SIZE_INCREASE_PER_LEVEL = 2  -- setiap naik level, maze tambah sebesar ini
local MAX_WIDTH              = 25  -- batas maksimum biar tidak kebesaran
local MAX_HEIGHT             = 25
local REGENERATE_DELAY       = 5   -- jeda (detik) sebelum maze baru dibuat setelah finish

----------------------------------------------------------------
-- STATE
----------------------------------------------------------------
local WIDTH, HEIGHT
local grid = {}
local currentLevel = 1
local regenerating = false
local gameRunning = false

----------------------------------------------------------------
-- SETUP FOLDER
----------------------------------------------------------------
local mazeFolder = Workspace:FindFirstChild("Maze")
if mazeFolder then
	mazeFolder:Destroy()
end
mazeFolder = Instance.new("Folder")
mazeFolder.Name = "Maze"
mazeFolder.Parent = Workspace

-- Event yang bisa dipakai script lain (misal untuk update UI, kasih reward, dsb)
local MazeFinished = Instance.new("BindableEvent")
MazeFinished.Name = "MazeFinished"
MazeFinished.Parent = mazeFolder

-- Value level yang bisa dibaca script lain
local LevelValue = Instance.new("IntValue")
LevelValue.Name = "Level"
LevelValue.Value = currentLevel
LevelValue.Parent = mazeFolder

----------------------------------------------------------------
-- BINDABLE FUNCTION UNTUK NAIK/TURUNKAN START & FINISH SAAT RUNTIME
----------------------------------------------------------------
local function repositionStart()
	local spawn = mazeFolder:FindFirstChild("Start")
	if spawn then
		spawn.CFrame = CFrame.new(spawn.Position.X, ORIGIN.Y + START_Y_OFFSET, spawn.Position.Z)
	end
end

local function repositionFinish()
	local finishPart = mazeFolder:FindFirstChild("Finish")
	if finishPart then
		finishPart.CFrame = CFrame.new(finishPart.Position.X, ORIGIN.Y + FINISH_Y_OFFSET, finishPart.Position.Z)
	end
end

local SetStartHeightOffset = Instance.new("BindableFunction")
SetStartHeightOffset.Name = "SetStartHeightOffset"
SetStartHeightOffset.Parent = mazeFolder
SetStartHeightOffset.OnInvoke = function(offset)
	START_Y_OFFSET = offset
	repositionStart()
	return true
end

local SetFinishHeightOffset = Instance.new("BindableFunction")
SetFinishHeightOffset.Name = "SetFinishHeightOffset"
SetFinishHeightOffset.Parent = mazeFolder
SetFinishHeightOffset.OnInvoke = function(offset)
	FINISH_Y_OFFSET = offset
	repositionFinish()
	return true
end

----------------------------------------------------------------
-- UKURAN MAZE BERDASARKAN LEVEL (SEMAKIN TINGGI LEVEL SEMAKIN BESAR/SUSAH)
----------------------------------------------------------------
local function applySizeForLevel(level)
	WIDTH  = math.min(BASE_WIDTH  + (level - 1) * SIZE_INCREASE_PER_LEVEL, MAX_WIDTH)
	HEIGHT = math.min(BASE_HEIGHT + (level - 1) * SIZE_INCREASE_PER_LEVEL, MAX_HEIGHT)
	-- pastikan ganjil biar sel terakhir rapi
	if WIDTH % 2 == 0 then WIDTH += 1 end
	if HEIGHT % 2 == 0 then HEIGHT += 1 end
end

local START_CELL = {x = 1, y = 1} -- start selalu di pojok kiri atas
local function getFinishCell()
	return {x = WIDTH, y = HEIGHT} -- finish selalu di pojok kanan bawah
end

----------------------------------------------------------------
-- STRUKTUR DATA MAZE
----------------------------------------------------------------
local function createGrid()
	grid = {}
	for x = 1, WIDTH do
		grid[x] = {}
		for y = 1, HEIGHT do
			grid[x][y] = {
				visited = false,
				N = true, S = true, E = true, W = true,
			}
		end
	end
end

local DIRS = {
	{dx = 0, dy = -1, wall = "N", opp = "S"},
	{dx = 0, dy = 1,  wall = "S", opp = "N"},
	{dx = 1, dy = 0,  wall = "E", opp = "W"},
	{dx = -1, dy = 0, wall = "W", opp = "E"},
}

local function shuffle(t)
	for i = #t, 2, -1 do
		local j = math.random(i)
		t[i], t[j] = t[j], t[i]
	end
	return t
end

----------------------------------------------------------------
-- RECURSIVE BACKTRACKING (stack iteratif)
----------------------------------------------------------------
local function generateMaze(startX, startY)
	local stack = {{x = startX, y = startY}}
	grid[startX][startY].visited = true
	local visitedCount = 1
	local total = WIDTH * HEIGHT

	while #stack > 0 and visitedCount < total do
		local current = stack[#stack]
		local cx, cy = current.x, current.y

		local dirs = shuffle({1, 2, 3, 4})
		local moved = false

		for _, i in ipairs(dirs) do
			local d = DIRS[i]
			local nx, ny = cx + d.dx, cy + d.dy

			if nx >= 1 and nx <= WIDTH and ny >= 1 and ny <= HEIGHT and not grid[nx][ny].visited then
				grid[cx][cy][d.wall] = false
				grid[nx][ny][d.opp] = false

				grid[nx][ny].visited = true
				visitedCount += 1
				table.insert(stack, {x = nx, y = ny})
				moved = true
				break
			end
		end

		if not moved then
			table.remove(stack)
		end
	end
end

----------------------------------------------------------------
-- BUILD PART (helper)
----------------------------------------------------------------
local function createPart(size, cframe, color, name)
	local part = Instance.new("Part")
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.BrickColor = color
	part.Material = Enum.Material.SmoothPlastic
	part.Name = name
	part.Parent = mazeFolder
	return part
end

local function cellCenter(cellX, cellY)
	local worldX = ORIGIN.X + (cellX - 1) * CELL_SIZE
	local worldZ = ORIGIN.Z + (cellY - 1) * CELL_SIZE
	return worldX + CELL_SIZE / 2, worldZ + CELL_SIZE / 2
end
-------------------------------------------------------
-- UPDATE DATA UNTUK AI
-------------------------------------------------------
local function updateMazeData()

	MazeData.Grid = grid

	MazeData.Width = WIDTH
	MazeData.Height = HEIGHT

	MazeData.Start = {
		x = START_CELL.x,
		y = START_CELL.y
	}

	local finish = getFinishCell()

	MazeData.Finish = {
		x = finish.x,
		y = finish.y
	}

	MazeData.CellSize = CELL_SIZE
	MazeData.Origin = ORIGIN

end

local function GridToWorld(x,y)

	return Vector3.new(

		ORIGIN.X + (x - 0.5) * CELL_SIZE,

		3,

		ORIGIN.Z + (y - 0.5) * CELL_SIZE

	)

end

MazeData.GridToWorld = GridToWorld
----------------------------------------------------------------
-- GUI: PENANDA LEVEL (nempel di atas Start, kelihatan semua orang)
----------------------------------------------------------------
local function updateLevelDisplay(level)
	local spawn = mazeFolder:FindFirstChild("Start")
	if not spawn then return end

	local existing = spawn:FindFirstChild("LevelDisplay")
	if existing then existing:Destroy() end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "LevelDisplay"
	billboard.Size = UDim2.new(0, 200, 0, 60)
	billboard.StudsOffset = Vector3.new(0, 6, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = spawn

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "LEVEL " .. level
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Parent = billboard
end

----------------------------------------------------------------
-- GUI: POPUP KETIKA PLAYER SAMPAI DI FINISH
----------------------------------------------------------------
local function showFinishGui(player, level, delaySeconds)
	local playerGui = player:FindFirstChild("PlayerGui")
	if not playerGui then return end

	local old = playerGui:FindFirstChild("MazeFinishGui")
	if old then old:Destroy() end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "MazeFinishGui"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 420, 0, 170)
	frame.Position = UDim2.new(0.5, -210, 0.3, -85)
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 60)
	title.Position = UDim2.new(0, 0, 0, 10)
	title.BackgroundTransparency = 1
	title.Text = "LEVEL " .. level .. " SELESAI!"
	title.TextColor3 = Color3.fromRGB(80, 255, 120)
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.Parent = frame

	local subtitle = Instance.new("TextLabel")
	subtitle.Size = UDim2.new(1, 0, 0, 40)
	subtitle.Position = UDim2.new(0, 0, 0, 75)
	subtitle.BackgroundTransparency = 1
	subtitle.Text = "Labirin baru (Level " .. (level + 1) .. ") sedang dibuat..."
	subtitle.TextColor3 = Color3.fromRGB(230, 230, 230)
	subtitle.Font = Enum.Font.Gotham
	subtitle.TextScaled = true
	subtitle.Parent = frame

	local countdown = Instance.new("TextLabel")
	countdown.Size = UDim2.new(1, 0, 0, 30)
	countdown.Position = UDim2.new(0, 0, 1, -35)
	countdown.BackgroundTransparency = 1
	countdown.Font = Enum.Font.GothamBold
	countdown.TextColor3 = Color3.fromRGB(255, 255, 255)
	countdown.TextScaled = true
	countdown.Parent = frame

	task.spawn(function()
		for i = delaySeconds, 1, -1 do
			if not screenGui.Parent then return end
			countdown.Text = tostring(i) .. "..."
			task.wait(1)
		end
		if screenGui.Parent then
			screenGui:Destroy()
		end
	end)
end

----------------------------------------------------------------
-- BUILD START (SpawnLocation)
----------------------------------------------------------------
local function buildStart()
	local cx, cz = cellCenter(START_CELL.x, START_CELL.y)

	local spawn = Instance.new("SpawnLocation")
	spawn.Size = Vector3.new(MARKER_SIZE, MARKER_THICKNESS, MARKER_SIZE)
	spawn.CFrame = CFrame.new(cx, ORIGIN.Y + START_Y_OFFSET, cz)
	spawn.Anchored = true
	spawn.BrickColor = START_COLOR
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Name = "Start"
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = mazeFolder

	return spawn
end

----------------------------------------------------------------
-- BUILD FINISH (Part + Touched event)
----------------------------------------------------------------
local regenerateMaze
local function buildFinish()
	local finishCell = getFinishCell()
	local cx, cz = cellCenter(finishCell.x, finishCell.y)

	local finishPart = Instance.new("Part")
	finishPart.Size = Vector3.new(MARKER_SIZE, MARKER_THICKNESS, MARKER_SIZE)
	finishPart.CFrame = CFrame.new(cx, ORIGIN.Y + FINISH_Y_OFFSET, cz)
	finishPart.Anchored = true
	finishPart.CanCollide = true
	finishPart.BrickColor = FINISH_COLOR
	finishPart.Material = Enum.Material.Neon
	finishPart.Name = "Finish"
	finishPart.Parent = mazeFolder

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 60, 60)
	light.Range = CELL_SIZE * 1.5
	light.Brightness = 2
	light.Parent = finishPart

	local playersFinished = {}


	finishPart.Touched:Connect(function(hit)
		local model = hit.Parent
		if not model then return end
		local player = Players:GetPlayerFromCharacter(model)
		if not player then return end
		if gameRunning then return end

		gameRunning = true

		-- 1. Freeze player
		local humanoid = player.Character and player.Character:FindFirstChild("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = 0
			humanoid.JumpPower = 0
		end

		-- 2. Generate maze baru (LEVEL TETAP SAMA) -> TIDAK teleport
		regenerateMaze(currentLevel, false)

		-- 3. Spawn TungTung + 4. AI jalan (blocking; kamera otomatis ke TungTung dari dalam TungTungAI)
		local success = TungTungAI.Start()
		print("TungTungAI success =", success)

		if success then
			-- 5. TungTung sampai finish -> naik level + generate maze baru + teleport
			regenerateMaze(currentLevel + 1, true)
		end

		-- 6. Kembalikan kamera semua player ke karakter masing-masing
		local CameraEvent = ReplicatedStorage.RemoteEvents:WaitForChild("CameraEvent")
		for _, plr in ipairs(Players:GetPlayers()) do
			local char = plr.Character
			if char then
				CameraEvent:FireClient(plr, char)
			end
		end

		-- Unfreeze player (baik AI sukses maupun gagal cari path)
		humanoid = player.Character and player.Character:FindFirstChild("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = 16
			humanoid.JumpPower = 50
		end

		gameRunning = false
	end)
end

----------------------------------------------------------------
-- RENDER MAZE KE DALAM PART ROBLOX
----------------------------------------------------------------
local function buildMaze()
	if BUILD_FLOOR then
		local floorSizeX = WIDTH * CELL_SIZE
		local floorSizeZ = HEIGHT * CELL_SIZE
		createPart(
			Vector3.new(floorSizeX, 1, floorSizeZ),
			CFrame.new(ORIGIN + Vector3.new(floorSizeX / 2, -0.5, floorSizeZ / 2)),
			FLOOR_COLOR,
			"Floor"
		)
	end

	for x = 1, WIDTH do
		for y = 1, HEIGHT do
			local cell = grid[x][y]
			local worldX = ORIGIN.X + (x - 1) * CELL_SIZE
			local worldZ = ORIGIN.Z + (y - 1) * CELL_SIZE

			if cell.N then
				createPart(
					Vector3.new(CELL_SIZE + WALL_THICKNESS, WALL_HEIGHT, WALL_THICKNESS),
					CFrame.new(worldX + CELL_SIZE / 2, WALL_HEIGHT / 2, worldZ),
					WALL_COLOR,
					string.format("Wall_N_%d_%d", x, y)
				)
			end

			if cell.W then
				createPart(
					Vector3.new(WALL_THICKNESS, WALL_HEIGHT, CELL_SIZE + WALL_THICKNESS),
					CFrame.new(worldX, WALL_HEIGHT / 2, worldZ + CELL_SIZE / 2),
					WALL_COLOR,
					string.format("Wall_W_%d_%d", x, y)
				)
			end

			if cell.S and y == HEIGHT then
				createPart(
					Vector3.new(CELL_SIZE + WALL_THICKNESS, WALL_HEIGHT, WALL_THICKNESS),
					CFrame.new(worldX + CELL_SIZE / 2, WALL_HEIGHT / 2, worldZ + CELL_SIZE),
					WALL_COLOR,
					string.format("Wall_S_%d_%d", x, y)
				)
			end

			if cell.E and x == WIDTH then
				createPart(
					Vector3.new(WALL_THICKNESS, WALL_HEIGHT, CELL_SIZE + WALL_THICKNESS),
					CFrame.new(worldX + CELL_SIZE, WALL_HEIGHT / 2, worldZ + CELL_SIZE / 2),
					WALL_COLOR,
					string.format("Wall_E_%d_%d", x, y)
				)
			end
		end
	end

	if BUILD_START_PAD then
		buildStart()
	end

	if BUILD_FINISH_PAD then
		buildFinish()
	end
end

----------------------------------------------------------------
-- TELEPORT SEMUA PLAYER KE START BARU SETELAH REGENERATE
----------------------------------------------------------------
local function teleportAllPlayersToStart()
	local spawn = mazeFolder:FindFirstChild("Start")
	if not spawn then return end
	local targetCFrame = spawn.CFrame + Vector3.new(0, 5, 0)

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character then
			local hrp = character:FindFirstChild("HumanoidRootPart")
			local humanoid = character:FindFirstChild("Humanoid")

			if humanoid then
				humanoid.WalkSpeed = 16
				humanoid.JumpPower = 50
			end
			if hrp then
				hrp.CFrame = targetCFrame
			end
		end
	end
end

----------------------------------------------------------------
-- REGENERATE MAZE (dipanggil ulang setiap ada yang sampai finish)
----------------------------------------------------------------
regenerateMaze = function(newLevel, teleportPlayers)


	for _, obj in ipairs(workspace:GetChildren()) do
		if obj.Name == "Tungs 2" then
			obj:Destroy()
		end
	end

	currentLevel = newLevel
	LevelValue.Value = currentLevel

	applySizeForLevel(currentLevel)
	createGrid()
	generateMaze(1, 1)

	updateMazeData()
	-- hapus maze lama
	for _, child in ipairs(mazeFolder:GetChildren()) do
		if child:IsA("Part") or child:IsA("SpawnLocation") then
			child:Destroy()
		end
	end

	buildMaze()
	updateLevelDisplay(currentLevel)

	if teleportPlayers then
		teleportAllPlayersToStart()
	end

	print(string.format(
		"[MazeGenerator] Level %d | Maze %dx%d berhasil dibuat ulang.",
		currentLevel, WIDTH, HEIGHT
		))
end

----------------------------------------------------------------
-- JALANKAN PERTAMA KALI
----------------------------------------------------------------
math.randomseed(os.time())
applySizeForLevel(currentLevel)
createGrid()
generateMaze(1, 1)
updateMazeData()
buildMaze()
updateLevelDisplay(currentLevel)

print(string.format(
	"[MazeGenerator] Maze %dx%d berhasil dibuat di Workspace.Maze (Level %d | Start: %d,%d | Finish: %d,%d)",
	WIDTH, HEIGHT, currentLevel, START_CELL.x, START_CELL.y, getFinishCell().x, getFinishCell().y
	))