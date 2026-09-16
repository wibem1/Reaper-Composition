-- @description Composition Studio Basic
-- @version 0.1-test
-- @author Klangwerke
-- @about First end-to-end test: selected REAPER MIDI -> OpenAI -> new MIDI in REAPER.

local SCRIPT_NAME = "Composition Studio Basic"
local VERSION = "0.1-test"
local EXT_SECTION = "CompositionStudio"
local EXT_KEY = "OpenAIAPIKey"

local function trim(s)
  return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function shell_quote(s)
  return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function json_escape(s)
  return tostring(s or ""):gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
end

local function read_file(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local s = f:read("*a")
  f:close()
  return s
end

local function write_file(path, s)
  local f = io.open(path, "wb")
  if not f then return false end
  f:write(s)
  f:close()
  return true
end

local function get_guid(item)
  local ok, guid = reaper.GetSetMediaItemInfo_String(item, "GUID", "", false)
  return ok and guid or ""
end

local function get_api_key()
  local key = trim(reaper.GetExtState(EXT_SECTION, EXT_KEY))
  if key ~= "" then return key end

  local ok, input = reaper.GetUserInputs(
    SCRIPT_NAME .. " – Ersteinrichtung", 1,
    "OpenAI API-Key:,extrawidth=320", ""
  )
  if not ok then return nil, "API-Key-Eingabe abgebrochen." end

  key = trim(input)
  if key == "" then return nil, "Kein API-Key eingegeben." end
  reaper.SetExtState(EXT_SECTION, EXT_KEY, key, true)
  return key
end

-- Liest alle aktuell ausgewaehlten MIDI-Items direkt aus REAPER.
local function selected_midi_items()
  local items = {}

  for i = 0, reaper.CountSelectedMediaItems(0) - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    local take = item and reaper.GetActiveTake(item)

    if take and reaper.TakeIsMIDI(take) then
      local track = reaper.GetMediaItem_Track(item)
      local _, track_name = reaper.GetTrackName(track)
      local _, take_name = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
      local position = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
      local length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
      local _, note_count = reaper.MIDI_CountEvts(take)
      local notes = {}

      for n = 0, (note_count or 0) - 1 do
        local ok, _, muted, start_ppq, end_ppq, channel, pitch, velocity = reaper.MIDI_GetNote(take, n)
        if ok and not muted then
          local start_time = reaper.MIDI_GetProjTimeFromPPQPos(take, start_ppq)
          local end_time = reaper.MIDI_GetProjTimeFromPPQPos(take, end_ppq)
          local start_qn = reaper.TimeMap2_timeToQN(0, start_time)
          local end_qn = reaper.TimeMap2_timeToQN(0, end_time)
          notes[#notes + 1] = {
            start_qn = start_qn,
            duration_qn = end_qn - start_qn,
            pitch = pitch,
            velocity = velocity,
            channel = channel
          }
        end
      end

      items[#items + 1] = {
        item = item,
        take = take,
        track = track,
        guid = get_guid(item),
        track_name = track_name ~= "" and track_name or "Unbenannte Spur",
        take_name = take_name ~= "" and take_name or "Unbenanntes MIDI-Item",
        position = position,
        length = length,
        notes = notes
      }
    end
  end

  return items
end

local function context_text(items)
  local lines = { string.format("Tempo %.3f BPM", reaper.Master_GetTempo()) }

  for i, item in ipairs(items) do
    lines[#lines + 1] = string.format(
      "ITEM %d id=%s track=%s take=%s",
      i, item.guid, item.track_name, item.take_name
    )

    for _, note in ipairs(item.notes) do
      lines[#lines + 1] = string.format(
        "N %.5f %.5f %d %d %d",
        note.start_qn, note.duration_qn, note.pitch, note.velocity, note.channel
      )
    end
  end

  return table.concat(lines, "\n")
end

local function ask_request(count)
  local ok, text = reaper.GetUserInputs(
    SCRIPT_NAME .. " " .. VERSION, 1,
    string.format("%d MIDI-Item(s) erkannt. Freier Kompositionsauftrag:,extrawidth=420", count),
    ""
  )
  if not ok then return nil end
  text = trim(text)
  if text == "" then return nil end
  return text
end

-- Musikalisch bewusst offen. Das CS-Format ist nur die technische Rueckgabesprache.
local function build_prompt(request, music)
  return [[Du komponierst Musik.
Nutze das uebergebene Material als gemeinsamen musikalischen Kontext.
Erfuelle den freien Auftrag musikalisch eigenstaendig.
Fuege keine unnoetigen musikalischen Regeln hinzu.

Antworte ausschliesslich mit technischen Ergebniszeilen:
CS|unchanged|SOURCE_GUID
CS|revised|SOURCE_GUID|NAME|startQN,durationQN,pitch,velocity,channel;...
CS|new|-|NAME|startQN,durationQN,pitch,velocity,channel;...

Technische Regeln:
Fuer revised muss SOURCE_GUID exakt eine angebotene Item-GUID sein.
Fuer new ist SOURCE_GUID '-'.
startQN>=0, durationQN>0, pitch 0..127, velocity 1..127, channel 0..15.
NAME darf kein | enthalten.
Gib nur tatsaechlich benoetigte Ergebniszeilen zurueck.

AUFTRAG:
]] .. request .. "\n\nMUSIK:\n" .. music
end

local function parse_notes(text)
  local notes = {}
  for token in (text or ""):gmatch("[^;]+") do
    local a,b,c,d,e = token:match("^%s*([%d%.%-]+),([%d%.%-]+),(%d+),(%d+),(%d+)%s*$")
    a,b,c,d,e = tonumber(a),tonumber(b),tonumber(c),tonumber(d),tonumber(e)
    if not (a and b and c and d and e) then return nil, "Ungueltige Note: " .. token end
    if a < 0 or b <= 0 or c < 0 or c > 127 or d < 1 or d > 127 or e < 0 or e > 15 then
      return nil, "Note ausserhalb gueltiger Grenzen."
    end
    notes[#notes + 1] = { start_qn=a, duration_qn=b, pitch=c, velocity=d, channel=e }
  end
  if #notes == 0 then return nil, "Leere Notenliste." end
  return notes
end

local function validate_response(text, items)
  local sources = {}
  for _, item in ipairs(items) do sources[item.guid] = item end
  local results = {}

  text = (text or ""):gsub("```[%w_-]*", ""):gsub("```", "")

  for line in text:gmatch("[^\r\n]+") do
    line = trim(line)
    if line ~= "" then
      local kind, source, rest = line:match("^CS|([^|]+)|([^|]+)|?(.*)$")
      if not kind then return nil, "Unerwartete KI-Zeile: " .. line end

      if kind == "unchanged" then
        if not sources[source] then return nil, "Unbekannte unchanged-Quelle." end
        results[#results + 1] = { kind=kind, source=source }

      elseif kind == "revised" or kind == "new" then
        if kind == "revised" and not sources[source] then return nil, "Unbekannte revised-Quelle." end
        if kind == "new" and source ~= "-" then return nil, "new muss Quelle '-' verwenden." end

        local name, note_text = rest:match("^([^|]+)|(.+)$")
        name = trim(name)
        if not name or name == "" then return nil, "Ergebnisname fehlt." end

        local notes, err = parse_notes(note_text)
        if not notes then return nil, err end
        results[#results + 1] = { kind=kind, source=source, name=name, notes=notes }
      else
        return nil, "Unbekannter Ergebnistyp: " .. tostring(kind)
      end
    end
  end

  if #results == 0 then return nil, "Leere KI-Antwort." end
  return results
end

local function run_openai(prompt, key)
  local base = os.tmpname()
  local request_path = base .. ".json"
  local response_path = base .. ".out"
  local status_path = base .. ".code"

  local body = '{"model":"gpt-5.6","input":"' .. json_escape(prompt) .. '"}'
  if not write_file(request_path, body) then return nil, "Temporäre Anfrage konnte nicht geschrieben werden." end

  local command = "/usr/bin/curl -sS --max-time 120" ..
    " -o " .. shell_quote(response_path) ..
    " -w '%{http_code}'" ..
    " -H " .. shell_quote("Authorization: Bearer " .. key) ..
    " -H 'Content-Type: application/json'" ..
    " --data-binary @" .. shell_quote(request_path) ..
    " https://api.openai.com/v1/responses" ..
    " > " .. shell_quote(status_path)

  os.execute(command)
  local status = trim(read_file(status_path))
  local raw = read_file(response_path)
  os.remove(request_path); os.remove(response_path); os.remove(status_path)

  if status ~= "200" or not raw then
    local api_message = raw and raw:match('"message"%s*:%s*"([^"\\]*(\\.[^"\\]*)*)"')
    return nil, "KI-Aufruf fehlgeschlagen (HTTP " .. tostring(status) .. ")." .. (api_message and ("\n\n" .. api_message) or "")
  end

  local encoded = raw:match('"type"%s*:%s*"output_text".-"text"%s*:%s*"(([^"\\]|\\.)*)"')
  if not encoded then return nil, "Keine Textantwort der KI gefunden." end

  encoded = encoded:gsub('\\n','\n'):gsub('\\r','\r'):gsub('\\t','\t'):gsub('\\"','"'):gsub('\\\\','\\')
  return encoded
end

local function qn_to_time(qn)
  return reaper.TimeMap2_QNToTime(0, qn)
end

local function create_midi_item(track, name, notes)
  local lo, hi = math.huge, -math.huge
  for _, note in ipairs(notes) do
    lo = math.min(lo, note.start_qn)
    hi = math.max(hi, note.start_qn + note.duration_qn)
  end
  if lo == math.huge or hi <= lo then return nil, "Ungueltiger musikalischer Bereich." end

  local item = reaper.CreateNewMIDIItemInProj(track, qn_to_time(lo), qn_to_time(hi), false)
  if not item then return nil, "MIDI-Item konnte nicht erzeugt werden." end
  local take = reaper.GetActiveTake(item)
  if not take then return nil, "MIDI-Take konnte nicht erzeugt werden." end
  reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", name, true)

  for _, note in ipairs(notes) do
    local start_ppq = reaper.MIDI_GetPPQPosFromProjTime(take, qn_to_time(note.start_qn))
    local end_ppq = reaper.MIDI_GetPPQPosFromProjTime(take, qn_to_time(note.start_qn + note.duration_qn))
    reaper.MIDI_InsertNote(take, false, false, start_ppq, end_ppq, note.channel, note.pitch, note.velocity, true)
  end
  reaper.MIDI_Sort(take)
  return item
end

local function create_track(name)
  local index = reaper.CountTracks(0)
  reaper.InsertTrackAtIndex(index, true)
  local track = reaper.GetTrack(0, index)
  if track then reaper.GetSetMediaTrackInfo_String(track, "P_NAME", name, true) end
  return track
end

local function apply_results(results, items)
  local sources = {}
  for _, item in ipairs(items) do sources[item.guid] = item end
  local created = {}

  reaper.Undo_BeginBlock2(0)
  reaper.PreventUIRefresh(1)

  local success, err = xpcall(function()
    for _, result in ipairs(results) do
      if result.kind == "revised" then
        local source = sources[result.source]
        local item, why = create_midi_item(source.track, result.name .. " [Variante]", result.notes)
        if not item then error(why) end
        created[#created + 1] = item
      elseif result.kind == "new" then
        local track = create_track(result.name)
        if not track then error("Neue Spur konnte nicht erzeugt werden.") end
        local item, why = create_midi_item(track, result.name, result.notes)
        if not item then error(why) end
        created[#created + 1] = item
      end
    end
  end, debug.traceback)

  reaper.PreventUIRefresh(-1)

  if not success then
    reaper.Undo_EndBlock2(0, "Composition Studio – fehlgeschlagen", -1)
    reaper.Undo_DoUndo2(0)
    return nil, err
  end

  -- Bei ausschliesslich 'unchanged' bleibt die bisherige Auswahl erhalten.
  if #created > 0 then
    for i = 0, reaper.CountMediaItems(0) - 1 do
      reaper.SetMediaItemSelected(reaper.GetMediaItem(0, i), false)
    end
    for _, item in ipairs(created) do reaper.SetMediaItemSelected(item, true) end
  end

  reaper.UpdateArrange()
  reaper.Undo_EndBlock2(0, "Composition Studio – KI-Komposition", -1)
  return created
end

-- Hauptprogramm
local items = selected_midi_items()
if #items == 0 then
  reaper.ShowMessageBox("Keine ausgewählten MIDI-Items.\n\nWähle ein oder mehrere MIDI-Items aus.", SCRIPT_NAME .. " " .. VERSION, 0)
  return
end

local request = ask_request(#items)
if not request then return end

local key, key_error = get_api_key()
if not key then
  reaper.ShowMessageBox(key_error, SCRIPT_NAME, 0)
  return
end

local answer, api_error = run_openai(build_prompt(request, context_text(items)), key)
if not answer then
  reaper.ShowMessageBox("KI-Aufruf nicht ausgeführt:\n\n" .. api_error .. "\n\nDas REAPER-Projekt wurde nicht verändert.", SCRIPT_NAME .. " " .. VERSION, 0)
  return
end

local results, validation_error = validate_response(answer, items)
if not results then
  reaper.ShowMessageBox("KI-Antwort verworfen:\n\n" .. validation_error .. "\n\nDas REAPER-Projekt wurde nicht verändert.", SCRIPT_NAME .. " " .. VERSION, 0)
  return
end

local created, apply_error = apply_results(results, items)
if not created then
  reaper.ShowMessageBox("Ergebnis konnte nicht angewendet werden:\n\n" .. tostring(apply_error), SCRIPT_NAME .. " " .. VERSION, 0)
  return
end

if #created == 0 then
  reaper.ShowMessageBox("Die KI hat keine neue oder überarbeitete Stimme erzeugt.\nDie ursprüngliche Auswahl bleibt erhalten.", SCRIPT_NAME .. " " .. VERSION, 0)
else
  reaper.ShowMessageBox(string.format("%d neues/überarbeitetes MIDI-Item(s) erzeugt.\n\nOriginale blieben erhalten. Neue Items sind ausgewählt.\nDer Vorgang ist ein REAPER-Undo-Schritt.", #created), SCRIPT_NAME .. " " .. VERSION, 0)
end
