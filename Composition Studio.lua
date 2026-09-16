-- @description Composition Studio
-- @version 0.2-test3
-- @author Klangwerke
-- @about ReaImGui chat shell for AI composition and REAPER control.

local SCRIPT_NAME = "Composition Studio"
local VERSION = "0.2-test3"

-- ReaImGui is deliberately required from this version onward.  The old gfx editor
-- was useful as a proof of concept, but it is not a real text editor.  ReaImGui's
-- InputTextMultiline provides native cursor movement, selection and clipboard editing.
if not reaper.ImGui_CreateContext or not reaper.ImGui_InputTextMultiline then
  reaper.ShowMessageBox(
    "Composition Studio "..VERSION.." benötigt ReaImGui.\n\n"..
    "Installiere in REAPER über ReaPack das Paket 'ReaImGui: ReaScript binding for Dear ImGui' "..
    "aus dem standardmäßigen ReaTeam Extensions Repository und starte REAPER danach neu.",
    SCRIPT_NAME, 0)
  return
end

local ctx = reaper.ImGui_CreateContext(SCRIPT_NAME)
local open = true
local input = ""
local history = {
  {role="KI", text="Composition Studio ist bereit. Wähle MIDI-Material aus oder beginne ohne Auswahl."}
}

local function trim(s)
  return (s or ""):gsub("^%s+",""):gsub("%s+$","")
end

local function selected_midi_count()
  local count=0
  for i=0,reaper.CountSelectedMediaItems(0)-1 do
    local item=reaper.GetSelectedMediaItem(0,i)
    local take=item and reaper.GetActiveTake(item)
    if take and reaper.TakeIsMIDI(take) then count=count+1 end
  end
  return count
end

local function add_message(role,text)
  history[#history+1]={role=role,text=text}
end

local function submit()
  local request=trim(input)
  if request=="" then return end
  input=""
  add_message("Du",request)
  add_message("KI","Eingabe empfangen. Die Kompositions- und Befehlsengine wird im nächsten Integrationsschritt mit diesem Dialog verbunden.")
end

local function draw_history()
  for _,m in ipairs(history) do
    reaper.ImGui_TextWrapped(ctx,m.role..": "..m.text)
    reaper.ImGui_Spacing(ctx)
  end
  if reaper.ImGui_GetScrollY(ctx) >= reaper.ImGui_GetScrollMaxY(ctx)-4 then
    reaper.ImGui_SetScrollHereY(ctx,1.0)
  end
end

local function loop()
  if not open then return end

  -- The window is a normal ReaImGui window. REAPER can dock it through the standard
  -- script-window docking controls; ImGui also remembers its size and position.
  reaper.ImGui_SetNextWindowSize(ctx,460,650,reaper.ImGui_Cond_FirstUseEver())
  local visible
  visible,open=reaper.ImGui_Begin(ctx,SCRIPT_NAME.."  "..VERSION,open)

  if visible then
    reaper.ImGui_Text(ctx,string.format("GPT-5.6  |  %d MIDI-Item(s) ausgewählt",selected_midi_count()))
    reaper.ImGui_Separator(ctx)

    local avail_w,avail_h=reaper.ImGui_GetContentRegionAvail(ctx)
    local input_h=125
    local button_h=30
    local chat_h=math.max(100,avail_h-input_h-button_h-28)

    if reaper.ImGui_BeginChild(ctx,"##chat",avail_w,chat_h,reaper.ImGui_ChildFlags_Borders()) then
      draw_history()
      reaper.ImGui_EndChild(ctx)
    end

    reaper.ImGui_Spacing(ctx)

    local changed,new_input=reaper.ImGui_InputTextMultiline(
      ctx,"##composition_request",input,avail_w,input_h)
    if changed then input=new_input end

    reaper.ImGui_Spacing(ctx)
    if reaper.ImGui_Button(ctx,"Senden",100,button_h) then submit() end

    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_TextDisabled(ctx,"Mehrzeilige Eingabe · Cursor/Markieren/Kopieren/Einfügen")

    reaper.ImGui_End(ctx)
  end

  if open then reaper.defer(loop) end
end

loop()
