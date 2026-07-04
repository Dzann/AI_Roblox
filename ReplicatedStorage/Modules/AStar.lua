-- @ScriptType: ModuleScript
local AStar = {}

--------------------------------------------------
-- Heuristic (Manhattan Distance)
--------------------------------------------------
local function heuristic(a, b)
	return math.abs(a.x - b.x) + math.abs(a.y - b.y)
end

--------------------------------------------------
-- Ambil Tetangga
--------------------------------------------------
local function getNeighbors(grid, node)

	local neighbors = {}

	local cell = grid[node.x][node.y]

	-- Utara
	if not cell.N then
		table.insert(neighbors,{
			x = node.x,
			y = node.y - 1
		})
	end

	-- Selatan
	if not cell.S then
		table.insert(neighbors,{
			x = node.x,
			y = node.y + 1
		})
	end

	-- Timur
	if not cell.E then
		table.insert(neighbors,{
			x = node.x + 1,
			y = node.y
		})
	end

	-- Barat
	if not cell.W then
		table.insert(neighbors,{
			x = node.x - 1,
			y = node.y
		})
	end

	return neighbors

end

--------------------------------------------------
-- Cari node dengan fCost terkecil
--------------------------------------------------
local function getLowest(openSet,fScore)

	local best = 1

	for i=2,#openSet do

		local a = openSet[i]
		local b = openSet[best]

		local fa = fScore[a.x.."_"..a.y] or math.huge
		local fb = fScore[b.x.."_"..b.y] or math.huge

		if fa < fb then
			best = i
		end

	end

	return table.remove(openSet,best)

end

--------------------------------------------------
-- Rekonstruksi Path
--------------------------------------------------
local function reconstruct(cameFrom,current)

	local path = {}

	while current do

		table.insert(path,1,current)

		current = cameFrom[current.x.."_"..current.y]

	end

	return path

end

--------------------------------------------------
-- A*
--------------------------------------------------
function AStar.FindPath(grid,startNode,goalNode)

	local openSet = {}

	table.insert(openSet,startNode)

	local cameFrom = {}

	local gScore = {}

	local fScore = {}

	local startKey = startNode.x.."_"..startNode.y

	gScore[startKey] = 0

	fScore[startKey] = heuristic(startNode,goalNode)

	while #openSet > 0 do

		local current = getLowest(openSet,fScore)

		if current.x == goalNode.x and current.y == goalNode.y then

			return reconstruct(cameFrom,current)

		end

		for _,neighbor in ipairs(getNeighbors(grid,current)) do

			local key = neighbor.x.."_"..neighbor.y

			local currentKey = current.x.."_"..current.y

			local tentative = gScore[currentKey] + 1

			if tentative < (gScore[key] or math.huge) then

				cameFrom[key] = current

				gScore[key] = tentative

				fScore[key] = tentative + heuristic(neighbor,goalNode)

				local found = false

				for _,n in ipairs(openSet) do

					if n.x == neighbor.x and n.y == neighbor.y then
						found = true
						break
					end

				end

				if not found then
					table.insert(openSet,neighbor)
				end

			end

		end

	end

	return nil

end

return AStar