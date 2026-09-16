-- @description Composition Studio Basic
-- @version 0.1-dev
-- @author Klangwerke
-- @about
--   Recursive AI composition directly inside REAPER.
--   Composition Lab is not part of the runtime architecture.

local SCRIPT_NAME = "Composition Studio Basic"
local VERSION = "0.1-dev"

local function round(n, places)
  local p = 10 ^ (places or 3)
  return math.floor(n * p + 0.5) / p
end

local function item_guid(item)
  local ok, guid = reaper.GetSetMediaItemInfo_String(item, "GUID", "", false)
  return ok and guid or ""
end

local function take_guid(take)
  local ok, guid = reaper.GetSetMediaItemTakeInfo_String(take, "GUID", "", false)
  return ok and guid or ""
end

local function selected_midi_items()
  local result = {}
  local count = reaper.CountSelectedMediaItems(0)
  for i = 0, count - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    local take = item and reaper.GetActiveTake(item)
    if take and reaper.TakeIsMIDI(take) then
      local track = reaper.GetMediaItem_Track(item)
      local _, track_name = reaper.GetTrackName(track)
      local _, take_name = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
      local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
      local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
      local _, note_count, cc_count, text_count = reaper.MIDI_CountEvts(take)
      local notes = {}
      for n = 0, (note_count or 0) - 1 do
        local ok, selected, muted, start_ppq, end_ppq, chan, pitch, vel = reaper.MIDI_GetNote(take, n)
        if ok then
          local start_time = reaper.MIDI_GetProjTimeFromPPQPos(take, start_ppq)
          local end_time = reaper.MIDI_GetProjTimeFromPPQPos(take, end_ppq)
          local start_qn = reaper.TimeMap2_timeToQN(0, start_time)
          local end_qn = reaper.TimeMap2_timeToQN(0, end_time)
          notes[#notes + 1] = {
            start_qn = round(start_qn, 5),
            duration_qn = round(end_qn - start_qn, 5),
            pitch = pitch,
            velocity = vel,
            channel = chan,
            muted = muted and true or false
          }
        end
      end
      result[#result + 1] = {
        item = item,
        take = take,
        track = track,
        item_guid = item_guid(item),
        take_guid = take_guid(take),
        track_name = track_name ~= "" and track_name or "Unbenannte Spur",
        take_name = take_name ~= "" and take_name or "Unbenanntes MIDI-Item",
        position = pos,
        length = len,
        start_qn = round(reaper.TimeMap2_timeToQN(0, pos), 5),
        end_qn = round(reaper.TimeMap2_timeToQN(0, pos + len), 5),
        notes = notes,
        note_count = note_count or 0,
        cc_count = cc_count or 0,
        text_count = text_count or 0
      }
    end
  end
  return result
end

local function project_context(items)
  local bpm = reaper.Master_GetTempo()
  local _, num, denom = reaper.TimeMap_GetTimeSigAtTime(0, items[1] and items[1].position or 0)
  return {
    bpm = round(bpm, 3),
    numerator = num or 4,
    denominator = denom or 4,
    items = items
  }
end

local function compact_text(ctx)
  local lines = {
    string.format("Tempo: %.3f BPM | Takt: %d/%d", ctx.bpm, ctx.numerator, ctx.denominator),
    ""
  }
  for i, v in ipairs(ctx.items) do
    lines[#lines + 1] = string.format(
      "[%d] %s / %s | QN %.5f-%.5f | %d Noten",
      i, v.track_name, v.take_name, v.start_qn, v.end_qn, v.note_count)
    for _, note in ipairs(v.notes) do
      lines[#lines + 1] = string.format(
        "  N %.5f %.5f %d %d %d",
        note.start_qn, note.duration_qn, note.pitch, note.velocity, note.channel)
    end
  end
  return table.concat(lines, "\n")
end

local function ask_for_request(items)
  local caption = string.format("%d MIDI-Item(s) erkannt. Freier Kompositionsauftrag:", #items)
  local ok, text = reaper.GetUserInputs(SCRIPT_NAME .. " " .. VERSION, 1, caption .. ",extrawidth=420", "")
  if not ok then return nil end
  text = text:gsub("^%s+", ""):gsub("%s+$", "")
  if text == "" then return nil end
  return text
end

local items = selected_midi_items()
if #items == 0 then
  reaper.ShowMessageBox(
    "Keine ausgewählten MIDI-Items.\n\nWähle ein oder mehrere MIDI-Items in REAPER aus und starte Composition Studio erneut.",
    SCRIPT_NAME .. " " .. VERSION,
    0)
  return
end

local request = ask_for_request(items)
if not request then return end

local ctx = project_context(items)
local musical_context = compact_text(ctx)

-- Basic development checkpoint:
-- Selection and complete note content are now read directly from REAPER.
-- The next stage connects this payload to the AI transport and validates the
-- returned result before any REAPER project data is changed.
local preview = string.format(
  "Auftrag:\n%s\n\nDirekt aus REAPER gelesen:\n%s\n\nNoch keine Projektänderung – sicherer Basic-Zwischenstand.",
  request,
  musical_context)

-- Keep the preview bounded for very large selections.
if #preview > 12000 then
  preview = preview:sub(1, 12000) .. "\n\n… Vorschau gekürzt; interne Daten vollständig."
end
reaper.ShowMessageBox(preview, SCRIPT_NAME .. " " .. VERSION, 0)
