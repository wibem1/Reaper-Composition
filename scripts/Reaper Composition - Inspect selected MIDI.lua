-- Reaper Composition - Inspect selected MIDI
-- Phase 1: read one selected MIDI item without modifying the project.

local VERSION = "0.1.1-dev"

local function message(text)
  reaper.ShowMessageBox(text, "Reaper Composition", 0)
end

local project = 0
local selected_count = reaper.CountSelectedMediaItems(project)

if selected_count == 0 then
  message("Kein Item ausgewählt.\n\nBitte ein MIDI-Item auswählen und die Aktion erneut ausführen.")
  return
end

if selected_count > 1 then
  message("Für diesen ersten Test bitte genau ein MIDI-Item auswählen.\n\nAusgewählt: " .. tostring(selected_count))
  return
end

local item = reaper.GetSelectedMediaItem(project, 0)
if not item then
  message("Das ausgewählte Item konnte nicht gelesen werden.")
  return
end

local take = reaper.GetActiveTake(item)
if not take or not reaper.TakeIsMIDI(take) then
  message("Das ausgewählte Item ist kein MIDI-Item.")
  return
end

local track = reaper.GetMediaItemTrack(item)
local _, track_name = reaper.GetTrackName(track)
local track_number = math.floor(reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") or 0)
local item_position = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
local item_length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
local item_end = item_position + item_length
local _, take_name = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
local _, note_count, cc_count, text_count = reaper.MIDI_CountEvts(take)

local first_note_start = nil
local last_note_end = nil
local min_pitch = nil
local max_pitch = nil
local min_velocity = nil
local max_velocity = nil

for i = 0, note_count - 1 do
  local ok, _, _, start_ppq, end_ppq, _, pitch, velocity = reaper.MIDI_GetNote(take, i)
  if ok then
    local start_time = reaper.MIDI_GetProjTimeFromPPQPos(take, start_ppq)
    local end_time = reaper.MIDI_GetProjTimeFromPPQPos(take, end_ppq)
    if not first_note_start or start_time < first_note_start then first_note_start = start_time end
    if not last_note_end or end_time > last_note_end then last_note_end = end_time end
    if not min_pitch or pitch < min_pitch then min_pitch = pitch end
    if not max_pitch or pitch > max_pitch then max_pitch = pitch end
    if not min_velocity or velocity < min_velocity then min_velocity = velocity end
    if not max_velocity or velocity > max_velocity then max_velocity = velocity end
  end
end

local bpm = reaper.TimeMap_GetDividedBpmAtTime(item_position)
local _, measures, cml, fullbeats, cdenom = reaper.TimeMap2_timeToBeats(project, item_position)
local measure_number = (measures or 0) + 1
local numerator = math.floor((cml or 4) + 0.5)
local denominator = math.floor((cdenom or 4) + 0.5)

local function fmt_time(v)
  if v == nil then return "-" end
  return string.format("%.3f s", v)
end

local lines = {
  "Reaper Composition " .. VERSION,
  "Phase 1 – MIDI lesen",
  "",
  "Spur: " .. tostring(track_number) .. "  " .. (track_name or ""),
  "Take: " .. ((take_name ~= "" and take_name) or "ohne Namen"),
  "Item-Start: " .. fmt_time(item_position),
  "Item-Ende: " .. fmt_time(item_end),
  "Item-Länge: " .. fmt_time(item_length),
  "Starttakt: " .. tostring(measure_number),
  "Tempo am Item-Start: " .. string.format("%.3f BPM", bpm),
  "Taktart am Item-Start: " .. tostring(numerator) .. "/" .. tostring(denominator),
  "",
  "Noten: " .. tostring(note_count),
  "CC-Ereignisse: " .. tostring(cc_count),
  "Text/SysEx-Ereignisse: " .. tostring(text_count),
  "Erste Note: " .. fmt_time(first_note_start),
  "Letztes Notenende: " .. fmt_time(last_note_end),
  "Tonhöhenbereich: " .. (min_pitch and (tostring(min_pitch) .. "–" .. tostring(max_pitch)) or "-"),
  "Velocity-Bereich: " .. (min_velocity and (tostring(min_velocity) .. "–" .. tostring(max_velocity)) or "-"),
  "",
  "Projekt wurde nicht verändert.",
  "Status: MIDI-Item erfolgreich gelesen."
}

message(table.concat(lines, "\n"))
