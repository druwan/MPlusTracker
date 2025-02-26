-- Addon namespace
local MPT = _G.MPT or {}
_G.MPT = MPT
local eventFrame = CreateFrame("Frame")

-- Updates global stats and resets session data to avoid double counting
local function UpdateGlobalStats()
	if not MPT.DB_GLOBAL then
		MPT.DB_GLOBAL = {
			completed = {
				inTime = 0,
				overTime = 0,
			},
			incomplete = 0,
			runs = {},
			started = 0,
		}
	end
	MPT.DB_GLOBAL.started = MPT.DB_GLOBAL.started + MPT.DB.started
	MPT.DB_GLOBAL.completed.inTime = MPT.DB_GLOBAL.completed.inTime + MPT.DB.completed.inTime
	MPT.DB_GLOBAL.completed.overTime = MPT.DB_GLOBAL.completed.overTime + MPT.DB.completed.overTime
	MPT.DB_GLOBAL.incomplete = MPT.DB_GLOBAL.incomplete + MPT.DB.incomplete

	-- Reset Session data after updating global stats
	MPT.DB.started = 0
	MPT.DB.completed.inTime = 0
	MPT.DB.completed.overTime = 0
	MPT.DB.incomplete = 0

	-- Debugging
	PrintToChat("Global Stats Updated", 4)
end

-- Store curr char. Inspect
MPT.pendingInspect = nil
MPT.runActive = false

-- Init a new run
local function InitRun(mapName, keyLevel, affixNames, startTime)
	if MPT.runActive then
		return
	end

	MPT.runActive = true

	MPT.currentRun = {
		mapName = mapName,
		level = keyLevel,
		affixNames = affixNames,
		startTime = date("%Y-%m-%d %H:%M:%S", startTime),
		party = {},
	}

	for i = 1, 5 do
		local unit = (i == 1) and "player" or "party" .. (i - 1)
		local name, class, role, specName, specID

		if UnitExists(unit) then
			name = GetUnitName(unit, true)
			class = select(2, UnitClass(unit))
			role = UnitGroupRolesAssigned(unit)

			-- If it's the player, use GetSpecialization() directly
			if UnitIsUnit(unit, "player") then
				specID = GetSpecialization()
				specName = specID and select(2, GetSpecializationInfo(specID))
			else
				-- For party members, use NotifyInspect and set a placeholder until spec is available
				specName = "Inspecting..."
				RequestInspect(unit, name)
			end

			local isMe = UnitIsUnit(unit, "player") and "*" or ""

			table.insert(MPT.currentRun.party, {
				name = name .. isMe,
				role = role,
				class = class,
				spec = specName,
			})
		end
	end

	MPT.DB.started = MPT.DB.started + 1
	MPT.DB_GLOBAL.started = MPT.DB_GLOBAL.started + 1

	PrintToChat("Mythic+ started: " .. mapName .. " (Level: " .. keyLevel .. ")", 4)
end

-- MPT.inspectQueue = {}
-- MPT.inspectInProgress = false

-- Request an inspection for a unit, add it to the queue if another inspection is in progress
-- function RequestInspect(unit, name)
-- 	if CanInspect(unit) then
-- 		table.insert(MPT.inspectQueue, { unit = unit, name = name })
-- 		ProcessNextInspect()
-- 	else
-- 		PrintToChat("Error when inspecting: " .. name, 4)
-- 	end
-- end

-- function ProcessNextInspect()
-- 	-- Return if an inspection is already in progress or queue is empty
-- 	if MPT.inspectInProgress or #MPT.inspectQueue == 0 then
-- 		return
-- 	end
-- 	local nextInspect = table.remove(MPT.inspectQueue, 1)
-- 	MPT.inspectInProgress = true
-- 	-- Delay the next inspection by 1 second to avoid rapid requests
-- 	C_Timer.After(1, function()
-- 		if not CanInspect(nextInspect.unit) then
-- 			PrintToChat("Unable to inspect: " .. nextInspect.name, 4)
-- 			MPT.inspectInProgress = false
-- 			ProcessNextInspect()
-- 			return
-- 		end
-- 		PrintToChat("Inspecting player: " .. nextInspect.name, 4)
-- 		-- Request inspection for the next unit
-- 		NotifyInspect(nextInspect.unit)
-- 		-- Track the unit being inspected
-- 		MPT.pendingInspect = nextInspect.unit
-- 		-- Print when inspection is done (complete or awaiting result)
-- 		C_Timer.After(2, function()
-- 			PrintToChat("Inspection complete or waiting for response: " .. nextInspect.name, 4)
-- 			MPT.inspectInProgress = false
-- 			ProcessNextInspect()
-- 		end)
-- 	end)
-- end

