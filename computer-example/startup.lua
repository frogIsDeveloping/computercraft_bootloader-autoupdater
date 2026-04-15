-- MIT License
-- Copyright (c) 2026 frogIsDeveloping

-- Bootloader

local interrupt = false
local SETTINGS = {}

local _pullEvent = os.pullEvent -- for later restore (if needed)
os.pullEvent = os.pullEventRaw
settings.set("shell.allow_disk_startup",false)
settings.save()

local function resetTerminal()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()
    term.setCursorPos(1,1)
end

-- load settings
local function loadSettings()
    local success, err = pcall(function()
        local file = fs.open("SETTINGS.txt","r")
        if file then
            SETTINGS = textutils.unserialise(file.readAll())
            if SETTINGS["LOADED"] ~= 1 then
                error("SETTINGS FILE CORRUPTED")
            end
            file.close()
        else
            -- Default settings
            SETTINGS["UPDATE_CHANNEL"] = ""
            SETTINGS["AUTO_UPDATE"] = "false"

            SETTINGS["BOOT_TIME"] = "5"
            SETTINGS["MANUAL_UPDATE_TIME"] = "10"
            SETTINGS["PROGRAM_FOLDER"] = "src"
            SETTINGS["STARTUP_PROGRAM"] = "startup.lua"
            SETTINGS["USER_PASSWORD"] = ""
            SETTINGS["ADMIN_PASSWORD"] = ""
            SETTINGS["END_OF_SEQUENCE"] = "shutdown"
            SETTINGS["RESTORE_PULLEVENT"] = "false"

            -- do not change below
            SETTINGS["LOADED"] = 1
            SETTINGS["CURRENT_BUILD_NUMBER"] = 0
            file = fs.open("SETTINGS.txt","w")
            file.write(textutils.serialise(SETTINGS,{compact=true}))
            file.close()
        end
    end)
    if success == false then
        error("BOOTLOADER CRASH: SETTINGS CORRUPTED: "..err)
        --os.sleep(5)
        --os.shutdown()
    end
end
loadSettings()

local function bootTimer()
    for i=tonumber(SETTINGS["BOOT_TIME"]),1,-1 do
        resetTerminal()
        print("BOOTLOADER v1.1.0-beta") -- version
        print("")
        print("Booting in "..i.."...")
        print("Strike F3 key to interrupt boot")
        os.sleep(1)
    end
end

local function keyInterrupt()
    repeat
        local _,key = os.pullEvent("key")
        if key == 292 then -- F3 is 292
            interrupt = true
        end
    until interrupt == true
end

local function updateSettings()
    local file = fs.open("SETTINGS-BACKUP.txt","r")
    if file then
        file.close()
        shell.run("rm SETTINGS-BACKUP.txt")
    end
    shell.run("copy SETTINGS.txt SETTINGS-BACKUP.txt")
    local success,err = pcall(function()
        file = fs.open("SETTINGS.txt","w")
        file.write(textutils.serialise(SETTINGS,{compact=true}))
        file.close()
    end)
    if success == true then
        shell.run("rm SETTINGS-BACKUP.txt")
        print("Operation completed")
        os.sleep(1)
    else
        shell.run("rm SETTINGS.txt")
        shell.run("copy SETTINGS-BACKUP.txt SETTINGS.txt")
        shell.run("rm SETTINGS-BACKUP.txt")
        print("Operation failed: "..err)
        os.sleep(5)
    end
end

