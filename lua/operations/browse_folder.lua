local function BrowseFolder(initial_path)
    local os_name = reaper.GetOS()
    local path = ""

    if os_name:find("Win") then
        -- Windows: Use PowerShell to open FolderBrowserDialog
        -- We use a temporary script to avoid complex escaping issues in the command line
        local cmd = 'powershell -Command "Add-Type -AssemblyName System.Windows.Forms; $f = New-Object System.Windows.Forms.FolderBrowserDialog; $f.SelectedPath = \'' .. (initial_path or "") .. '\'; $f.ShowDialog() | Out-Null; $f.SelectedPath"'
        local handle = io.popen(cmd)
        if handle then
            path = handle:read("*a")
            handle:close()
        end
    else
        -- macOS: Use AppleScript via osascript
        -- 'choose folder' is the standard way.
        -- We wrap it in 'try' to handle cancellation (which throws an error) gracefully.
        local script = 'try\n' ..
                       '  set userPath to POSIX path of (choose folder with prompt "Select Export Folder")\n' ..
                       '  return userPath\n' ..
                       'on error\n' ..
                       '  return ""\n' ..
                       'end try'
        
        local handle = io.popen('osascript -e \'' .. script .. '\'')
        if handle then
            path = handle:read("*a")
            handle:close()
        end
    end

    -- Trim whitespace/newlines
    if path then
        path = path:gsub("^%s*(.-)%s*$", "%1")
    end

    return path
end

return BrowseFolder
