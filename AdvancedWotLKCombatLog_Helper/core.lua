local pairs = pairs
local select = select
local time = time
local strconcat, strjoin, strmatch = strconcat, string.join, string.match
local tconcat = table.concat

local GetArenaTeam = GetArenaTeam
local GetGuildInfo = GetGuildInfo
local GetInventoryItemLink = GetInventoryItemLink
local GetNumTalents = GetNumTalents
local GetTalentInfo = GetTalentInfo
local UnitClass = UnitClass
local UnitGUID = UnitGUID
local UnitName = UnitName
local UnitSex = UnitSex
local UnitRace = UnitRace

local UNKNOWN = UNKNOWN

-- GLOBALS: DEFAULT_CHAT_FRAME, SendAddonMessage

local RPLL_HELPER = CreateFrame("Frame")
RPLL_HELPER.VERSION = 3
RPLL_HELPER.MESSAGE_PREFIX = "RPLL_H_"
RPLL_HELPER.PlayerInfo = {
	arenaTeams = {},
	gear = {},
}

RPLL_HELPER:SetScript("OnEvent", function(self, event, ...)
	self:OnEvent(event, ...)
end)

RPLL_HELPER:RegisterEvent("CHAT_MSG_LOOT")
RPLL_HELPER:RegisterEvent("PET_STABLE_CLOSED")
RPLL_HELPER:RegisterEvent("PLAYER_ENTERING_WORLD")
RPLL_HELPER:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
RPLL_HELPER:RegisterEvent("PLAYER_GUILD_UPDATE")
RPLL_HELPER:RegisterEvent("PLAYER_PET_CHANGED")
RPLL_HELPER:RegisterEvent("UNIT_ENTERED_VEHICLE")
RPLL_HELPER:RegisterEvent("UNIT_PET")
RPLL_HELPER:RegisterEvent("ZONE_CHANGED_NEW_AREA")

function RPLL_HELPER:OnEvent(event, unit, ...)
	if event == "PLAYER_EQUIPMENT_CHANGED" or event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_GUILD_UPDATE" then
		RPLL_HELPER:SendPlayerInfo()
	elseif event == "UNIT_PET" or event == "UNIT_ENTERED_VEHICLE" then
		if unit == "player" then
			self:SendPetInfo()
		end
	elseif event == "PLAYER_PET_CHANGED" or event == "PET_STABLE_CLOSED" then
		self:SendPetInfo()
	elseif event == "CHAT_MSG_LOOT" then
		self:ProcessLootMessage(...)
	elseif event == "PLAYER_ENTERING_WORLD" then
		self:UnregisterEvent(event)

		RPLL_HELPER:SendPlayerInfo()

		self:PrintMessage("Initialized!")
	end
end

function RPLL_HELPER:PrintMessage(...)
	DEFAULT_CHAT_FRAME:AddMessage(strconcat("|cFFFF8080LegacyPlayers Helper|r: ", ...))
end

function RPLL_HELPER:SendPetInfo()
	local petGUID = UnitGUID("pet")
	if petGUID and petGUID ~= "" then
		SendAddonMessage(RPLL_HELPER.MESSAGE_PREFIX .. "PET", strjoin("&", UnitGUID("player"), petGUID), "RAID")
	end
end

