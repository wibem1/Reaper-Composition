-- @description Composition Studio Basic
-- @version 0.1-test6
-- @author Klangwerke
-- @about First end-to-end test: selected REAPER MIDI -> OpenAI -> new MIDI in REAPER.

local SCRIPT_NAME = "Composition Studio Basic"
local VERSION = "0.1-test6"
local EXT_SECTION, EXT_KEY = "CompositionStudio", "OpenAIAPIKey"

local function trim(s) return (s or ""):gsub("^%s+",""):gsub("%s+$","") end
local function shell_quote(s) return "'"..tostring(s):gsub("'","'\\''").."'" end
local function json_escape(s) return tostring(s or ""):gsub("\\","\\\\"):gsub('"','\\"'):gsub("\n","\\n"):gsub("\r","\\r"):gsub("\t","\\t") end
local function read_file(p) local f=io.open(p,"rb"); if not f then return nil end; local s=f:read("*a"); f:close(); return s end
local function write_file(p,s) local f=io.open(p,"wb"); if not f then return false end; f:write(s); f:close(); return true end

local function read_json_string(raw, quote_pos)
  if not raw or raw:sub(quote_pos,quote_pos) ~= '"' then return nil end
  local out,i={},quote_pos+1
  while i<=#raw do
    local c=raw:sub(i,i)
    if c=='"' then return table.concat(out) end
    if c=="\\" then
      i=i+1; local e=raw:sub(i,i)
      if e=="n" then out[#out+1]="\n" elseif e=="r" then out[#out+1]="\r" elseif e=="t" then out[#out+1]="\t"
      elseif e=='"' then out[#out+1]='"' elseif e=="\\" then out[#out+1]="\\" elseif e=="/" then out[#out+1]="/"
      elseif e=="b" then out[#out+1]="\b" elseif e=="f" then out[#out+1]="\f" else out[#out+1]=e end
    else out[#out+1]=c end
    i=i+1
  end
end

local function response_output_text(raw)
  local pos=1
  while true do
    local ts,te=raw:find('"type"%s*:%s*"output_text"',pos)
    if not ts then return nil end
    local next_type=raw:find('"type"%s*:',te+1)
    local block_end=next_type and (next_type-1) or #raw
    local text_s,text_e=raw:find('"text"%s*:',te+1)
    if text_s and text_s<=block_end then
      local quote=raw:find('"',text_e+1,true)
      if quote and quote<=block_end then
        local text=read_json_string(raw,quote)
        if text and text~="" then return text end
      end
    end
    pos=te+1
  end
end

local function get_guid(item) local ok,g=reaper.GetSetMediaItemInfo_String(item,"GUID","",false); return ok and g or "" end
local function get_api_key()
  local key=trim(reaper.GetExtState(EXT_SECTION,EXT_KEY)); if key~="" then return key end
  local ok,input=reaper.GetUserInputs(SCRIPT_NAME.." – Ersteinrichtung",1,"OpenAI API-Key:,extrawidth=320","")
  if not ok then return nil,"API-Key-Eingabe abgebrochen." end
  key=trim(input); if key=="" then return nil,"Kein API-Key eingegeben." end
  reaper.SetExtState(EXT_SECTION,EXT_KEY,key,true); return key
end

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
      items[#items+1]={item=item,take=take,track=track,guid=get_guid(item),track_name=tn~="" and tn or "Unbenannte Spur",take_name=kn~="" and kn or "Unbenanntes MIDI-Item",notes=notes}
    end
  end
  return items
end

local function context_text(items)
  local l={string.format("Tempo %.3f BPM",reaper.Master_GetTempo())}
  for i,it in ipairs(items) do
    l[#l+1]=string.format("ITEM %d id=%s track=%s take=%s",i,it.guid,it.track_name,it.take_name)
    for _,n in ipairs(it.notes) do l[#l+1]=string.format("N %.5f %.5f %d %d %d",n.start_qn,n.duration_qn,n.pitch,n.velocity,n.channel) end
  end
  return table.concat(l,"\n")
end

local function build_prompt(request,music)
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
]]..request.."\n\nMUSIK:\n"..music
end

local function parse_notes(text)
  local notes={}
  for token in (text or ""):gmatch("[^;]+") do
    local a,b,c,d,e=token:match("^%s*([%d%.%-]+),([%d%.%-]+),(%d+),(%d+),(%d+)%s*$"); a,b,c,d,e=tonumber(a),tonumber(b),tonumber(c),tonumber(d),tonumber(e)
    if not(a and b and c and d and e) then return nil,"Ungueltige Note: "..token end
    if a<0 or b<=0 or c<0 or c>127 or d<1 or d>127 or e<0 or e>15 then return nil,"Note ausserhalb gueltiger Grenzen." end
    notes[#notes+1]={start_qn=a,duration_qn=b,pitch=c,velocity=d,channel=e}
  end
  if #notes==0 then return nil,"Leere Notenliste." end; return notes
end

local function validate_response(text,items)
  local sources={}; for _,it in ipairs(items) do sources[it.guid]=it end; local results={}
  text=(text or ""):gsub("```[%w_-]*",""):gsub("```","")
  for line in text:gmatch("[^\r\n]+") do
    line=trim(line)
    if line~="" then
      local kind,source,rest=line:match("^CS|([^|]+)|([^|]+)|?(.*)$"); if not kind then return nil,"Unerwartete KI-Zeile: "..line end
      if kind=="unchanged" then if not sources[source] then return nil,"Unbekannte unchanged-Quelle." end; results[#results+1]={kind=kind,source=source}
      elseif kind=="revised" or kind=="new" then
        if kind=="revised" and not sources[source] then return nil,"Unbekannte revised-Quelle." end; if kind=="new" and source~="-" then return nil,"new muss Quelle '-' verwenden." end
        local name,nt=rest:match("^([^|]+)|(.+)$"); name=trim(name); if not name or name=="" then return nil,"Ergebnisname fehlt." end
        local notes,err=parse_notes(nt); if not notes then return nil,err end; results[#results+1]={kind=kind,source=source,name=name,notes=notes}
      else return nil,"Unbekannter Ergebnistyp: "..tostring(kind) end
    end
  end
  if #results==0 then return nil,"Leere KI-Antwort." end; return results
end

local function run_openai(prompt,key)
  local base=os.tmpname(); local req,res,code=base..".json",base..".out",base..".code"
  local body='{"model":"gpt-5.6","input":"'..json_escape(prompt)..'"}'; if not write_file(req,body) then return nil,"Temporäre Anfrage konnte nicht geschrieben werden." end
  local cmd="/usr/bin/curl -sS --max-time 120 -o "..shell_quote(res).." -w '%{http_code}' -H "..shell_quote("Authorization: Bearer "..key).." -H 'Content-Type: application/json' --data-binary @"..shell_quote(req).." https://api.openai.com/v1/responses > "..shell_quote(code)
  os.execute(cmd); local status=trim(read_file(code)); local raw=read_file(res); os.remove(req);os.remove(res);os.remove(code)
  if status~="200" or not raw then return nil,"KI-Aufruf fehlgeschlagen (HTTP "..tostring(status)..")." end
  local text=response_output_text(raw); if not text then return nil,"Keine Textantwort der KI gefunden." end; return text
end

local function qn_to_time(qn) return reaper.TimeMap2_QNToTime(0,qn) end
local function create_midi_item(track,name,notes)
  local lo,hi=math.huge,-math.huge; for _,n in ipairs(notes) do lo=math.min(lo,n.start_qn); hi=math.max(hi,n.start_qn+n.duration_qn) end
  if lo==math.huge or hi<=lo then return nil,"Ungueltiger musikalischer Bereich." end
  local item=reaper.CreateNewMIDIItemInProj(track,qn_to_time(lo),qn_to_time(hi),false); if not item then return nil,"MIDI-Item konnte nicht erzeugt werden." end
  local take=reaper.GetActiveTake(item); if not take then return nil,"MIDI-Take konnte nicht erzeugt werden." end; reaper.GetSetMediaItemTakeInfo_String(take,"P_NAME",name,true)
  for _,n in ipairs(notes) do local s=reaper.MIDI_GetPPQPosFromProjTime(take,qn_to_time(n.start_qn)); local e=reaper.MIDI_GetPPQPosFromProjTime(take,qn_to_time(n.start_qn+n.duration_qn)); reaper.MIDI_InsertNote(take,false,false,s,e,n.channel,n.pitch,n.velocity,true) end
  reaper.MIDI_Sort(take); return item
end
local function create_track(name) local i=reaper.CountTracks(0); reaper.InsertTrackAtIndex(i,true); local t=reaper.GetTrack(0,i); if t then reaper.GetSetMediaTrackInfo_String(t,"P_NAME",name,true) end; return t end

local function apply_results(results,items)
  local sources={}; for _,it in ipairs(items) do sources[it.guid]=it end; local created={}; reaper.Undo_BeginBlock2(0); reaper.PreventUIRefresh(1)
  local ok,err=xpcall(function()
    for _,r in ipairs(results) do
      if r.kind=="revised" then local src=sources[r.source]; local item,why=create_midi_item(src.track,r.name.." [Variante]",r.notes); if not item then error(why) end; created[#created+1]=item
      elseif r.kind=="new" then local tr=create_track(r.name); if not tr then error("Neue Spur konnte nicht erzeugt werden.") end; local item,why=create_midi_item(tr,r.name,r.notes); if not item then error(why) end; created[#created+1]=item end
    end
  end,debug.traceback)
  reaper.PreventUIRefresh(-1); if not ok then reaper.Undo_EndBlock2(0,"Composition Studio – fehlgeschlagen",-1); reaper.Undo_DoUndo2(0); return nil,err end
  if #created>0 then for i=0,reaper.CountMediaItems(0)-1 do reaper.SetMediaItemSelected(reaper.GetMediaItem(0,i),false) end; for _,it in ipairs(created) do reaper.SetMediaItemSelected(it,true) end end
  reaper.UpdateArrange(); reaper.Undo_EndBlock2(0,"Composition Studio – KI-Komposition",-1); return created
end

local function process_request(items,request)
  local key,kerr=get_api_key(); if not key then reaper.ShowMessageBox(kerr,SCRIPT_NAME,0); return end
  local answer,aerr=run_openai(build_prompt(request,context_text(items)),key); if not answer then reaper.ShowMessageBox("KI-Aufruf nicht ausgeführt:\n\n"..aerr.."\n\nDas REAPER-Projekt wurde nicht verändert.",SCRIPT_NAME.." "..VERSION,0); return end
  local results,verr=validate_response(answer,items); if not results then reaper.ShowMessageBox("KI-Antwort verworfen:\n\n"..verr.."\n\nDas REAPER-Projekt wurde nicht verändert.",SCRIPT_NAME.." "..VERSION,0); return end
  local created,cerr=apply_results(results,items); if not created then reaper.ShowMessageBox("Ergebnis konnte nicht angewendet werden:\n\n"..tostring(cerr),SCRIPT_NAME.." "..VERSION,0); return end
  if #created==0 then reaper.ShowMessageBox("Die KI hat keine neue oder überarbeitete Stimme erzeugt.\nDie ursprüngliche Auswahl bleibt erhalten.",SCRIPT_NAME.." "..VERSION,0) else reaper.ShowMessageBox(string.format("%d neues/überarbeitetes MIDI-Item(s) erzeugt.\n\nOriginale blieben erhalten. Neue Items sind ausgewählt.\nDer Vorgang ist ein REAPER-Undo-Schritt.",#created),SCRIPT_NAME.." "..VERSION,0) end
end

-- Normales natives Eingabefeld als sichere Rückfallebene: Cursor, Auswahl und Zwischenablage funktionieren.
local function ask_request_native(n, on_submit)
  local ok, text = reaper.GetUserInputs(
    SCRIPT_NAME.." "..VERSION,
    1,
    string.format("%d MIDI-Item(s) erkannt. Freier Kompositionsauftrag:,extrawidth=520", n),
    ""
  )
  if not ok then return end
  text=trim(text)
  if text~="" then on_submit(text) end
end

-- ReaImGui liefert ein echtes mehrzeiliges Textfeld mit Cursor, Auswahl und Cmd-C/Cmd-V.
local function ask_request_imgui(n, on_submit)
  local ctx = reaper.ImGui_CreateContext(SCRIPT_NAME)
  local text = ""
  local open = true
  local first_frame = true
  local font = nil

  if reaper.ImGui_CreateFont and reaper.ImGui_Attach then
    font = reaper.ImGui_CreateFont("sans-serif", 20)
    reaper.ImGui_Attach(ctx, font)
  end

  local function finish(request)
    open=false
    if request and trim(request)~="" then on_submit(trim(request)) end
  end

  local function loop()
    if not open then return end

    if first_frame then
      reaper.ImGui_SetNextWindowSize(ctx, 760, 300, reaper.ImGui_Cond_FirstUseEver())
      first_frame=false
    end

    local visible
    visible, open = reaper.ImGui_Begin(ctx, SCRIPT_NAME.." "..VERSION, open)
    if visible then
      if font and reaper.ImGui_PushFont then reaper.ImGui_PushFont(ctx, font) end

      reaper.ImGui_Text(ctx, string.format("%d MIDI-Item(s) erkannt", n))
      reaper.ImGui_Spacing(ctx)
      reaper.ImGui_Text(ctx, "Freier Kompositionsauftrag:")
      local changed
      changed, text = reaper.ImGui_InputTextMultiline(ctx, "##composition_request", text, -1, 150)

      reaper.ImGui_Spacing(ctx)
      if reaper.ImGui_Button(ctx, "Komponieren", 150, 40) and trim(text)~="" then
        if font and reaper.ImGui_PopFont then reaper.ImGui_PopFont(ctx) end
        reaper.ImGui_End(ctx)
        finish(text)
        return
      end
      reaper.ImGui_SameLine(ctx)
      if reaper.ImGui_Button(ctx, "Abbrechen", 120, 40) then
        if font and reaper.ImGui_PopFont then reaper.ImGui_PopFont(ctx) end
        reaper.ImGui_End(ctx)
        open=false
        return
      end

      if font and reaper.ImGui_PopFont then reaper.ImGui_PopFont(ctx) end
      reaper.ImGui_End(ctx)
    end

    if open then reaper.defer(loop) end
  end

  loop()
end

-- Sofortiger Vorabtest: ohne Auswahl wird kein Eingabefenster geöffnet.
if reaper.CountSelectedMediaItems(0)==0 then
  reaper.ShowMessageBox("Keine ausgewählten MIDI-Items.\n\nWähle ein oder mehrere MIDI-Items aus.",SCRIPT_NAME.." "..VERSION,0)
  return
end

local items=selected_midi_items()
if #items==0 then
  reaper.ShowMessageBox("Unter der Auswahl befindet sich kein MIDI-Item.\n\nWähle ein oder mehrere MIDI-Items aus.",SCRIPT_NAME.." "..VERSION,0)
  return
end

local function submit(request)
  process_request(items,request)
end

if reaper.ImGui_CreateContext and reaper.ImGui_InputTextMultiline then
  ask_request_imgui(#items, submit)
else
  ask_request_native(#items, submit)
end