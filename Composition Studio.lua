-- @description Composition Studio Basic
-- @version 0.1-dev
-- @author Klangwerke
-- @about
--   Technical foundation for recursive AI composition directly inside REAPER.
--   Composition Lab is not part of the runtime architecture.

local SCRIPT_NAME = "Composition Studio Basic"
local VERSION = "0.1-dev"

local function selected_midi_items()
  local result = {}
  local count = reaper.CountSelectedMediaItems(0)
  for i = 0, count - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    local take = item and reaper.GetActiveTake(item)
    if take and reaper.TakeIsMIDI(take) then
      local track = reaper.GetMediaItem_Track(item)
      local _, track_name = reaper.GetTrackName(track)
      local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
      local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
      local _, note_count, cc_count, text_count = reaper.MIDI_CountEvts(take)
      result[#result + 1] = {
        item = item,
        take = take,
        track = track,
        track_name = track_name ~= "" and track_name or "Unbenannte Spur",
        position = pos,
        length = len,
        notes = note_count or 0,
        cc = cc_count or 0,
        text = text_count or 0
      }
    end
  end
  return result
end

local function describe(items)
  if #items == 0 then
    return "Keine ausgewählten MIDI-Items.\n\nWähle in REAPER ein oder mehrere MIDI-Items aus und starte Composition Studio erneut."
  end
  local lines = {"Ausgewählte MIDI-Items: " .. #items, ""}
  for i, v in ipairs(items) do
    lines[#lines + 1] = string.format(
      "%d. %s  |  Start %.2f s  |  Länge %.2f s  |  %d Noten",
      i, v.track_name, v.position, v.length, v.notes)
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = "Basic V0.1: REAPER-Auswahl wird direkt erkannt."
  lines[#lines + 1] = "Nächster Kernschritt: musikalische MIDI-Daten + freier KI-Auftrag."
  return table.concat(lines, "\n")
end

local items = selected_midi_items()
reaper.ShowMessageBox(describe(items), SCRIPT_NAME .. "  " .. VERSION, 0)
