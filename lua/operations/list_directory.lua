local function ListDirectory(path)
    if not path or path == "" then
        if reaper.GetOS():find("Win") then
            path = "C:\\"
        else
            path = "/"
        end
    end

    -- Ensure path doesn't end with slash unless it's root, for consistency
    -- But EnumerateSubdirectories might need it?
    -- Let's try to keep it clean.
    
    local subdirs = {}
    local i = 0
    while true do
        local subdir = reaper.EnumerateSubdirectories(path, i)
        if not subdir then break end
        table.insert(subdirs, subdir)
        i = i + 1
    end
    
    local files = {}
    i = 0
    while true do
        local file = reaper.EnumerateFiles(path, i)
        if not file then break end
        table.insert(files, file)
        i = i + 1
    end
    
    table.sort(subdirs)
    table.sort(files)

    return path, subdirs, files
end

return ListDirectory
