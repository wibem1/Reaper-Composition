-- @description Composition Studio Basic
-- @version 0.1-dev
-- @author Klangwerke
-- @about Recursive AI composition directly inside REAPER. Composition Lab is not a runtime dependency.

local SCRIPT_NAME, VERSION = "Composition Studio Basic", "0.1-dev"
local EXT_SECTION, EXT_KEY = "CompositionStudio", "OpenAIAPIKey"

local function round(n,p) local m=10^(p or 3); return math.floor(n*m+0.5)/m end
local function trim(s) return (s or ""):gsub("^%s+",""):gsub("%s+$","") end
local function shell_quote(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end
local function json_escape(s) return tostring(s or ""):gsub("\\","\\\\"):gsub('"','\\"'):gsub("\b","\\b"):gsub("\f","\\f"):gsub("\n","\\n"):gsub("\r","\\r"):gsub("\t","\\t") end
local function read_file(path) local f=io.open(path,"rb"); if not f then return nil end; local s=f:read("*a"); f:close(); return s end
local function write_file(path,s) local f=io.open(path,"wb"); if not f then return false end; f:write(s); f:close(); return true end
local function remove_file(path) if path then os.remove(path) end end
local function guid(obj,take)
  local ok,g
  if take then ok,g=reaper.GetSetMediaItemTakeInfo_String(obj,"GUID","",false) else ok,g=reaper.GetSetMediaItemInfo_String(obj,"GUID","",false) end
  return ok and g or ""
end

-- Basic key storage: local REAPER ExtState only, never GitHub/project files.
-- This is convenience storage, not macOS Keychain encryption. Comfort version can upgrade it later.
local function get_api_key()
  local key=trim(reaper.GetExtState(EXT_SECTION,EXT_KEY))
  if key~="" then return key end
  local ok,input=reaper.GetUserInputs(SCRIPT_NAME.." – Ersteinrichtung",1,"OpenAI API-Key:,extrawidth=320","")
  if not ok then return nil,"API-Key-Eingabe abgebrochen" end
  key=trim(input)
  if key=="" then return nil,"Kein API-Key eingegeben" end
  if not key:match("^sk%-") then
    local answer=reaper.ShowMessageBox("Der eingegebene Schlüssel sieht nicht wie ein OpenAI API-Key aus. Trotzdem lokal speichern?",SCRIPT_NAME,4)
    if answer~=6 then return nil,"API-Key nicht gespeichert" end
  end
  reaper.SetExtState(EXT_SECTION,EXT_KEY,key,true)
  return key
end

local function selected_midi_items()
  local out={}
  for i=0,reaper.CountSelectedMediaItems(0)-1 do
    local item=reaper.GetSelectedMediaItem(0,i); local take=item and reaper.GetActiveTake(item)
    if take and reaper.TakeIsMIDI(take) then
      local track=reaper.GetMediaItem_Track(item); local _,tn=reaper.GetTrackName(track); local _,kn=reaper.GetSetMediaItemTakeInfo_String(take,"P_NAME","",false)
      local pos=reaper.GetMediaItemInfo_Value(item,"D_POSITION"); local len=reaper.GetMediaItemInfo_Value(item,"D_LENGTH")
      local _,nc,cc,tx=reaper.MIDI_CountEvts(take); local notes={}
      for n=0,(nc or 0)-1 do
        local ok,_,muted,sppq,eppq,ch,pitch,vel=reaper.MIDI_GetNote(take,n)
        if ok then
          local st=reaper.MIDI_GetProjTimeFromPPQPos(take,sppq); local et=reaper.MIDI_GetProjTimeFromPPQPos(take,eppq)
          local sq=reaper.TimeMap2_timeToQN(0,st); local eq=reaper.TimeMap2_timeToQN(0,et)
          notes[#notes+1]={start_qn=round(sq,5),duration_qn=round(eq-sq,5),pitch=pitch,velocity=vel,channel=ch,muted=muted and true or false}
        end
      end
      out[#out+1]={item=item,take=take,track=track,item_guid=guid(item,false),take_guid=guid(take,true),track_name=tn~="" and tn or "Unbenannte Spur",take_name=kn~="" and kn or "Unbenanntes MIDI-Item",position=pos,length=len,start_qn=round(reaper.TimeMap2_timeToQN(0,pos),5),end_qn=round(reaper.TimeMap2_timeToQN(0,pos+len),5),notes=notes,note_count=nc or 0,cc_count=cc or 0,text_count=tx or 0}
    end
  end
  return out
end

local function context_text(items)
  local bpm=reaper.Master_GetTempo(); local _,num,den=reaper.TimeMap_GetTimeSigAtTime(0,items[1].position)
  local L={string.format("Tempo %.3f BPM; Takt %d/%d",bpm,num or 4,den or 4)}
  for i,v in ipairs(items) do
    L[#L+1]=string.format("ITEM %d id=%s track=%s take=%s range_qn=%.5f..%.5f",i,v.item_guid,v.track_name,v.take_name,v.start_qn,v.end_qn)
    for _,n in ipairs(v.notes) do L[#L+1]=string.format("N %.5f %.5f %d %d %d",n.start_qn,n.duration_qn,n.pitch,n.velocity,n.channel) end
  end
  return table.concat(L,"\n")
end

local function ask_request(n)
  local ok,s=reaper.GetUserInputs(SCRIPT_NAME.." "..VERSION,1,string.format("%d MIDI-Item(s) erkannt. Freier Kompositionsauftrag:,extrawidth=420",n),"")
  s=trim(s); if not ok or s=="" then return nil end; return s
end

local function build_prompt(request,music)
  return [[Du komponierst Musik. Nutze das übergebene Material als gemeinsamen musikalischen Kontext und erfülle den freien Auftrag musikalisch eigenständig. Füge keine unnötigen Regeln hinzu.
Antworte ausschließlich mit technischen Ergebniszeilen:
CS|unchanged|SOURCE_GUID
CS|revised|SOURCE_GUID|NAME|startQN,durationQN,pitch,velocity,channel;...
CS|new|-|NAME|startQN,durationQN,pitch,velocity,channel;...
Für revised muss SOURCE_GUID exakt eine angebotene Item-GUID sein. Für new ist SOURCE_GUID '-'. Werte: startQN>=0, durationQN>0, pitch 0..127, velocity 1..127, channel 0..15. NAME darf kein | enthalten. Gib nur tatsächlich benötigte Ergebniszeilen zurück. Eine überarbeitete Stimme soll musikalisch an der Lage des Quellmaterials orientiert bleiben, sofern der Auftrag nichts anderes verlangt.

AUFTRAG:
]]..request.."\n\nMUSIK:\n"..music
end

local function source_map(items) local t={}; for _,v in ipairs(items) do t[v.item_guid]=v end; return t end
local function parse_notes(s)
  local notes={}; if not s or s=="" then return nil,"Notenliste fehlt" end
  for token in s:gmatch("[^;]+") do
    local a,b,c,d,e=token:match("^%s*([%d%.%-]+),([%d%.%-]+),(%d+),(%d+),(%d+)%s*$")
    a,b,c,d,e=tonumber(a),tonumber(b),tonumber(c),tonumber(d),tonumber(e)
    if not(a and b and c and d and e) then return nil,"Ungültige Note: "..token end
    if a<0 or b<=0 or c<0 or c>127 or d<1 or d>127 or e<0 or e>15 then return nil,"Note außerhalb gültiger Grenzen" end
    notes[#notes+1]={start_qn=a,duration_qn=b,pitch=c,velocity=d,channel=e}; if #notes>10000 then return nil,"Zu viele Noten" end
  end
  if #notes==0 then return nil,"Leere Notenliste" end; return notes
end
local function validate_response(text,items)
  local sources=source_map(items); local out={}; local seen={}
  text=(text or ""):gsub("```[%w_-]*",""):gsub("```","")
  for line in text:gmatch("[^\r\n]+") do
    line=trim(line)
    if line~="" then
      local kind,source,rest=line:match("^CS|([^|]+)|([^|]+)|?(.*)$"); if not kind then return nil,"Unerwartete Antwortzeile: "..line end
      if kind=="unchanged" then
        if not sources[source] or rest~="" then return nil,"Ungültige unchanged-Zuordnung" end; out[#out+1]={kind=kind,source=source}
      elseif kind=="revised" or kind=="new" then
        if kind=="revised" then if not sources[source] then return nil,"Unbekannte Quelle für revised" end; if seen[source] then return nil,"Quelle mehrfach revised" end; seen[source]=true elseif source~="-" then return nil,"new muss Quelle '-' verwenden" end
        local name,nstr=rest:match("^([^|]+)|(.+)$"); name=trim(name); if not name or name=="" then return nil,"Ergebnisname fehlt" end
        local notes,err=parse_notes(nstr); if not notes then return nil,err end; out[#out+1]={kind=kind,source=source,name=name,notes=notes}
      else return nil,"Unbekannter Ergebnistyp: "..tostring(kind) end
    end
  end
  if #out==0 then return nil,"Leere KI-Antwort" end; return out
end

local function run_openai(prompt,key)
  local tmp=os.tmpname(); local req=tmp..".json"; local resp=tmp..".out"; local codef=tmp..".code"
  local body='{"model":"gpt-5.6","input":"'..json_escape(prompt)..'"}'
  if not write_file(req,body) then return nil,"Temporäre Anfrage konnte nicht geschrieben werden" end
  local cmd="/usr/bin/curl -sS --max-time 120 -o "..shell_quote(resp).." -w '%{http_code}' -H "..shell_quote("Authorization: Bearer "..key).." -H 'Content-Type: application/json' --data-binary @"..shell_quote(req).." https://api.openai.com/v1/responses > "..shell_quote(codef)
  local ok=os.execute(cmd); local status=trim(read_file(codef)); local raw=read_file(resp); remove_file(req);remove_file(resp);remove_file(codef)
  if not ok or status~="200" or not raw then return nil,"KI-Aufruf fehlgeschlagen (HTTP "..tostring(status)..")" end
  local encoded=raw:match('"type"%s*:%s*"output_text".-"text"%s*:%s*"(([^"\\]|\\.)*)"'); if not encoded then return nil,"Keine Textantwort der KI gefunden" end
  encoded=encoded:gsub('\\n','\n'):gsub('\\r','\r'):gsub('\\t','\t'):gsub('\\"','"'):gsub('\\\\','\\'); return encoded
end

local function qn_to_time(qn) return reaper.TimeMap2_QNToTime(0,qn) end
local function note_bounds(notes) local lo,hi=math.huge,-math.huge; for _,n in ipairs(notes) do lo=math.min(lo,n.start_qn); hi=math.max(hi,n.start_qn+n.duration_qn) end; return lo,hi end
local function create_midi_item(track,name,notes)
  local lo,hi=note_bounds(notes); if lo==math.huge or hi<=lo then return nil,"Ungültiger musikalischer Bereich" end
  local item=reaper.CreateNewMIDIItemInProj(track,qn_to_time(lo),qn_to_time(hi),false); if not item then return nil,"MIDI-Item konnte nicht erzeugt werden" end
  local take=reaper.GetActiveTake(item); if not take then reaper.DeleteTrackMediaItem(track,item); return nil,"MIDI-Take konnte nicht erzeugt werden" end
  reaper.GetSetMediaItemTakeInfo_String(take,"P_NAME",name,true)
  for _,n in ipairs(notes) do
    local sppq=reaper.MIDI_GetPPQPosFromProjTime(take,qn_to_time(n.start_qn)); local eppq=reaper.MIDI_GetPPQPosFromProjTime(take,qn_to_time(n.start_qn+n.duration_qn))
    if not reaper.MIDI_InsertNote(take,false,false,sppq,eppq,n.channel,n.pitch,n.velocity,true) then reaper.DeleteTrackMediaItem(track,item); return nil,"Note konnte nicht erzeugt werden" end
  end
  reaper.MIDI_Sort(take); return item
end
local function create_named_track(name)
  local idx=reaper.CountTracks(0); reaper.InsertTrackAtIndex(idx,true); local tr=reaper.GetTrack(0,idx); if not tr then return nil end
  reaper.GetSetMediaTrackInfo_String(tr,"P_NAME",name,true); return tr
end
local function apply_results(results,items)
  local sources=source_map(items); local created={}
  reaper.Undo_BeginBlock2(0); reaper.PreventUIRefresh(1)
  local success,why=xpcall(function()
    for _,r in ipairs(results) do
      if r.kind=="revised" then
        local src=sources[r.source]; if not src then error("Quelle nicht mehr vorhanden") end
        local item,e=create_midi_item(src.track,r.name.." [Variante]",r.notes); if not item then error(e) end; created[#created+1]=item
      elseif r.kind=="new" then
        local tr=create_named_track(r.name); if not tr then error("Neue Spur konnte nicht erzeugt werden") end
        local item,e=create_midi_item(tr,r.name,r.notes); if not item then error(e) end; created[#created+1]=item
      end
    end
  end,debug.traceback)
  reaper.PreventUIRefresh(-1)
  if not success then reaper.Undo_EndBlock2(0,"Composition Studio – fehlgeschlagene Anwendung",-1); reaper.Undo_DoUndo2(0); return nil,why end
  for i=0,reaper.CountMediaItems(0)-1 do reaper.SetMediaItemSelected(reaper.GetMediaItem(0,i),false) end
  for _,item in ipairs(created) do reaper.SetMediaItemSelected(item,true) end
  reaper.UpdateArrange(); reaper.Undo_EndBlock2(0,"Composition Studio – KI-Komposition",-1); return created
end

local items=selected_midi_items()
if #items==0 then reaper.ShowMessageBox("Keine ausgewählten MIDI-Items.\n\nWähle ein oder mehrere MIDI-Items in REAPER aus.",SCRIPT_NAME.." "..VERSION,0); return end
local request=ask_request(#items); if not request then return end
local key,kerr=get_api_key(); if not key then reaper.ShowMessageBox(kerr,SCRIPT_NAME,0); return end
local answer,err=run_openai(build_prompt(request,context_text(items)),key)
if not answer then reaper.ShowMessageBox("KI-Aufruf nicht ausgeführt:\n\n"..err.."\n\nDas REAPER-Projekt wurde nicht verändert.",SCRIPT_NAME.." "..VERSION,0); return end
local result,verr=validate_response(answer,items)
if not result then reaper.ShowMessageBox("KI-Antwort verworfen:\n\n"..verr.."\n\nDas REAPER-Projekt wurde nicht verändert.",SCRIPT_NAME.." "..VERSION,0); return end
local created,aerr=apply_results(result,items)
if not created then reaper.ShowMessageBox("Ergebnis konnte nicht sicher angewendet werden:\n\n"..tostring(aerr).."\n\nDer Apply-Schritt wurde rückgängig gemacht.",SCRIPT_NAME.." "..VERSION,0); return end
reaper.ShowMessageBox(string.format("Composition Studio hat %d neues/überarbeitetes MIDI-Item(s) erzeugt.\n\nOriginale blieben erhalten. Die neuen Items sind für den nächsten rekursiven Schritt ausgewählt.\nDer gesamte Vorgang ist ein REAPER-Undo-Schritt.",#created),SCRIPT_NAME.." "..VERSION,0)
