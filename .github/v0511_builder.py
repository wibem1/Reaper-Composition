from pathlib import Path
p=Path('Composition Studio.lua')
s=p.read_text()
s=s.replace('-- @version 0.5.10','-- @version 0.5.11',1).replace('local VERSION="0.5.10"','local VERSION="0.5.11"',1)
a=s.index('local function choose_save_path('); b=s.index('\nlocal function save_diagnosis()',a)
new=r'''local save_panel=nil
local function begin_save_panel(kind,title,default_name,ext)
 if save_panel then update_status="Ein Speichern-Dialog ist bereits geöffnet."; return end
 local script=os.tmpname()..".applescript"; local out=os.tmpname()..".path"; local done=os.tmpname()..".done"
 local function aq(v) return tostring(v or ""):gsub("\\","\\\\"):gsub('"','\\"') end
 local as='try\nset f to choose file name with prompt "'..aq(title)..'" default name "'..aq(default_name)..'"\nreturn POSIX path of f\non error number -128\nreturn ""\nend try\n'
 if not write_file(script,as) then update_status="Speichern-Dialog konnte nicht vorbereitet werden."; return end
 local cmd="(/usr/bin/osascript "..shell_quote(script).." > "..shell_quote(out).." 2>/dev/null; echo done > "..shell_quote(done)..") &"
 os.execute(cmd); save_panel={kind=kind,script=script,out=out,done=done,ext=ext}; update_status="Speicherort wählen …"
end
local function finish_save_panel()
 if not save_panel or not read_file(save_panel.done) then return end
 local p=save_panel; save_panel=nil; local fn=trim(read_file(p.out)); os.remove(p.script); os.remove(p.out); os.remove(p.done)
 if fn=="" then update_status="Speichern abgebrochen."; return end
 if not fn:lower():match("%."..p.ext.."$") then fn=fn.."."..p.ext end
 if p.kind=="diagnosis" then
  local raw=diag_json(); if write_file(fn,raw) then local chk=read_file(fn); if chk and #chk==#raw then persist_diag(); write_file(DIAG_CACHE_PATH,raw); update_status="Diagnose gespeichert: "..fn.." ("..tostring(#raw).." Bytes)" else update_status="Diagnose konnte nach dem Schreiben nicht verifiziert werden: "..fn end else update_status="Diagnose konnte nicht gespeichert werden: "..fn end
 elseif p.kind=="midi" then local ok,msg=write_last_midi_to(fn); update_status=msg end
end'''
s=s[:a]+new+s[b:]
a=s.index('local function save_diagnosis()'); b=s.index('\nlocal function be16',a)
s=s[:a]+'''local function save_diagnosis()\n begin_save_panel("diagnosis","Diagnose speichern","Composition-Studio-Diagnose-"..os.date("%Y%m%d-%H%M%S")..".json","json")\nend\n'''+s[b:]
s=s.replace('local function export_last_midi()','local function write_last_midi_to(fn)',1)
old=' local fn=choose_save_path("MIDI exportieren","Composition-Studio-"..os.date("%Y%m%d-%H%M%S")..".mid","mid"); if not fn then update_status="MIDI-Export abgebrochen."; return end'
if old not in s: raise SystemExit('export path block not found')
s=s.replace(old,'',1)
s=s.replace('update_status="MIDI exportiert: "..fn.." ("..tostring(tracks).." Spuren, "..tostring(#chk).." Bytes)"','return true,"MIDI exportiert: "..fn.." ("..tostring(tracks).." Spuren, "..tostring(#chk).." Bytes)"',1)
s=s.replace('update_status="MIDI-Datei wurde geschrieben, ist aber ungültig: "..fn','return false,"MIDI-Datei wurde geschrieben, ist aber ungültig: "..fn',1)
s=s.replace('update_status="MIDI-Datei konnte nicht geschrieben werden: "..fn','return false,"MIDI-Datei konnte nicht geschrieben werden: "..fn',1)
pos=s.index('local function analysis_prompt(')
launcher='''local function export_last_midi()\n local made=last_made; if #made==0 then made=recover_last_made() end\n local valid=0; for _,it in ipairs(made) do if reaper.ValidatePtr2(0,it,"MediaItem*") then valid=valid+1 end end\n if valid==0 then update_status="Noch keine gültige von Composition Studio erzeugte MIDI-Komposition zum Exportieren."; return end\n begin_save_panel("midi","MIDI exportieren","Composition-Studio-"..os.date("%Y%m%d-%H%M%S")..".mid","mid")\nend\n'''
s=s[:pos]+launcher+s[pos:]
if 'local function loop() poll_job();' not in s: raise SystemExit('loop marker missing')
s=s.replace('local function loop() poll_job();','local function loop() poll_job(); finish_save_panel();',1)
p.write_text(s)