function RPLL_HELPER:SendPlayerInfo()
	local guid = UnitGUID("player")
	if guid and guid ~= "" then
		local now = time()
		if self.lastUpdate and (now - self.lastUpdate) <= 30 then
			return
		end

		self.lastUpdate = now

		local pinfo = RPLL_HELPER.PlayerInfo

		pinfo["guid"] = guid
		pinfo["name"] = UnitName("player")

		-- Guild
		local guildName, guildRankName, guildRankIndex = GetGuildInfo("player")
		if guildName then
			pinfo["guildName"] = guildName
			pinfo["guildRankName"] = guildRankName
			pinfo["guildRankIndex"] = guildRankIndex
		else
			pinfo["guildName"] = nil
			pinfo["guildRankName"] = nil
			pinfo["guildRankIndex"] = nil
		end

		-- Pet name
		local petName = UnitName("pet")
		if petName and petName ~= UNKNOWN then
			pinfo["pet"] = petName
		else
			pinfo["pet"] = nil
		end

		-- Hero Class, race, sex
		pinfo["class"] = select(2, UnitClass("player"))
		pinfo["race"] = select(2, UnitRace("player"))
		pinfo["gender"] = UnitSex("player")

		-- Gear
		for i = 1, 19 do
			local itemLink = GetInventoryItemLink("player", i)
			if itemLink then
				local itemString = strmatch(itemLink, "item:([^\124]+)")
				if itemString then
					pinfo["gear"][i] = itemString
				else
					pinfo["gear"][i] = nil
				end
			else
				pinfo["gear"][i] = nil
			end
		end

		-- Talents
		do
			local index = 1
			local talents = {}
			for tabIndex = 1, 3 do
				local numTalents = GetNumTalents(tabIndex, false)
				for talentIndex = 1, numTalents do
					local name, _, _, _, curRank = GetTalentInfo(tabIndex, talentIndex, false)
					talents[index] = name and curRank or "0"
					index = index + 1
				end
				if tabIndex ~= 3 then
					talents[index] = "}"
					index = index + 1
				end
			end

			if index > 10 then
				pinfo["talents"] = tconcat(talents, "")
			end
		end

		-- Arena Teams
		for i = 1, 3 do
			local teamName, teamSize = GetArenaTeam(i)
			if teamName then
				pinfo["arenaTeams"][teamSize] = teamName
			end
		end

		SendAddonMessage(RPLL_HELPER.MESSAGE_PREFIX .. "CBT_I_1", RPLL_HELPER:SerializePlayerInformation(1), "RAID")
		SendAddonMessage(RPLL_HELPER.MESSAGE_PREFIX .. "CBT_I_2", RPLL_HELPER:SerializePlayerInformation(2), "RAID")
		SendAddonMessage(RPLL_HELPER.MESSAGE_PREFIX .. "CBT_I_3", RPLL_HELPER:SerializePlayerInformation(3), "RAID")
		SendAddonMessage(RPLL_HELPER.MESSAGE_PREFIX .. "CBT_I_4", RPLL_HELPER:SerializePlayerInformation(4), "RAID")
		SendAddonMessage(RPLL_HELPER.MESSAGE_PREFIX .. "CBT_I_5", RPLL_HELPER:SerializePlayerInformation(5), "RAID")
		SendAddonMessage(RPLL_HELPER.MESSAGE_PREFIX .. "CBT_I_6", RPLL_HELPER:SerializePlayerInformation(6), "RAID")
	end
end

local function valueOrNil(val)
	if val == nil then
		return "nil"
	end
	return val
end

function RPLL_HELPER:SerializePlayerInformation(iteration)
	local pinfo = RPLL_HELPER.PlayerInfo

	if iteration == 1 then
		return strjoin("&", valueOrNil(pinfo["guid"]),
			valueOrNil(pinfo["name"]), valueOrNil(pinfo["race"]), valueOrNil(pinfo["class"]), valueOrNil(pinfo["gender"]),
			valueOrNil(pinfo["guildName"]), valueOrNil(pinfo["guildRankName"]), valueOrNil(pinfo["guildRankIndex"]))
	elseif iteration == 2 then
		return strjoin("&", valueOrNil(pinfo["guid"]),
			valueOrNil(pinfo["talents"]),
			valueOrNil(pinfo["arenaTeams"][2]), valueOrNil(pinfo["arenaTeams"][3]), valueOrNil(pinfo["arenaTeams"][5]))
	elseif iteration == 3 then
		local gear = valueOrNil(pinfo["gear"][1])
		for i = 2, 5 do
			gear = gear .. "}" .. valueOrNil(pinfo["gear"][i])
		end
		return strjoin("&", valueOrNil(pinfo["guid"]), gear)
	elseif iteration == 4 then
		local gear = valueOrNil(pinfo["gear"][6])
		for i = 7, 10 do
			gear = gear .. "}" .. valueOrNil(pinfo["gear"][i])
		end
		return strjoin("&", valueOrNil(pinfo["guid"]), gear)
	elseif iteration == 5 then
		local gear = valueOrNil(pinfo["gear"][11])
		for i = 12, 15 do
			gear = gear .. "}" .. valueOrNil(pinfo["gear"][i])
		end
		return strjoin("&", valueOrNil(pinfo["guid"]), gear)
	elseif iteration == 6 then
		local gear = valueOrNil(pinfo["gear"][16])
		for i = 17, 19 do
			gear = gear .. "}" .. valueOrNil(pinfo["gear"][i])
		end
		return strjoin("&", valueOrNil(pinfo["guid"]), gear)
	end
end

