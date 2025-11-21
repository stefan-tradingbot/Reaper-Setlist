local function msg(s)
    reaper.ShowConsoleMsg(tostring(s) .. "\n")
end

local function ensure_directory(path)
    reaper.RecursiveCreateDirectory(path, 0)
end

local function os_date_string()
    return os.date("%Y-%m-%d_%H-%M-%S")
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

local function export_tracks_in_project(proj, export_root, track_names)
    local _, _ = reaper.EnumProjects(-1, "")
    local proj_name = reaper.GetProjectName(proj, "")
    proj_name = proj_name:gsub("%.rpp", "")
    local export_path = export_root .. "/" .. proj_name
    ensure_directory(export_path)
    msg("Exportiere Projekt: " .. proj_name)
    reaper.Main_OnCommand(40297, 0)
    local num_tracks = reaper.CountTracks(proj)
    local selected = 0
    for i = 0, num_tracks - 1 do
        local track = reaper.GetTrack(proj, i)
        local _, name = reaper.GetTrackName(track, "")
        for _, wanted_name in ipairs(track_names) do
            if name == wanted_name then
                reaper.SetTrackSelected(track, true)
                selected = selected + 1
            end
        end
    end
    if selected == 0 then
        msg("⚠️ Keine passenden Spuren gefunden in " .. proj_name)
        return
    end
    local end_pos = get_end_marker_pos(proj)
    reaper.GetSet_LoopTimeRange2(proj, true, false, 0.0, end_pos, false)
    reaper.GetSetProjectInfo(proj, "RENDER_SETTINGS", 1, true)
    reaper.GetSetProjectInfo(proj, "RENDER_BOUNDSFLAG", 1, true)
    reaper.GetSetProjectInfo(proj, "RENDER_CHANNELS", 2, true)
    reaper.GetSetProjectInfo(proj, "RENDER_SRATE", 48000, true)
    reaper.GetSetProjectInfo_String(proj, "RENDER_FORMAT", "wav", true)
    reaper.GetSetProjectInfo_String(proj, "RENDER_FILE", export_path .. "/$track", true)
    reaper.GetSetProjectInfo_String(proj, "RENDER_PATTERN", "$track", true)
    msg("→ Rendern nach: " .. export_path)
    reaper.Main_OnCommand(41824, 0)
    reaper.GetSet_LoopTimeRange2(proj, true, false, 0.0, 0.0, false)
    reaper.Main_OnCommand(40297, 0)
end

---@param track_names string[]
---@param export_path string
local function ExportRecordings(track_names, export_path)
    reaper.ClearConsole()
    
    if not track_names or #track_names == 0 then
        msg("Keine Spuren ausgewählt.")
        return
    end
    
    if not export_path or export_path == "" then
        msg("Kein Export-Pfad angegeben.")
        return
    end

    msg("Starte Export mit " .. #track_names .. " ausgewählten Spuren...")
    msg("Zielordner: " .. export_path)
    
    local root_folder = export_path .. "/TT_Liveset_Recording_" .. os_date_string()
    ensure_directory(root_folder)
    
    local i = 0
    while true do
        local proj = reaper.EnumProjects(i, "")
        if not proj then break end
        reaper.SelectProjectInstance(proj)
        export_tracks_in_project(proj, root_folder, track_names)
        i = i + 1
    end
    
    msg("✅ Export abgeschlossen!")
    reaper.ShowMessageBox("Alle Projekte wurden exportiert!\n\nZielordner:\n" .. root_folder, "Export abgeschlossen", 0)
end

return ExportRecordings
