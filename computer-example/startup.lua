-- MIT License
-- Copyright (c) 2026 frogIsDeveloping

-- Bootloader v2.0.0-alpha

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
resetTerminal()

local interrupt = 0

local Config = require("BOOTLOADER/config")

local Config_loadSuccess, Config_loadError = Config.load()
if not Config_loadSuccess then
    error("Error while loading bootloader config: "..Config_loadError)
end

local function bootTimer()
    for i=tonumber(Config.data["BOOT_TIME"]),1,-1 do
        resetTerminal()
        print("BOOTLOADER v2.0.0-alpha") -- version
        print("")
        print("Booting in "..i.."...")
        print("Strike F3 key to interrupt boot")
        print("Strike F12 key to change startup program")
        os.sleep(1)
    end
end

local function keyInterrupt()
    repeat
        local _,key = os.pullEvent("key")
        if key == 292 then -- F3 is 292
            interrupt = 1
        elseif key == 301 then -- F12 is 301
            interrupt = 2
        end
    until interrupt > 0
end

local function loadInterruptConfig()
    while true do
        resetTerminal()
        print("Showing config:")
        print("")

        local alphaOrder = {}
        for i in pairs(Config.data) do
            if i ~= "LOADED" and i ~= "CURRENT_BUILD_NUMBER" then
                alphaOrder[#alphaOrder+1] = i 
            end
        end
        table.sort(alphaOrder)
        for i=1,#alphaOrder do
            local currentSetting = Config.data[alphaOrder[i]]

            if currentSetting ~= "" and (alphaOrder[i] == "ADMIN_PASSWORD" or alphaOrder[i] == "USER_PASSWORD" or alphaOrder[i] == "TOKEN_FOR_PRIVATE_REPO") then
                currentSetting = "<set>"
            end

            print(alphaOrder[i].." : "..currentSetting)
        end

        print("")
        print("Enter setting to change, 'quit' or 'terminate' > ")
        local input = string.upper(read())
        if Config.data[input] ~= nil and input ~= "LOADED" and input ~= "CURRENT_BUILD_NUMBER" then -- edit a setting
            print("Changing "..input.." enter new value:")
            local input2 = read():gsub(" ","") -- remove blank spaces
            write("Change from "..Config.data[input].." to "..input2.." ? (Y/N) > ")
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
                elseif input == "TOKEN_FOR_PRIVATE_REPO" then
                    if string.sub(input2,1,11) ~= "github_pat_" and input2 ~= "" then
                        failsafe = true
                        print("WARNING: Token should start with github_pat_")
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
                    Config.data[input] = input2
                    Config.save()
                    
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

local function loadChangeStartupConfig()
    resetTerminal()
    print("Listing available startup programs:")
    print("Changing the startup program will save it as new default !")
    print("")
    local availableStartupFiles = {}
    pcall(function()
        local files = fs.list(Config.data["PROGRAM_FOLDER"])
        for i=1,#files do
            if files[i]:match("%.lua$") then
                availableStartupFiles[#availableStartupFiles+1] = files[i]
                print(#availableStartupFiles.." :: "..files[i])
            end
        end
    end)
    print("")
    print("Press Enter to abort")
    write("Select program by number > ")
    local ans = tonumber(read())
    if availableStartupFiles[ans] then
        Config.data["STARTUP_PROGRAM"] = availableStartupFiles[ans]
        Config.save()
        os.sleep(1)
        os.reboot()
    else
        print("Invalid option! Aborting..")
        os.sleep(5)
        os.reboot()
    end
end

local function doUpdate(newBuild,fileList)
    -- Do a backup
    if fs.exists(Config.data["PROGRAM_FOLDER"].."-BACKUP") == true then
        pcall(function()
            fs.delete(Config.data["PROGRAM_FOLDER"].."-BACKUP")
        end)
    end
    local success,err = pcall(function()
        fs.copy(Config.data["PROGRAM_FOLDER"],Config.data["PROGRAM_FOLDER"].."-BACKUP")
    end)
    if success == true then
        success,err = pcall(function()
            for i=1,#fileList do
                fs.delete(Config.data["PROGRAM_FOLDER"].."/"..fileList[i])
                print("Downloading",fileList[i])
                local response,http_error = http.get(Config.data["UPDATE_CHANNEL"]:match("^(.+)buildNumber%.txt$")..fileList[i],Config.http_headers)
                if response ~= nil then
                    local file = fs.open(Config.data["PROGRAM_FOLDER"].."/"..fileList[i],"w")
                    file.write(response.readAll())
                    file.close()
                    response.close()
                else
                    error("File download failed: "..http_error)
                end
                os.sleep(1)
                print("Downloaded",fileList[i])
            end
        end)
        if success == true then
            pcall(function()
                fs.delete(Config.data["PROGRAM_FOLDER"].."-BACKUP")
            end)
            print("------------------")
            Config.data["CURRENT_BUILD_NUMBER"] = newBuild
            Config.save()

            print("Update successful !")
            os.sleep(2)
        else
            -- Restore backup
            print("------------------")
            print("UPDATE FAILED: "..err)
            print("Restoring old files from backup")
            success, err = pcall(function()
                fs.delete(Config.data["PROGRAM_FOLDER"])
                fs.copy(Config.data["PROGRAM_FOLDER"].."-BACKUP",Config.data["PROGRAM_FOLDER"])
                fs.delete(Config.data["PROGRAM_FOLDER"].."-BACKUP")
            end)
            if success == true then
                print("Backup successfully restored. Files not updated.")
            else
                print("WARNING: COULD NOT RESTORE BACKUP. Files may be lost.",err)
            end
            print("PRESS ENTER TO CONTINUE.")
            read()
        end
    else
        print("------------------")
        print("UPDATE FAILED: Could not create backup before update:",err)
        print("PRESS ENTER TO CONTINUE.")
        read()
    end
end

local function loadMainProgram()
    -- check for updates (if active)
    if Config.data["UPDATE_CHANNEL"] == "" then
        if Config.data["RESTORE_PULLEVENT"] == "true" then
            os.pullEvent = _pullEvent
        end
        shell.run(Config.data["PROGRAM_FOLDER"].."/"..Config.data["STARTUP_PROGRAM"])
    else
        print("Checking for updates...")
        local success,err = pcall(function()
            local response,http_error = http.get(Config.data["UPDATE_CHANNEL"],HTTP_HEADERS)
            if response ~= nil then
                local buildNumber = textutils.unserialise(response.readAll())
                response.close()
                if buildNumber[1] > Config.data["CURRENT_BUILD_NUMBER"] then
                    resetTerminal()
                    print("An update is available!")
                    print("Newest build number: "..buildNumber[1])
                    print("Current build number: "..Config.data["CURRENT_BUILD_NUMBER"].." ["..buildNumber[1]-Config.data["CURRENT_BUILD_NUMBER"].." version(s) behind]")
                    print("")
                    if Config.data["AUTO_UPDATE"] == "true" then
                        print("Auto-update enabled!")
                        doUpdate(buildNumber[1],buildNumber[2])
                    else
                        print("Auto-update disabled!")
                        print("Out-of-date program will load in "..Config.data["MANUAL_UPDATE_TIME"].." seconds")
                        write("Update? (Y/N) > ")
                        local canExit = true
                        local function timeOut()
                            os.sleep(tonumber(Config.data["MANUAL_UPDATE_TIME"]))
                            if canExit == false then -- if update takes more than MANUAL_UPDATE_TIME seconds, this will prevent exit and won't run program
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
                        print("Running build "..Config.data["CURRENT_BUILD_NUMBER"])
                    end
                else
                    -- Up-to-date
                    print("Up to date! Running build "..Config.data["CURRENT_BUILD_NUMBER"])
                    os.sleep(0.5)
                end
            else
                error("Unable to check for update: "..http_error)
            end
        end)
        if success == true then
            if Config.data["RESTORE_PULLEVENT"] == "true" then
                os.pullEvent = _pullEvent
            end
            shell.run(Config.data["PROGRAM_FOLDER"].."/"..Config.data["STARTUP_PROGRAM"])
        else
            print("ATTENTION: Is buildnumber.txt malformed?")
            print("WARNING: CANNOT CHECK FOR UPDATES: "..err)
            os.sleep(5)
            if Config.data["RESTORE_PULLEVENT"] == "true" then
                os.pullEvent = _pullEvent
            end
            shell.run(Config.data["PROGRAM_FOLDER"].."/"..Config.data["STARTUP_PROGRAM"])
        end
    end
end

parallel.waitForAny(bootTimer,keyInterrupt) -- main

if interrupt == 0 then -- Continue booting
    resetTerminal()
    if Config.data["USER_PASSWORD"] == "" then
        loadMainProgram()
    else
        local attempt = 1
        repeat
            write("Enter admin or user password > ")
            local psw = read("*")
            if psw == Config.data["USER_PASSWORD"] or psw == Config.data["ADMIN_PASSWORD"] then
                loadMainProgram()
                break
            else
                print("Incorrect password")
                attempt = attempt + 1
            end
        until attempt > 3
        if attempt > 3 then os.shutdown() end
    end
elseif interrupt == 1 then -- Interrupt booting, enter config
    resetTerminal()
    if Config.data["ADMIN_PASSWORD"] == "" then
        loadInterruptConfig()
    else
        print("Interrupted!")
        print("To change CONFIG, log in below...")
        local attempt = 1
        repeat
            write("Enter admin password > ")
            local psw = read("*")
            if psw == Config.data["ADMIN_PASSWORD"] then
                loadInterruptConfig()
                break
            else
                print("Incorrect password")
                attempt = attempt + 1
            end
        until attempt > 3
        if attempt > 3 then os.shutdown() end
    end
elseif interrupt == 2 then -- Interrupt booting, enter startup program change
    resetTerminal()
    if Config.data["ADMIN_PASSWORD"] == "" then
        loadChangeStartupConfig()
    else
        print("Interrupted!")
        print("To change STARTUP PROGRAM, log in below...")
        local attempt = 1
        repeat
            write("Enter admin password > ")
            local psw = read("*")
            if psw == Config.data["ADMIN_PASSWORD"] then
                loadChangeStartupConfig()
                break
            else
                print("Incorrect password")
                attempt = attempt + 1
            end
        until attempt > 3
        if attempt > 3 then os.shutdown() end
    end
end

if Config.data["END_OF_SEQUENCE"] == "shutdown" then
    print("End of sequence! Shutting down...")
    os.sleep(5)
    os.shutdown()
elseif Config.data["END_OF_SEQUENCE"] == "reboot" then
    print("End of sequence! Rebooting...")
    os.sleep(5)
    os.reboot()
elseif Config.data["END_OF_SEQUENCE"] == "wait" then
    print("End of sequence! Waiting...")
    while true do
        os.sleep(10)
    end
end
print("End of sequence! Terminating...")
-- Terminate at script exit
