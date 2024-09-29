-- Addon namespace
local MPT = _G.MPT or {}
_G.MPT = MPT
local eventFrame = CreateFrame("Frame")
local GetAddOnMetadata = C_AddOns.GetAddOnMetadata
local Name, _ = ...


-- Default values for the database
MPT.DB = MPT.DB or {
  completed = {
    inTime = 0,
    overTime = 0,
  },
  incomplete = 0,
  runs = {},
  started = 0,
}


-- Helper functions

-- Init a new run
local function InitRun(mapName, keyLevel, startTime)
  MPT.currentRun = {
    mapName = mapName,
    level = keyLevel,
    startTime = date("%Y-%m-%d %H:%M:%S", startTime),
    party = {}
  }

  for i = 1, 5 do
    local name, _, _, _, class, _, _, _, _, _, _, combatRole = GetRaidRosterInfo(i)
    if name then
      table.insert(MPT.currentRun.party, { name = name, class = class, combatRole = combatRole })
    end
  end

  MPT.DB.started = MPT.DB.started + 1
  print("Mythic+ started: " .. mapName .. " (Level: " .. keyLevel .. ")")
end

-- Finalize a run, either completed or incomplete
local function FinalizeRun(isCompleted, onTime, completionTime, affixName)
  if MPT.currentRun then
    MPT.currentRun.completed = isCompleted
    MPT.currentRun.completionTime = completionTime
    MPT.currentRun.primaryAffix = affixName

    table.insert(MPT.DB.runs, MPT.currentRun)
    MPT.currentRun = nil

    if isCompleted then
      if onTime then
        MPT.DB.completed.inTime = MPT.DB.completed.inTime + 1
      else
        MPT.DB.completed.overTime = MPT.DB.completed.overTime + 1
      end
    else
      MPT.DB.incomplete = MPT.DB.incomplete + 1
    end
  end
end

-- Event handlers
local function OnAddonLoaded(addonName)
  if addonName == GetAddOnMetadata(Name, 'X-Title') then
    MPT.isReloading = false
    -- Check if there was an active run not marked as completed or abandoned
    if MPT.currentRun and not MPT.currentRun.completed and not MPT.currentRun.abandoned then
      -- Run was still active before the reload, do not count as abandoned
      -- Do nothing, as it's a reload
    end
  end
end

local function OnPlayerLogout()
  MPT.isReloading = true
end

-- Event handler for m+ tracking
function MPT.OnEvent(event, ...)
  if event == "ADDON_LOADED" then
    OnAddonLoaded(...)
  elseif event == "PLAYER_LOGOUT" then
    OnPlayerLogout()
  elseif event == "CHALLENGE_MODE_START" then
    local mapChallengeModeID = C_ChallengeMode.GetActiveChallengeMapID()
    if mapChallengeModeID then
      local activeKeystoneLevel = select(1, C_ChallengeMode.GetActiveKeystoneInfo())
      local name, _, _ = C_ChallengeMode.GetMapUIInfo(mapChallengeModeID)
      InitRun(name, activeKeystoneLevel, time())
    end
  elseif event == "CHALLENGE_MODE_COMPLETED" then
    if MPT.currentRun then
      local _, _, time, onTime, _, _, _, _, _, _, primaryAffix, _, _ = C_ChallengeMode.GetCompletionInfo()
      local name = select(1, C_ChallengeMode.GetAffixInfo(primaryAffix))
      FinalizeRun(true, onTime, time, name)
    end

    -- Handle Abandoned runs,
  elseif event == "CHALLENGE_MODE_RESET" or event == "PLAYER_LEAVING_WORLD" then
    if MPT.currentRun and not MPT.isReloading then
      MPT.currentRun.abandoned = true
      FinalizeRun(false, 'N/A', time(),
        select(1, C_ChallengeMode.GetAffixInfo(select(2, C_ChallengeMode.GetActiveKeystoneInfo()))))

      MPT.currentRun = nil
    end
  end
end

