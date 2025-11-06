---comment Export recordings using the stem export script
local function ExportRecordings()
    -- Get the script path relative to the main script
    local info = debug.getinfo(1, 'S')
    local script_path = info.source:match("@(.+)")
    local script_dir = script_path:match("(.+[/\\])")
    local export_script_path = script_dir:gsub("operations[/\\]", "") .. "stem_export_chatgpt.lua"
    
    -- Execute the stem export script
    local success = dofile(export_script_path)
    
    if not success then
        reaper.ShowConsoleMsg("Export script executed.\n")
    end
end

return ExportRecordings
