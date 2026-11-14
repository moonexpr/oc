-- Connects pathfinding tests to the pathfinding library.
-- Tests reach the library only through this file, so keep these names and arguments.
-- Graph, pawn and position shapes are described at the top of tests/support/graph_cases.lua.
local error = error
module(...)

-- Returns the node ids from startId to goalId, both included, or nil when no path exists for
-- this pawn (its hull and the media it can move through).
function FindPath(graph, startId, goalId, pawn)
	error("FindPath is not connected to a pathfinding library yet", 2)
end

-- Turns a node path into world waypoints: a list of { x, y, z } taken from the path's node
-- positions, in order. The first and last nodes stay, and so do both nodes wherever the path
-- changes medium. Any other node may be left out, but only when canSee(a, b) is true for the
-- kept waypoints a and b on either side of it.
function BuildWaypoints(graph, nodePath, canSee)
	error("BuildWaypoints is not connected to a pathfinding library yet", 2)
end
