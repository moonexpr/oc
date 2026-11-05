AddCSLuaFile()

-- Players inside the volume do not collide with each other (a lift full of
-- players, say). Outputs, filters and enabling come from trigger_once_oc.
ENT.Type = "brush"
ENT.Base = "trigger_multiple_oc"

-- how many nocollide volumes a player is in; networked so prediction agrees
local NW_KEY = "oc_nocollide"

local function inside(ply)
	return ply:GetNWInt(NW_KEY, 0) > 0
end

local function enter(ply)
	ply:SetNWInt(NW_KEY, ply:GetNWInt(NW_KEY, 0) + 1)
	ply:SetCustomCollisionCheck(true)
end

local function leave(ply)
	if IsValid(ply) then
		ply:SetNWInt(NW_KEY, math.max(0, ply:GetNWInt(NW_KEY, 0) - 1))
	end
end

function ENT:Held()
	self.held = self.held or {}

	return self.held
end

function ENT:OnTouchStart(ent)
	if not ent:IsPlayer() or self:Held()[ent] then return end

	self:Held()[ent] = true
	enter(ent)
end

function ENT:OnTouchEnd(ent)
	if not self:Held()[ent] then return end

	self:Held()[ent] = nil
	leave(ent)
end

function ENT:ReleaseAll()
	for ply in pairs(self:Held()) do
		leave(ply)
	end

	self.held = {}
end

function ENT:AcceptInput(name, activator, caller, data)
	local result = self.BaseClass.AcceptInput(self, name, activator, caller, data)

	if self:GetDisabled() then self:ReleaseAll() end

	return result
end

function ENT:OnRemove()
	self:ReleaseAll()
end

-- ShouldCollide runs only for entities that ask for it, in both realms
hook.Add("OnEntityCreated", "oc_trigger_nocollide", function(ent)
	if ent:IsPlayer() then
		ent:SetCustomCollisionCheck(true)
	end
end)

hook.Add("ShouldCollide", "oc_trigger_nocollide", function(a, b)
	if a:IsPlayer() and b:IsPlayer() and inside(a) and inside(b) then
		return false
	end
end)
