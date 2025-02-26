local MPT = _G.MPT

function MPT:InitializeDB()
  MPT.DB = MPT_DB or {
    completed = { inTime = 0, overTime = 0 },
    incomplete = 0,
    runs = {},
    started = 0,
    unsyncedRuns = {} -- Runs awaiting sync
  }
  MPT.DB_GLOBAL = MPT_DB_GLOBAL or {
    completed = { inTime = 0, overTime = 0 },
    started = 0,
  }
  MPT_DB = MPT.DB
  MPT_DB_GLOBAL = MPT.DB_GLOBAL
end

function MPT:UpdateGlobalStats()
  MPT.DB_GLOBAL.started = MPT.DB_GLOBAL.started + MPT.DB.started
  MPT.DB_GLOBAL.completed.inTime = MPT.DB_GLOBAL.completed.inTime + MPT.DB.completed.inTime
  MPT.DB_GLOBAL.completed.overTime = MPT.DB_GLOBAL.completed.overTime + MPT.DB.completed.overTime

  MPT.DB.started = 0
  MPT.DB.completed.inTime = 0
  MPT.DB.completed.overTime = 0
  MPT.DB.incomplete = 0

  MPT:SyncUnsyncedRuns()
  MPT:Print("Global Stats Updated")
  MPT:UpdateUI()
end

function MPT:InitRun(mapName, keyLvl, affix, startTime)
  if MPT.runActive then return end
  MPT.runActive = true
  MPT.currentRun = {
    char = GetUnitName("player", true),
    mapName = mapName,
    keyLvl = keyLvl,
    affix = affix,
    startTime = date("%Y-%m-%d %H:%M:%S", startTime),
    tank = nil,
    healer = nil,
    dps1 = nil,
    dps2 = nil,
    dps3 = nil,
  }
  local dpsCnt = 0
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
        specName = MPT:Print("Inspecting: " .. name)
        MPT:RequestInspect(unit, name)
      end
      local member = {
        name = name .. (UnitIsUnit(unit, "player") or ""),
        role = role,
        class = class,
        spec = specName
      }
      if role == "TANK" then
        MPT.currentRun.tank = member
      elseif role == "HEALER" then
        MPT.currentRun.healer = member
      elseif role == "DAMAGER" then
        dpsCnt = dpsCnt + 1
        if dpsCnt == 1 then
          MPT.currentRun.dps1 = member
        elseif dpsCnt == 2 then
          MPT.currentRun.dps2 = member
        elseif dpsCnt == 3 then
          MPT.currentRun.dps3 = member
        end
      end
    end
  end
  MPT.DB.started = MPT.db.started + 1
  MPT.DB_GLOBAL.started = MPT.DB_GLOBAL.started + 1
  MPT:Print("M+ started: " .. startTime .. " " .. mapName .. " (Level: " .. keyLvl .. ")")
end

function MPT:FinalizeRun(isCompleted, onTime, completionTime, keystoneUpgradeLevels, oldScore, newScore, numDeaths,
                         timeLost)
  if not MPT.currentRun then return end
  MPT.currentRun.completed = isCompleted
  MPT.currentRun.completionTime = completionTime
  MPT.currentRun.keystoneUpgradeLevels = keystoneUpgradeLevels or 0
  MPT.currentRun.oldOverallDungeonScore = oldScore or 0
  MPT.currentRun.newOverallDungeonScore = newScore or 0
  MPT.currentRun.numDeaths = numDeaths or 0
  MPT.currentRun.timeLost = timeLost or 0
  table.insert(MPT.DB.runs, MPT.currentRun)
  table.insert(MPT.DB.unsyncedRuns, MPT.currentRun)
  if isCompleted then
    if onTime then
      MPT.DB.completed.inTime = MPT.DB.completed.inTime + 1
      MPT.DB_GLOBAL.completed.inTime = MPT.DB_GLOBAL.completed.inTime + 1
    else
      MPT.DB.completed.overTime = MPT.DB.completed.overTime + 1
      MPT.DB_GLOBAL.completed.overTime = MPT.DB_GLOBAL.completed.overTime + 1
    end
  else
    MPT.DB.incomplete = MPT.DB.incomplete + 1
  end
  MPT:SyncUnsyncedRuns()
  MPT.currentRun = nil
  MPT.runActive = false
  MPT:UpdateUI()
end

function MPT:SyncUnsyncedRuns()
  if #MPT.DB.unsyncedRuns == 0 then return end
  for i = #MPT.DB.unsyncedRuns, 1, -1 do
    local run = MPT.DB.unsyncedRuns[i]
    if MPT.WriteRunToFile(run) then
      table.remove(MPT.DB.unsyncedRuns, i)
      MPT.Print("Queued run for sync: " .. run.mapName .. " " .. run.keyLevel)
    else
      MPT.Print("faile to queue run: " .. run.mapName .. " " .. run.keyLevel)
    end
  end
end
