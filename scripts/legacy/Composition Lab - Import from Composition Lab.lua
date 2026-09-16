-- Composition Lab - Import from Composition Lab.lua
-- V0.6.0
-- Creates a new MIDI item directly from Composition Lab's structured result JSON.
-- No playback, recording or manual MIDI-file export is required.

local function msg(s)
  reaper.MB(s, "Composition Lab", 0)
end

local function read_all(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local d = f:read("*a")
  f:close()
  return d
end

local function decode_json(str)
  local pos = 1
  local len = #str
  local function skip_ws() while pos <= len and str:sub(pos,pos):match("%s") do pos = pos + 1 end end
  local parse_value
  local function parse_string()
    pos = pos + 1
    local out = {}
    while pos <= len do
      local c = str:sub(pos,pos)
      if c == '"' then pos = pos + 1; return table.concat(out) end
      if c == "\\" then
        local n = str:sub(pos+1,pos+1)
        local map = {['"']='"', ['\\']='\\', ['/']='/', b='\b', f='\f', n='\n', r='\r', t='\t'}
        if map[n] then out[#out+1] = map[n]; pos = pos + 2
        elseif n == "u" then
          local hex = str:sub(pos+2,pos+5)
          local cp = tonumber(hex,16) or 63
          if cp < 128 then out[#out+1] = string.char(cp)
          elseif cp < 2048 then out[#out+1] = string.char(192 + math.floor(cp/64), 128 + (cp%64))
          else out[#out+1] = "?" end
          pos = pos + 6
        else error("Ungültige JSON-Escape-Sequenz") end
      else out[#out+1] = c; pos = pos + 1 end
    end
    error("Nicht abgeschlossener JSON-String")
  end
  local function parse_number()
    local s = pos
    while pos <= len and str:sub(pos,pos):match("[%d%+%-%e%E%.]") do pos = pos + 1 end
    local n = tonumber(str:sub(s,pos-1)); if n == nil then error("Ungültige JSON-Zahl") end; return n
  end
  local function parse_array()
    pos = pos + 1; local arr = {}; skip_ws()
    if str:sub(pos,pos) == "]" then pos = pos + 1; return arr end
    while true do arr[#arr+1] = parse_value(); skip_ws(); local c = str:sub(pos,pos); if c == "]" then pos = pos + 1; return arr end; if c ~= "," then error("JSON-Array erwartet Komma") end; pos = pos + 1 end
  end
  local function parse_object()
    pos = pos + 1; local obj = {}; skip_ws()
    if str:sub(pos,pos) == "}" then pos = pos + 1; return obj end
    while true do skip_ws(); if str:sub(pos,pos) ~= '"' then error("JSON-Objekt erwartet Schlüssel") end; local key = parse_string(); skip_ws(); if str:sub(pos,pos) ~= ":" then error("JSON-Objekt erwartet Doppelpunkt") end; pos = pos + 1; obj[key] = parse_value(); skip_ws(); local c = str:sub(pos,pos); if c == "}" then pos = pos + 1; return obj end; if c ~= "," then error("JSON-Objekt erwartet Komma") end; pos = pos + 1 end
  end
  function parse_value()
    skip_ws(); local c = str:sub(pos,pos)
    if c == '"' then return parse_string() elseif c == "{" then return parse_object() elseif c == "[" then return parse_array() elseif c == "-" or c:match("%d") then return parse_number() elseif str:sub(pos,pos+3) == "true" then pos = pos + 4; return true elseif str:sub(pos,pos+4) == "false" then pos = pos + 5; return false elseif str:sub(pos,pos+3) == "null" then pos = pos + 4; return nil else error("Ungültiges JSON bei Position " .. tostring(pos)) end
  end
  return parse_value()
end

local function from_hex(s)
  local out={}
  for h in tostring(s or ""):gmatch("%x%x") do out[#out+1]=string.char(tonumber(h,16)) end
  return table.concat(out)
end

local bridge_dir=reaper.GetResourcePath().."/Composition Lab"
local result_path=bridge_dir.."/composition_lab_result.json"
local raw=read_all(result_path)
if not raw then msg("Noch kein Ergebnis von Composition Lab gefunden."); return end
local ok,doc=pcall(decode_json,raw)
if not ok or type(doc)~="table" or doc.source~="Composition Lab" or type(doc.tracks)~="table" then
  msg("Die Composition-Lab-Rückgabedatei konnte nicht gelesen werden.\n\n"..tostring(doc)); return
end

local selected_item=reaper.GetSelectedMediaItem(0,0)
local source_track=selected_item and reaper.GetMediaItem_Track(selected_item) or reaper.GetSelectedTrack(0,0)
local insert_time=selected_item and reaper.GetMediaItemInfo_Value(selected_item,"D_POSITION") or reaper.GetCursorPosition()
if not source_track then msg("Bitte in REAPER eine Zielspur oder einen Clip auswählen."); return end
local source_index=math.floor(reaper.GetMediaTrackInfo_Value(source_track,"IP_TRACKNUMBER"))

local valid={}
for _,tr in ipairs(doc.tracks) do
  local max_end=0; local has=false
  if type(tr.notes)=="table" then for _,n in ipairs(tr.notes) do if n.duration and n.duration>0 then max_end=math.max(max_end,(n.start or 0)+n.duration); has=true end end end
  if type(tr.midi_events)=="table" then for _,e in ipairs(tr.midi_events) do max_end=math.max(max_end,e.beat or 0); has=true end end
  if has then valid[#valid+1]={track=tr,max_end=math.max(max_end,0.25)} end
end
if #valid==0 then msg("Das Composition-Lab-Ergebnis enthält keine verwendbaren MIDI-Daten."); return end

reaper.Undo_BeginBlock(); reaper.PreventUIRefresh(1)
local start_qn=reaper.TimeMap2_timeToQN(0,insert_time)
local created={}
for idx,v in ipairs(valid) do
  local tr=v.track
  local insert_index=source_index+(idx-1)
  reaper.InsertTrackAtIndex(insert_index,true)
  local target=reaper.GetTrack(0,insert_index)
  if target then
    reaper.GetSetMediaTrackInfo_String(target,"P_NAME",(tr.name and tr.name~="" and tr.name or ("Composition Lab "..idx)),true)
    local end_time=reaper.TimeMap2_QNToTime(0,start_qn+v.max_end+0.01)
    local item=reaper.CreateNewMIDIItemInProj(target,insert_time,end_time,false)
    local take=item and reaper.GetActiveTake(item)
    if take then
      reaper.MIDI_DisableSort(take)
      for _,n in ipairs(tr.notes or {}) do
        if n.duration and n.duration>0 and n.pitch and n.pitch>=0 and n.pitch<=127 then
          local sqn=start_qn+(n.start or 0); local eqn=sqn+n.duration
          local sppq=reaper.MIDI_GetPPQPosFromProjQN(take,sqn); local eppq=reaper.MIDI_GetPPQPosFromProjQN(take,eqn)
          reaper.MIDI_InsertNote(take,false,false,sppq,eppq,math.max(0,math.min(15,math.floor(n.channel or tr.channel or 0))),math.max(0,math.min(127,math.floor(n.pitch+0.5))),math.max(1,math.min(127,math.floor((n.velocity or 96)+0.5))),true)
        end
      end
      for _,e in ipairs(tr.midi_events or {}) do
        local msgstr=from_hex(e.message)
        if #msgstr>0 then local ppq=reaper.MIDI_GetPPQPosFromProjQN(take,start_qn+(e.beat or 0)); reaper.MIDI_InsertEvt(take,e.selected==true,e.muted==true,ppq,msgstr,true) end
      end
      reaper.MIDI_Sort(take)
      if doc.title and doc.title~="" then reaper.GetSetMediaItemTakeInfo_String(take,"P_NAME",doc.title.." – "..(tr.name or tostring(idx)),true) end
      created[#created+1]=item
    end
  end
end
for i=0,reaper.CountMediaItems(0)-1 do reaper.SetMediaItemSelected(reaper.GetMediaItem(0,i),false) end
for _,item in ipairs(created) do reaper.SetMediaItemSelected(item,true) end
reaper.UpdateArrange(); reaper.PreventUIRefresh(-1); reaper.Undo_EndBlock("Import from Composition Lab – full MIDI",-1)
