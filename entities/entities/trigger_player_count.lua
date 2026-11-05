AddCSLuaFile()

-- A volume that counts the players inside it, and fires when they enter or
-- leave, and when every player (or every player of a team) is inside.
-- Not implemented: SetReceiver / NullReceiver.
ENT.Type = "brush"
ENT.Base = "trigger_multiple_oc"

ENT.VolumeName = nil
ENT.ConstantAnnounce = false

local TEAM_NAMES = {
	[TEAM_RED] = "Red",
	[TEAM_BLUE] = "Blue",
}

function ENT:KeyValue(key, value)
	local keyLower = string.lower(key)

	if keyLower == "volumename" then
		self.VolumeName = value
	elseif keyLower == "constantannounce" then
		self.ConstantAnnounce = value == "1"
	else
		self.BaseClass.KeyValue(self, key, value)
	end
end

local function playing(ply)
	return IsValid(ply) and ply:Alive() and ply:Team() ~= TEAM_SPECTATOR
end

function ENT:Inside()
	self.playersInside = self.playersInside or {}

	return self.playersInside
end

-- the players inside who are playing, optionally of one team
function ENT:CountInside(teamId)
	local count = 0

	for ply in pairs(self:Inside()) do
		if playing(ply) and (teamId == nil or ply:Team() == teamId) then
			count = count + 1
		end
	end

	return count
end

local function countPlaying(teamId)
	local count = 0

	for _, ply in ipairs(player.GetAll()) do
		if playing(ply) and (teamId == nil or ply:Team() == teamId) then
			count = count + 1
		end
	end

	return count
end

function ENT:Announce(recipient)
	local count = self:CountInside()
	local message = string.format("%s: %d %s", self.VolumeName or self:GetName(), count, count == 1 and "player" or "players")

	if recipient == nil then
		PrintMessage(HUD_PRINTTALK, message)
	elseif IsValid(recipient) and recipient:IsPlayer() then
		recipient:PrintMessage(HUD_PRINTTALK, message)
	end
end

function ENT:OnTouchStart(ent)
	if not ent:IsPlayer() then return end

	self:Inside()[ent] = true

	self:CallAllOutputs("OnPlayerEntered", ent)

	local teamName = TEAM_NAMES[ent:Team()]
	if teamName then
		self:CallAllOutputs("On" .. teamName .. "PlayerEntered", ent)
	end

	if self:CountInside() == countPlaying() then
		self:CallAllOutputs("OnAllPlayersEntered", ent)
	end

	if teamName and self:CountInside(ent:Team()) == countPlaying(ent:Team()) then
		self:CallAllOutputs("OnAll" .. teamName .. "PlayersEntered", ent)
	end

	if self.ConstantAnnounce then self:Announce() end
end

function ENT:OnTouchEnd(ent)
	if not self:Inside()[ent] then return end

	self:Inside()[ent] = nil

	if self:GetDisabled() then return end

	self:CallAllOutputs("OnPlayerLeave", ent)

	local teamName = TEAM_NAMES[ent:Team()]
	if teamName then
		self:CallAllOutputs("On" .. teamName .. "PlayerLeave", ent)
	end

	if self.ConstantAnnounce then self:Announce() end
end

function ENT:AcceptInput(name, activator, caller, data)
	local nameLower = string.lower(name)

	if nameLower == "countplayers" then
		self:Announce()
	elseif nameLower == "countplayerstoactivator" then
		self:Announce(activator)
	else
		return self.BaseClass.AcceptInput(self, name, activator, caller, data)
	end

	return true
end
