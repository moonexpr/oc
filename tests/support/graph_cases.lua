-- Seeded node graphs, and a slow, plain cheapest-route search to check a pathfinder against.
--
-- Graphs are plain data, so any library can read them:
--   graph.nodes[id] = { pos = { x, y, z }, medium = name }
--   graph.links[i]  = { from = id, to = id, cost = number, maxHull = HULL_* }
-- Links are one way; a two-way connection is two links. A link never costs less than the
-- straight distance between its nodes, so distance is a safe estimate of remaining cost.
--
-- A pawn is { hull = HULL_*, media = { [name] = true, ... } }. It may stand on a node whose
-- medium is in its media, and take a link when it may stand on both ends and its hull is no
-- larger than the link's maxHull. A medium is only a name: some cases rename every medium to
-- random text, so a library must not read meaning into "ground", "water" or "air".
local ipairs, pairs, type, tostring = ipairs, pairs, type, tostring
local ceil, floor, sqrt = math.ceil, math.floor, math.sqrt
local format = string.format
local concat = table.concat
module(...)

HULL_SMALL, HULL_MEDIUM, HULL_LARGE = 1, 2, 3
MEDIUM_GROUND, MEDIUM_WATER, MEDIUM_AIR = "ground", "water", "air"

-- Park-Miller generator: the same numbers under Lua 5.1 and LuaJIT, unlike math.random.
local MODULUS = 2147483647
local MULTIPLIER = 16807

local SPACING = 10
local AIR_HEIGHT = 40
local AIR_STRIDE = 2
local MIN_SIDE, MAX_SIDE = 3, 9
local WALL_PERCENT = 25
local ONE_WAY_PERCENT = 40
local LIFT_PERCENT = 70
local STANDABLE_PICK_PERCENT = 85
local MAX_EXTRA_COST = 12
local SEEDS_PER_SHAPE = 15
local SEEDS_PER_LAYERED_SHAPE = 60
local RENAMED_MEDIUM_DIGITS = 6

-- Each step is added in both directions, so this covers all eight neighbours.
local STEPS = {
	{ 1, 0 },
	{ 0, 1 },
	{ 1, 1 },
	{ 1, -1 },
}

local PAWN_MEDIA = {
	{ MEDIUM_GROUND },
	{ MEDIUM_WATER },
	{ MEDIUM_AIR },
	{ MEDIUM_GROUND, MEDIUM_WATER },
	{ MEDIUM_GROUND, MEDIUM_AIR },
	{ MEDIUM_GROUND, MEDIUM_WATER, MEDIUM_AIR },
}

local SHAPES = {
	{ name = "open" },
	{ name = "walls", walls = true },
	{ name = "ties", ties = true },
	{ name = "oneway", oneway = true },
	{ name = "hulls", hulls = true },
	{
		name = "islands",
		islands = true,
		walls = true,
	},
	{
		name = "layered",
		layered = true,
		islands = true,
		walls = true,
	},
	{
		name = "renamed",
		layered = true,
		islands = true,
		walls = true,
		renamed = true,
	},
}

local function newRandom(seed)
	local state = seed % MODULUS
	if state == 0 then
		state = 1
	end

	return function(low, high)
		state = state * MULTIPLIER % MODULUS
		return low + state % (high - low + 1)
	end
end

local function distance(a, b)
	local dx, dy, dz = a[1] - b[1], a[2] - b[2], a[3] - b[3]
	return sqrt(dx * dx + dy * dy + dz * dz)
end

