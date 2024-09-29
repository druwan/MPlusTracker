-- Addon namespace
local MPT = _G.MPT or {}
_G.MPT = MPT
local eventFrame = CreateFrame("Frame")

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

MPT.DB = MPT_DB


-- Init a new run
local function InitRun(mapName, keyLevel, affixNames, startTime)
  MPT.currentRun = {
    mapName = mapName,
    level = keyLevel,
    affixNames = affixNames,
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
local function FinalizeRun(isCompleted, onTime, completionTime)
  if MPT.currentRun then
    MPT.currentRun.completed = isCompleted
    MPT.currentRun.completionTime = completionTime

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


-- Event handler for m+ tracking
function MPT.OnEvent(_, event, ...)
  local dungeonName, affixName, affixIDs, activeKeystoneLevel

  if event == "CHALLENGE_MODE_START" then
    dungeonName = C_ChallengeMode.GetMapUIInfo(C_ChallengeMode.GetActiveChallengeMapID())
    activeKeystoneLevel, affixIDs, _ = C_ChallengeMode.GetActiveKeystoneInfo()
    affixName = select(1, C_ChallengeMode.GetAffixInfo(affixIDs[1]))
    InitRun(dungeonName, activeKeystoneLevel, affixName, time())
  end

  if event == "CHALLENGE_MODE_COMPLETED" then
    if MPT.currentRun then
      local _, _, time, onTime, _, _, _, _, _, _, _, _, _ = C_ChallengeMode.GetCompletionInfo()
      FinalizeRun(true, onTime, time)
    end
    -- Handle Abandoned runs,
  elseif event == "CHALLENGE_MODE_RESET" or event == "PLAYER_LEAVING_WORLD" then
    if MPT.currentRun then
      if not IsInGroup() then
        MPT.currentRun.abandoned = true
        FinalizeRun(false, 'N/A', time())
        MPT.currentRun = nil
      end
    end
  end
end

-- Register events
local events = {
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
SlashCmdList["MPTTRACKER"] = function()
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

function MPT.UpdateUI()
  frame.stats:SetText(BuildStatsText())
end

SLASH_MPTTRACKERUI1 = "/mptui"
SlashCmdList["MPTTRACKERUI"] = function()
  if frame:IsShown() then
    frame:Hide()
  else
    MPT.UpdateUI()
    frame:Show()
  end
end
