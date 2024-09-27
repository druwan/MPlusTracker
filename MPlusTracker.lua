-- Addon namespace
local MPlusTracker = {}
local eventFrame = CreateFrame("Frame")
local mplusIsActive = false
local currRun = {}


-- Default values for the database
MPlusTracker.DB = MPlusTracker.DB or {
  total = 0,
  completed = 0,
  incomplete = 0,
  runs = {},
}

-- Utility to get player role
function MPlusTracker.GetPlayerRole(name)
  local role = UnitGroupRolesAssigned(name)
  return role ~= "NONE" and role or 'UNKNOWN'
end

-- Gather Party info (name, class, spec & role)
function MPlusTracker.GatherPartyInfo()
  local partyInfo = {}
  for i = 1, 5 do
    local unit = (i == 5 and "player") or ("party" .. i)
    if UnitExists(unit) then
      local name = UnitName(unit)
      local _, class = UnitClass(unit)
      local role = MPlusTracker.GetPlayerRole(unit)
      local specID = GetInspectSpecialization(unit)
      local specName = specID and select(2, GetSpecializationInfoByID(specID)) or "Unknown"

      table.insert(partyInfo, {
        name = name,
        class = class,
        spec = specName,
        role = role
      })
    end
  end
  return partyInfo
end

-- Start a new M+ run
function MPlusTracker.StartRun()
  local mapID, level = C_ChallengeMode.GetActiveChallengeMapID(), C_ChallengeMode.GetActiveKeystoneInfo()
  local dungeonName = mapID and C_ChallengeMode.GetMapUIInfo(mapID) or "Unknown Dungeon"

  currRun = {
    dungeon = dungeonName,
    keyLevel = level,
    party = MPlusTracker.GatherPartyInfo(),
    completed = false,
    timestamp = time()
  }

  MPlusTracker.DB.total = MPlusTracker.DB.total + 1
  mplusIsActive = true

  print("Mythic+ started: " .. dungeonName .. " (Level: " .. level .. ")")
end

-- Complete curr m+ run
function MPlusTracker.CompleteRun()
  if mplusIsActive then
    currRun.completed = true
    MPlusTracker.DB.completed = MPlusTracker.DB.completed + 1
    table.insert(MPlusTracker.DB.runs, currRun)

    print("M+ completed")
    mplusIsActive = false
    currRun = {}
  end
end

-- Mark runs incomplete
function MPlusTracker.MarkRunIncomplete(reason)
  if mplusIsActive then
    currRun.completed = false
    MPlusTracker.DB.incomplete = MPlusTracker.DB.incomplete + 1
    table.insert(MPlusTracker.DB.runs, currRun)

    print("M+ incomplete")
    mplusIsActive = false
    currRun = {}
  end
end

-- Event handler for m+ tracking
function MPlusTracker.OnEvent(self, event, ...)
  if event == "CHALLENGE_MODE_START" then
    MPlusTracker.StartRun()
  elseif event == "CHALLENGE_MODE_COMPLETED" then
    MPlusTracker.CompleteRun()
  elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
    -- Detect if player left dungeon without completing
    if mplusIsActive then
      local isInInstance, instanceType = IsInInstance()
      if not C_ChallengeMode.IsChallengeModeActive() and (not isInInstance or instanceType ~= "party") then
        MPlusTracker.MarkRunIncomplete("Player left the dungeon.")
      end
    end
  elseif event == "GROUP_ROSTER_UPDATE" then
    if mplusIsActive and GetNumGroupMembers() < #currRun.party then
      MPlusTracker.MarkRunIncomplete("Party member left the dungeon.")
    end
  end
end

-- Register events
eventFrame:SetScript("OnEvent", MPlusTracker.OnEvent)
eventFrame:RegisterEvent("CHALLENGE_MODE_START")
eventFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")

-- Slash command to display stats
SLASH_MPTRACKER1 = "/mpt"
SlashCmdList["MPT"] = function()
  print("M+ Runs: " .. MPlusTracker.DB.total)
  print("Completed: " .. MPlusTracker.DB.completed)
  print("Incomplete: " .. MPlusTracker.DB.incomplete)
end

-- CSV Export function
function MPlusTracker.ExportToCSV()
  local csvData = "Timestamp,Dungeon,Key,Party,Completed\n"

  for _, run in ipairs(MPlusTracker.DB.runs) do
    local partyMembers = {}
    for _, member in ipairs(run.party) do
      table.insert(partyMembers,
        member.name .. " (" .. member.class .. " - " .. member.spec .. " - " .. member.role .. ")")
    end

    csvData = csvData .. string.format(
      "%s,%s,%d,\"%s\",%s\n", run.timestamp, run.dungeon, run.keyLevel, table.concat(partyMembers, "; "),
      tostring(run.completed)
    )
  end
  return csvData
end

-- Simple UI to display CSV
local function ShowExportUI(csvData)
  local exportFrame = CreateFrame("Frame", "MPlusExportFrame", UIParent, "BasicFrameTemplateWithInser")
  exportFrame:SetSize(400, 300)
  exportFrame:SetPoint("CENTER")

  local scrollFrame = CreateFrame("ScrollFrame", nil, exportFrame, "UIPanelScrollFrameTemplate")
  scrollFrame:SetSize(400, 300)
  scrollFrame:SetPoint("TOP", exportFrame, "TOP", 0, -30)

  local editBox = CreateFrame("EditBox", nil, scrollFrame)
  editBox:SetMultiLine(true)
  editBox:SetFontObject("ChatFontNormal")
  editBox:SetWidth(360)
  editBox:SetText(csvData)
  editBox:HighlightText()
  scrollFrame:SetScrollChild(editBox)

  exportFrame:Show()
end

-- Slash cmd to export data as CSV
SLASH_MPTRACKEREXPORT1 = "/mpexport"
SlashCmdList["SLASH_MPTRACKEREXPORT"] = function()
  local csvData = MPlusTracker.ExportToCSV
  ShowExportUI(csvData)
end

-- Simple UI
local frame = CreateFrame("Frame", "MPlusTrackerFrame", UIParent, "BasicFrameTemplateWithInset")
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

function MPlusTracker.UpdateUI()
  local text = "Total runs: " .. MPlusTracker.DB.total .. "\n"
  text = text .. "Completed: " .. MPlusTracker.DB.completed .. "\n"
  text = text .. "Incomplete: " .. MPlusTracker.DB.incomplete .. "\n\n"
  text = text .. "Recent Runs:\n"

  for i = math.max(1, #MPlusTracker.DB.runs - 5), #MPlusTracker.DB.runs do
    local run = MPlusTracker.DB.runs[i]
    local status = run.completed and "Completed" or "Incomplete"
    text = text .. "- " .. run.dungeon .. " (+ " .. run.keyLevel .. ") -" .. status .. "\n"
  end
  frame.stats:SetText(text)
end

SLASH_MPTRACKERUI1 = "/mptui"
SlashCmdList["MPTRACKERUI"] = function()
  if frame:IsShown() then
    frame:Hide()
  else
    MPlusTracker.UpdateUI()
    frame:Show()
  end
end
