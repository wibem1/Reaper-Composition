-- @description Composition Studio
-- @version 0.2-test5
-- @author Klangwerke
-- @about Dockable AI chat and direct MIDI composition in REAPER.

local SCRIPT_NAME="Composition Studio"
local VERSION="0.2-test5"
local EXT_SECTION,EXT_KEY="CompositionStudio","OpenAIAPIKey"

if not reaper.ImGui_CreateContext or not reaper.ImGui_InputTextMultiline then
  reaper.ShowMessageBox("Composition Studio benötigt ReaImGui.",SCRIPT_NAME,0)
  return
end

local ctx=reaper.ImGui_CreateContext(SCRIPT_NAME)
local open=true
local input=""
local busy=false
local history={{role="KI",text="Composition Studio ist bereit. Du kannst mit mir über die Musik sprechen oder mir einen Kompositionsauftrag geben."}}

-- ReaImGui 0.10+ trennt Schriftfamilie und Schriftgröße. Die Größe wird beim PushFont gesetzt.
local font=reaper.ImGui_CreateFont and reaper.ImGui_CreateFont("sans-serif") or nil
if font and reaper.ImGui_Attach then pcall(reaper.ImGui_Attach,ctx,font) end

local function push_font()
  if not font or not reaper.ImGui_PushFont then return false end
  local ok=pcall(reaper.ImGui_PushFont,ctx,font,18)
  if not ok then ok=pcall(reaper.ImGui_PushFont,ctx,font) end
  return ok
end
local function pop_font(pushed) if pushed and reaper.ImGui_PopFont then reaper.ImGui_PopFont(ctx) end end

local function trim(s) return (s or ""):gsub("^%s+",""):gsub("%s+$","") end
local function shell_quote(s) return "'"..tostring(s):gsub("'","'\\''").."'" end
local function json_escape(s) return tostring(s or ""):gsub("\\","\\\\"):gsub('"','\\"'):gsub("\n","\\n"):gsub("\r","\\r"):gsub("\t","\\t") end
local function read_file(p) local f=io.open(p,"rb"); if not f then return nil end local s=f:read("*a"); f:close(); return s end
local function write_file(p,s) local f=io.open(p,"wb"); if not f then return false end f:write(s); f:close(); return true end

