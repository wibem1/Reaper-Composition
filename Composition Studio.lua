-- @description Composition Studio Basic
-- @version 0.1-dev
-- @author Klangwerke
-- @about Recursive AI composition directly inside REAPER. Composition Lab is not a runtime dependency.

local SCRIPT_NAME, VERSION = "Composition Studio Basic", "0.1-dev"

local function round(n,p) local m=10^(p or 3); return math.floor(n*m+0.5)/m end
local function trim(s) return (s or ""):gsub("^%s+",""):gsub("%s+$","") end
local function shell_quote(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end
local function json_escape(s)
  return tostring(s or ""):gsub("\\","\\\\"):gsub('"','\\"'):gsub("\b","\\b"):gsub("\f","\\f"):gsub("\n","\\n"):gsub("\r","\\r"):gsub("\t","\\t")
end
local function read_file(path) local f=io.open(path,"rb"); if not f then return nil end; local s=f:read("*a"); f:close(); return s end
local function write_file(path,s) local f=io.open(path,"wb"); if not f then return false end; f:write(s); f:close(); return true end
local function remove_file(path) if path then os.remove(path) end end
local function guid(obj,take)
  local ok,g
  if take then ok,g=reaper.GetSetMediaItemTakeInfo_String(obj,"GUID","",false) else ok,g=reaper.GetSetMediaItemInfo_String(obj,"GUID","",false) end
  return ok and g or ""
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

-- Deliberately tiny response protocol. Musical decisions remain free; only the technical return envelope is constrained.
-- Each output line: CS|unchanged|SOURCE_GUID
-- or:              CS|revised|SOURCE_GUID|NAME|start,duration,pitch,velocity,channel;...
-- or:              CS|new|-|NAME|start,duration,pitch,velocity,channel;...
local function build_prompt(request,music)
  return [[Du komponierst Musik. Nutze das übergebene Material als gemeinsamen musikalischen Kontext und erfülle den freien Auftrag musikalisch eigenständig. Füge keine unnötigen Regeln hinzu.
Antworte ausschließlich mit technischen Ergebniszeilen:
CS|unchanged|SOURCE_GUID
CS|revised|SOURCE_GUID|NAME|startQN,durationQN,pitch,velocity,channel;...
CS|new|-|NAME|startQN,durationQN,pitch,velocity,channel;...
Für revised muss SOURCE_GUID exakt eine angebotene Item-GUID sein. Für new ist SOURCE_GUID '-'. Werte: startQN>=0, durationQN>0, pitch 0..127, velocity 1..127, channel 0..15. NAME darf kein | enthalten.

AUFTRAG:
]]..request.."\n\nMUSIK:\n"..music
end

local function known_sources(items) local t={}; for _,v in ipairs(items) do t[v.item_guid]=true end; return t end
local function parse_notes(s)
  local notes={}; if not s or s=="" then return nil,"Notenliste fehlt" end
  for token in s:gmatch("[^;]+") do
    local a,b,c,d,e=token:match("^%s*([%d%.%-]+),([%d%.%-]+),(%d+),(%d+),(%d+)%s*$")
    a,b,c,d,e=tonumber(a),tonumber(b),tonumber(c),tonumber(d),tonumber(e)
    if not(a and b and c and d and e) then return nil,"Ungültige Note: "..token end
    if a<0 or b<=0 or c<0 or c>127 or d<1 or d>127 or e<0 or e>15 then return nil,"Note außerhalb gültiger Grenzen" end
    notes[#notes+1]={start_qn=a,duration_qn=b,pitch=c,velocity=d,channel=e}
    if #notes>10000 then return nil,"Zu viele Noten" end
  end
  if #notes==0 then return nil,"Leere Notenliste" end; return notes
end
local function validate_response(text,items)
  local known=known_sources(items); local out={}; local seen_revised={}
  text=(text or ""):gsub("```[%w_-]*",""):gsub("```","")
  for line in text:gmatch("[^\r\n]+") do
    line=trim(line)
    if line~="" then
      local kind,source,rest=line:match("^CS|([^|]+)|([^|]+)|?(.*)$")
      if not kind then return nil,"Unerwartete Antwortzeile: "..line end
      if kind=="unchanged" then
        if not known[source] or rest~="" then return nil,"Ungültige unchanged-Zuordnung" end
        out[#out+1]={kind=kind,source=source}
      elseif kind=="revised" or kind=="new" then
        if kind=="revised" then if not known[source] then return nil,"Unbekannte Quelle für revised" end; if seen_revised[source] then return nil,"Quelle mehrfach revised" end; seen_revised[source]=true
        elseif source~="-" then return nil,"new muss Quelle '-' verwenden" end
        local name,nstr=rest:match("^([^|]+)|(.+)$"); name=trim(name)
        if not name or name=="" then return nil,"Ergebnisname fehlt" end
        local notes,err=parse_notes(nstr); if not notes then return nil,err end
        out[#out+1]={kind=kind,source=source,name=name,notes=notes}
      else return nil,"Unbekannter Ergebnistyp: "..tostring(kind) end
    end
  end
  if #out==0 then return nil,"Leere KI-Antwort" end; return out
end

local function run_openai(prompt)
  local key=os.getenv("OPENAI_API_KEY")
  if not key or key=="" then return nil,"OPENAI_API_KEY ist nicht gesetzt" end
  local tmp=os.tmpname(); local req=tmp..".json"; local resp=tmp..".out"; local codef=tmp..".code"
  local body='{"model":"gpt-5.6","input":"'..json_escape(prompt)..'"}'
  if not write_file(req,body) then return nil,"Temporäre Anfrage konnte nicht geschrieben werden" end
  local cmd="/usr/bin/curl -sS --max-time 120 -o "..shell_quote(resp).." -w '%{http_code}' -H "..shell_quote("Authorization: Bearer "..key).." -H 'Content-Type: application/json' --data-binary @"..shell_quote(req).." https://api.openai.com/v1/responses > "..shell_quote(codef)
  local ok=os.execute(cmd); local status=trim(read_file(codef)); local raw=read_file(resp); remove_file(req);remove_file(resp);remove_file(codef)
  if not ok or status~="200" or not raw then return nil,"KI-Aufruf fehlgeschlagen (HTTP "..tostring(status)..")" end
  -- Responses API JSON extraction without a JSON dependency: decode the first output_text string conservatively.
  local encoded=raw:match('"type"%s*:%s*"output_text".-"text"%s*:%s*"(([^"\\]|\\.)*)"')
  if not encoded then return nil,"Keine Textantwort der KI gefunden" end
  encoded=encoded:gsub('\\n','\n'):gsub('\\r','\r'):gsub('\\t','\t'):gsub('\\"','"'):gsub('\\\\','\\')
  return encoded
end

local items=selected_midi_items()
if #items==0 then reaper.ShowMessageBox("Keine ausgewählten MIDI-Items.\n\nWähle ein oder mehrere MIDI-Items in REAPER aus.",SCRIPT_NAME.." "..VERSION,0); return end
local request=ask_request(#items); if not request then return end
local prompt=build_prompt(request,context_text(items))

-- Safety checkpoint: transport + validation are implemented, but project writing stays disabled until this layer is practically tested.
local answer,err=run_openai(prompt)
if not answer then reaper.ShowMessageBox("KI-Test nicht ausgeführt:\n\n"..err.."\n\nDas REAPER-Projekt wurde nicht verändert.",SCRIPT_NAME.." "..VERSION,0); return end
local result,verr=validate_response(answer,items)
if not result then reaper.ShowMessageBox("KI-Antwort verworfen:\n\n"..verr.."\n\nDas REAPER-Projekt wurde nicht verändert.",SCRIPT_NAME.." "..VERSION,0); return end
local revised,newc,unchanged=0,0,0
for _,r in ipairs(result) do if r.kind=="revised" then revised=revised+1 elseif r.kind=="new" then newc=newc+1 else unchanged=unchanged+1 end end
reaper.ShowMessageBox(string.format("KI-Antwort technisch gültig.\n\nUnverändert: %d\nBearbeitet: %d\nNeu: %d\n\nNoch keine Projektänderung – Validierungsstufe bestanden.",unchanged,revised,newc),SCRIPT_NAME.." "..VERSION,0)
