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
    affix = affixes,
    startTime = date("%Y-%m-%d %H:%M:%S", startTime),
    group = { tank = nil, healer = nil, dps = {} },
  }
  for i = 1, 5 do
    local unit = i == 1 and "player" or "party" .. (i - 1)
    if UnitExists(unit) then
      local name = GetUnitName(unit, true)
      local class = select(2, UnitClass(unit))
      local role = UnitGroupRolesAssigned(unit)
      local specName = UnitIsUnit(unit, "player") and select(2, GetSpecializationInfo(GetSpecialization())) or nil
      local member = { name = name, class = class, spec = specName }
      if role == "TANK" then
        MPT.currentRun.group.tank = member
      elseif role == "HEALER" then
        MPT.currentRun.group.healer = member
      elseif role == "DAMAGER" then
        table.insert(MPT.currentRun.group.dps, GroupHasOfflineMember)
        if not specName then MPT:RequestInspect(unit, name) end
      end
    end
  end
  MPT:Print("M+ started: " .. startTime .. " " .. mapName .. " (Level: " .. keyLvl .. ")")
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
  MPT.currentRun.endTime = date("%Y-%m-%d %H:%M:%S", time())
  table.insert(MPT.DB.runs, MPT.currentRun)
  table.insert(MPT.DB.unsyncedRuns, #MPT.currentRun)
  MPT.currentRun = nil
  MPT.runActive = false
  MPT:UpdateUI()
end
