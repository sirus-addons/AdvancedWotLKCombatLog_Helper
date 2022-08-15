local date = date
local pairs = pairs
local strfind = string.find
local strjoin = string.join
local strlen = string.len
local time = time

local GetGuildInfo = GetGuildInfo
local GetInventoryItemLink = GetInventoryItemLink
local GetNumTalents = GetNumTalents
local GetTalentInfo = GetTalentInfo
local NotifyInspect = NotifyInspect
local SendAddonMessage = SendAddonMessage
local UnitGUID = UnitGUID
local UnitName = UnitName
local UnitSex = UnitSex
local GetArenaTeam = GetArenaTeam
local UnitClass = UnitClass
local UnitRace = UnitRace

local UNKNOWN = UNKNOWN

local function prep_value(val)
	if val == nil then
		return "nil"
	end
	return val
end

local RPLL_HELPER = CreateFrame("Frame")
RPLL_HELPER.VERSION = 3
RPLL_HELPER.MESSAGE_PREFIX = "RPLL_H_"
RPLL_HELPER.PlayerInfo = {}

RPLL_HELPER:SetScript("OnEvent", function(self, event, ...)
	self[event](...)
end)

RPLL_HELPER:RegisterEvent("ZONE_CHANGED_NEW_AREA")
RPLL_HELPER:RegisterEvent("PLAYER_ENTERING_WORLD")
RPLL_HELPER:RegisterEvent("PLAYER_GUILD_UPDATE")

RPLL_HELPER:RegisterEvent("UNIT_PET")
RPLL_HELPER:RegisterEvent("PLAYER_PET_CHANGED")
RPLL_HELPER:RegisterEvent("PET_STABLE_CLOSED")

RPLL_HELPER:RegisterEvent("CHAT_MSG_LOOT")
RPLL_HELPER:RegisterEvent("UNIT_INVENTORY_CHANGED")

RPLL_HELPER:RegisterEvent("INSPECT_TALENT_READY")
RPLL_HELPER:RegisterEvent("UNIT_ENTERED_VEHICLE")

local inspect_pending = false
RPLL_HELPER.ZONE_CHANGED_NEW_AREA = function()
	if not inspect_pending then
		NotifyInspect("player")
		inspect_pending = true
	end
end

RPLL_HELPER.PLAYER_GUILD_UPDATE = function()
	if not inspect_pending then
		NotifyInspect("player")
		inspect_pending = true
	end
end

RPLL_HELPER.UNIT_INVENTORY_CHANGED = function(unit)
	if unit == "player" and not inspect_pending then
		NotifyInspect("player")
		inspect_pending = true
	end
end

RPLL_HELPER.PLAYER_ENTERING_WORLD = function()
	RPLL_HELPER:UnregisterEvent("PLAYER_ENTERING_WORLD")

	if not inspect_pending then
		NotifyInspect("player")
		inspect_pending = true
	end
	RPLL_HELPER:SendMessage("Initialized!")
end

RPLL_HELPER.PLAYER_PET_CHANGED = function()
	RPLL_HELPER:grab_pet_information()
end

RPLL_HELPER.PET_STABLE_CLOSED = function()
	RPLL_HELPER:grab_pet_information()
end

RPLL_HELPER.UNIT_PET = function(unit)
	if unit == "player" then
		RPLL_HELPER:grab_pet_information()
	end
end

RPLL_HELPER.UNIT_ENTERED_VEHICLE = function(unit)
	if unit == "player" then
		RPLL_HELPER:grab_pet_information()
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

RPLL_HELPER.CHAT_MSG_LOOT = function(msg)
	local result, resultName
	local playerName = UnitName("player")

	for pattern, replaceMessage in pairs(CHAT_LOOT_SELF_PATTERNS) do
		local loot, count = string.match(msg, pattern)
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
			resultName, loot, count = string.match(msg, pattern)
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

local inspect_ready = false
RPLL_HELPER.INSPECT_TALENT_READY = function()
	if inspect_pending then
		inspect_ready = true
		RPLL_HELPER:grab_player_information()
		inspect_ready = false
		inspect_pending = false
	end
end

function RPLL_HELPER:grab_pet_information()
	local pet_guid = UnitGUID("pet")
	if pet_guid ~= nil and pet_guid ~= "" then
		local player_guid = UnitGUID("player")
		SendAddonMessage(RPLL_HELPER.MESSAGE_PREFIX .. "PET", strjoin("&", player_guid, pet_guid), "RAID")
	end
end

