-- @description Composition Studio
-- @version 0.3-test2
-- @author Klangwerke
-- @about Dockable AI chat, controlled REAPER actions and MIDI composition.

local SCRIPT_NAME="Composition Studio"
local VERSION="0.3-test2"
local EXT_SECTION,EXT_KEY="CompositionStudio","OpenAIAPIKey"
local WINDOW_STATE_KEY="WindowOpen"
local HISTORY_KEY="HistoryV1"

local function ensure_native_startup_hook()
  local p=reaper.GetResourcePath().."/Scripts/__startup.lua"
  local mark="-- BEGIN COMPOSITION STUDIO AUTO START"
  local f=io.open(p,"rb"); local old=f and (f:read("*a") or "") or ""; if f then f:close() end
  if old:find(mark,1,true) then return end
  local block=[[
-- BEGIN COMPOSITION STUDIO AUTO START
do
 if reaper.GetExtState("CompositionStudio","WindowOpen")=="1" then
  local p=reaper.GetResourcePath().."/Scripts/Composition Studio/Composition Studio.lua"
  local f=io.open(p,"rb"); if f then f:close(); local ok,e=pcall(dofile,p); if not ok then reaper.ShowConsoleMsg(tostring(e).."\n") end end
 end
end
-- END COMPOSITION STUDIO AUTO START
]]
  local w=io.open(p,"wb"); if w then if old~="" and old:sub(-1)~="\n" then old=old.."\n" end; w:write(old..block); w:close() end
end
ensure_native_startup_hook()

if type(reaper.ImGui_CreateContext)~="function" then reaper.ShowMessageBox("Composition Studio benötigt ReaImGui.",SCRIPT_NAME,0); return end
local ctx=reaper.ImGui_CreateContext(SCRIPT_NAME,reaper.ImGui_ConfigFlags_DockingEnable())
if type(reaper.ImGui_SetConfigVar)=="function" and type(reaper.ImGui_ConfigVar_DockingNoSplit)=="function" then reaper.ImGui_SetConfigVar(ctx,reaper.ImGui_ConfigVar_DockingNoSplit(),1) end
reaper.SetExtState(EXT_SECTION,WINDOW_STATE_KEY,"1",true)

