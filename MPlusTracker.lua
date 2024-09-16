-- Addon namespace
local MPlusTracker = {}
local eventFrame = CreateFrame("Frame")
local mplusIsActive = false
local currRun = {}


-- Saved vars
MPlusTrackerDB = MPlusTrackerDB or {
  total = 0,
  completed = 0,
  incomplete = 0,
  runs = {},
}

-- Determine Party member Info
local function GetPlayerRole(name)
  local role = UnitGroupRolesAssigned(name)
  return role or 'NONE'
end

-- Gather Party info
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

-- Event handler for detecting m+ start or end
eventFrame:SetScript("OnEvent", function(self, event, ...)
  if event == "CHALLENGE_MODE_START" then
    mplusIsActive = true
    local mapID, level = C_ChallengeMode.GetActiveChallengeMapID(), C_ChallengeMode.GetActiveKeystoneInfo()
    local mapName = C_ChallengeMode.GetMapUIInfo(mapID)

    MPlusTrackerDB.total = MPlusTrackerDB.total + 1
    currRun = {
      dungeon = mapName,
      keyLevel = level,
      party = GatherPartyInfo(),
      completed = false,
      timestamp = time()
    }
    print("Mythic+ started: " .. mapName .. " (Level: " .. level .. ")")
  elseif event == "CHALLENGE_MODE_COMPLETED" then
    if mplusIsActive then
      MPlusTrackerDB.completed = MPlusTrackerDB.completed + 1
      currRun.completed = true
      table.insert(MPlusTrackerDB.runs, currRun)
      print("M+ completed")
      mplusIsActive = false
    end
  elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
    -- Detect if left without completing
    if mplusIsActive then
      local isInInstance, instanceType = IsInInstance()

      if not C_ChallengeMode.IsChallengeModeActive() and (not isInInstance or instanceType ~= "party") then
        MPlusTrackerDB.incomplete = MPlusTrackerDB.incomplete + 1
        currRun.completed = false
        table.insert(MPlusTrackerDB.runs, currRun)
        print("M+ incomplete")
        mplusIsActive = false
      end
    end
  elseif event == "GROUP_ROSTER_UPDATE" then
    if mplusIsActive then
      local numGroupMembers = GetNumGroupMembers()
      if numGroupMembers < #currRun.party then
        MPlusTrackerDB.incomplete = MPlusTrackerDB.incomplete + 1
        currRun.completed = false
        table.insert(MPlusTrackerDB.runs, currRun)
        print("A player left, m+ marked as incomplete")
        mplusIsActive = false
      end
    end
  end
end)

eventFrame:RegisterEvent("CHALLENGE_MODE_START")
eventFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")

-- Slash cmds
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
