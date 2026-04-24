-- MIT License
-- Copyright (c) 2026 frogIsDeveloping

-- Backup handler module build 1

local Backup_Handler = {}

function Backup_Handler.doBackup(path)
    if not fs.exists(path) then -- init, no file to backup
        return true
    end
    
    local createBackup_success, createBackup_error = pcall(function()
        pcall(function() fs.delete(path.."-BACKUP") end)
        fs.copy(path,path.."-BACKUP")
    end)
    if not createBackup_success then
        return false, createBackup_error
    end

    return true
end

function Backup_Handler.cleanup(path)
    pcall(function() fs.delete(path.."-BACKUP") end)
end

function Backup_Handler.restoreBackup(path) -- do not include the "-BACKUP" in path
    local restoreBackup_success, restoreBackup_error = pcall(function()
        fs.delete(path)
        fs.copy(path.."-BACKUP",path)
    end)
    if restoreBackup_success then
        pcall(function() fs.delete(path.."-BACKUP") end)
        return true
    else
        return false, restoreBackup_error
    end
end

return Backup_Handler