local Globals = require "globals"
local ListRppFilesRecursive = require "list_rpp_files"
local NormalizePath = require "normalize_path"

local MAX_RUNTIME_SECONDS = 10

---Returns a list of .rpp files in the project root folder and its subfolders
---@return string[]
local function ListProjects()
    local project_root_folder = reaper.GetExtState(Globals.SECTION, Globals.KEYS.project_root_folder)
    if not project_root_folder or project_root_folder == "" then
        error("Project root folder is not set. Cannot list files.")
    end

    project_root_folder = NormalizePath(project_root_folder)
    project_root_folder = project_root_folder:gsub("/$", "")

    -- Record start time for timeout checking
    local start_time = reaper.time_precise()

    -- Use pcall to catch timeout errors
    local success, result = pcall(function()
        return ListRppFilesRecursive(project_root_folder, project_root_folder, start_time, MAX_RUNTIME_SECONDS)
    end)

    if not success then
        -- Check if it's a timeout error
        if result:match("^TIMEOUT:") then
            reaper.ShowMessageBox(
                "Operation timed out after " .. MAX_RUNTIME_SECONDS .. " seconds. Consider reducing the search scope.",
                "List Projects Timeout", 0)
            return {} -- Return empty list on timeout
        else
            -- Re-throw other errors
            error(result)
        end
    end

    local project_files = result

    table.sort(project_files, function(a, b)
        return a:lower() < b:lower()
    end)

    return project_files
end

return ListProjects
