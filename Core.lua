-- Addon namespace
local MPT = _G.MPT
local eventFrame = CreateFrame("Frame")


MPT.runActive = false
MPT.currentRun = nil


-- Event handler for m+ tracking
function MPT:OnEvent(_, event, ...)
	if event == "ADDON_LOADED" and ... == "MPlusTracker" then
		MPT:InitializeDB()
		MPT:Print("MPT Loaded")
	elseif event == "PLAYER_LOGOUT" then
		MPT:UpdateGlobalStats()
	elseif event == "CHALLENGE_MODE_START" then
		local mapID = C_ChallengeMode.GetActiveChallengeMapID()
		local mapName = mapID and C_ChallengeMode.GetMapUIInfo(mapID)
		local keyLvl, affixIDs, _ = C_ChallengeMode.GetActiveKeystoneInfo()
		local affixName = select(1, C_ChallengeMode.GetAffixInfo(affixIDs[1]))
		MPT:InitRun(mapName, keyLvl, affixName, time())
	elseif event == "CHALLENGE_MODE_COMPLETED" and MPT.currentRun then
		local _, _, time, onTime, keyUpgradeLvl, _, oldOverallDungeonScore, newOverallDungeonScore = C_ChallengeMode
				.GetChallengeCompletionInfo()
		local numDeaths, timeLost = C_ChallengeMode.GetDeathCount()
		MPT:FinalizeRun(true, onTime, time, keyUpgradeLvl, oldOverallDungeonScore, newOverallDungeonScore, numDeaths,
			timeLost)
	elseif (event == "CHALLENGE_MODE_RESET" or event == "PLAYER_LEAVING_WORLD") and MPT.currentRun and not IsInGroup() then
		MPT:FinalizeRun(false, nil, time())
	elseif event == "INSPECT_READY" then
		MPT:OnInspectReady()
	end
end

-- Register events
local events = {
	"ADDON_LOADED",
	"CHALLENGE_MODE_COMPLETED",
	"CHALLENGE_MODE_RESET",
	"CHALLENGE_MODE_START",
	"PLAYER_LEAVING_WORLD",
	"PLAYER_LOGOUT",
	"INSPECT_READY",
}

for _, e in pairs(events) do
	eventFrame:RegisterEvent(e)
end
eventFrame:SetScript("OnEvent", MPT.OnEvent)

-- Register a timer to save every 10 minutes
C_Timer.NewTicker(600, function() MPT:UpdateGlobalStats() end)
