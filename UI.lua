local MPT = _G.MPT

MPT.frame = CreateFrame("Frame", "MPTFrame", UIParent, "BasicFrameTemplateWithInset")
MPT.frame:SetSize(300, 200)
MPT.frame:SetPoint("CENTER")
MPT.frame:Hide()

MPT.frame.title = MPT.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
MPT.frame.title:SetPoint("TOP", 0, -5)
MPT.frame.title:SetText("Mythic+ Tracker")

MPT.frame.stats = MPT.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
MPT.frame.stats:SetPoint("TOPLEFT", 10, -30)
MPT.frame.stats:SetJustifyH("LEFT")

MPT.frame.toggle = CreateFrame("Button", nil, MPT.frame, "UIPanelButtonTemplate")
MPT.frame.toggle:SetSize(80, 22)
MPT.frame.toggle:SetPoint("BOTTOM", 0, 10)
MPT.frame.toggle:SetText("Toggle")
MPT.frame.toggle:SetScript("OnClick", function() MPT:ToggleUI() end)

function MPT:UpdateUI()
  if not MPT.frame:IsShown() then return end
  local failed = MPT.DB_GLOBAL.started - (MPT.DB_GLOBAL.completed.inTime + MPT.DB_GLOBAL.completed.overTime)
  local stats = string.format(
    "Runs Started: %d\nCompleted In Time: %d\nCompleted Over Time: %d\nAbandoned: %d\nUnsynced: %d",
    MPT.DB_GLOBAL.started,
    MPT.DB_GLOBAL.completed.inTime,
    MPT.DB_GLOBAL.completed.overTime,
    failed,
    #MPT.DB.unsyncedRuns
  )
  MPT.frame.stats:SetText(stats)
end

function MPT:ToggleUI()
  if MPT.frame:IsShown() then
    MPT.frame:Hide()
  else
    MPT.frame:Show()
    MPT:UpdateUI()
  end
end

SLASH_MPTTRACKER1 = "/mpt"
SlashCmdList["MPTTRACKER"] = function() MPT:ToggleUI() end