local CHAT_LOOT_SELF_PATTERNS = {}
local CHAT_LOOT_OTHER_PATTERNS = {}
do
	if GetLocale() == "ruRU" then
		-- LOOT_ITEM_PUSHED_SELF
		CHAT_LOOT_SELF_PATTERNS["^Вы получаете предмет: (.+)%.$"] = "%s receives item: %s%s."

		-- LOOT_ITEM_PUSHED_SELF_MULTIPLE
		CHAT_LOOT_SELF_PATTERNS["^Вы получаете предмет: (.+)x(%d+)%.$"] = "%s receives item: %sx%s."

		-- LOOT_ITEM_SELF
		CHAT_LOOT_SELF_PATTERNS["^Ваша добыча: (.+)%.$"] = "%s receives loot: %s%s."

		-- LOOT_ITEM_SELF_MULTIPLE
		CHAT_LOOT_SELF_PATTERNS["^Ваша добыча: (.+)x(%d+)%.$"] = "%s receives loot: %sx%s."

		-- LOOT_ITEM_CREATED_SELF
		CHAT_LOOT_SELF_PATTERNS["^Вы создаете: (.+)%.$"] = "%s creates: %s%s."

		-- LOOT_ITEM_CREATED_SELF_MULTIPLE
		CHAT_LOOT_SELF_PATTERNS["^Вы создаете: (.+)x(%d+)%.$"] = "%s creates: %sx%s."

		-- TRADESKILL_LOG_FIRSTPERSON
	--	CHAT_LOOT_SELF_PATTERNS["^Вы создаете: (.+)%.$"] = "%s creates %s%s."

		-- LOOT_ITEM
		CHAT_LOOT_OTHER_PATTERNS["^(.+) получает добычу: (.+)%.$"] = "%s receives loot: %s%s."

		-- LOOT_ITEM_MULTIPLE
		CHAT_LOOT_OTHER_PATTERNS["^(.+) получает добычу: (.+)x(%d+)%.$"] = "%s receives loot: %sx%s."
	else
		-- LOOT_ITEM_PUSHED_SELF
		CHAT_LOOT_SELF_PATTERNS["You receive item: (.+)%.$"] = "%s receives item: %s%s."

		-- LOOT_ITEM_PUSHED_SELF_MULTIPLE
		CHAT_LOOT_SELF_PATTERNS["^You receive item: (.+)x(%d+)%.$"] = "%s receives item: %sx%s."

		-- LOOT_ITEM_SELF
		CHAT_LOOT_SELF_PATTERNS["^You receive loot: (.+)%.$"] = "%s receives loot: %s%s."

		-- LOOT_ITEM_SELF_MULTIPLE
		CHAT_LOOT_SELF_PATTERNS["^You receive loot: (.+)x(%d+)%."] = "%s receives loot: %sx%s."

		-- LOOT_ITEM_CREATED_SELF
		CHAT_LOOT_SELF_PATTERNS["^You create: (.+)%.$"] = "%s creates: %s%s."

		-- LOOT_ITEM_CREATED_SELF_MULTIPLE
		CHAT_LOOT_SELF_PATTERNS["^You create: (.+)x(%d+)%.$"] = "%s creates: %sx%s."

		-- TRADESKILL_LOG_FIRSTPERSON
		CHAT_LOOT_SELF_PATTERNS["^You create (.+)%.$"] = "%s creates %s%s."

		-- LOOT_ITEM
		CHAT_LOOT_OTHER_PATTERNS["^(.+) receives loot: (.+)%.$"] = "%s receives loot: %s%s."

		-- LOOT_ITEM_MULTIPLE
	--	CHAT_LOOT_OTHER_PATTERNS["^(.+) receives loot: (.+)x(%d+)."] = "%s receives loot: %sx%s."
	end
end

function RPLL_HELPER:ProcessLootMessage(message)
	local result, resultName
	local playerName = UnitName("player")

	for pattern, replaceMessage in pairs(CHAT_LOOT_SELF_PATTERNS) do
		local loot, count = strmatch(message, pattern)
		if loot then
			if count then
				result = replaceMessage:format(replaceMessage, playerName, loot, count)
			else
				result = replaceMessage:format(playerName, loot, "x1")
			end
			break
		end
	end

	if not result then
		for pattern, replaceMessage in pairs(CHAT_LOOT_OTHER_PATTERNS) do
			local loot, count
			resultName, loot, count = strmatch(message, pattern)
			if resultName then
				if count then
					result = replaceMessage:format(replaceMessage, resultName, loot, count)
				else
					result = replaceMessage:format(replaceMessage, resultName, loot, "x1")
				end
				break
			end
		end
	end

	if result and resultName == playerName then
		SendAddonMessage(RPLL_HELPER.MESSAGE_PREFIX .. "LOOT", result, "RAID")
	end
end