local MPT = _G.MPT

function MPT:InitializeDB()
  MPT.DB = MPT_DB or {
    runs = {},
    unsyncedRuns = {} -- Runs awaiting sync
  }
  MPT.DB_GLOBAL = MPT_DB_GLOBAL or {
    started = 0,
    completed = {
      inTime = 0,
      overTime = 0
    }
  }
  MPT_DB = MPT.DB
  MPT_DB_GLOBAL = MPT.DB_GLOBAL
end

function MPT:UpdateGlobalStats()
  local runs = MPT.DB.runs
  MPT.DB_GLOBAL.started = MPT.DB_GLOBAL.started + #runs
  MPT.DB_GLOBAL.completed.inTime = MPT.DB_GLOBAL.completed.inTime +
  #MPT:tFilter(runs, function(run) return run.completed and run.onTime end)
  MPT.DB_GLOBAL.completed.overTime = MPT.DB_GLOBAL.completed.overTime +
  #MPT:tFilter(runs, function(run) return run.completed and not run.onTime end)
  print("Global Stats Updated")
  MPT:UpdateUI()
end

function MPT:tFilter(tbl, predicate)
  local res = {}
  for _, v in ipairs(tbl) do
    if predicate(v) then
      table.insert(res, v)
    end
  end
  return res
end

function MPT:InitRun(mapName, keyLvl, affixIDs, startTime)
  if MPT.runActive then
    print("[MPT Debug] Run already active, cannot start new run:", mapName, keyLvl)
    return
  end
  print("[MPT Debug] Initializing new run:", mapName, keyLvl, startTime)
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
  print(mapName .. " " .. keyLvl .. " started " .. startTime)
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
