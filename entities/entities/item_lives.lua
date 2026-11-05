AddCSLuaFile()

ENT.Base = "item_pickup_base"

ENT.PrintName = "Lives"
ENT.Spawnable = false
ENT.AdminSpawnable = false

ENT.PickupModel = "models/healthvial.mdl"
ENT.LivesToGive = 1

function ENT:KeyValue(key, value)
	if string.lower(key) == "livestogive" then
		self.LivesToGive = tonumber(value) or self.LivesToGive
	end

	self.BaseClass.KeyValue(self, key, value)
end

-- A negative LivesToGive takes lives. Without lives on the map there is nothing to
-- give, so the item stays where it is.
function ENT:OnPickup(ply)
	if not OC.Lives.isEnabled() then return false end

	OC.Lives.addLives(ply, self.LivesToGive)
	ply:ChatPrint(string.format("%+d %s", self.LivesToGive, math.abs(self.LivesToGive) == 1 and "life" or "lives"))

	return true
end
