AddCSLuaFile()

-- A trigger without a volume: it touches whatever is within TriggerRadius. It
-- finds its touchers by scanning, so keep them few ("processor-intensive").
-- Outputs, filters and enabling come from trigger_once_oc.
ENT.Type = "point"
ENT.Base = "trigger_once_oc"

-- Defaults from Obsidian.fgd: TriggerRadius 128, TriggerOnce 0 (Multiple)
ENT.TriggerRadius = 128
ENT.TriggerOnce = false

local SCAN_INTERVAL = 0.1

function ENT:KeyValue(key, value)
	local keyLower = string.lower(key)

	if keyLower == "triggerradius" then
		self.TriggerRadius = tonumber(value) or self.TriggerRadius
	elseif keyLower == "triggeronce" then
		self.TriggerOnce = value == "1"
	else
		self.BaseClass.KeyValue(self, key, value)
	end
end

-- A brush trigger only ever touches solid things, but a scan sees everything in
-- the sphere, so the type flags must pick what counts (as Source's trigger does).
function ENT:IsTouchable(ent)
	local flags = self.Flags

	return self:HasSpawnFlags(flags.EVERYTHING)
		or (self:HasSpawnFlags(flags.CLIENTS) and ent:IsPlayer())
		or (self:HasSpawnFlags(flags.NPCS) and ent:IsNPC())
		or (self:HasSpawnFlags(flags.PUSHABLES) and ent:GetClass() == "func_pushable")
		or (self:HasSpawnFlags(flags.PHYSICS_OBJECTS) and ent:GetMoveType() == MOVETYPE_VPHYSICS)
end

function ENT:Initialize()
	self.touching = {}
	self:NextThink(CurTime())
end

function ENT:Scan()
	local found = {}

	for _, ent in ipairs(ents.FindInSphere(self:GetPos(), self.TriggerRadius)) do
		if ent ~= self and not ent:IsWorld() and self:IsTouchable(ent) and self:CheckFilter(ent) then
			found[ent] = true
		end
	end

	for ent in pairs(self.touching) do
		if not found[ent] then
			self.touching[ent] = nil

			if IsValid(ent) then
				self:EndTouch(ent)
			else
				-- it was removed; it can no longer say it left
				self.touchAmount = math.max(0, self.touchAmount - 1)
				if self.touchAmount == 0 then self:CallAllOutputs("OnEndTouchAll", nil) end
			end
		end
	end

	for ent in pairs(found) do
		if not self.touching[ent] then
			self.touching[ent] = true
			self:StartTouch(ent)
		end
	end

	if self.TriggerOnce and next(found) ~= nil then
		self:Remove()
	end
end

function ENT:Think()
	if SERVER then
		if self:GetDisabled() then
			self.touching = {}
			self.touchAmount = 0
		else
			self:Scan()
		end
	end

	self:NextThink(CurTime() + SCAN_INTERVAL)
	return true
end
