AddCSLuaFile()

-- "Eats" (removes) dropped weapons in a radius when it gets the Eat input.
ENT.Type = "point"
ENT.Base = "base_point"

-- Obsidian.fgd: EatRadius defaults to 256
ENT.EatRadius = 256

-- the wiki: "It only can eat up to 512 entities"
local MAX_EATEN = 512

function ENT:KeyValue(key, value)
	if string.lower(key) == "eatradius" then
		self.EatRadius = tonumber(value) or self.EatRadius
	end
end

function ENT:Eat()
	local eaten = 0

	for _, ent in ipairs(ents.FindInSphere(self:GetPos(), self.EatRadius)) do
		if eaten >= MAX_EATEN then break end

		if ent:IsWeapon() and not IsValid(ent:GetOwner()) then
			ent:Remove()
			eaten = eaten + 1
		end
	end
end

function ENT:AcceptInput(name, activator, caller, data)
	if string.lower(name) == "eat" then
		self:Eat()
		return true
	end

	return false
end
