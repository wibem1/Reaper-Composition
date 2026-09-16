-- Composition Lab - Send to Composition Lab.lua
-- V0.6.0: multi-track + complete raw non-note MIDI event bridge.

local function msg(s) reaper.MB(s,"Composition Lab",0) end
local function esc(s)
  s=tostring(s or "")
  return s:gsub("\\","\\\\"):gsub('"','\\"'):gsub("\b","\\b"):gsub("\f","\\f")
          :gsub("\n","\\n"):gsub("\r","\\r"):gsub("\t","\\t")
end
local function shell_quote(s) return "'"..tostring(s or ""):gsub("'","'\\''").."'" end
local function exists(p) local f=io.open(p,"r"); if f then f:close(); return true end return false end
local function hex(msgstr)
  local t={}
  for i=1,#msgstr do t[#t+1]=string.format("%02X",msgstr:byte(i)) end
  return table.concat(t," ")
end
local function is_note_message(msgstr)
  if #msgstr < 1 then return false end
  local kind = msgstr:byte(1) & 0xF0
  return kind == 0x80 or kind == 0x90
end

local selected={}
local nsel=reaper.CountSelectedMediaItems(0)
for i=0,nsel-1 do
  local item=reaper.GetSelectedMediaItem(0,i)
  local take=item and reaper.GetActiveTake(item)
  if take and reaper.TakeIsMIDI(take) then
    selected[#selected+1]={item=item,take=take}
  end
end
if #selected==0 then msg("Bitte mindestens einen MIDI-Clip in REAPER auswählen."); return end

local earliest_qn=nil
for _,x in ipairs(selected) do
  local qn=reaper.TimeMap2_timeToQN(0,reaper.GetMediaItemInfo_Value(x.item,"D_POSITION"))
  if not earliest_qn or qn<earliest_qn then earliest_qn=qn end
end

local first_pos=reaper.GetMediaItemInfo_Value(selected[1].item,"D_POSITION")
local bpm=reaper.Master_GetTempo()
local _,_,_,_,_,num,den=reaper.TimeMap_GetTimeSigAtTime(0,first_pos)
local tracks={}
local total_notes=0

for ti,x in ipairs(selected) do
  local item,take=x.item,x.take
  local tr=reaper.GetMediaItem_Track(item)
  local _,name=reaper.GetTrackName(tr)
  local item_qn=reaper.TimeMap2_timeToQN(0,reaper.GetMediaItemInfo_Value(item,"D_POSITION"))
  local offset=item_qn-earliest_qn

  local _,note_count=reaper.MIDI_CountEvts(take)
  local notes={}
  local first_channel=nil
  for i=0,(note_count or 0)-1 do
    local ok,sel,mut,sppq,eppq,ch,pitch,vel=reaper.MIDI_GetNote(take,i)
    if ok then
      local sqn=reaper.MIDI_GetProjQNFromPPQPos(take,sppq)-item_qn+offset
      local eqn=reaper.MIDI_GetProjQNFromPPQPos(take,eppq)-item_qn+offset
      notes[#notes+1]={start=sqn,duration=eqn-sqn,pitch=pitch,velocity=vel,channel=ch,selected=sel,muted=mut}
      first_channel=first_channel or ch
    end
  end
  total_notes=total_notes+#notes

  local events={}
  local evt=0
  while true do
    local ok,sel,mut,ppq,msgstr=reaper.MIDI_GetEvt(take,evt)
    if not ok then break end
    if #msgstr>0 and not is_note_message(msgstr) then
      local qn=reaper.MIDI_GetProjQNFromPPQPos(take,ppq)-item_qn+offset
      events[#events+1]={beat=qn,message=hex(msgstr),selected=sel,muted=mut}
    end
    evt=evt+1
  end

  tracks[#tracks+1]={name=(name and name~="" and name or ("REAPER "..ti)),
                     channel=first_channel or (ti-1)%16,program=0,notes=notes,events=events}
end

local out_dir=reaper.GetResourcePath().."/Composition Lab"
reaper.RecursiveCreateDirectory(out_dir,0)
local out_path=out_dir.."/reaper_selected_midi.json"
local f,err=io.open(out_path,"w")
if not f then msg("Die Übergabedatei konnte nicht geschrieben werden:\n"..tostring(err)); return end

f:write('{\n  "format":"CompositionLab-Reaper-Bridge-0.6",\n  "source":"REAPER",\n')
f:write('  "title":"REAPER – '..#tracks..' Spur(en)",\n')
f:write(string.format('  "bpm":%.12g,\n',bpm))
f:write(string.format('  "time_signature":{"numerator":%d,"denominator":%d},\n',num or 4,den or 4))
f:write(string.format('  "track_count":%d,\n  "note_count":%d,\n  "tracks":[\n',#tracks,total_notes))
for ti,t in ipairs(tracks) do
  f:write('    {"name":"'..esc(t.name)..'",')
  f:write(string.format('"channel":%d,"program":%d,"notes":[',t.channel,t.program))
  for i,n in ipairs(t.notes) do
    f:write(string.format('{"start":%.12g,"duration":%.12g,"pitch":%d,"velocity":%d,"channel":%d,"selected":%s,"muted":%s}',
      n.start,n.duration,n.pitch,n.velocity,n.channel,n.selected and "true" or "false",n.muted and "true" or "false"))
    if i<#t.notes then f:write(",") end
  end
  f:write('],"midi_events":[')
  for i,e in ipairs(t.events) do
    f:write(string.format('{"beat":%.12g,"message":"%s","selected":%s,"muted":%s}',
      e.beat,e.message,e.selected and "true" or "false",e.muted and "true" or "false"))
    if i<#t.events then f:write(",") end
  end
  f:write("]}")
  if ti<#tracks then f:write(",") end
  f:write("\n")
end
f:write("  ]\n}\n"); f:close()
reaper.SetExtState("CompositionLab","LastExportPath",out_path,true)

local app="/Applications/Composition Lab.app"
if not exists(app.."/Contents/Info.plist") then
  msg("Composition Lab wurde nicht unter\n\n/Applications/Composition Lab.app\n\ngefunden."); return
end
local cmd='/usr/bin/open '..shell_quote(app)
if reaper.ExecProcess then reaper.ExecProcess(cmd,0) else os.execute(cmd..' >/dev/null 2>&1 &') end
