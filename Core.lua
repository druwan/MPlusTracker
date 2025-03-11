-- Addon namespace
local MPT = _G.MPT or {}
_G.MPT = MPT
local eventFrame = CreateFrame("Frame")

MPT.runActive = false
MPT.currentRun = nil

function MPT:EnsureInit()
	if not MPT.Initialized then
		MPT:InitializeDB()
		MPT.Initialized = true
		print("MPT Init")
	end
end

-- Event handler for m+ tracking
function MPT:OnEvent(_, event, ...)
	local handlers = {
		ADDON_LOADED = function(addonName)
			if addonName == "MPlusTracker" then
				MPT:InitializeDB()
				MPT.Initialized = true
				print("MPT Loaded")
			end
		end,
		PLAYER_LOGOUT = function()
			MPT:UpdateGlobalStats()
		end,
		CHALLENGE_MODE_START = function()
			local mapID = C_ChallengeMode.GetActiveChallengeMapID()
			local mapName = mapID and C_ChallengeMode.GetMapUIInfo(mapID)
			local keyLvl, affixIDs, _ = C_ChallengeMode.GetActiveKeystoneInfo()
			MPT:InitRun(mapName, keyLvl, affixIDs, time())
			print("M+ started " .. mapName .. " " .. keyLvl .. " " .. time())
		end,
		CHALLENGE_MODE_COMPLETED = function()
			if not MPT.currentRun then return end
			local _, _, time, onTime, keyUpgradeLvl, _, oldOverallDungeonScore, newOverallDungeonScore = C_ChallengeMode
			.GetChallengeCompletionInfo()
			local numDeaths, timeLost = C_ChallengeMode.GetDeathCount()
			MPT:FinalizeRun(true, onTime, time, keyUpgradeLvl, oldOverallDungeonScore, newOverallDungeonScore, numDeaths,
				timeLost)
			print("M+ finished: " .. time)
		end,
		CHALLENGE_MODE_RESET = function()
			if MPT.currentRun and not IsInGroup() then
				MPT:FinalizeRun(false, nil, time())
			end
		end,
		PLAYER_LEAVING_WORLD = function()
			if MPT.currentRun and not IsInGroup() then
				MPT:FinalizeRun(false, nil, time())
			end
		end,
		CHALLENGE_MODE_MAPS_UPDATE = function()
			if MPT.currentRun and not IsInGroup() then
				MPT:FinalizeRun(false, nil, time())
			end
		end,
		CHALLENGE_MODE_MEMBER_INFO_UPDATED = function()
			if MPT.currentRun and not IsInGroup() then
				MPT:FinalizeRun(false, nil, time())
			end
		end,
		INSPECT_READY = function()
			MPT:OnInspectReady()
		end,
	}

	local handler = handlers[event]
	if handler then
		handler(...)
	end
end

-- Register events
local events = {
	"ADDON_LOADED",
	"CHALLENGE_MODE_COMPLETED",
	"CHALLENGE_MODE_MAPS_UPDATE",
	"CHALLENGE_MODE_MEMBER_INFO_UPDATED",
	"CHALLENGE_MODE_RESET",
	"CHALLENGE_MODE_START",
	"INSPECT_READY",
	"PLAYER_LEAVING_WORLD",
	"PLAYER_LOGOUT",
}

for _, e in pairs(events) do
	eventFrame:RegisterEvent(e)
end
eventFrame:SetScript("OnEvent", MPT.OnEvent)

-- Register a timer to save every 10 minutes
C_Timer.NewTicker(600, function() MPT:UpdateGlobalStats() end)
