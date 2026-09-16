-- @description Composition Studio
-- @version 0.2-test1
-- @author Klangwerke
-- @about Dockable chat shell for AI composition and REAPER control.

local SCRIPT_NAME = "Composition Studio"
local VERSION = "0.2-test1"
local EXT_SECTION = "CompositionStudio"
local DOCK_KEY = "ChatDockState"

-- This development step deliberately keeps the proven 0.1-test9 engine as reference.
-- The new UI is a persistent REAPER-dockable conversation surface. Engine integration
-- and the expanded command protocol are developed behind this surface rather than
-- extending the old modal request window.

local history = {
  {role="KI", text="Composition Studio ist bereit. Wähle MIDI-Material aus oder beginne ohne Auswahl."}
}
local input = ""
local mouse_was_down = false

local function trim(s)
  return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function selected_midi_count()
  local count = 0
  for i=0,reaper.CountSelectedMediaItems(0)-1 do
    local item = reaper.GetSelectedMediaItem(0,i)
    local take = item and reaper.GetActiveTake(item)
    if take and reaper.TakeIsMIDI(take) then count = count + 1 end
  end
  return count
end

local function wrap_lines(text,max_width)
  local lines = {}
  local line = ""
  for word in tostring(text):gmatch("%S+") do
    local candidate = line == "" and word or line .. " " .. word
    if line ~= "" and gfx.measurestr(candidate) > max_width then
      lines[#lines+1] = line
      line = word
    else
      line = candidate
    end
  end
  if line ~= "" then lines[#lines+1] = line end
  return lines
end

local function button(x,y,w,h,label)
  gfx.set(0.88,0.88,0.88,1); gfx.rect(x,y,w,h,1)
  gfx.set(0.25,0.25,0.25,1); gfx.rect(x,y,w,h,0)
  local tw,th = gfx.measurestr(label)
  gfx.x=x+(w-tw)/2; gfx.y=y+(h-th)/2; gfx.drawstr(label)
end

local function inside(x,y,w,h)
  return gfx.mouse_x>=x and gfx.mouse_x<=x+w and gfx.mouse_y>=y and gfx.mouse_y<=y+h
end

local function add_message(role,text)
  history[#history+1] = {role=role,text=text}
end

local function submit()
  local request = trim(input)
  if request == "" then return end
  input = ""
  add_message("Du",request)
  add_message("KI","Chatoberfläche aktiv. Die neue Befehlsengine wird im nächsten Integrationsschritt mit diesem Dialog verbunden.")
end

local saved_dock = tonumber(reaper.GetExtState(EXT_SECTION,DOCK_KEY)) or 1
gfx.init(SCRIPT_NAME.." "..VERSION,430,650,saved_dock)
if saved_dock ~= 0 then gfx.dock(saved_dock) end

local function loop()
  local ch = gfx.getchar()
  if ch < 0 then
    reaper.SetExtState(EXT_SECTION,DOCK_KEY,tostring(gfx.dock(-1)),true)
    return
  end

  local W,H = gfx.w,gfx.h
  gfx.set(0.96,0.96,0.96,1); gfx.rect(0,0,W,H,1)

  gfx.setfont(1,"Arial",18)
  gfx.set(0.10,0.10,0.10,1); gfx.x=16; gfx.y=12
  gfx.drawstr("Composition Studio")

  gfx.setfont(1,"Arial",13)
  gfx.set(0.35,0.35,0.35,1); gfx.x=16; gfx.y=38
  gfx.drawstr(string.format("%d MIDI-Item(s) ausgewählt",selected_midi_count()))

  local chat_top = 64
  local chat_bottom = H-170
  gfx.set(1,1,1,1); gfx.rect(10,chat_top,W-20,math.max(80,chat_bottom-chat_top),1)

  gfx.setfont(1,"Arial",14)
  local blocks,total = {},0
  for _,m in ipairs(history) do
    local lines = wrap_lines(m.role..": "..m.text,W-48)
    blocks[#blocks+1] = lines
    total = total + #lines*19 + 8
  end
  local visible_h = chat_bottom-chat_top-18
  local y = chat_top+10-math.max(0,total-visible_h)
  for _,lines in ipairs(blocks) do
    gfx.set(0.16,0.16,0.16,1)
    for _,line in ipairs(lines) do
      if y>chat_top-20 and y<chat_bottom then gfx.x=22; gfx.y=y; gfx.drawstr(line) end
      y=y+19
    end
    y=y+8
  end

  local field_y = H-154
  gfx.set(1,1,1,1); gfx.rect(10,field_y,W-20,92,1)
  gfx.set(0.35,0.35,0.35,1); gfx.rect(10,field_y,W-20,92,0)
  gfx.setfont(1,"Arial",14); gfx.set(0.08,0.08,0.08,1)
  local shown=input
  while gfx.measurestr(shown)>W-48 and #shown>1 do shown=shown:sub(2) end
  gfx.x=20; gfx.y=field_y+16; gfx.drawstr(shown)

  button(W-112,H-50,100,36,"Senden")
  gfx.update()

  if ch==13 then submit()
  elseif ch==8 then input=input:sub(1,-2)
  elseif ch==22 and reaper.CF_GetClipboard then
    local clip=reaper.CF_GetClipboard("")
    if clip then input=input..clip:gsub("[\r\n]+"," ") end
  elseif ch>=32 and ch<=0x10FFFF then
    local ok,c=pcall(utf8.char,ch); if ok then input=input..c end
  end

  local down=(gfx.mouse_cap & 1)==1
  if down and not mouse_was_down and inside(W-112,H-50,100,36) then submit() end
  mouse_was_down=down

  reaper.defer(loop)
end

loop()
