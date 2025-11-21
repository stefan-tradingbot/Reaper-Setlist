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
    elseif os_name:find("OSX") or os_name:find("macOS") then
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
    else
        -- Linux: Try zenity first, then kdialog
        -- zenity is common on GNOME/GTK based systems
        local handle = io.popen('zenity --file-selection --directory --title="Select Export Folder" 2>/dev/null')
        if handle then
            path = handle:read("*a")
            handle:close()
        end

        -- If zenity failed or returned empty (and exit code was failure, though io.popen doesn't give exit code easily),
        -- check if path is empty. If empty, try kdialog (KDE).
        if not path or path == "" then
             local handle_k = io.popen('kdialog --getexistingdirectory 2>/dev/null')
             if handle_k then
                 path = handle_k:read("*a")
                 handle_k:close()
             end
        end
    end

    -- Trim whitespace/newlines
    if path then
        path = path:gsub("^%s*(.-)%s*$", "%1")
    end

    return path
end

return BrowseFolder
