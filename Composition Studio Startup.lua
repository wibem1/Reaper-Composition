-- @description Composition Studio Startup
-- @version 0.2
-- @author Klangwerke
-- @about Restores Composition Studio at REAPER launch only when it was left open.

local EXT_SECTION = "CompositionStudio"
local STATE_KEY = "WindowOpen"
local ACTION_NAME = "Script: Composition Studio.lua"

-- Nur wiederherstellen, wenn Composition Studio beim letzten Beenden
-- von REAPER noch geöffnet war.
if reaper.GetExtState(EXT_SECTION, STATE_KEY) ~= "1" then
  return
end

-- Composition Studio ist bereits als ReaScript in REAPER registriert.
-- Deshalb registrieren wir es hier NICHT erneut. Stattdessen suchen wir
-- seine vorhandene Action-ID und starten genau diese Action.
local command_id = nil

if type(reaper.CF_EnumerateActions) == "function" then
  local index = 0
  while true do
    local id, name = reaper.CF_EnumerateActions(0, index, "")
    if not id or id <= 0 then break end
    if name == ACTION_NAME then
      command_id = id
      break
    end
    index = index + 1
  end
end

if command_id and command_id > 0 then
  reaper.Main_OnCommand(command_id, 0)
else
  reaper.ShowConsoleMsg("Composition Studio Startup: Action '" .. ACTION_NAME .. "' wurde nicht gefunden.\n")
end
