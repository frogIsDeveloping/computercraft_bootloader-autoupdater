-- MIT License
-- Copyright (c) 2026 frogIsDeveloping

-- Config module build 1

local Config = {}
Config.data = {}
Config.http_headers = {}

local DEFAULT_CONFIG = {
    ["UPDATE_CHANNEL"] = "https://raw.githubusercontent.com/frogIsDeveloping/computercraft_bootloader-autoupdater/refs/heads/latest/auto-update_example/buildNumber.txt";
    ["AUTO_UPDATE"] = "false";
    ["TOKEN_FOR_PRIVATE_REPO"] = "";

    ["BOOT_TIME"] = "5";
    ["MANUAL_UPDATE_TIME"] = "10";
    ["PROGRAM_FOLDER"] = "src";
    ["STARTUP_PROGRAM"] = "startup.lua";
    ["USER_PASSWORD"] = "";
    ["ADMIN_PASSWORD"] = "";
    ["END_OF_SEQUENCE"] = "shutdown";
    ["RESTORE_PULLEVENT"] = "false";

    ["LOADED"] = 1;
    ["CURRENT_BUILD_NUMBER"] = 0;
}

function Config.save()
    local mustShutdown
    print("Saving config...")

     if fs.exists("BOOTLOADER/CONFIG_DATA-BACKUP.txt") then
        pcall(function() fs.delete("BOOTLOADER/CONFIG_DATA-BACKUP.txt") end)
    end

    local success, err = pcall(function()
        if fs.exists("BOOTLOADER/CONFIG_DATA.txt") then
            fs.copy("BOOTLOADER/CONFIG_DATA.txt","BOOTLOADER/CONFIG_DATA-BACKUP.txt")
        end
    end)
    if success == true then
        success, err = pcall(function()
            local file = fs.open("BOOTLOADER/CONFIG_DATA.txt","w")
            file.write(textutils.serialise(Config.data,{compact=true}))
            file.close()
        end)
        if success == true then
            pcall(function() fs.delete("BOOTLOADER/CONFIG_DATA-BACKUP.txt") end)
            print("Config saved successfully")
            os.sleep(1)
        else
            mustShutdown = true
            print("FAIL: Could not write to config: ",err)
            pcall(function() fs.delete("BOOTLOADER/CONFIG_DATA.txt") end)
            success, err = pcall(function()
                fs.copy("BOOTLOADER/CONFIG_DATA-BACKUP.txt","BOOTLOADER/CONFIG_DATA.txt")
            end)
            if success == true then
                pcall(function() fs.delete("BOOTLOADER/CONFIG_DATA-BACKUP.txt") end)
                print("A backup of config was restored successfully.")
            else
                print("FAIL #2: Could not restore config backup: ",err)
                print("WARNING: Config may have corrupted")
            end
        end
    else
        mustShutdown = true
        print("FAIL: Could not create config backup: "..err)
    end

    if mustShutdown then
        print("PRESS ENTER TO CONTINUE.")
        read()
        os.shutdown()
        -- We shutdown in case of an error otherwise the modified config will only be temporary and this will mislead the user
    end
end

function Config.load()
    local success, err = pcall(function()
        local file = fs.open("BOOTLOADER/CONFIG_DATA.txt","r")
        local missingConfig = false
        if file then
            Config.data = textutils.unserialise(file.readAll())
            file.close()

            if Config.data["LOADED"] ~= 1 then
                error("CONFIG FILE CORRUPTED")
            end

            -- if something is missing, add it
            for i in pairs(DEFAULT_CONFIG) do
                if Config.data[i] == nil then
                    Config.data[i] = DEFAULT_CONFIG[i]
                    missingConfig = true
                end
            end

            if Config.data["TOKEN_FOR_PRIVATE_REPO"] ~= "" then -- private repo support
                Config.http_headers["Authorization"] = "Bearer "..Config.data["TOKEN_FOR_PRIVATE_REPO"]
            end
        else
            for i in pairs(DEFAULT_CONFIG) do
                Config.data[i] = DEFAULT_CONFIG[i]
            end
            missingConfig = true
        end

        if missingConfig == true then
            Config.save()
        end
    end)
    if success == false then
        return false, err
    end

    return true
end


return Config