function RPLL_HELPER:grab_player_information()
	local unit_guid = UnitGUID("player")
	if unit_guid ~= nil and unit_guid ~= "" then
		if RPLL_HELPER.PlayerInfo["last_update"] ~= nil and time() - RPLL_HELPER.PlayerInfo["last_update"] <= 30 then
			return
		end
		RPLL_HELPER.PlayerInfo["last_update_date"] = date("%d.%m.%y %H:%M:%S")
		RPLL_HELPER.PlayerInfo["last_update"] = time()
		RPLL_HELPER.PlayerInfo["unit_name"] = UnitName("player")
		RPLL_HELPER.PlayerInfo["unit_guid"] = unit_guid

		-- Guild RPLL_HELPER.PlayerInfo
		local guildName, guildRankName, guildRankIndex = GetGuildInfo("player")
		if guildName ~= nil then
			RPLL_HELPER.PlayerInfo["guild_name"] = guildName
			RPLL_HELPER.PlayerInfo["guild_rank_name"] = guildRankName
			RPLL_HELPER.PlayerInfo["guild_rank_index"] = guildRankIndex
		end

		-- Pet name
		local pet_name = UnitName("pet")
		if pet_name ~= nil and pet_name ~= UNKNOWN then
			RPLL_HELPER.PlayerInfo["pet"] = pet_name
		end

		-- Hero Class, race, sex
		if UnitClass("player") ~= nil then
			local _, english_class = UnitClass("player")
			RPLL_HELPER.PlayerInfo["hero_class"] = english_class
		end
		if UnitRace("player") ~= nil then
			local _, en_race = UnitRace("player")
			RPLL_HELPER.PlayerInfo["race"] = en_race
		end
		if UnitSex("player") ~= nil then
			RPLL_HELPER.PlayerInfo["gender"] = UnitSex("player")
		end

		-- Gear
		local any_item = false
		for i = 1, 19 do
			if GetInventoryItemLink("player", i) ~= nil then
				any_item = true
				break
			end
		end

		if RPLL_HELPER.PlayerInfo["gear"] == nil then
			RPLL_HELPER.PlayerInfo["gear"] = {}
		end

		if any_item then
			RPLL_HELPER.PlayerInfo["gear"] = {}
			for i = 1, 19 do
				local inv_link = GetInventoryItemLink("player", i)
				if inv_link == nil then
					RPLL_HELPER.PlayerInfo["gear"][i] = nil
				else
					local found, _, itemString = strfind(inv_link, "Hitem:(.+)\124h%[")
					if found == nil then
						RPLL_HELPER.PlayerInfo["gear"][i] = nil
					else
						RPLL_HELPER.PlayerInfo["gear"][i] = itemString
					end
				end
			end
		end

		if RPLL_HELPER.PlayerInfo["arena_teams"] == nil then
			RPLL_HELPER.PlayerInfo["arena_teams"] = {}
		end

		if inspect_ready then
			-- Talents
			local talents = { "", "", "" };
			for t = 1, 3 do
				local numTalents = GetNumTalents(t, false);
				-- Last one is missing?
				for i = 1, numTalents do
					local _, _, _, _, currRank = GetTalentInfo(t, i, false);
					talents[t] = talents[t] .. currRank
				end
			end
			talents = strjoin("}", talents[1], talents[2], talents[3])
			if strlen(talents) <= 10 then
				talents = nil
			end

			if talents ~= nil then
				RPLL_HELPER.PlayerInfo["talents"] = talents
			end

			-- Arena Teams
			local arena_teams = {}
			for i = 1, 3 do
				local team_name, team_size
			--	if unit == "player" then
					team_name, team_size = GetArenaTeam(i);
			--	else
			--		team_name, team_size = GetInspectArenaTeamData(i);
			--	end

				if team_name ~= nil and team_size ~= nil then
					arena_teams[team_size] = team_name
				end
			end
			for team_size, team_name in pairs(arena_teams) do
				RPLL_HELPER.PlayerInfo["arena_teams"][team_size] = team_name
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

function RPLL_HELPER:SerializePlayerInformation(iteration)
	local val = RPLL_HELPER.PlayerInfo;

	if iteration == 1 then
		return strjoin("&", prep_value(val["unit_guid"]), prep_value(val["unit_name"]),
				prep_value(val["race"]), prep_value(val["hero_class"]), prep_value(val["gender"]), prep_value(val["guild_name"]),
				prep_value(val["guild_rank_name"]), prep_value(val["guild_rank_index"]))
	elseif iteration == 2 then
		return strjoin("&", prep_value(val["unit_guid"]), prep_value(val["talents"]),
				prep_value(val["arena_teams"][2]), prep_value(val["arena_teams"][3]), prep_value(val["arena_teams"][5]))
	elseif iteration == 3 then
		local gear = prep_value(val["gear"][1])
		for i = 2, 5 do
			gear = gear .. "}" .. prep_value(val["gear"][i])
		end
		return strjoin("&", prep_value(val["unit_guid"]), gear)
	elseif iteration == 4 then
		local gear = prep_value(val["gear"][6])
		for i = 7, 10 do
			gear = gear .. "}" .. prep_value(val["gear"][i])
		end
		return strjoin("&", prep_value(val["unit_guid"]), gear)
	elseif iteration == 5 then
		local gear = prep_value(val["gear"][11])
		for i = 12, 15 do
			gear = gear .. "}" .. prep_value(val["gear"][i])
		end
		return strjoin("&", prep_value(val["unit_guid"]), gear)
	elseif iteration == 6 then
		local gear = prep_value(val["gear"][16])
		for i = 17, 19 do
			gear = gear .. "}" .. prep_value(val["gear"][i])
		end
		return strjoin("&", prep_value(val["unit_guid"]), gear)
	end
end

function RPLL_HELPER:SendMessage(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cFFFF8080LegacyPlayers Helper|r: " .. msg)
end