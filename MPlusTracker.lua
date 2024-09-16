-- Addon namespace
local MPlusTracker = {}
local eventFrame = CreateFrame("Frame")
local mplusIsActive = false
local currRun = {}


-- Default values for the database
MPlusTrackerDB = MPlusTrackerDB or {
  total = 0,
  completed = 0,
  incomplete = 0,
  runs = {},
}

-- Utility to get player role
local function GetPlayerRole(name)
  local role = UnitGroupRolesAssigned(name)
  return role ~= "NONE" and role or 'UNKNOWN'
end

-- Gather Party info (name, class, spec & role)
local function GatherPartyInfo()
  local partyInfo = {}
  for i = 1, 5 do
    local unit = (i == 5 and "player") or ("party" .. i)
    if UnitExists(unit) then
      local name = UnitName(unit)
      local _, class = UnitClass(unit)
      local role = GetPlayerRole(unit)
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
local function StartRun()
  local mapID, level = C_ChallengeMode.GetActiveChallengeMapID(), C_ChallengeMode.GetActiveKeystoneInfo()
  local dungeonName = mapID and C_ChallengeMode.GetMapUIInfo(mapID) or "Unknown Dungeon"

  currRun = {
    dungeon = dungeonName,
    keyLevel = level,
    party = GatherPartyInfo(),
    completed = false,
    timestamp = time()
  }

  MPlusTrackerDB.total = MPlusTrackerDB.total + 1
  mplusIsActive = true

  print("Mythic+ started: " .. dungeonName .. " (Level: " .. level .. ")")
end

-- Complete curr m+ run
local function CompleteRun()
  if mplusIsActive then
    currRun.completed = true
    MPlusTrackerDB.completed = MPlusTrackerDB.completed + 1
    table.insert(MPlusTrackerDB.runs, currRun)

    print("M+ completed")
    mplusIsActive = false
    currRun = {}
  end
end

-- Mark runs incomplete
local function MarkRunIncomplete(reason)
  if mplusIsActive then
    currRun.completed = false
    MPlusTrackerDB.incomplete = MPlusTrackerDB.incomplete + 1
    table.insert(MPlusTrackerDB.runs, currRun)

    print("M+ incomplete")
    mplusIsActive = false
    currRun = {}
  end
end


-- Event handler for m+ tracking
local function OnEvent(self, event, ...)
  if event == "CHALLENGE_MODE_START" then
    StartRun()
  elseif event == "CHALLENGE_MODE_COMPLETED" then
    CompleteRun()
  elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
    -- Detect if player left dungeon without completing
    if mplusIsActive then
      local isInInstance, instanceType = IsInInstance()
      if not C_ChallengeMode.IsChallengeModeActive() and (not isInInstance or instanceType ~= "party") then
        MarkRunIncomplete("Player left the dungeon.")
      end
    end
  elseif event == "GROUP_ROSTER_UPDATE" then
    if mplusIsActive and GetNumGroupMembers() < #currRun.party then
      MarkRunIncomplete("Party member left the dungeon.")
    end
  end
end

-- Register events
eventFrame:SetScript("OnEvent", OnEvent)
eventFrame:RegisterEvent("CHALLENGE_MODE_START")
eventFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")

-- Slash command to display stats
SLASH_MPTRACKER1 = "/mpt"
SlashCmdList["MPT"] = function()
  print("M+ Runs: " .. MPlusTrackerDB.total)
  print("Completed: " .. MPlusTrackerDB.completed)
  print("Incomplete: " .. MPlusTrackerDB.incomplete)
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

local function UpdateUI()
  local text = "Total runs: " .. MPlusTrackerDB.total .. "\n"
  text = text .. "Completed: " .. MPlusTrackerDB.completed .. "\n"
  text = text .. "Incomplete: " .. MPlusTrackerDB.incomplete .. "\n\n"
  text = text .. "Recent Runs:\n"

  for i = math.max(1, #MPlusTrackerDB.runs - 5), #MPlusTrackerDB.runs do
    local run = MPlusTrackerDB.runs[i]
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
    UpdateUI()
    frame:Show()
  end
end
