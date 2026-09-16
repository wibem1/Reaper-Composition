-- @description Composition Studio
-- @version 0.2-test1
-- @author Klangwerke
-- @about Dockable AI composition and REAPER control panel.

local SCRIPT_NAME = "Composition Studio"
local VERSION = "0.2-test1"
local EXT_SECTION, EXT_KEY = "CompositionStudio", "OpenAIAPIKey"
local DOCK_KEY = "ChatDockState"

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
      if e=="n" then out[#out+1]="\n" elseif e=="r" then out[#out+1]="\r" elseif e=="t" then out[#out+1]="\t" elseif e=='"' then out[#out+1]='"' elseif e=="\\" then out[#out+1]="\\" elseif e=="/" then out[#out+1]="/" else out[#out+1]=e end
    else out[#out+1]=c end
    i=i+1
  end
end

local function response_output_text(raw)
  local pos=1
  while true do
    local _,te=raw:find('"type"%s*:%s*"output_text"',pos); if not te then return nil end
    local next_type=raw:find('"type"%s*:',te+1); local block_end=next_type and next_type-1 or #raw
    local _,text_e=raw:find('"text"%s*:',te+1)
    if text_e and text_e<=block_end then
      local quote=raw:find('"',text_e+1,true)
      if quote and quote<=block_end then local text=read_json_string(raw,quote); if text and text~="" then return text end end
    end
    pos=te+1
  end
end

local function get_api_key()
  local key=trim(reaper.GetExtState(EXT_SECTION,EXT_KEY)); if key~="" then return key end
  local ok,input=reaper.GetUserInputs(SCRIPT_NAME.." – Ersteinrichtung",1,"OpenAI API-Key:,extrawidth=320","")
  if not ok then return nil,"API-Key-Eingabe abgebrochen." end
  key=trim(input); if key=="" then return nil,"Kein API-Key eingegeben." end
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
      items[#items+1]={item=item,take=take,track=track,guid=get_guid(item),track_name=tn~="" and tn or "Unbenannte Spur",take_name=kn~="" and kn or "Unbenanntes MIDI-Item",notes=notes}
    end
  end
  return items
end

local function context_text(items)
  local l={string.format("Tempo %.3f BPM",reaper.Master_GetTempo())}
  if #items==0 then l[#l+1]="KEIN MIDI-ITEM AUSGEWAEHLT."
  else
    for i,it in ipairs(items) do
      l[#l+1]=string.format("ITEM %d id=%s track=%s take=%s",i,it.guid,it.track_name,it.take_name)
      for _,n in ipairs(it.notes) do l[#l+1]=string.format("N %.5f %.5f %d %d %d",n.start_qn,n.duration_qn,n.pitch,n.velocity,n.channel) end
    end
  end
  return table.concat(l,"\n")
end

local function history_text(history)
  local l={}
  for i=math.max(1,#history-9),#history do local m=history[i]; l[#l+1]=(m.role=="user" and "BENUTZER: " or "ASSISTENT: ")..m.text end
  return table.concat(l,"\n")
end

local function build_prompt(request,music,history)
  return [[Du bist Composition Studio in REAPER. Du kannst mit dem Benutzer ueber Musik sprechen, musikalisch komponieren und klar definierte REAPER-Operationen anfordern.
Interpretiere freie Sprache im Zusammenhang mit dem bisherigen Gespraech und der aktuellen REAPER-Auswahl.
Musikalische Aufgaben loest du eigenstaendig und ohne unnoetige Kompositionsregeln.

Antworte AUSSCHLIESSLICH mit einer oder mehreren Zeilen dieser internen Sprache:
CHAT|kurze Rueckmeldung oder Antwort
CS|unchanged|SOURCE_GUID
CS|revised|SOURCE_GUID|NAME|startQN,durationQN,pitch,velocity,channel;...
CS|new|-|NAME|startQN,durationQN,pitch,velocity,channel;...
OP|create_track|NAME
OP|rename_track|SOURCE_GUID|NAME
OP|transpose|SOURCE_GUID|SEMITONES

Bedeutung:
CHAT ist fuer Gespraech, Erklaerungen und Rueckmeldungen. Reine Fragen duerfen nur CHAT liefern.
CS revised erzeugt eine nichtdestruktive musikalische Variante des angegebenen MIDI-Items.
CS new erzeugt eine neue Stimme/Spur.
OP create_track erzeugt eine leere REAPER-Spur.
OP rename_track benennt die Spur des angegebenen MIDI-Items um.
OP transpose erzeugt aus dem angegebenen MIDI-Item eine nichtdestruktive transponierte Variante.
SOURCE_GUID muss exakt aus dem angebotenen Kontext stammen. SEMITONES ist eine ganze Zahl von -48 bis 48.
NAME darf kein | enthalten. Noten: startQN>=0, durationQN>0, pitch 0..127, velocity 1..127, channel 0..15.
Wenn eine gewuenschte technische Operation noch nicht in dieser Sprache definiert ist, fuehre sie NICHT durch, sondern erklaere mit CHAT kurz, dass sie noch nicht implementiert ist.
Bei ausgefuehrten Aktionen gib zusaetzlich eine kurze CHAT-Rueckmeldung aus.

BISHERIGES GESPRAECH:
]]..history.."\n\nAKTUELLER AUFTRAG:\n"..request.."\n\nAKTUELLER REAPER-KONTEXT:\n"..music
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
  local sources={}; for _,it in ipairs(items) do sources[it.guid]=it end
  local results={}, chats={}
  text=(text or ""):gsub("```[%w_-]*",""):gsub("```","")
  for line in text:gmatch("[^\r\n]+") do
    line=trim(line)
    if line~="" then
      local chat=line:match("^CHAT|(.+)$")
      if chat then chats[#chats+1]=trim(chat)
      else
        local kind,source,rest=line:match("^CS|([^|]+)|([^|]+)|?(.*)$")
        if kind then
          if kind=="unchanged" then if not sources[source] then return nil,nil,"Unbekannte unchanged-Quelle." end; results[#results+1]={kind=kind,source=source}
          elseif kind=="revised" or kind=="new" then
            if kind=="revised" and not sources[source] then return nil,nil,"Unbekannte revised-Quelle." end
            if kind=="new" and source~="-" then return nil,nil,"new muss Quelle '-' verwenden." end
            local name,nt=rest:match("^([^|]+)|(.+)$"); name=trim(name); if not name or name=="" then return nil,nil,"Ergebnisname fehlt." end
            local notes,err=parse_notes(nt); if not notes then return nil,nil,err end
            results[#results+1]={kind=kind,source=source,name=name,notes=notes}
          else return nil,nil,"Unbekannter CS-Typ: "..tostring(kind) end
        else
          local op,args=line:match("^OP|([^|]+)|(.+)$")
          if not op then return nil,nil,"Unerwartete KI-Zeile: "..line end
          if op=="create_track" then results[#results+1]={kind="create_track",name=trim(args)}
          elseif op=="rename_track" then local g,n=args:match("^([^|]+)|(.+)$"); if not g or not sources[g] then return nil,nil,"Unbekannte rename-Quelle." end; results[#results+1]={kind="rename_track",source=g,name=trim(n)}
          elseif op=="transpose" then local g,s=args:match("^([^|]+)|([%-]?%d+)$"); s=tonumber(s); if not g or not sources[g] or not s or s < -48 or s > 48 then return nil,nil,"Ungueltige Transposition." end; results[#results+1]={kind="transpose",source=g,semitones=s}
          else return nil,nil,"Noch nicht erlaubte REAPER-Operation: "..tostring(op) end
        end
      end
    end
  end
  if #results==0 and #chats==0 then return nil,nil,"Leere KI-Antwort." end
  return results,chats
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
local function create_track(name)
  local i=reaper.CountTracks(0); reaper.InsertTrackAtIndex(i,true); local t=reaper.GetTrack(0,i); if t then reaper.GetSetMediaTrackInfo_String(t,"P_NAME",name,true) end; return t
end
local function create_track_below(source_track,name)
  local track_number=source_track and reaper.GetMediaTrackInfo_Value(source_track,"IP_TRACKNUMBER"); if not track_number or track_number<1 then return nil end
  local i=math.floor(track_number); reaper.InsertTrackAtIndex(i,true); local t=reaper.GetTrack(0,i); if t then reaper.GetSetMediaTrackInfo_String(t,"P_NAME",name,true) end; return t
end
local function create_midi_item(track,name,notes)
  local lo,hi=math.huge,-math.huge; for _,n in ipairs(notes) do lo=math.min(lo,n.start_qn); hi=math.max(hi,n.start_qn+n.duration_qn) end
  if lo==math.huge or hi<=lo then return nil,"Ungueltiger musikalischer Bereich." end
  local item=reaper.CreateNewMIDIItemInProj(track,qn_to_time(lo),qn_to_time(hi),false); if not item then return nil,"MIDI-Item konnte nicht erzeugt werden." end
  local take=reaper.GetActiveTake(item); if not take then return nil,"MIDI-Take konnte nicht erzeugt werden." end
  reaper.GetSetMediaItemTakeInfo_String(take,"P_NAME",name,true)
  for _,n in ipairs(notes) do local s=reaper.MIDI_GetPPQPosFromProjTime(take,qn_to_time(n.start_qn)); local e=reaper.MIDI_GetPPQPosFromProjTime(take,qn_to_time(n.start_qn+n.duration_qn)); reaper.MIDI_InsertNote(take,false,false,s,e,n.channel,n.pitch,n.velocity,true) end
  reaper.MIDI_Sort(take); return item
end
local function transposed_notes(src,semitones)
  local out={}; for _,n in ipairs(src.notes) do local p=n.pitch+semitones; if p<0 or p>127 then return nil,"Transposition fuehrt aus dem MIDI-Bereich." end; out[#out+1]={start_qn=n.start_qn,duration_qn=n.duration_qn,pitch=p,velocity=n.velocity,channel=n.channel} end; return out
end

local function apply_results(results,items)
  local sources={}; for _,it in ipairs(items) do sources[it.guid]=it end; local created={}; local changes=0
  if #results==0 then return created,0 end
  reaper.Undo_BeginBlock2(0); reaper.PreventUIRefresh(1)
  local ok,err=xpcall(function()
    for _,r in ipairs(results) do
      if r.kind=="revised" then
        local src=sources[r.source]; local name=r.name.." [Variante]"; local tr=create_track_below(src.track,name); if not tr then error("Variantenspur konnte nicht erzeugt werden.") end
        local item,why=create_midi_item(tr,name,r.notes); if not item then error(why) end; created[#created+1]=item; changes=changes+1
      elseif r.kind=="new" then
        local tr=create_track(r.name); if not tr then error("Neue Spur konnte nicht erzeugt werden.") end
        local item,why=create_midi_item(tr,r.name,r.notes); if not item then error(why) end; created[#created+1]=item; changes=changes+1
      elseif r.kind=="create_track" then if r.name=="" or not create_track(r.name) then error("Spur konnte nicht erzeugt werden.") end; changes=changes+1
      elseif r.kind=="rename_track" then local src=sources[r.source]; reaper.GetSetMediaTrackInfo_String(src.track,"P_NAME",r.name,true); changes=changes+1
      elseif r.kind=="transpose" then
        local src=sources[r.source]; local notes,why=transposed_notes(src,r.semitones); if not notes then error(why) end
        local name=src.track_name.." transponiert"; local tr=create_track_below(src.track,name); if not tr then error("Transpositionsspur konnte nicht erzeugt werden.") end
        local item,why2=create_midi_item(tr,name,notes); if not item then error(why2) end; created[#created+1]=item; changes=changes+1
      end
    end
  end,debug.traceback)
  reaper.PreventUIRefresh(-1)
  if not ok then reaper.Undo_EndBlock2(0,"Composition Studio – fehlgeschlagen",-1); reaper.Undo_DoUndo2(0); return nil,nil,err end
  if #created>0 then for i=0,reaper.CountMediaItems(0)-1 do reaper.SetMediaItemSelected(reaper.GetMediaItem(0,i),false) end; for _,it in ipairs(created) do reaper.SetMediaItemSelected(it,true) end end
  reaper.UpdateArrange(); reaper.Undo_EndBlock2(0,"Composition Studio",-1); return created,changes
end

-- Dauerhaftes, andockbares Chatfenster. REAPER bleibt die eigentliche Arbeitsflaeche.
local history={{role="assistant",text="Composition Studio ist bereit. Waehle MIDI-Material aus oder beginne ohne Auswahl mit einer neuen Komposition."}}
local input=""
local busy=false
local pending=nil
local scroll_to_bottom=true

local saved_dock=tonumber(reaper.GetExtState(EXT_SECTION,DOCK_KEY)) or 1
gfx.init(SCRIPT_NAME.." "..VERSION,430,650,saved_dock)
if saved_dock~=0 then gfx.dock(saved_dock) end

local function add_message(role,text) history[#history+1]={role=role,text=text}; scroll_to_bottom=true end

local function process_chat(request)
  local items=selected_midi_items(); local key,kerr=get_api_key(); if not key then add_message("assistant",kerr); return end
  local answer,aerr=run_openai(build_prompt(request,context_text(items),history_text(history)),key)
  if not answer then add_message("assistant","KI-Aufruf fehlgeschlagen: "..aerr); return end
  local results,chats,verr=validate_response(answer,items)
  if not results then add_message("assistant","Antwort verworfen: "..verr); return end
  local _,changes,cerr=apply_results(results,items)
  if cerr then add_message("assistant","REAPER-Aktion fehlgeschlagen: "..tostring(cerr)); return end
  if #chats>0 then add_message("assistant",table.concat(chats,"\n"))
  elseif changes and changes>0 then add_message("assistant",string.format("%d Aktion(en) ausgefuehrt.",changes))
  else add_message("assistant","Keine Aenderung ausgefuehrt.") end
end

local function wrap_lines(text,maxw)
  local lines={}; for para in (tostring(text).."\n"):gmatch("(.-)\n") do
    local line=""; for word in para:gmatch("%S+") do local test=line=="" and word or line.." "..word; if gfx.measurestr(test)>maxw and line~="" then lines[#lines+1]=line; line=word else line=test end end; lines[#lines+1]=line
  end; return lines
end

local function button(x,y,w,h,label)
  gfx.set(0.88,0.88,0.88,1); gfx.rect(x,y,w,h,1); gfx.set(0.25,0.25,0.25,1); gfx.rect(x,y,w,h,0); local tw,th=gfx.measurestr(label); gfx.x=x+(w-tw)/2; gfx.y=y+(h-th)/2; gfx.drawstr(label)
end
local function inside(x,y,w,h) return gfx.mouse_x>=x and gfx.mouse_x<=x+w and gfx.mouse_y>=y and gfx.mouse_y<=y+h end

local mouse_was_down=false
local function loop()
  local ch=gfx.getchar(); if ch<0 then local dock=gfx.dock(-1); reaper.SetExtState(EXT_SECTION,DOCK_KEY,tostring(dock),true); return end
  local W,H=gfx.w,gfx.h; gfx.set(0.96,0.96,0.96,1); gfx.rect(0,0,W,H,1)
  gfx.setfont(1,"Arial",18); gfx.set(0.10,0.10,0.10,1); gfx.x=16; gfx.y=12; gfx.drawstr("Composition Studio")
  gfx.setfont(1,"Arial",13); local n=#selected_midi_items(); gfx.set(0.35,0.35,0.35,1); gfx.x=16; gfx.y=38; gfx.drawstr(string.format("%d MIDI-Item(s) ausgewaehlt  |  GPT-5.6",n))

  local chat_top,chat_bottom=64,H-170; gfx.set(1,1,1,1); gfx.rect(10,chat_top,W-20,math.max(80,chat_bottom-chat_top),1)
  gfx.setfont(1,"Arial",14); local y=chat_top+10
  local rendered={}
  for _,m in ipairs(history) do local prefix=m.role=="user" and "Du: " or "KI: "; local lines=wrap_lines(prefix..m.text,W-48); rendered[#rendered+1]={role=m.role,lines=lines} end
  local total=0; for _,b in ipairs(rendered) do total=total+#b.lines*19+8 end
  local visible_h=chat_bottom-chat_top-18; local offset=math.max(0,total-visible_h)
  y=y-offset
  for _,b in ipairs(rendered) do
    gfx.set(b.role=="user" and 0.10 or 0.20,b.role=="user" and 0.25 or 0.20,b.role=="user" and 0.55 or 0.20,1)
    for _,line in ipairs(b.lines) do if y>chat_top-20 and y<chat_bottom then gfx.x=22; gfx.y=y; gfx.drawstr(line) end; y=y+19 end; y=y+8
  end

  local field_y=H-154; gfx.set(1,1,1,1); gfx.rect(10,field_y,W-20,92,1); gfx.set(0.35,0.35,0.35,1); gfx.rect(10,field_y,W-20,92,0)
  gfx.setfont(1,"Arial",14); gfx.set(0.08,0.08,0.08,1); local shown=input; while gfx.measurestr(shown)>W-48 and #shown>1 do shown=shown:sub(2) end; gfx.x=20; gfx.y=field_y+16; gfx.drawstr(shown)
  button(W-112,H-50,100,36,busy and "Bitte warten" or "Senden")
  gfx.update()

  if not busy then
    if ch==13 and trim(input)~="" then pending=trim(input); input=""
    elseif ch==8 then input=input:sub(1,-2)
    elseif ch==22 and reaper.CF_GetClipboard then local clip=reaper.CF_GetClipboard(""); if clip then input=input..clip:gsub("[\r\n]+"," ") end
    elseif ch>=32 and ch<=0x10FFFF then local ok,c=pcall(utf8.char,ch); if ok then input=input..c end end
    local down=(gfx.mouse_cap & 1)==1
    if down and not mouse_was_down and inside(W-112,H-50,100,36) and trim(input)~="" then pending=trim(input); input="" end
    mouse_was_down=down
  end

  if pending and not busy then
    local request=pending; pending=nil; busy=true; add_message("user",request)
    reaper.defer(function() process_chat(request); busy=false; reaper.defer(loop) end)
  else reaper.defer(loop) end
end

loop()
