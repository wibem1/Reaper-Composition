-- @description Composition Studio Startup
-- @version 0.1
-- @author Klangwerke
-- @about Starts Composition Studio at REAPER launch only when it was left open in the previous session.

local EXT_SECTION = "CompositionStudio"
local STATE_KEY = "WindowOpen"
local SCRIPT_RELATIVE = "/Scripts/Composition Studio/Composition Studio.lua"

-- Only restore Composition Studio when the previous REAPER session ended
-- while its window was still open.
if reaper.GetExtState(EXT_SECTION, STATE_KEY) ~= "1" then
  return
end

local script_path = reaper.GetResourcePath() .. SCRIPT_RELATIVE
local command_id = reaper.AddRemoveReaScript(true, 0, script_path, true)
if command_id and command_id > 0 then
  reaper.Main_OnCommand(command_id, 0)
end