local function read_json_string(raw,q)
  if not raw or raw:sub(q,q)~='"' then return nil end
  local out,i={},q+1
  while i<=#raw do
    local c=raw:sub(i,i)
    if c=='"' then return table.concat(out) end
    if c=="\\" then
      i=i+1 local e=raw:sub(i,i)
      if e=="n" then out[#out+1]="\n" elseif e=="r" then out[#out+1]="\r" elseif e=="t" then out[#out+1]="\t" elseif e=='"' then out[#out+1]='"' elseif e=="\\" then out[#out+1]="\\" elseif e=="/" then out[#out+1]="/" else out[#out+1]=e end
    else out[#out+1]=c end
    i=i+1
  end
end

local function response_output_text(raw)
  local pos=1
  while true do
    local s,e=raw:find('"type"%s*:%s*"output_text"',pos)
    if not s then return nil end
    local next_type=raw:find('"type"%s*:',e+1)
    local block_end=next_type and next_type-1 or #raw
    local ts,te=raw:find('"text"%s*:',e+1)
    if ts and ts<=block_end then
      local q=raw:find('"',te+1,true)
      if q and q<=block_end then local t=read_json_string(raw,q); if t and t~="" then return t end end
    end
    pos=e+1
  end
end

local function get_api_key()
  local key=trim(reaper.GetExtState(EXT_SECTION,EXT_KEY))
  if key~="" then return key end
  local ok,v=reaper.GetUserInputs(SCRIPT_NAME.." – Ersteinrichtung",1,"OpenAI API-Key:,extrawidth=320","")
  if not ok then return nil end
  key=trim(v); if key=="" then return nil end
  reaper.SetExtState(EXT_SECTION,EXT_KEY,key,true); return key
end

local function get_guid(item) local ok,g=reaper.GetSetMediaItemInfo_String(item,"GUID","",false); return ok and g or "" end

local function selected_midi_items()
  local items={}
  for i=0,reaper.CountSelectedMediaItems(0)-1 do
    local item=reaper.GetSelectedMediaItem(0,i); local take=item and reaper.GetActiveTake(item)
    if take and reaper.TakeIsMIDI(take) then
      local track=reaper.GetMediaItem_Track(item); local _,tn=reaper.GetTrackName(track); local _,kn=reaper.GetSetMediaItemTakeInfo_String(take,"P_NAME","",false)
      local _,count=reaper.MIDI_CountEvts(take); local notes={}
      for n=0,(count or 0)-1 do
        local ok,_,muted,sppq,eppq,ch,pitch,vel=reaper.MIDI_GetNote(take,n)
        if ok and not muted then
          local st=reaper.MIDI_GetProjTimeFromPPQPos(take,sppq); local et=reaper.MIDI_GetProjTimeFromPPQPos(take,eppq)
          local sq=reaper.TimeMap2_timeToQN(0,st); local eq=reaper.TimeMap2_timeToQN(0,et)
          notes[#notes+1]={start_qn=sq,duration_qn=eq-sq,pitch=pitch,velocity=vel,channel=ch}
        end
      end
      items[#items+1]={item=item,track=track,guid=get_guid(item),track_name=tn~="" and tn or "Unbenannte Spur",take_name=kn~="" and kn or "Unbenanntes MIDI-Item",notes=notes}
    end
  end
  return items
end

local function context_text(items)
  local l={string.format("Tempo %.3f BPM",reaper.Master_GetTempo())}
  if #items==0 then l[#l+1]="KEIN MIDI-MATERIAL AUSGEWÄHLT."
  else
    for i,it in ipairs(items) do
      l[#l+1]=string.format("ITEM %d id=%s track=%s take=%s",i,it.guid,it.track_name,it.take_name)
      for _,n in ipairs(it.notes) do l[#l+1]=string.format("N %.5f %.5f %d %d %d",n.start_qn,n.duration_qn,n.pitch,n.velocity,n.channel) end
    end
  end
  return table.concat(l,"\n")
end

local function recent_dialog()
  local l={}
  local first=math.max(1,#history-7)
  for i=first,#history do l[#l+1]=history[i].role..": "..history[i].text end
  return table.concat(l,"\n")
end

local function build_prompt(request,music)
  return [[Du bist der musikalische Dialogpartner von Composition Studio in REAPER.
Du kannst mit dem Benutzer normal über Musik sprechen, Fragen beantworten und Kompositionsaufträge ausführen.
Nutze ausgewähltes MIDI als musikalischen Kontext. Füge keine unnötigen musikalischen Regeln hinzu.

Wenn nur eine Gesprächsantwort nötig ist, antworte genau so:
CHAT|deine normale Antwort

Wenn Musik erzeugt oder überarbeitet werden soll, antworte ausschließlich mit einer oder mehreren technischen Ergebniszeilen:
CS|unchanged|SOURCE_GUID
CS|revised|SOURCE_GUID|NAME|startQN,durationQN,pitch,velocity,channel;...
CS|new|-|NAME|startQN,durationQN,pitch,velocity,channel;...

Für revised muss SOURCE_GUID exakt eine angebotene Item-GUID sein. Für new ist SOURCE_GUID '-'.
Wenn kein MIDI ausgewählt ist und komponiert werden soll, verwende CS|new.
startQN>=0, durationQN>0, pitch 0..127, velocity 1..127, channel 0..15. NAME darf kein | enthalten.

BISHERIGER DIALOG:
]]..recent_dialog().."\n\nAKTUELLER AUFTRAG:\n"..request.."\n\nAUSGEWÄHLTE MUSIK:\n"..music
end

local function run_openai(prompt,key)
  local base=os.tmpname(); local req,res,code=base..".json",base..".out",base..".code"
  local body='{"model":"gpt-5.6","input":"'..json_escape(prompt)..'"}'
  if not write_file(req,body) then return nil,"Temporäre Anfrage konnte nicht geschrieben werden." end
  local cmd="/usr/bin/curl -sS --max-time 120 -o "..shell_quote(res).." -w '%{http_code}' -H "..shell_quote("Authorization: Bearer "..key).." -H 'Content-Type: application/json' --data-binary @"..shell_quote(req).." https://api.openai.com/v1/responses > "..shell_quote(code)
  os.execute(cmd)
  local status=trim(read_file(code)); local raw=read_file(res); os.remove(req); os.remove(res); os.remove(code)
  if status~="200" or not raw then return nil,"KI-Aufruf fehlgeschlagen (HTTP "..tostring(status)..")." end
  local text=response_output_text(raw); if not text then return nil,"Keine Textantwort der KI gefunden." end
  return text
end

local function parse_notes(text)
  local notes={}
  for token in (text or ""):gmatch("[^;]+") do
    local a,b,c,d,e=token:match("^%s*([%d%.%-]+),([%d%.%-]+),(%d+),(%d+),(%d+)%s*$")
    a,b,c,d,e=tonumber(a),tonumber(b),tonumber(c),tonumber(d),tonumber(e)
    if not(a and b and c and d and e) or a<0 or b<=0 or c<0 or c>127 or d<1 or d>127 or e<0 or e>15 then return nil end
    notes[#notes+1]={start_qn=a,duration_qn=b,pitch=c,velocity=d,channel=e}
  end
  return #notes>0 and notes or nil
end

local function parse_results(text,items)
  local sources={}; for _,it in ipairs(items) do sources[it.guid]=it end
  local results={}; text=(text or ""):gsub("```[%w_-]*",""):gsub("```","")
  for line in text:gmatch("[^\r\n]+") do
    line=trim(line)
    if line~="" then
      local kind,source,rest=line:match("^CS|([^|]+)|([^|]+)|?(.*)$")
      if not kind then return nil,"Unerwartete KI-Antwort." end
      if kind=="unchanged" then
        if not sources[source] then return nil,"Unbekannte Quelle." end
        results[#results+1]={kind=kind,source=source}
      elseif kind=="revised" or kind=="new" then
        if kind=="revised" and not sources[source] then return nil,"Unbekannte Quelle." end
        if kind=="new" and source~="-" then return nil,"Ungültige neue Stimme." end
        local name,nt=rest:match("^([^|]+)|(.+)$"); local notes=parse_notes(nt)
        if not name or not notes then return nil,"Ungültige Notendaten." end
        results[#results+1]={kind=kind,source=source,name=trim(name),notes=notes}
      else return nil,"Unbekannter Ergebnistyp." end
    end
  end
  return #results>0 and results or nil,"Leere KI-Antwort."
end

local function qn_to_time(qn) return reaper.TimeMap2_QNToTime(0,qn) end
local function create_track(name,index)
  index=index or reaper.CountTracks(0); reaper.InsertTrackAtIndex(index,true); local t=reaper.GetTrack(0,index)
  if t then reaper.GetSetMediaTrackInfo_String(t,"P_NAME",name,true) end return t
end
local function create_midi_item(track,name,notes)
  local lo,hi=math.huge,-math.huge
  for _,n in ipairs(notes) do lo=math.min(lo,n.start_qn); hi=math.max(hi,n.start_qn+n.duration_qn) end
  if lo==math.huge or hi<=lo then return nil end
  local item=reaper.CreateNewMIDIItemInProj(track,qn_to_time(lo),qn_to_time(hi),false); if not item then return nil end
  local take=reaper.GetActiveTake(item); if not take then return nil end
  reaper.GetSetMediaItemTakeInfo_String(take,"P_NAME",name,true)
  for _,n in ipairs(notes) do
    local s=reaper.MIDI_GetPPQPosFromProjTime(take,qn_to_time(n.start_qn)); local e=reaper.MIDI_GetPPQPosFromProjTime(take,qn_to_time(n.start_qn+n.duration_qn))
    reaper.MIDI_InsertNote(take,false,false,s,e,n.channel,n.pitch,n.velocity,true)
  end
  reaper.MIDI_Sort(take); return item
end

local function apply_results(results,items)
  local sources={}; for _,it in ipairs(items) do sources[it.guid]=it end
  local created={}; reaper.Undo_BeginBlock2(0); reaper.PreventUIRefresh(1)
  local ok,err=xpcall(function()
    for _,r in ipairs(results) do
      if r.kind=="revised" then
        local src=sources[r.source]; local track_no=math.floor(reaper.GetMediaTrackInfo_Value(src.track,"IP_TRACKNUMBER")); local name=r.name.." [Variante]"
        local tr=create_track(name,track_no); local item=create_midi_item(tr,name,r.notes); if not item then error("MIDI-Item konnte nicht erzeugt werden") end; created[#created+1]=item
      elseif r.kind=="new" then
        local tr=create_track(r.name); local item=create_midi_item(tr,r.name,r.notes); if not item then error("MIDI-Item konnte nicht erzeugt werden") end; created[#created+1]=item
      end
    end
  end,debug.traceback)
  reaper.PreventUIRefresh(-1)
  if not ok then reaper.Undo_EndBlock2(0,"Composition Studio – fehlgeschlagen",-1); reaper.Undo_DoUndo2(0); return nil,err end
  if #created>0 then
    for i=0,reaper.CountMediaItems(0)-1 do reaper.SetMediaItemSelected(reaper.GetMediaItem(0,i),false) end
    for _,it in ipairs(created) do reaper.SetMediaItemSelected(it,true) end
  end
  reaper.UpdateArrange(); reaper.Undo_EndBlock2(0,"Composition Studio – KI-Komposition",-1)
  return created
end

local function add_message(role,text) history[#history+1]={role=role,text=text} end

local function process_request(request)
  local key=get_api_key(); if not key then add_message("KI","Kein OpenAI API-Key verfügbar."); return end
  local items=selected_midi_items()
  local answer,err=run_openai(build_prompt(request,context_text(items)),key)
  if not answer then add_message("KI",err); return end
  local chat=answer:match("^%s*CHAT|(.*)$")
  if chat then add_message("KI",trim(chat)); return end
  local results,perr=parse_results(answer,items)
  if not results then add_message("KI","Die Antwort konnte nicht sicher angewendet werden: "..tostring(perr)); return end
  local created,aerr=apply_results(results,items)
  if not created then add_message("KI","Das Ergebnis konnte nicht angewendet werden: "..tostring(aerr)); return end
  if #created==0 then add_message("KI","Ich habe keine neue oder überarbeitete Stimme erzeugt. Das vorhandene Material blieb unverändert.")
  else add_message("KI",string.format("Erledigt. %d neues bzw. überarbeitetes MIDI-Item wurde in REAPER erzeugt. Das Original blieb erhalten.",#created)) end
end

local function submit()
  local request=trim(input); if request=="" or busy then return end
  input=""; add_message("Du",request); busy=true
  process_request(request)
  busy=false
end

local function draw_history()
  for _,m in ipairs(history) do
    reaper.ImGui_TextWrapped(ctx,m.role..": "..m.text)
    reaper.ImGui_Spacing(ctx)
  end
end

local function loop()
  if not open then return end
  reaper.ImGui_SetNextWindowSize(ctx,520,700,reaper.ImGui_Cond_FirstUseEver())
  local visible; visible,open=reaper.ImGui_Begin(ctx,SCRIPT_NAME.."  "..VERSION,open)
  if visible then
    local pushed=push_font()
    local items=selected_midi_items()
    reaper.ImGui_Text(ctx,string.format("GPT-5.6  |  %d MIDI-Item(s) ausgewählt",#items))
    reaper.ImGui_Separator(ctx)
    local avail_w,avail_h=reaper.ImGui_GetContentRegionAvail(ctx)
    local input_h=150; local button_h=38; local chat_h=math.max(120,avail_h-input_h-button_h-40)
    if reaper.ImGui_BeginChild(ctx,"##chat",avail_w,chat_h,reaper.ImGui_ChildFlags_Borders()) then draw_history(); reaper.ImGui_EndChild(ctx) end
    reaper.ImGui_Spacing(ctx)
    local changed,new_input=reaper.ImGui_InputTextMultiline(ctx,"##composition_request",input,avail_w,input_h)
    if changed then input=new_input end
    reaper.ImGui_Spacing(ctx)
    if reaper.ImGui_Button(ctx,busy and "Bitte warten…" or "Senden",120,button_h) and not busy then submit() end
    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_Button(ctx,"Schließen",120,button_h) then open=false end
    pop_font(pushed)
    reaper.ImGui_End(ctx)
  end
  if open then reaper.defer(loop) end
end

loop()