-- Register events
local events = {
  "ADDON_LOADED",
  "PLAYER_LOGOUT",
  "CHALLENGE_MODE_COMPLETED",
  "CHALLENGE_MODE_RESET",
  "CHALLENGE_MODE_START",
  "PLAYER_LEAVING_WORLD"
}

for _, e in pairs(events) do
  eventFrame:RegisterEvent(e)
end
eventFrame:SetScript("OnEvent", MPT.OnEvent)

-- Slash command to display stats
SLASH_MPTTRACKER1 = "/mpt"
SlashCmdList["MPT"] = function()
  print("M+ Runs started: " .. MPT.DB.started)
  print("Completed: " .. MPT.DB.completed.inTime .. " in time, " .. MPT.DB.completed.overTime .. " over time.")
  print("Incomplete: " .. MPT.DB.incomplete)
end

-- CSV Export function
local function BuildCSVData()
  local csvData = "Timestamp,Dungeon,Key,Party,Completed\n"
  for _, run in ipairs(MPT.DB.runs) do
    local party = {}
    for _, member in ipairs(run.party) do
      table.insert(party, member.name .. " (" .. member.class .. " - " .. member.combatRole .. ")")
    end
    csvData = csvData .. string.format("%s,%s,%d,\"%s\",%s\n",
      run.startTime, run.mapName, run.level, table.concat(party, "; "), tostring(run.completed))
  end
  return csvData
end

function MPT.ExportToCSV()
  return BuildCSVData()
end

-- Simple UI to display CSV
local exportFrame
local function ShowExportUI(csvData)
  if not exportFrame then
    exportFrame = CreateFrame("Frame", "MPlusExportFrame", UIParent, "BasicFrameTemplateWithInset")
    exportFrame:SetSize(400, 300)
    exportFrame:SetPoint("CENTER")

    local scrollFrame = CreateFrame("ScrollFrame", nil, exportFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(400, 300)
    scrollFrame:SetPoint("TOP", exportFrame, "TOP", 0, -30)

    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetFontObject("ChatFontNormal")
    editBox:SetWidth(360)
    scrollFrame:SetScrollChild(editBox)
    exportFrame.editBox = editBox
  end
  exportFrame.editBox:SetText(csvData)
  exportFrame:Show()
end

-- Slash cmd to export data as CSV
SLASH_MPTTRACKEREXPORT1 = "/mptexport"
SlashCmdList["MPTTRACKEREXPORT"] = function()
  local csvData = MPT.ExportToCSV()
  ShowExportUI(csvData)
end

-- UI Function
local function BuildStatsText()
  local text = string.format(
    "Started runs: %d\nCompleted (in time/over time): %d / %d\nIncomplete: %d\n\nRecent Runs:\n", MPT.DB.started,
    MPT.DB.completed.inTime, MPT.DB.completed.overTime, MPT.DB.incomplete)

  for i = math.max(1, #MPT.DB.runs - 5), #MPT.DB.runs do
    local run = MPT.DB.runs[i]
    local status = run.completed and "Completed" or "Incomplete"
    text = text .. string.format("- %s (+%d) - %s\n", run.mapName, run.level, status)
  end
  return text
end

function MPT.UpdateUI(frame)
  frame.stats:SetText(BuildStatsText())
end

-- Simple UI
local frame = CreateFrame("Frame", "MPTFrame", UIParent, "BasicFrameTemplateWithInset")
frame:SetSize(300, 400) -- Width, Height
frame:SetPoint("CENTER")
frame:Hide()

frame.title = frame:CreateFontString(nil, "OVERLAY")
frame.title:SetFontObject("GameFontHighlightLarge")
frame.title:SetPoint("TOP", frame, "TOP", 0, -10)
frame.title:SetText("M+ Tracker")

frame.stats = frame:CreateFontString(nil, "OVERLAY")
frame.stats:SetFontObject("GameFontHighlight")
frame.stats:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -40)
frame.stats:SetJustifyH("LEFT")

SLASH_MPTTRACKERUI1 = "/mptui"
SlashCmdList["MPTTRACKERUI"] = function()
  if frame:IsShown() then
    frame:Hide()
  else
    MPT.UpdateUI()
    frame:Show()
  end
end
