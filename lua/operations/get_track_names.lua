---Returns a list of unique track names from all open projects
---@return string[] track_names
local function GetTrackNames()
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
    
    -- Convert to sorted list
    local track_list = {}
    for name, _ in pairs(track_set) do
        table.insert(track_list, name)
    end
    table.sort(track_list)
    
    return track_list
end

return GetTrackNames