local function loadInterruptSettings()
    while true do
        resetTerminal()
        print("Showing settings:")
        print("")
        for i in pairs(SETTINGS) do
            if i ~= "LOADED" and i ~= "CURRENT_BUILD_NUMBER" then
                print(i.." : "..SETTINGS[i])
            end
        end
        print("")
        print("Enter setting to change, 'quit' or 'terminate' > ")
        local input = read()
        if SETTINGS[input] ~= nil and input ~= "LOADED" and input ~= "CURRENT_BUILD_NUMBER" then -- edit a setting
            write("Changing "..input.." enter new value > ")
            local input2 = read():gsub(" ","") -- remove blank spaces
            write("Change from "..SETTINGS[input].." to "..input2.." ? (Y/N) > ")
            local input3 = read()
            if string.lower(input3) == "y" then

                -- Failsafes (don't want to lock bootloader)
                local failsafe = false
                if input == "BOOT_TIME" or input == "MANUAL_UPDATE_TIME" then
                    if tonumber(input2) == nil then
                        failsafe = true
                    elseif tonumber(input2) < 1 then
                        failsafe = true
                    end
                elseif input == "PROGRAM_FOLDER" then -- root protection
                    input2 = input2:gsub("/","")
                    input2 = input2:gsub("%.", "")
                    if input2 == "" then
                        failsafe = true
                        print("WARNING: Do not set PROGRAM_FOLDER as root or include '/' !")
                    end
                elseif input == "UPDATE_CHANNEL" then
                    if input2:match("buildNumber%.txt$") == nil and input2 ~= "" then
                        failsafe = true
                        print("WARNING: Update channel must end with buildNumber.txt!")
                    end
                elseif input == "AUTO_UPDATE" or input == "RESTORE_PULLEVENT" then
                    if input2 ~= "true" and input2 ~= "false" then
                        print("WARNING: must be true or false!")
                        failsafe = true
                    end
                elseif input == "END_OF_SEQUENCE" then
                    if input2 ~= "shutdown" and input2 ~= "reboot" and input2 ~= "wait" and input2 ~= "terminate" then
                        print("WARNING: END_OF_SEQUENCE can only be shutdown/reboot/wait/terminate")
                        failsafe = true
                    end
                end
                
                if failsafe == false then
                    -- change setting
                    SETTINGS[input] = input2
                    updateSettings()
                    
                else
                    print("Invalid parameters !")
                    os.sleep(5)
                end
            else
                print("Operation cancelled")
                os.sleep(1)
            end
        elseif string.lower(input) == "quit" then
            os.reboot()
        elseif string.lower(input) == "terminate" then
            error("User termination")
        else
            print("Invalid option")
            os.sleep(1)
        end
    end
end

local function doUpdate(newBuild,fileList)
    -- Do a backup
    print("-- IGNORE TEXT BELOW --")
    shell.run("rm "..SETTINGS["PROGRAM_FOLDER"].."-BACKUP")
    shell.run("copy "..SETTINGS["PROGRAM_FOLDER"].." "..SETTINGS["PROGRAM_FOLDER"].."-BACKUP")
    local success,err = pcall(function()
        local file = nil
        for i=1,#fileList do
            shell.run("rm "..SETTINGS["PROGRAM_FOLDER"].."/"..fileList[i])
            shell.run("wget "..SETTINGS["UPDATE_CHANNEL"]:match("^(.+)buildNumber%.txt$")..fileList[i].." "..SETTINGS["PROGRAM_FOLDER"].."/"..fileList[i])
            file = fs.open(SETTINGS["PROGRAM_FOLDER"].."/"..fileList[i],"r")
            if file then
                -- all good!
                file.close()
            else
                -- The file did not download (no internet?)
                error("File download failed!")
            end
        end
    end)
    if success == true then
        shell.run("rm "..SETTINGS["PROGRAM_FOLDER"].."-BACKUP")
        print("------------------")
        SETTINGS["CURRENT_BUILD_NUMBER"] = newBuild
        updateSettings()

        print("Update successful !")
        os.sleep(1)
    else
        -- Restore backup
        shell.run("rm "..SETTINGS["PROGRAM_FOLDER"])
        shell.run("copy "..SETTINGS["PROGRAM_FOLDER"].."-BACKUP "..SETTINGS["PROGRAM_FOLDER"])
        shell.run("rm "..SETTINGS["PROGRAM_FOLDER"].."-BACKUP")
        print("------------------")
        print("UPDATE FAILED: "..err)
        os.sleep(5)
    end
end

local function loadMainProgram()
    -- check for updates (if active)
    if SETTINGS["UPDATE_CHANNEL"] == "" then
        if SETTINGS["RESTORE_PULLEVENT"] == "true" then
            os.pullEvent = _pullEvent
        end
        shell.run(SETTINGS["PROGRAM_FOLDER"].."/"..SETTINGS["STARTUP_PROGRAM"])
    else
        print("Checking for updates...")
        local success,err = pcall(function()
            local file = fs.open("buildNumber.txt","r")
            if file then
                file.close()
                shell.run("rm buildNumber.txt")
            end
            shell.run("wget "..SETTINGS["UPDATE_CHANNEL"].." buildNumber.txt")
            file = fs.open("buildNumber.txt","r")
            if file then
                local buildNumber = textutils.unserialise(file.readAll())
                file.close()
                shell.run("rm buildNumber.txt")
                if buildNumber[1] > SETTINGS["CURRENT_BUILD_NUMBER"] then
                    resetTerminal()
                    print("")
                    print("An update is available!")
                    print("Newest build number: "..buildNumber[1])
                    print("Current build number: "..SETTINGS["CURRENT_BUILD_NUMBER"].." ["..buildNumber[1]-SETTINGS["CURRENT_BUILD_NUMBER"].." version(s) behind]")
                    print("")
                    if SETTINGS["AUTO_UPDATE"] == "true" then
                        print("Auto-update enabled!")
                        doUpdate(buildNumber[1],buildNumber[2])
                    else
                        print("Auto-update disabled!")
                        print("Out-of-date program will load in "..SETTINGS["MANUAL_UPDATE_TIME"].." seconds")
                        write("Update? (Y/N) > ")
                        local canExit = true
                        local function timeOut()
                            os.sleep(tonumber(SETTINGS["MANUAL_UPDATE_TIME"]))
                            if canExit == false then -- if update takes more than 10 seconds, this will prevent exit and won't run program
                                while true do
                                    os.sleep(10) -- just wait forever, once watchUpdate is done this will stop because of the waitForAny
                                end
                            end
                        end
                        local function watchUpdate()
                            while true do
                                local input = read()
                                if string.lower(input) == "y" then
                                    canExit = false
                                    doUpdate(buildNumber[1],buildNumber[2])
                                    break
                                elseif string.lower(input) == "n" then
                                    break
                                end
                            end
                        end
                        parallel.waitForAny(timeOut,watchUpdate)
                        term.setCursorBlink(false)
                        print("")
                        print("Running build "..SETTINGS["CURRENT_BUILD_NUMBER"])
                    end
                else
                    -- Up-to-date
                    print("Up to date! Running build "..SETTINGS["CURRENT_BUILD_NUMBER"])
                    os.sleep(0.5)
                end
            else
                error("Unable to check for update! Is UPDATE_CHANNEL set correctly? Set to nothing to disable update check.")
            end
        end)
        if success == true then
            if SETTINGS["RESTORE_PULLEVENT"] == "true" then
                os.pullEvent = _pullEvent
            end
            shell.run(SETTINGS["PROGRAM_FOLDER"].."/"..SETTINGS["STARTUP_PROGRAM"])
        else
            print("WARNING: CANNOT CHECK FOR UPDATES: "..err)
            os.sleep(5)
            if SETTINGS["RESTORE_PULLEVENT"] == "true" then
                os.pullEvent = _pullEvent
            end
            shell.run(SETTINGS["PROGRAM_FOLDER"].."/"..SETTINGS["STARTUP_PROGRAM"])
        end
    end
end

parallel.waitForAny(bootTimer,keyInterrupt) -- main

if interrupt == false then -- Continue booting
    resetTerminal()
    if SETTINGS["USER_PASSWORD"] == "" then
        loadMainProgram()
    else
        local attempt = 1
        repeat
            write("Enter admin or user password > ")
            local psw = read("*")
            if psw == SETTINGS["USER_PASSWORD"] or psw == SETTINGS["ADMIN_PASSWORD"] then
                loadMainProgram()
                break
            else
                print("Incorrect password")
                attempt = attempt + 1
            end
        until attempt > 3
        if attempt > 3 then os.shutdown() end
    end
else -- Interrupt booting
    print("Interrupted!")
    if SETTINGS["ADMIN_PASSWORD"] == "" then
        loadInterruptSettings()
    else
        local attempt = 1
        repeat
            write("Enter admin password > ")
            local psw = read("*")
            if psw == SETTINGS["ADMIN_PASSWORD"] then
                loadInterruptSettings()
                break
            else
                print("Incorrect password")
                attempt = attempt + 1
            end
        until attempt > 3
        if attempt > 3 then os.shutdown() end
    end
end

if SETTINGS["END_OF_SEQUENCE"] == "shutdown" then
    print("End of sequence! Shutting down...")
    os.sleep(5)
    os.shutdown()
elseif SETTINGS["END_OF_SEQUENCE"] == "reboot" then
    print("End of sequence! Rebooting...")
    os.sleep(5)
    os.reboot()
elseif SETTINGS["END_OF_SEQUENCE"] == "wait" then
    print("End of sequence! Waiting...")
    while true do
        os.sleep(10)
    end
end
print("End of sequence! Terminating...")
-- terminate no need