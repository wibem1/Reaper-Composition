-- Reaper Composition - Diagnose
-- Development action: verifies that REAPER is loading this project directly.
-- No external dependencies, no file writes, no project modifications.

local VERSION = "0.1.0-dev"

local function msg(text)
  reaper.ShowMessageBox(text, "Reaper Composition", 0)
end

local resource_path = reaper.GetResourcePath()
local project, project_path = reaper.EnumProjects(-1, "")
local track_count = reaper.CountTracks(project)
local selected_tracks = reaper.CountSelectedTracks(project)
local selected_items = reaper.CountSelectedMediaItems(project)

local lines = {
  "Reaper Composition " .. VERSION,
  "",
  "ReaScript läuft direkt in REAPER.",
  "Keine Kompilation erforderlich.",
  "",
  "REAPER-Ressourcenordner:",
  resource_path,
  "",
  "Projekt: " .. ((project_path ~= "" and project_path) or "noch nicht gespeichert"),
  "Spuren: " .. tostring(track_count),
  "Ausgewählte Spuren: " .. tostring(selected_tracks),
  "Ausgewählte Items: " .. tostring(selected_items),
  "",
  "Status: Grundverbindung funktioniert."
}

msg(table.concat(lines, "\n"))