local open,input,busy,show_info=true,"",false,false
local history={}
local current_project=reaper.EnumProjects(-1,"")
local font=nil
if type(reaper.ImGui_CreateFont)=="function" then local ok,f=pcall(reaper.ImGui_CreateFont,"sans-serif"); if ok then font=f end end
if font and type(reaper.ImGui_Attach)=="function" then pcall(reaper.ImGui_Attach,ctx,font) end
local function push_font() if not font then return false end; return pcall(reaper.ImGui_PushFont,ctx,font,18) end
local function pop_font(x) if x then reaper.ImGui_PopFont(ctx) end end
local function trim(s) return (s or ""):gsub("^%s+",""):gsub("%s+$","") end
local function shell_quote(s) return "'"..tostring(s):gsub("'","'\\''").."'" end
local function json_escape(s) return tostring(s or ""):gsub("\\","\\\\"):gsub('"','\\"'):gsub("\n","\\n"):gsub("\r","\\r"):gsub("\t","\\t") end
local function read_file(p) local f=io.open(p,"rb"); if not f then return nil end; local s=f:read("*a"); f:close(); return s end
local function write_file(p,s) local f=io.open(p,"wb"); if not f then return false end; f:write(s); f:close(); return true end
local function utf8(cp) if cp<=0x7f then return string.char(cp) elseif cp<=0x7ff then return string.char(0xc0+math.floor(cp/64),0x80+cp%64) elseif cp<=0xffff then return string.char(0xe0+math.floor(cp/4096),0x80+math.floor(cp/64)%64,0x80+cp%64) else return string.char(0xf0+math.floor(cp/262144),0x80+math.floor(cp/4096)%64,0x80+math.floor(cp/64)%64,0x80+cp%64) end end
local function read_json_string(raw,q)
 local out,i={},q+1
 while i<=#raw do local c=raw:sub(i,i); if c=='"' then return table.concat(out) end
  if c=="\\" then i=i+1; local e=raw:sub(i,i); if e=="n" then out[#out+1]="\n" elseif e=="r" then out[#out+1]="\r" elseif e=="t" then out[#out+1]="\t" elseif e=='"' then out[#out+1]='"' elseif e=="\\" then out[#out+1]="\\" elseif e=="u" then local h=raw:sub(i+1,i+4); local cp=tonumber(h,16); if cp then i=i+4; if cp>=0xD800 and cp<=0xDBFF and raw:sub(i+1,i+2)=="\\u" then local lo=tonumber(raw:sub(i+3,i+6),16); if lo and lo>=0xDC00 and lo<=0xDFFF then cp=0x10000+(cp-0xD800)*0x400+(lo-0xDC00); i=i+6 end end; out[#out+1]=utf8(cp) end else out[#out+1]=e end else out[#out+1]=c end; i=i+1 end
end
local function response_text(raw)
 local s,e=raw:find('"type"%s*:%s*"output_text"'); if not s then return nil end; local ts,te=raw:find('"text"%s*:',e+1); if not ts then return nil end; local q=raw:find('"',te+1,true); return q and read_json_string(raw,q) or nil
end
local function get_key()
 local k=trim(reaper.GetExtState(EXT_SECTION,EXT_KEY)); if k~="" then return k end
 local ok,v=reaper.GetUserInputs(SCRIPT_NAME.." – Ersteinrichtung",1,"OpenAI API-Key:,extrawidth=320",""); if not ok then return nil end; k=trim(v); if k~="" then reaper.SetExtState(EXT_SECTION,EXT_KEY,k,true); return k end
end
local function run_openai(prompt,key)
 local b=os.tmpname(); local rq,rs,cd=b..".json",b..".out",b..".code"; if not write_file(rq,'{"model":"gpt-5.6","input":"'..json_escape(prompt)..'"}') then return nil,"Anfrage konnte nicht geschrieben werden." end
 local cmd="/usr/bin/curl -sS --max-time 120 -o "..shell_quote(rs).." -w '%{http_code}' -H "..shell_quote("Authorization: Bearer "..key).." -H 'Content-Type: application/json' --data-binary @"..shell_quote(rq).." https://api.openai.com/v1/responses > "..shell_quote(cd)
 os.execute(cmd); local status=trim(read_file(cd)); local raw=read_file(rs); os.remove(rq); os.remove(rs); os.remove(cd); if status~="200" or not raw then return nil,"KI-Aufruf fehlgeschlagen (HTTP "..tostring(status)..")." end; return response_text(raw),nil
end

local function enc(s) return (tostring(s or ""):gsub("([^%w%-%._~])",function(c) return string.format("%%%02X",string.byte(c)) end)) end
local function dec(s) return (tostring(s or ""):gsub("%%(%x%x)",function(h) return string.char(tonumber(h,16)) end)) end
local function save_history(proj)
 proj=proj or current_project; if not proj then return end
 local rows={}; for _,m in ipairs(history) do rows[#rows+1]=enc(m.role).."\t"..enc(m.text) end
 reaper.SetProjExtState(proj,EXT_SECTION,HISTORY_KEY,table.concat(rows,"\n"))
end
local function load_history(proj)
 history={}; if proj then local _,raw=reaper.GetProjExtState(proj,EXT_SECTION,HISTORY_KEY); if raw and raw~="" then for row in raw:gmatch("[^\n]+") do local r,t=row:match("^([^\t]*)\t(.*)$"); if r then history[#history+1]={role=dec(r),text=dec(t)} end end end end
 if #history==0 then history={{role="KI",text="Composition Studio ist bereit."}} end
end
local function add(role,text) history[#history+1]={role=role,text=text}; save_history() end
load_history(current_project)

local function item_guid(item) local ok,g=reaper.GetSetMediaItemInfo_String(item,"GUID","",false); return ok and g or "" end
local function track_guid(track) return reaper.GetTrackGUID(track) or "" end
local function selected_items(with_notes)
 local a={}
 for i=0,reaper.CountSelectedMediaItems(0)-1 do
  local item=reaper.GetSelectedMediaItem(0,i); local take=item and reaper.GetActiveTake(item)
  if take and reaper.TakeIsMIDI(take) then
   local tr=reaper.GetMediaItem_Track(item); local _,tn=reaper.GetTrackName(tr); local _,kn=reaper.GetSetMediaItemTakeInfo_String(take,"P_NAME","",false)
   local pos=reaper.GetMediaItemInfo_Value(item,"D_POSITION"); local len=reaper.GetMediaItemInfo_Value(item,"D_LENGTH")
   local it={item=item,take=take,track=tr,guid=item_guid(item),track_guid=track_guid(tr),track_name=tn~="" and tn or "Unbenannte Spur",take_name=kn~="" and kn or "Unbenanntes MIDI-Item",start_qn=reaper.TimeMap2_timeToQN(0,pos),end_qn=reaper.TimeMap2_timeToQN(0,pos+len),notes={}}
   if with_notes then local _,ncount=reaper.MIDI_CountEvts(take); for n=0,(ncount or 0)-1 do local ok,_,muted,s,e,ch,p,v=reaper.MIDI_GetNote(take,n); if ok and not muted then local st=reaper.MIDI_GetProjTimeFromPPQPos(take,s); local et=reaper.MIDI_GetProjTimeFromPPQPos(take,e); local sq=reaper.TimeMap2_timeToQN(0,st); local eq=reaper.TimeMap2_timeToQN(0,et); it.notes[#it.notes+1]={start_qn=sq,duration_qn=eq-sq,pitch=p,velocity=v,channel=ch} end end end
   a[#a+1]=it
  end
 end
 return a
end
local function compact_context(items)
 local l={string.format("Tempo %.2f BPM; selected MIDI items=%d",reaper.Master_GetTempo(),#items)}
 for i,it in ipairs(items) do l[#l+1]=string.format("ITEM %d id=%s track=%s take=%s rangeQN=%.3f..%.3f",i,it.guid,it.track_name,it.take_name,it.start_qn,it.end_qn) end
 return table.concat(l,"\n")
end
local function music_context(items)
 local l={compact_context(items)}; for _,it in ipairs(items) do for _,n in ipairs(it.notes) do l[#l+1]=string.format("N %s %.5f %.5f %d %d %d",it.guid,n.start_qn,n.duration_qn,n.pitch,n.velocity,n.channel) end end; return table.concat(l,"\n")
end
local function recent_dialog() local l={}; for i=math.max(1,#history-7),#history do l[#l+1]=history[i].role..": "..history[i].text end; return table.concat(l,"\n") end

local CONTROLLER=[[Du bist der Controller von Composition Studio in REAPER. Der Benutzer spricht frei; es gibt KEINE Triggerwörter.
Interpretiere nur, was eindeutig gemeint ist. Bei Unklarheit FRAGE nach. Behaupte nie, eine nicht angebotene Funktion ausführen zu können.
Antworte mit GENAU EINER Zeile aus diesem Protokoll:
CHAT|Text
ASK|Rückfrage
ACTION|TRANSPOSE|ITEM_GUID|SEMITONES|verständliche Beschreibung
ACTION|MOVE_ITEM|ITEM_GUID|DELTA_QN|verständliche Beschreibung
ACTION|COPY_ITEM|ITEM_GUID|DELTA_QN|verständliche Beschreibung
ACTION|RENAME_TRACK|TRACK_GUID|NEUER_NAME|verständliche Beschreibung
NEED_MUSIC|kurze Begründung

Erlaubte lokale Aktionen: ausgewähltes MIDI-Item transponieren; Item zeitlich verschieben; Item kopieren; Spur umbenennen.
Nur angebotene ITEM_GUID/TRACK_GUID verwenden. Wenn mehrere Ziele möglich sind und der Auftrag sie nicht eindeutig bezeichnet: ASK.
SEMITONES ist eine ganze Zahl. DELTA_QN ist die Verschiebung in Viertelnoten; negativ=früher. Nutze Taktangaben nur, wenn sie aus dem Kontext eindeutig in QN umsetzbar sind; sonst ASK.
Für Analyse, Komposition, Variation, Fortsetzung oder andere Aufgaben, die konkrete Noten benötigen: NEED_MUSIC.
Für normale Unterhaltung ohne REAPER-Aktion: CHAT.
Keine erfundenen Aktionen und kein Lua-/Shell-Code.]]

local function parse_action(line,items)
 line=trim(line or ""); local typ,a,b,desc=line:match("^ACTION|([^|]+)|([^|]+)|([^|]+)|(.+)$"); if not typ then return nil,"Ungültiger ACTION-Aufruf." end
 local by_item,by_track={},{ }; for _,it in ipairs(items) do by_item[it.guid]=it; by_track[it.track_guid]=it.track end
 if typ=="TRANSPOSE" then local n=tonumber(b); if not by_item[a] or not n or n~=math.floor(n) or n < -127 or n > 127 then return nil,"Ungültige Transposition." end; return {kind=typ,item=by_item[a],n=n,desc=desc}
 elseif typ=="MOVE_ITEM" or typ=="COPY_ITEM" then local q=tonumber(b); if not by_item[a] or not q then return nil,"Ungültige Item-Verschiebung." end; return {kind=typ,item=by_item[a],q=q,desc=desc}
 elseif typ=="RENAME_TRACK" then if not by_track[a] or trim(b)=="" then return nil,"Ungültige Spurbenennung." end; return {kind=typ,track=by_track[a],name=trim(b),desc=desc} end
 return nil,"Diese Aktion ist nicht freigegeben."
end
local function execute_action(a)
 reaper.Undo_BeginBlock2(0); local ok,err=xpcall(function()
  if a.kind=="TRANSPOSE" then local take=a.item.take; local _,ncount=reaper.MIDI_CountEvts(take); for i=0,(ncount or 0)-1 do local yes,sel,mut,s,e,ch,p,v=reaper.MIDI_GetNote(take,i); if yes and not mut then local np=p+a.n; if np<0 or np>127 then error("Transposition würde den MIDI-Bereich verlassen.") end; reaper.MIDI_SetNote(take,i,sel,mut,s,e,ch,np,v,true) end end; reaper.MIDI_Sort(take)
  elseif a.kind=="MOVE_ITEM" then local pos=reaper.GetMediaItemInfo_Value(a.item.item,"D_POSITION"); local qn=reaper.TimeMap2_timeToQN(0,pos)+a.q; if qn<0 then error("Item würde vor Projektbeginn liegen.") end; reaper.SetMediaItemInfo_Value(a.item.item,"D_POSITION",reaper.TimeMap2_QNToTime(0,qn))
  elseif a.kind=="COPY_ITEM" then local src=a.item.item; local tr=a.item.track; local chunk_ok,chunk=reaper.GetItemStateChunk(src,"",false); if not chunk_ok then error("Item konnte nicht gelesen werden.") end; local ni=reaper.AddMediaItemToTrack(tr); if not reaper.SetItemStateChunk(ni,chunk,false) then error("Item konnte nicht kopiert werden.") end; local pos=reaper.GetMediaItemInfo_Value(src,"D_POSITION"); local qn=reaper.TimeMap2_timeToQN(0,pos)+a.q; if qn<0 then error("Kopie würde vor Projektbeginn liegen.") end; reaper.SetMediaItemInfo_Value(ni,"D_POSITION",reaper.TimeMap2_QNToTime(0,qn)); reaper.SetMediaItemSelected(ni,true)
  elseif a.kind=="RENAME_TRACK" then reaper.GetSetMediaTrackInfo_String(a.track,"P_NAME",a.name,true) end
 end,debug.traceback)
 if not ok then reaper.Undo_EndBlock2(0,"Composition Studio – fehlgeschlagen",-1); reaper.Undo_DoUndo2(0); return nil,err end
 reaper.UpdateArrange(); reaper.Undo_EndBlock2(0,"Composition Studio – "..a.kind,-1); return true
end

local function parse_notes(text) local notes={}; for t in (text or ""):gmatch("[^;]+") do local a,b,c,d,e=t:match("^%s*([%d%.%-]+),([%d%.%-]+),(%d+),(%d+),(%d+)%s*$"); a,b,c,d,e=tonumber(a),tonumber(b),tonumber(c),tonumber(d),tonumber(e); if not(a and b and c and d and e) then return nil end; notes[#notes+1]={start_qn=a,duration_qn=b,pitch=c,velocity=d,channel=e} end; return #notes>0 and notes or nil end
local function create_track(name,index) index=index or reaper.CountTracks(0); reaper.InsertTrackAtIndex(index,true); local t=reaper.GetTrack(0,index); if t then reaper.GetSetMediaTrackInfo_String(t,"P_NAME",name,true) end; return t end
local function create_midi(track,name,notes) local lo,hi=math.huge,-math.huge; for _,n in ipairs(notes) do lo=math.min(lo,n.start_qn); hi=math.max(hi,n.start_qn+n.duration_qn) end; if hi<=lo then return nil end; local item=reaper.CreateNewMIDIItemInProj(track,reaper.TimeMap2_QNToTime(0,lo),reaper.TimeMap2_QNToTime(0,hi),false); local take=item and reaper.GetActiveTake(item); if not take then return nil end; reaper.GetSetMediaItemTakeInfo_String(take,"P_NAME",name,true); for _,n in ipairs(notes) do local s=reaper.MIDI_GetPPQPosFromProjTime(take,reaper.TimeMap2_QNToTime(0,n.start_qn)); local e=reaper.MIDI_GetPPQPosFromProjTime(take,reaper.TimeMap2_QNToTime(0,n.start_qn+n.duration_qn)); reaper.MIDI_InsertNote(take,false,false,s,e,n.channel,n.pitch,n.velocity,true) end; reaper.MIDI_Sort(take); return item end
local function apply_composition(text,items)
 local src={}; for _,it in ipairs(items) do src[it.guid]=it end; local jobs={}; for line in text:gmatch("[^\r\n]+") do local k,g,rest=trim(line):match("^CS|([^|]+)|([^|]+)|?(.*)$"); if not k then return nil,"Unerwartete Kompositionsantwort." end; if k=="unchanged" then if not src[g] then return nil,"Unbekannte Quelle." end elseif k=="revised" or k=="new" then local name,nt=rest:match("^([^|]+)|(.+)$"); local notes=parse_notes(nt); if not name or not notes or (k=="revised" and not src[g]) or (k=="new" and g~="-") then return nil,"Ungültige Kompositionsdaten." end; jobs[#jobs+1]={kind=k,guid=g,name=trim(name),notes=notes} else return nil,"Unbekannter Ergebnistyp." end end
 reaper.Undo_BeginBlock2(0); local made={}; local ok,err=xpcall(function() for _,j in ipairs(jobs) do local tr; if j.kind=="revised" then local no=math.floor(reaper.GetMediaTrackInfo_Value(src[j.guid].track,"IP_TRACKNUMBER")); tr=create_track(j.name.." [Variante]",no) else tr=create_track(j.name) end; local it=create_midi(tr,j.name,j.notes); if not it then error("MIDI konnte nicht erzeugt werden") end; made[#made+1]=it end end,debug.traceback); if not ok then reaper.Undo_EndBlock2(0,"Composition Studio – fehlgeschlagen",-1); reaper.Undo_DoUndo2(0); return nil,err end; reaper.UpdateArrange(); reaper.Undo_EndBlock2(0,"Composition Studio – KI-Komposition",-1); return made
end
local function composition_prompt(request,items)
 return [[Du komponierst Musik in Composition Studio. Nutze das übergebene Material als gemeinsamen musikalischen Kontext und erfülle den freien Auftrag musikalisch eigenständig. Füge keine unnötigen Regeln hinzu.
Antworte ausschließlich mit technischen Ergebniszeilen:
CS|unchanged|SOURCE_GUID
CS|revised|SOURCE_GUID|NAME|startQN,durationQN,pitch,velocity,channel;...
CS|new|-|NAME|startQN,durationQN,pitch,velocity,channel;...
Für revised muss SOURCE_GUID angeboten sein; für new '-'. NAME enthält kein |.
]].."AUFTRAG:\n"..request.."\nMUSIK:\n"..music_context(items)
end
local function process(request)
 local key=get_key(); if not key then add("KI","Kein OpenAI API-Key verfügbar."); return end
 local items=selected_items(false)
 local prompt=CONTROLLER.."\n\nBISHERIGER DIALOG:\n"..recent_dialog().."\n\nAKTUELLER AUFTRAG:\n"..request.."\n\nKOMPAKTER REAPER-KONTEXT:\n"..compact_context(items)
 local answer,err=run_openai(prompt,key); if not answer then add("KI",err); return end; answer=trim(answer)
 local chat=answer:match("^CHAT|(.*)$"); if chat then add("KI",trim(chat)); return end
 local ask=answer:match("^ASK|(.*)$"); if ask then add("KI",trim(ask)); return end
 local why=answer:match("^NEED_MUSIC|(.*)$")
 if why then local full=selected_items(true); local comp,cerr=run_openai(composition_prompt(request,full),key); if not comp then add("KI",cerr); return end; local made,aerr=apply_composition(comp,full); if not made then add("KI","Die musikalische Antwort konnte nicht sicher angewendet werden: "..tostring(aerr)); return end; add("KI",string.format("Erledigt. %d neues bzw. überarbeitetes MIDI-Item wurde erzeugt.",#made)); return end
 if answer:match("^ACTION|") then local a,perr=parse_action(answer,items); if not a then add("KI","Ich führe nichts aus: "..perr); return end; local ok,aerr=execute_action(a); if not ok then add("KI","Die Aktion wurde nicht ausgeführt: "..tostring(aerr)); return end; add("KI",trim(a.desc).." – erledigt. REAPER Undo kann die Änderung rückgängig machen."); return end
 add("KI","Ich konnte den Auftrag nicht eindeutig einem sicheren Vorgang zuordnen und habe nichts verändert.")
end
local function submit() local r=trim(input); if r=="" or busy then return end; input=""; add("Du",r); busy=true; process(r); busy=false end
local function draw_history() for _,m in ipairs(history) do reaper.ImGui_TextWrapped(ctx,m.role..": "..m.text); reaper.ImGui_Spacing(ctx) end end
local function remember_closed() save_history(); reaper.SetExtState(EXT_SECTION,WINDOW_STATE_KEY,"0",true) end
local function check_project_change()
 local p=reaper.EnumProjects(-1,""); if p~=current_project then save_history(current_project); current_project=p; load_history(current_project) end
end
local function draw_info()
 if not show_info then return end
 reaper.ImGui_SetNextWindowSize(ctx,520,560,reaper.ImGui_Cond_FirstUseEver())
 local visible; visible,show_info=reaper.ImGui_Begin(ctx,"Info – Composition Studio "..VERSION,show_info)
 if visible then
  reaper.ImGui_TextWrapped(ctx,"AKTUELLER STAND")
  reaper.ImGui_Separator(ctx)
  reaper.ImGui_TextWrapped(ctx,"Composition Studio arbeitet direkt in REAPER. GPT-5.6 nutzt den Dialog und ausgewählte MIDI-Items als Kontext. Es kann MIDI analysieren und bearbeiten, Varianten bzw. neue MIDI-Items erzeugen sowie freigegebene REAPER-Aktionen ausführen. Änderungen lassen sich mit REAPER Undo rückgängig machen.")
  reaper.ImGui_Spacing(ctx); reaper.ImGui_TextWrapped(ctx,"WAS IST NEU? – "..VERSION); reaper.ImGui_Separator(ctx)
  reaper.ImGui_TextWrapped(ctx,"• Composition Studio merkt sich, ob sein Fenster geöffnet war, und öffnet es beim nächsten REAPER-Start automatisch wieder.\n• Die Versionsnummer ist dauerhaft in der Oberfläche sichtbar.\n• Der Verlauf wird projektbezogen gespeichert und beim erneuten Öffnen wiederhergestellt.\n• Der Verlauf kann gelöscht werden.\n• Neuer Info-Bereich mit Funktionsstand, Neuerungen und Testhinweisen.")
  reaper.ImGui_Spacing(ctx); reaper.ImGui_TextWrapped(ctx,"IN DIESER VERSION BITTE TESTEN"); reaper.ImGui_Separator(ctx)
  reaper.ImGui_TextWrapped(ctx,"• REAPER mit geöffnetem Composition Studio beenden und neu starten: Composition Studio soll automatisch wieder erscheinen.\n• REAPER mit geschlossenem Composition Studio beenden: beim nächsten Start soll es geschlossen bleiben.\n• Projekt speichern und neu öffnen: der Verlauf soll wieder vorhanden sein.\n• Zwischen zwei REAPER-Projekten wechseln: jedes Projekt soll seinen eigenen Verlauf zeigen.\n• Verlauf löschen und prüfen, ob er nach erneutem Öffnen gelöscht bleibt.\n• Prüfen, ob überall "..VERSION.." angezeigt wird.\n• Unterhaltung, MIDI-Auswahl, MIDI-Bearbeitung bzw. Variante und REAPER Undo kurz gegenprüfen.")
  reaper.ImGui_End(ctx)
 end
end
local function loop()
 if not open then remember_closed(); return end
 check_project_change()
 reaper.ImGui_SetNextWindowSize(ctx,520,700,reaper.ImGui_Cond_FirstUseEver()); local visible; visible,open=reaper.ImGui_Begin(ctx,SCRIPT_NAME.."  "..VERSION,open)
 if visible then
  local pushed=push_font(); local items=selected_items(false)
  reaper.ImGui_Text(ctx,SCRIPT_NAME.."  "..VERSION); reaper.ImGui_SameLine(ctx); if reaper.ImGui_Button(ctx,"Info") then show_info=true end
  reaper.ImGui_Text(ctx,string.format("GPT-5.6  |  %d MIDI-Item(s) ausgewählt",#items)); reaper.ImGui_Separator(ctx)
  local w,h=reaper.ImGui_GetContentRegionAvail(ctx); local ih,bh=150,38; local ch=math.max(120,h-ih-bh-78)
  if reaper.ImGui_BeginChild(ctx,"##chat",w,ch,reaper.ImGui_ChildFlags_Borders()) then draw_history(); reaper.ImGui_EndChild(ctx) end
  reaper.ImGui_Spacing(ctx); local changed,v=reaper.ImGui_InputTextMultiline(ctx,"##request",input,w,ih); if changed then input=v end; reaper.ImGui_Spacing(ctx)
  if reaper.ImGui_Button(ctx,busy and "Bitte warten…" or "Senden",120,bh) and not busy then submit() end
  reaper.ImGui_SameLine(ctx); if reaper.ImGui_Button(ctx,"Verlauf löschen",150,bh) then history={{role="KI",text="Verlauf gelöscht. Composition Studio ist bereit."}}; save_history() end
  reaper.ImGui_SameLine(ctx); if reaper.ImGui_Button(ctx,"Schließen",120,bh) then open=false end
  pop_font(pushed); reaper.ImGui_End(ctx)
 end
 draw_info()
 if open then reaper.defer(loop) else remember_closed() end
end
loop()