-- Update the party member's spec when INSPECT_READY is fired
-- local function OnInspectReady()
-- 	if MPT.pendingInspect then
-- 		local unit = MPT.pendingInspect
-- 		local specID = GetInspectSpecialization(unit)
-- 		local specName = specID and GetSpecializationNameForSpecID(specID) or "Unknown"
--
-- 		-- Update the spec for the inspected party member
-- 		for _, member in ipairs(MPT.currentRun.party) do
-- 			if string.find(member.name, GetUnitName(unit, true), 1, true) then
-- 				member.spec = specName
-- 				PrintToChat("Updated spec for " .. member.name .. " to " .. specName, 4)
-- 				break
-- 			end
-- 		end
--
-- 		MPT.pendingInspect = nil -- Clear pending inspection
-- 		MPT.inspectInProgress = false
-- 		ProcessNextInspect()
-- 	end
-- end

-- Finalize a run, either completed or incomplete
local function FinalizeRun(isCompleted, onTime, completionTime)
	if MPT.currentRun then
		MPT.currentRun.completed = isCompleted
		MPT.currentRun.completionTime = completionTime

		table.insert(MPT.DB.runs, MPT.currentRun)

		if isCompleted then
			if onTime then
				MPT.DB.completed.inTime = MPT.DB.completed.inTime + 1
				MPT.DB_GLOBAL.completed.inTime = MPT.DB_GLOBAL.completed.inTime + 1
			else
				MPT.DB.completed.overTime = MPT.DB.completed.overTime + 1
				MPT.DB_GLOBAL.completed.overTime = MPT.DB_GLOBAL.completed.overTime + 1
			end
		else
			MPT.DB.incomplete = MPT.DB.incomplete + 1
			MPT.DB_GLOBAL.incomplete = MPT.DB_GLOBAL.incomplete + 1
		end
		MPT.currentRun = nil
		MPT.runActive = false
	end
end

-- Register a timer to save every 10 minutes
C_Timer.NewTicker(600, UpdateGlobalStats)

-- Event handler for m+ tracking
function MPT.OnEvent(_, event, ...)
	if event == "INSPECT_READY" then
		OnInspectReady()
	end

	if event == "ADDON_LOADED" then
		local addonName = ...
		if addonName == "MPlusTracker" then
			-- Default values for the database
			if not MPT_DB then
				MPT_DB = {
					completed = {
						inTime = 0,
						overTime = 0,
					},
					incomplete = 0,
					runs = {},
					started = 0,
				}
			end

			if not MPT_DB_GLOBAL then
				MPT_DB_GLOBAL = {
					completed = {
						inTime = 0,
						overTime = 0,
					},
					incomplete = 0,
					runs = {},
					started = 0,
				}
			end
			MPT.DB = MPT_DB
			MPT.DB_GLOBAL = MPT_DB_GLOBAL
			print("MPT Loaded")
		end
	end

	if event == "PLAYER_LOGOUT" then
		UpdateGlobalStats()
	end

	if event == "CHALLENGE_MODE_START" then
		local activeMapID = C_ChallengeMode.GetActiveChallengeMapID()
		local dungeonName = activeMapID and C_ChallengeMode.GetMapUIInfo(activeMapID)
		local activeKeystoneLevel, affixIDs, _ = C_ChallengeMode.GetActiveKeystoneInfo()
		local affixName = select(1, C_ChallengeMode.GetAffixInfo(affixIDs[1]))
		InitRun(dungeonName, activeKeystoneLevel, affixName, time())
	end

	if event == "CHALLENGE_MODE_COMPLETED" then
		if MPT.currentRun then
			local _, _, time, onTime, _, _, _, _, _, _, _, _, _ = C_ChallengeMode.GetCompletionInfo()
			FinalizeRun(true, onTime, time)
		end
	end

	-- Handle Abandoned runs,
	if event == "CHALLENGE_MODE_RESET" or event == "PLAYER_LEAVING_WORLD" then
		if MPT.currentRun and not IsInGroup() then
			MPT.currentRun.abandoned = true
			FinalizeRun(false, "N/A", time())
			-- Reset current run
			MPT.currentRun = nil
			MPT.runActive = false
		end
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

---------------------------------------------------
--- Slash CMD
---------------------------------------------------
SLASH_MPTTRACKER1 = "/mpt"
SlashCmdList["MPTTRACKER"] = function()
	local statsMsg = "M+ Runs started: " .. MPT.DB_GLOBAL.started .. "\n"
	statsMsg = statsMsg .. "Completed: " .. MPT.DB_GLOBAL.completed.inTime .. " in time, "
	statsMsg = statsMsg .. MPT.DB_GLOBAL.completed.overTime .. " over time.\n"
	statsMsg = statsMsg .. "Incomplete: " .. MPT.DB_GLOBAL.incomplete

	PrintToChat(statsMsg, 4)
end
