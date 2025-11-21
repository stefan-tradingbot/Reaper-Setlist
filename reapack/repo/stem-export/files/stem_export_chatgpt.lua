-- TT_Liveset_Recording_Export.lua
-- Version mit UI-Auswahl für Track-Export

---------------------------------
-- EINSTELLUNGEN
---------------------------------
local EXPORT_BASE_PATH = "/home/verwalter/Dokumente/set_export"

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
-- TRACK-SAMMLUNG
---------------------------------
local function collect_all_track_names()
    local track_set = {}
    local i = 0
    
    while true do
        local proj = reaper.EnumProjects(i, "")
        if not proj then break end
        
        local num_tracks = reaper.CountTracks(proj)
        for j = 0, num_tracks - 1 do
            local track = reaper.GetTrack(proj, j)
            local _, name = reaper.GetTrackName(track, "")
            if name and name ~= "" then
                track_set[name] = true
            end
        end
        i = i + 1
    end
    
    -- In sortierte Liste umwandeln
    local track_list = {}
    for name, _ in pairs(track_set) do
        table.insert(track_list, name)
    end
    table.sort(track_list)
    
    return track_list
end

---------------------------------
-- UI DIALOG
---------------------------------
local function show_track_selection_dialog(track_names)
    local selected = {}
    for i = 1, #track_names do
        selected[i] = true  -- Standardmäßig alle ausgewählt
    end
    
    local window_w = 400
    local window_h = math.min(600, 100 + #track_names * 25)
    local margin = 20
    local line_height = 25
    local button_height = 30
    local scroll_offset = 0
    local max_scroll = math.max(0, #track_names * line_height - (window_h - 120))
    
    gfx.init("Track-Auswahl für Export", window_w, window_h)
    
    local running = true
    local confirmed = false
    
    while running do
        -- Hintergrund
        gfx.set(0.2, 0.2, 0.2)
        gfx.rect(0, 0, window_w, window_h, 1)
        
        -- Titel
        gfx.set(1, 1, 1)
        gfx.setfont(1, "Arial", 16, 'b')
        gfx.x = margin
        gfx.y = margin
        gfx.drawstr("Wählen Sie die zu exportierenden Spuren:")
        
        -- Buttons oben
        local btn_y = margin + 30
        local btn_w = 100
        local btn_spacing = 10
        
        -- "Alle" Button
        gfx.set(0.3, 0.5, 0.3)
        gfx.rect(margin, btn_y, btn_w, button_height, 1)
        gfx.set(1, 1, 1)
        gfx.setfont(1, "Arial", 14)
        gfx.x = margin + 25
        gfx.y = btn_y + 8
        gfx.drawstr("Alle")
        
        -- "Keine" Button
        gfx.set(0.5, 0.3, 0.3)
        gfx.rect(margin + btn_w + btn_spacing, btn_y, btn_w, button_height, 1)
        gfx.set(1, 1, 1)
        gfx.x = margin + btn_w + btn_spacing + 20
        gfx.y = btn_y + 8
        gfx.drawstr("Keine")
        
        -- Track-Liste
        local list_y = btn_y + button_height + 20
        local list_h = window_h - list_y - button_height - margin * 2
        
        gfx.setfont(1, "Arial", 13)
        for i = 1, #track_names do
            local y = list_y + (i - 1) * line_height - scroll_offset
            
            if y >= list_y and y < list_y + list_h then
                -- Checkbox
                local checkbox_x = margin
                local checkbox_y = y
                local checkbox_size = 16
                
                gfx.set(0.4, 0.4, 0.4)
                gfx.rect(checkbox_x, checkbox_y, checkbox_size, checkbox_size, 1)
                
                if selected[i] then
                    gfx.set(0.2, 0.7, 0.3)
                    gfx.rect(checkbox_x + 3, checkbox_y + 3, checkbox_size - 6, checkbox_size - 6, 1)
                end
                
                -- Track-Name
                gfx.set(1, 1, 1)
                gfx.x = checkbox_x + checkbox_size + 10
                gfx.y = checkbox_y + 2
                gfx.drawstr(track_names[i])
            end
        end
        
        -- OK/Abbrechen Buttons
        local bottom_btn_y = window_h - button_height - margin
        
        -- OK Button
        gfx.set(0.2, 0.6, 0.2)
        gfx.rect(window_w - 2 * btn_w - btn_spacing - margin, bottom_btn_y, btn_w, button_height, 1)
        gfx.set(1, 1, 1)
        gfx.setfont(1, "Arial", 14, 'b')
        gfx.x = window_w - 2 * btn_w - btn_spacing - margin + 30
        gfx.y = bottom_btn_y + 8
        gfx.drawstr("OK")
        
        -- Abbrechen Button
        gfx.set(0.6, 0.2, 0.2)
        gfx.rect(window_w - btn_w - margin, bottom_btn_y, btn_w, button_height, 1)
        gfx.set(1, 1, 1)
        gfx.x = window_w - btn_w - margin + 15
        gfx.y = bottom_btn_y + 8
        gfx.drawstr("Abbrechen")
        
        gfx.update()
        
        -- Event-Handling
        local char = gfx.getchar()
        if char == -1 or char == 27 then  -- Fenster geschlossen oder ESC
            running = false
        elseif char == 13 then  -- Enter
            confirmed = true
            running = false
        end
        
        local mouse_cap = gfx.mouse_cap
        if mouse_cap == 1 then  -- Linksklick
            local mx, my = gfx.mouse_x, gfx.mouse_y
            
            -- "Alle" Button
            if mx >= margin and mx <= margin + btn_w and 
               my >= btn_y and my <= btn_y + button_height then
                for i = 1, #selected do selected[i] = true end
                reaper.defer(function() end)  -- Kurze Pause
            end
            
            -- "Keine" Button
            if mx >= margin + btn_w + btn_spacing and mx <= margin + 2 * btn_w + btn_spacing and
               my >= btn_y and my <= btn_y + button_height then
                for i = 1, #selected do selected[i] = false end
                reaper.defer(function() end)
            end
            
            -- Track-Checkboxen
            for i = 1, #track_names do
                local y = list_y + (i - 1) * line_height - scroll_offset
                if y >= list_y and y < list_y + list_h then
                    if mx >= margin and mx <= margin + 200 and
                       my >= y and my <= y + line_height then
                        selected[i] = not selected[i]
                        reaper.defer(function() end)
                        break
                    end
                end
            end
            
            -- OK Button
            if mx >= window_w - 2 * btn_w - btn_spacing - margin and 
               mx <= window_w - btn_w - btn_spacing - margin and
               my >= bottom_btn_y and my <= bottom_btn_y + button_height then
                confirmed = true
                running = false
            end
            
            -- Abbrechen Button
            if mx >= window_w - btn_w - margin and mx <= window_w - margin and
               my >= bottom_btn_y and my <= bottom_btn_y + button_height then
                running = false
            end
        end
        
        -- Scrolling mit Mausrad
        local mouse_wheel = gfx.mouse_wheel
        if mouse_wheel ~= 0 then
            scroll_offset = scroll_offset - mouse_wheel
            scroll_offset = math.max(0, math.min(scroll_offset, max_scroll))
            gfx.mouse_wheel = 0
        end
    end
    
    gfx.quit()
    
    if not confirmed then
        return nil
    end
    
    -- Ausgewählte Tracks zurückgeben
    local selected_tracks = {}
    for i = 1, #track_names do
        if selected[i] then
            table.insert(selected_tracks, track_names[i])
        end
    end
    
    return selected_tracks
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

    ---------------------------------
    -- FIX: Time-Selection auf Projektbereich setzen
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
    reaper.Main_OnCommand(41824, 0)

    -- Aufräumen
    reaper.GetSet_LoopTimeRange2(proj, true, false, 0.0, 0.0, false)
    reaper.Main_OnCommand(40297, 0)
end

---------------------------------
-- HAUPTPROGRAMM
---------------------------------
reaper.ClearConsole()
msg("Sammle verfügbare Spuren...")

-- Alle Track-Namen sammeln
local all_tracks = collect_all_track_names()

if #all_tracks == 0 then
    reaper.ShowMessageBox("Keine Spuren in den geöffneten Projekten gefunden!", "Fehler", 0)
    return
end

-- UI-Dialog anzeigen
local selected_tracks = show_track_selection_dialog(all_tracks)

if not selected_tracks or #selected_tracks == 0 then
    msg("Export abgebrochen oder keine Spuren ausgewählt.")
    return
end

msg("Starte Export mit " .. #selected_tracks .. " ausgewählten Spuren...")

local root_folder = EXPORT_BASE_PATH .. "/TT_Liveset_Recording_" .. os_date_string()
ensure_directory(root_folder)

local i = 0
while true do
    local proj = reaper.EnumProjects(i, "")
    if not proj then break end
    reaper.SelectProjectInstance(proj)
    export_tracks_in_project(proj, root_folder, selected_tracks)
    i = i + 1
end

msg("✅ Export abgeschlossen!")
reaper.ShowMessageBox("Alle Projekte wurden exportiert!\n\nZielordner:\n" .. root_folder,
                      "Export abgeschlossen", 0)
