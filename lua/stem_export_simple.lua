-- Vereinfachter Stem Export ohne GUI
-- Exportiert alle Spuren aus allen geöffneten Projekten

---------------------------------
-- EINSTELLUNGEN
---------------------------------
local EXPORT_BASE_PATH = "/Users/mgeigerhilk/Documents/set_export"

-- Hier kannst du die Track-Namen anpassen, die exportiert werden sollen
-- Leer lassen = alle Tracks exportieren
local TRACK_NAMES = {
    "Bass", "Sample", "Backing Vox", "E-Drums",
    "Git S", "Git P", "Vox S", "Vox P", "Vox E"
}

---------------------------------
-- HILFSFUNKTIONEN
---------------------------------
local function os_date_string()
    return os.date("%Y-%m-%d_%H-%M-%S")
end

local function ensure_directory(path)
    reaper.RecursiveCreateDirectory(path, 0)
end

local function msg(s)
    reaper.ShowConsoleMsg(tostring(s) .. "\n")
end

local function get_end_marker_pos(proj)
    local count = reaper.CountProjectMarkers(proj)
    local end_pos = reaper.GetProjectLength(proj)
    for i = 0, count - 1 do
        local retval, isrgn, pos, _, name = reaper.EnumProjectMarkers(i)
        if retval and not isrgn and name:upper():find("END") then
            end_pos = pos
            break
        end
    end
    return end_pos
end

---------------------------------
-- EXPORT-FUNKTION
---------------------------------
local function export_tracks_in_project(proj, export_root, track_names)
    local _, _ = reaper.EnumProjects(-1, "")
    local proj_name = reaper.GetProjectName(proj, "")
    proj_name = proj_name:gsub("%.rpp", "")
    local export_path = export_root .. "/" .. proj_name
    ensure_directory(export_path)

    msg("Exportiere Projekt: " .. proj_name)

    -- Spuren selektieren
    reaper.Main_OnCommand(40297, 0)  -- Deselect all tracks
    local num_tracks = reaper.CountTracks(proj)
    local selected = 0
    
    for i = 0, num_tracks - 1 do
        local track = reaper.GetTrack(proj, i)
        local _, name = reaper.GetTrackName(track, "")
        
        -- Wenn TRACK_NAMES leer ist, alle Tracks exportieren
        if #track_names == 0 then
            reaper.SetTrackSelected(track, true)
            selected = selected + 1
        else
            -- Nur bestimmte Tracks exportieren
            for _, wanted_name in ipairs(track_names) do
                if name == wanted_name then
                    reaper.SetTrackSelected(track, true)
                    selected = selected + 1
                    break
                end
            end
        end
    end

    if selected == 0 then
        msg("⚠️ Keine passenden Spuren gefunden in " .. proj_name)
        return
    end

    msg("→ " .. selected .. " Spuren ausgewählt")

    ---------------------------------
    -- Time-Selection auf Projektbereich setzen
    ---------------------------------
    local end_pos = get_end_marker_pos(proj)
    reaper.GetSet_LoopTimeRange2(proj, true, false, 0.0, end_pos, false)

    ---------------------------------
    -- Render Einstellungen
    ---------------------------------
    reaper.GetSetProjectInfo(proj, "RENDER_SETTINGS", 1, true)   -- 1 = Master + Stems
    reaper.GetSetProjectInfo(proj, "RENDER_BOUNDSFLAG", 1, true) -- 1 = time selection
    reaper.GetSetProjectInfo(proj, "RENDER_CHANNELS", 2, true)
    reaper.GetSetProjectInfo(proj, "RENDER_SRATE", 48000, true)
    reaper.GetSetProjectInfo_String(proj, "RENDER_FORMAT", "wav", true)
    reaper.GetSetProjectInfo_String(proj, "RENDER_FILE", export_path .. "/$track", true)
    reaper.GetSetProjectInfo_String(proj, "RENDER_PATTERN", "$track", true)

    msg("→ Rendern nach: " .. export_path)

    -- Rendern
    reaper.Main_OnCommand(41824, 0)  -- File: Render project, using the most recent render settings

    -- Aufräumen
    reaper.GetSet_LoopTimeRange2(proj, true, false, 0.0, 0.0, false)
    reaper.Main_OnCommand(40297, 0)  -- Deselect all tracks
end

---------------------------------
-- HAUPTPROGRAMM
---------------------------------
reaper.ClearConsole()
msg("=== Stem Export gestartet ===")
msg("Export-Pfad: " .. EXPORT_BASE_PATH)

local root_folder = EXPORT_BASE_PATH .. "/TT_Liveset_Recording_" .. os_date_string()
ensure_directory(root_folder)

local project_count = 0
local i = 0
while true do
    local proj = reaper.EnumProjects(i, "")
    if not proj then break end
    reaper.SelectProjectInstance(proj)
    export_tracks_in_project(proj, root_folder, TRACK_NAMES)
    project_count = project_count + 1
    i = i + 1
end

msg("✅ Export abgeschlossen!")
msg("Exportierte Projekte: " .. project_count)
msg("Zielordner: " .. root_folder)

reaper.ShowMessageBox(
    "Alle Projekte wurden exportiert!\n\n" ..
    "Anzahl Projekte: " .. project_count .. "\n" ..
    "Zielordner:\n" .. root_folder,
    "Export abgeschlossen", 
    0
)
