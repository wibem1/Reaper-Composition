-- @description Composition Studio Basic
-- @version 0.1-test9
-- @author Klangwerke
-- @about Direct AI composition in REAPER: create new music or continue from selected MIDI.

local SCRIPT_NAME = "Composition Studio Basic"
local VERSION = "0.1-test9"
local EXT_SECTION, EXT_KEY = "CompositionStudio", "OpenAIAPIKey"
local WINDOW_EXT_KEY = "RequestWindowGeometry"

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
      if quote and quote<=block_end then local text=read_json_string(raw,quote); if text and text~="" then return text end end
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
  if #items==0 then
    l[#l+1]="KEIN VORHANDENES MIDI-MATERIAL. Die Komposition beginnt neu."
  else
    for i,it in ipairs(items) do
      l[#l+1]=string.format("ITEM %d id=%s track=%s take=%s",i,it.guid,it.track_name,it.take_name)
      for _,n in ipairs(it.notes) do l[#l+1]=string.format("N %.5f %.5f %d %d %d",n.start_qn,n.duration_qn,n.pitch,n.velocity,n.channel) end
    end
  end
  return table.concat(l,"\n")
end

local function build_prompt(request,music)
  return [[Du komponierst Musik.
Wenn MIDI-Material uebergeben wurde, nutze es als gemeinsamen musikalischen Kontext.
Wenn kein MIDI-Material uebergeben wurde, komponiere auf Grundlage des freien Auftrags etwas Neues.
Erfuelle den freien Auftrag musikalisch eigenstaendig.
Fuege keine unnoetigen musikalischen Regeln hinzu.

Antworte ausschliesslich mit technischen Ergebniszeilen:
CS|unchanged|SOURCE_GUID
CS|revised|SOURCE_GUID|NAME|startQN,durationQN,pitch,velocity,channel;...
CS|new|-|NAME|startQN,durationQN,pitch,velocity,channel;...

Technische Regeln:
Fuer revised muss SOURCE_GUID exakt eine angebotene Item-GUID sein.
Fuer new ist SOURCE_GUID '-'.
Wenn kein MIDI-Material angeboten wurde, verwende ausschliesslich CS|new|-|... .
Fuer jede benoetigte Stimme bzw. Spur eine eigene CS|new-Zeile ausgeben.
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
        if kind=="revised" and not sources[source] then return nil,"Unbekannte revised-Quelle." end
        if kind=="new" and source~="-" then return nil,"new muss Quelle '-' verwenden." end
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
  local take=reaper.GetActiveTake(item); if not take then return nil,"MIDI-Take konnte nicht erzeugt werden." end
  reaper.GetSetMediaItemTakeInfo_String(take,"P_NAME",name,true)
  for _,n in ipairs(notes) do
    local s=reaper.MIDI_GetPPQPosFromProjTime(take,qn_to_time(n.start_qn)); local e=reaper.MIDI_GetPPQPosFromProjTime(take,qn_to_time(n.start_qn+n.duration_qn))
    reaper.MIDI_InsertNote(take,false,false,s,e,n.channel,n.pitch,n.velocity,true)
  end
  reaper.MIDI_Sort(take); return item
end

local function create_track(name)
  local i=reaper.CountTracks(0); reaper.InsertTrackAtIndex(i,true); local t=reaper.GetTrack(0,i)
  if t then reaper.GetSetMediaTrackInfo_String(t,"P_NAME",name,true) end; return t
end

local function create_track_below(source_track,name)
  if not source_track then return nil end
  local track_number=reaper.GetMediaTrackInfo_Value(source_track,"IP_TRACKNUMBER"); if not track_number or track_number<1 then return nil end
  local insert_index=math.floor(track_number); reaper.InsertTrackAtIndex(insert_index,true); local t=reaper.GetTrack(0,insert_index)
  if t then reaper.GetSetMediaTrackInfo_String(t,"P_NAME",name,true) end; return t
end

local function apply_results(results,items)
  local sources={}; for _,it in ipairs(items) do sources[it.guid]=it end; local created={}
  reaper.Undo_BeginBlock2(0); reaper.PreventUIRefresh(1)
  local ok,err=xpcall(function()
    for _,r in ipairs(results) do
      if r.kind=="revised" then
        local src=sources[r.source]; local variant_name=r.name.." [Variante]"; local tr=create_track_below(src.track,variant_name)
        if not tr then error("Variantenspur konnte nicht erzeugt werden.") end
        local item,why=create_midi_item(tr,variant_name,r.notes); if not item then error(why) end; created[#created+1]=item
      elseif r.kind=="new" then
        local tr=create_track(r.name); if not tr then error("Neue Spur konnte nicht erzeugt werden.") end
        local item,why=create_midi_item(tr,r.name,r.notes); if not item then error(why) end; created[#created+1]=item
      end
    end
  end,debug.traceback)
  reaper.PreventUIRefresh(-1)
  if not ok then reaper.Undo_EndBlock2(0,"Composition Studio – fehlgeschlagen",-1); reaper.Undo_DoUndo2(0); return nil,err end
  if #created>0 then
    for i=0,reaper.CountMediaItems(0)-1 do reaper.SetMediaItemSelected(reaper.GetMediaItem(0,i),false) end
    for _,it in ipairs(created) do reaper.SetMediaItemSelected(it,true) end
  end
  reaper.UpdateArrange(); reaper.Undo_EndBlock2(0,"Composition Studio – KI-Komposition",-1); return created
end

local function process_request(items,request)
  local key,kerr=get_api_key(); if not key then reaper.ShowMessageBox(kerr,SCRIPT_NAME,0); return end
  local answer,aerr=run_openai(build_prompt(request,context_text(items)),key)
  if not answer then reaper.ShowMessageBox("KI-Aufruf nicht ausgeführt:\n\n"..aerr.."\n\nDas REAPER-Projekt wurde nicht verändert.",SCRIPT_NAME.." "..VERSION,0); return end
  local results,verr=validate_response(answer,items)
  if not results then reaper.ShowMessageBox("KI-Antwort verworfen:\n\n"..verr.."\n\nDas REAPER-Projekt wurde nicht verändert.",SCRIPT_NAME.." "..VERSION,0); return end
  local created,cerr=apply_results(results,items)
  if not created then reaper.ShowMessageBox("Ergebnis konnte nicht angewendet werden:\n\n"..tostring(cerr),SCRIPT_NAME.." "..VERSION,0); return end
  if #created==0 then
    reaper.ShowMessageBox("Die KI hat keine neue oder überarbeitete Stimme erzeugt.\nDie ursprüngliche Auswahl bleibt erhalten.",SCRIPT_NAME.." "..VERSION,0)
  else
    reaper.ShowMessageBox(string.format("%d neues/überarbeitetes MIDI-Item(s) erzeugt.\n\nOriginale blieben erhalten. Neue Items sind ausgewählt.\nDer Vorgang ist ein REAPER-Undo-Schritt.",#created),SCRIPT_NAME.." "..VERSION,0)
  end
end

local function load_window_geometry()
  local saved=reaper.GetExtState(EXT_SECTION,WINDOW_EXT_KEY)
  local x,y,w,h=saved:match("^(-?%d+),(-?%d+),(%d+),(%d+)$")
  x,y,w,h=tonumber(x),tonumber(y),tonumber(w),tonumber(h)
  if not (x and y and w and h and w>=500 and h>=220) then return nil,nil,780,280 end
  return x,y,w,h
end

local function ask_request_large(n,on_submit)
  local X,Y,W,H=load_window_geometry()
  local text=""
  local mouse_was_down=false
  local cursor_visible=true
  local last_blink=reaper.time_precise()
  gfx.init(SCRIPT_NAME.." "..VERSION,W,H,0,X,Y)

  local function save_geometry()
    local _,x,y,w,h=gfx.dock(-1,0,0,0,0)
    w=gfx.w>0 and gfx.w or w; h=gfx.h>0 and gfx.h or h
    if x and y and w and h then reaper.SetExtState(EXT_SECTION,WINDOW_EXT_KEY,string.format("%d,%d,%d,%d",x,y,w,h),true) end
  end
  local function close_window()
    save_geometry(); gfx.quit()
  end
  local function inside(x,y,w,h) return gfx.mouse_x>=x and gfx.mouse_x<=x+w and gfx.mouse_y>=y and gfx.mouse_y<=y+h end
  local function button(x,y,w,h,label)
    gfx.set(0.88,0.88,0.88,1); gfx.rect(x,y,w,h,1); gfx.set(0.25,0.25,0.25,1); gfx.rect(x,y,w,h,0)
    local tw,th=gfx.measurestr(label); gfx.x=x+(w-tw)/2; gfx.y=y+(h-th)/2; gfx.drawstr(label)
  end
  local function paste_clipboard()
    if reaper.CF_GetClipboard then local clip=reaper.CF_GetClipboard(""); if clip and clip~="" then text=text..clip:gsub("[\r\n]+"," ") end end
  end
  local function finish()
    local request=trim(text); close_window(); if request~="" then on_submit(request) end
  end
  local function loop()
    W,H=gfx.w,gfx.h
    if W<500 then W=500 end; if H<220 then H=220 end
    gfx.set(0.96,0.96,0.96,1); gfx.rect(0,0,W,H,1)
    gfx.setfont(1,"Arial",20); gfx.set(0.12,0.12,0.12,1); gfx.x=28; gfx.y=24
    if n==0 then gfx.drawstr("Neue Komposition – kein MIDI-Kontext") else gfx.drawstr(string.format("%d MIDI-Item(s) als Kontext erkannt",n)) end
    gfx.setfont(1,"Arial",18); gfx.x=28; gfx.y=60; gfx.drawstr("Freier Kompositionsauftrag:")
    local field_h=math.max(74,H-206)
    gfx.set(1,1,1,1); gfx.rect(28,96,W-56,field_h,1); gfx.set(0.30,0.30,0.30,1); gfx.rect(28,96,W-56,field_h,0)
    gfx.set(0.08,0.08,0.08,1); gfx.x=40; gfx.y=118
    local shown=text
    while gfx.measurestr(shown)>W-90 and #shown>1 do shown=shown:sub(2) end
    gfx.drawstr(shown)
    if reaper.time_precise()-last_blink>0.5 then cursor_visible=not cursor_visible; last_blink=reaper.time_precise() end
    if cursor_visible then local tw=gfx.measurestr(shown); gfx.line(40+tw,116,40+tw,142) end
    local by=H-62
    button(W-270,by,110,42,"Abbrechen"); button(W-142,by,114,42,"Komponieren")
    gfx.update()

    local ch=gfx.getchar()
    if ch<0 or ch==27 then close_window(); return end
    if ch==13 and trim(text)~="" then finish(); return
    elseif ch==8 then text=text:sub(1,-2)
    elseif ch==22 then paste_clipboard()
    elseif ch>=32 and ch<=0x10FFFF then local ok,c=pcall(utf8.char,ch); if ok then text=text..c end end

    local down=(gfx.mouse_cap & 1)==1
    if down and not mouse_was_down then
      if inside(W-270,by,110,42) then close_window(); return
      elseif inside(W-142,by,114,42) and trim(text)~="" then finish(); return end
    end
    mouse_was_down=down
    reaper.defer(loop)
  end
  loop()
end

local items=selected_midi_items()
ask_request_large(#items,function(request) process_request(items,request) end)
