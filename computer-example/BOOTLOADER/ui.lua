-- MIT License
-- Copyright (c) 2026 frogIsDeveloping

-- UI module build 1

local Config = require("BOOTLOADER/config")

local UI = {}

local interrupt = 0

function UI.resetTerminal()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()
    term.setCursorPos(1,1)
end

local function bootTimer(versionText)
    for i=tonumber(Config.data["BOOT_TIME"]),1,-1 do
        UI.resetTerminal()
        print("BOOTLOADER "..versionText)
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

function UI.runBootTimer(versionText)
    parallel.waitForAny(function() bootTimer(versionText) end,keyInterrupt)
    return interrupt
end

local function promptPassword(question,acceptedAns)
    local attempt = 1
    repeat
        write(question.." > ")
        local psw = read("*")
        for i=1,#acceptedAns do
            if acceptedAns[i] == psw then
                return true
            end
        end
        print("Incorrect password")
        attempt = attempt + 1
    until attempt > 3
    return false
end

local function loadInterruptConfig()
    while true do
        UI.resetTerminal()
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
        elseif string.lower(input) == "quit" or string.lower(input) == "reboot" then
            os.reboot()
        elseif string.lower(input) == "terminate" then
            error("[TERMINATION_CRITICAL] User termination")
        else
            print("Invalid option")
            os.sleep(1)
        end
    end
end

local function loadChangeStartupConfig()
    UI.resetTerminal()
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

function UI.normalBoot(_pullEvent,checkAndRun)
    UI.resetTerminal()
    if Config.data["USER_PASSWORD"] == "" then
        checkAndRun(_pullEvent)
    else
        if promptPassword("Enter admin or user password",{Config.data["USER_PASSWORD"],Config.data["ADMIN_PASSWORD"]}) then
            checkAndRun(_pullEvent)
        else
            os.shutdown()
        end
    end
end

function UI.configInterrupt()
    UI.resetTerminal()
     if Config.data["ADMIN_PASSWORD"] == "" then
        loadInterruptConfig()
    else
        print("Interrupted!")
        print("To change CONFIG, log in below...")
        if promptPassword("Enter admin password",{Config.data["ADMIN_PASSWORD"]}) then
            loadInterruptConfig()
        else
            os.shutdown()
        end
    end
end

function UI.startupInterrupt()
    UI.resetTerminal()
     if Config.data["ADMIN_PASSWORD"] == "" then
        loadChangeStartupConfig()
    else
        print("Interrupted!")
        print("To change STARTUP PROGRAM, log in below...")
        if promptPassword("Enter admin password",{Config.data["ADMIN_PASSWORD"]}) then
            loadChangeStartupConfig()
        else
            os.shutdown()
        end
    end
end

return UI