local function gridGraph(random, shape)
	local width, height = random(MIN_SIDE, MAX_SIDE), random(MIN_SIDE, MAX_SIDE)
	local gap = ceil(width / 2)
	local lakeLeft, lakeTop = random(1, width), random(1, height)
	local lakeRight, lakeBottom = random(lakeLeft, width), random(lakeTop, height)
	local nodes, ids, links = {}, {}, {}

	local function groundId(x, y)
		return (y - 1) * width + x
	end

	local function airId(x, y)
		return width * height + groundId(x, y)
	end

	local function link(from, to)
		local extra = shape.ties and 0 or random(0, MAX_EXTRA_COST)
		links[#links + 1] = {
			from = from,
			to = to,
			cost = ceil(distance(nodes[from].pos, nodes[to].pos)) + extra,
			maxHull = shape.hulls and random(HULL_SMALL, HULL_LARGE) or HULL_LARGE,
		}
	end

	local function connect(from, to)
		if shape.oneway and random(1, 100) <= ONE_WAY_PERCENT then
			if random(0, 1) == 0 then
				link(from, to)
			else
				link(to, from)
			end
		else
			link(from, to)
			link(to, from)
		end
	end

	for y = 1, height do
		for x = 1, width do
			local cut = shape.islands and x == gap
			local wall = shape.walls and random(1, 100) <= WALL_PERCENT
			local lake = shape.layered and x >= lakeLeft and x <= lakeRight and y >= lakeTop and y <= lakeBottom
			if not cut and not wall then
				local id = groundId(x, y)
				nodes[id] = {
					pos = { x * SPACING, y * SPACING, 0 },
					medium = lake and MEDIUM_WATER or MEDIUM_GROUND,
				}
				ids[#ids + 1] = id
			end
		end
	end

	for _, id in ipairs(ids) do
		local x, y = (id - 1) % width + 1, floor((id - 1) / width) + 1
		for _, step in ipairs(STEPS) do
			local nx, ny = x + step[1], y + step[2]
			if nx >= 1 and nx <= width and ny >= 1 and ny <= height and nodes[groundId(nx, ny)] ~= nil then
				connect(id, groundId(nx, ny))
			end
		end
	end

	-- A sparser air layer over the whole map, gap included, reached by lifts from below.
	if shape.layered then
		for y = 1, height, AIR_STRIDE do
			for x = 1, width, AIR_STRIDE do
				local id = airId(x, y)
				nodes[id] = {
					pos = { x * SPACING, y * SPACING, AIR_HEIGHT },
					medium = MEDIUM_AIR,
				}
				ids[#ids + 1] = id
			end
		end

		for y = 1, height, AIR_STRIDE do
			for x = 1, width, AIR_STRIDE do
				for _, step in ipairs(STEPS) do
					local nx, ny = x + step[1] * AIR_STRIDE, y + step[2] * AIR_STRIDE
					if nx >= 1 and nx <= width and ny >= 1 and ny <= height and nodes[airId(nx, ny)] ~= nil then
						connect(airId(x, y), airId(nx, ny))
					end
				end
				if nodes[groundId(x, y)] ~= nil and random(1, 100) <= LIFT_PERCENT then
					connect(groundId(x, y), airId(x, y))
				end
			end
		end
	end

	return {
		nodes = nodes,
		links = links,
	}, ids
end

local function pawnFor(random, shape)
	local media = {}
	local names = shape.layered and PAWN_MEDIA[random(1, #PAWN_MEDIA)] or PAWN_MEDIA[1]
	for _, name in ipairs(names) do
		media[name] = true
	end

	return {
		hull = shape.hulls and random(HULL_SMALL, HULL_LARGE) or HULL_SMALL,
		media = media,
	}
end

-- Layered cases mostly pick nodes the pawn can stand on, away from the medium of the other
-- end where it can, so most routes exist and many change medium. The rest pick any node, so
-- some searches must refuse their start or goal.
local function pickNode(random, graph, ids, pawn, shape, otherEnd)
	if shape.layered and random(1, 100) <= STANDABLE_PICK_PERCENT then
		local standable, elsewhere = {}, {}
		for _, id in ipairs(ids) do
			local medium = graph.nodes[id].medium
			if pawn.media[medium] and otherEnd ~= nil and medium ~= graph.nodes[otherEnd].medium then
				elsewhere[#elsewhere + 1] = id
			end
			if pawn.media[medium] then
				standable[#standable + 1] = id
			end
		end
		if #elsewhere > 0 then
			return elsewhere[random(1, #elsewhere)]
		end
		if #standable > 0 then
			return standable[random(1, #standable)]
		end
	end

	return ids[random(1, #ids)]
end

local function renameMedia(random, graph, pawn)
	local names = {}
	local function renamed(name)
		if names[name] == nil then
			names[name] = format("m%0" .. RENAMED_MEDIUM_DIGITS .. "d", random(0, 10 ^ RENAMED_MEDIUM_DIGITS - 1))
		end
		return names[name]
	end

	for _, node in pairs(graph.nodes) do
		node.medium = renamed(node.medium)
	end

	local media = {}
	for name in pairs(pawn.media) do
		media[renamed(name)] = true
	end
	pawn.media = media
end

-- Every case is a fresh graph; a test may hand it to the library without copying it first.
function Cases()
	local cases = {}
	for shapeIndex, shape in ipairs(SHAPES) do
		local seeds = shape.layered and SEEDS_PER_LAYERED_SHAPE or SEEDS_PER_SHAPE
		for n = 1, seeds do
			local seed = shapeIndex * 1000 + n
			local random = newRandom(seed)
			local graph, ids = gridGraph(random, shape)

			if #ids > 0 then
				local pawn = pawnFor(random, shape)
				local startId = pickNode(random, graph, ids, pawn, shape)
				local goalId = pickNode(random, graph, ids, pawn, shape, startId)
				if shape.renamed then
					renameMedia(random, graph, pawn)
				end

				cases[#cases + 1] = {
					label = format("%s graph, seed %d, %d nodes, %d to %d", shape.name, seed, #ids, startId, goalId),
					seed = seed,
					graph = graph,
					startId = startId,
					goalId = goalId,
					pawn = pawn,
				}
			end
		end
	end

	return cases
end

function Fits(link, pawn)
	return pawn.hull <= link.maxHull
end

function StandsOn(graph, id, pawn)
	return pawn.media[graph.nodes[id].medium] == true
end

function Passable(graph, link, pawn)
	return Fits(link, pawn) and StandsOn(graph, link.from, pawn) and StandsOn(graph, link.to, pawn)
end

-- The cheapest link from one node to the next that the pawn may take, or nil.
function CheapestLink(graph, from, to, pawn)
	local best
	for _, link in ipairs(graph.links) do
		if link.from == from and link.to == to and Passable(graph, link, pawn) and (best == nil or link.cost < best.cost) then
			best = link
		end
	end

	return best
end

-- Relaxes every link until nothing improves. Slow and simple on purpose.
-- Returns the cheapest cost and one cheapest node path, or nil when the goal is out of reach,
-- which includes a start or goal the pawn cannot stand on.
function CheapestRoute(graph, startId, goalId, pawn)
	if not StandsOn(graph, startId, pawn) or not StandsOn(graph, goalId, pawn) then
		return nil
	end

	local best = { [startId] = 0 }
	local previous = {}
	local changed = true

	while changed do
		changed = false
		for _, link in ipairs(graph.links) do
			local from = best[link.from]
			if from ~= nil and Passable(graph, link, pawn) then
				local through = from + link.cost
				if best[link.to] == nil or through < best[link.to] then
					best[link.to] = through
					previous[link.to] = link.from
					changed = true
				end
			end
		end
	end

	if best[goalId] == nil then
		return nil
	end

	local reversed = { goalId }
	while reversed[#reversed] ~= startId do
		reversed[#reversed + 1] = previous[reversed[#reversed]]
	end

	local path = {}
	for index = #reversed, 1, -1 do
		path[#path + 1] = reversed[index]
	end

	return best[goalId], path
end

function Copy(value)
	if type(value) ~= "table" then
		return value
	end

	local copy = {}
	for key, field in pairs(value) do
		copy[Copy(key)] = Copy(field)
	end

	return copy
end

function Same(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then
		return a == b
	end

	for key, field in pairs(a) do
		if not Same(field, b[key]) then
			return false
		end
	end
	for key in pairs(b) do
		if a[key] == nil then
			return false
		end
	end

	return true
end

function SamePosition(a, b)
	return type(a) == "table" and a[1] == b[1] and a[2] == b[2] and a[3] == b[3]
end

-- A sight test that is the same both ways and depends on the seed, so any pair may be blocked.
function SightFor(seed)
	return function(a, b)
		local first, second = a, b
		if a[1] > b[1] or (a[1] == b[1] and (a[2] > b[2] or (a[2] == b[2] and a[3] > b[3]))) then
			first, second = b, a
		end

		local mix = first[1] * 7 + first[2] * 13 + first[3] * 3 + second[1] * 17 + second[2] * 19 + second[3] * 5 + seed
		return mix % 3 ~= 0
	end
end

function Describe(path)
	if type(path) ~= "table" then
		return tostring(path)
	end

	local parts = {}
	for index, id in ipairs(path) do
		parts[index] = tostring(id)
	end

	return "{ " .. concat(parts, ", ") .. " }"
end
