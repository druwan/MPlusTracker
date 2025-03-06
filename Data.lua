local MPT = _G.MPT

function MPT:InitializeDB()
  MPT.DB = MPT_DB or {
    runs = {},
    unsyncedRuns = {} -- Runs awaiting sync
  }
  MPT.DB_GLOBAL = MPT_DB_GLOBAL or {
    totalRuns = 0,
    totalCompleted = 0
  }
  MPT_DB = MPT.DB
  MPT_DB_GLOBAL = MPT.DB_GLOBAL
end

function MPT:UpdateGlobalStats()
  local runs = MPT.DB.runs
  MPT.DB_GLOBAL.totalRuns = MPT.DB_GLOBAL.totalRuns + #runs
  MPT.DB_GLOBAL.totalCompleted = MPT.DB_GLOBAL.totalCompleted +
      #MPT:tFilter(runs, function(run) return run.completed end)
  MPT:Print("Global Stats Updated")
  MPT:UpdateUI()
end

function MPT:InitRun(mapName, keyLvl, affixIDs, startTime)
  if MPT.runActive then return end
  MPT.runActive = true

  local affixes = {}
  for _, id in ipairs(affixIDs) do
    table.insert(affixes, (C_ChallengeMode.GetAffixInfo(id)))
  end

  MPT.currentRun = {
    char = GetUnitName("player", true),
    mapName = mapName,
    keyLvl = keyLvl,
    affixNames = affixes,
    startTime = date("%Y-%m-%d %H:%M:%S", startTime),
    party = {},
  }

  for i = 1, 5 do
    local unit = i == 1 and "player" or "party" .. (i - 1)
    if UnitExists(unit) then
      local name = GetUnitName(unit, true)
      local class = select(2, UnitClass(unit))
      local role = UnitGroupRolesAssigned(unit)
      local specName, specID

      if UnitIsUnit(unit, "player") then
        specID = GetSpecialization()
        specName = specID and select(2, GetSpecializationInfo(specID))
      else
        specName = "Inspecting..."
        MPT:RequestInspect(unit, name)
      end

      local isMe = UnitIsUnit(unit, "player") and "*" or ""

      table.insert(MPT.currentRun.party, {
        name = name .. isMe,
        role = role,
        class = class,
        spec = specName
      })
    end
  end
  MPT:Print(mapName .. " " .. keyLvl .. " started " .. startTime)
end

function MPT:FinalizeRun(isCompleted, onTime, completionTime, keystoneUpgradeLevels, oldScore, newScore, numDeaths,
                         timeLost)
  if not MPT.currentRun then return end
  MPT.currentRun.completed = isCompleted
  MPT.currentRun.onTime = onTime
  MPT.currentRun.completionTime = completionTime
  MPT.currentRun.keystoneUpgradeLevels = keystoneUpgradeLevels or 0
  MPT.currentRun.oldOverallDungeonScore = oldScore or 0
  MPT.currentRun.newOverallDungeonScore = newScore or 0
  MPT.currentRun.numDeaths = numDeaths or 0
  MPT.currentRun.timeLost = timeLost or 0
  table.insert(MPT.DB.runs, MPT.currentRun)
  table.insert(MPT.DB.unsyncedRuns, #MPT.DB.runs)
  MPT.currentRun = nil
  MPT.runActive = false
  MPT:UpdateUI()
end
