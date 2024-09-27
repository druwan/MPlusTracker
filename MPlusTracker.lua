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
function MPT.OnEvent(self, event, ...)
  if event == "ADDON_LOADED" then
    OnAddonLoaded(...)
  elseif event == "PLAYER_LOGOUT" then
    OnPlayerLogout()
    -- Start a new M+ run
  elseif event == "CHALLENGE_MODE_START" then
    local mapChallengeModeID = C_ChallengeMode.GetActiveChallengeMapID()
    if mapChallengeModeID then
      local activeKeystoneLevel = select(1, C_ChallengeMode.GetActiveKeystoneInfo())
      local name, _, _ = C_ChallengeMode.GetMapUIInfo(mapChallengeModeID)
      local startTime = time()

      MPT.currentRun = {
        mapName = name,
        level = activeKeystoneLevel,
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
      print("Mythic+ started: " .. name .. " (Level: " .. activeKeystoneLevel .. ")")
    end

    -- Complete M+
  elseif event == "CHALLENGE_MODE_COMPLETED" then
    if MPT.currentRun then
      local _, _, time, onTime, _, _, _, _, _, _, primaryAffix, _, _ = C_ChallengeMode.GetCompletionInfo()
      local name = select(1, C_ChallengeMode.GetAffixInfo(primaryAffix))

      MPT.currentRun.completionTime = time
      MPT.currentRun.primaryAffix = name
      table.insert(MPT.DB.runs, MPT.currentRun)
      MPT.currentRun = nil

      if onTime then
        MPT.DB.completed.inTime = MPT.DB.completed.inTime + 1
      else
        MPT.DB.completed.overTime = MPT.DB.completed.overTime + 1
      end
    end

    -- Handle Abandoned runs,
  elseif event == "CHALLENGE_MODE_RESET" or event == "PLAYER_LEAVING_WORLD" then
    if MPT.currentRun and not MPT.isReloading then
      MPT.currentRun.abandoned = true
      table.insert(MPT.DB.runs, MPT.currentRun)
      MPT.DB.incomplete = MPT.DB.incomplete + 1
      MPT.currentRun = nil
    end
  end
end

-- Register events
eventFrame:SetScript("OnEvent", MPT.OnEvent)
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
eventFrame:RegisterEvent("CHALLENGE_MODE_RESET")
eventFrame:RegisterEvent("CHALLENGE_MODE_START")
eventFrame:RegisterEvent("PLAYER_LEAVING_WORLD")

-- Slash command to display stats
SLASH_MPTRACKER1 = "/mpt"
SlashCmdList["MPT"] = function()
  print("M+ Runs: " .. MPT.DB.started)
  print("Completed: " .. MPT.DB.completed)
  print("Incomplete: " .. MPT.DB.incomplete)
end

-- CSV Export function
function MPT.ExportToCSV()
  local csvData = "Timestamp,Dungeon,Key,Party,Completed\n"

  for _, run in ipairs(MPT.DB.runs) do
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
    editBox:SetText(csvData)
    editBox:HighlightText()
    scrollFrame:SetScrollChild(editBox)
  end
  exportFrame.editBox:SetText(csvData)
  exportFrame:Show()
end

-- Slash cmd to export data as CSV
SLASH_MPTRACKEREXPORT1 = "/mptexport"
SlashCmdList["MPTRACKEREXPORT"] = function()
  local csvData = MPT.ExportToCSV()
  ShowExportUI(csvData)
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
  local text = "started runs: " .. MPT.DB.started .. "\n"
  text = text .. "Completed: " .. MPT.DB.completed .. "\n"
  text = text .. "Incomplete: " .. MPT.DB.incomplete .. "\n\n"
  text = text .. "Recent Runs:\n"

  for i = math.max(1, #MPT.DB.runs - 5), #MPT.DB.runs do
    local run = MPT.DB.runs[i]
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
    MPT.UpdateUI()
    frame:Show()
  end
end
