AddCSLuaFile()

-- The Obsidian Conflict "Item" base class: a player touches it to collect it, it
-- fires OnPlayerTouch, and it respawns unless "Do Not Respawn" is set.
ENT.Type = "anim"
ENT.Base = "base_anim"

ENT.PrintName = "Base Pickup"
ENT.Spawnable = false
ENT.AdminSpawnable = false

ENT.PickupModel = "models/items/battery.mdl"
ENT.FallbackModel = "models/items/battery.mdl"
ENT.PickupSound = "items/smallmedkit1.wav"
-- not in the FGD; items in Obsidian Conflict respawn, so it needs some delay
ENT.RespawnTime = 30

-- Obsidian.fgd, the "Item" base class
local DO_NOT_RESPAWN = 0x40000000

-- a subclass returns true when the player collected the item
function ENT:OnPickup(ply)
	return false
end

function ENT:KeyValue(key, value)
	if string.Left(string.lower(key), 2) == "on" then
		self:StoreOutput(key, value)
	end
end

function ENT:Initialize()
	self:SetModel(util.IsValidModel(self.PickupModel) and self.PickupModel or self.FallbackModel)

	if SERVER then
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetTrigger(true)
	end
end

function ENT:Touch(ent)
	if self.collected then return end
	if not (ent:IsPlayer() and ent:Alive()) then return end

	self:TriggerOutput("OnPlayerTouch", ent)

	if not self:OnPickup(ent) then return end

	self:EmitSound(self.PickupSound)
	self:Collect()
end

function ENT:Collect()
	if self:HasSpawnFlags(DO_NOT_RESPAWN) then
		self:Remove()
		return
	end

	self.collected = true
	self:SetNoDraw(true)

	timer.Simple(self.RespawnTime, function()
		if not IsValid(self) then return end

		self.collected = false
		self:SetNoDraw(false)
	end)
end
