-- MIT License
-- Copyright (c) 2026 frogIsDeveloping

-- Updater module build 1

local Backup_Handler = require("BOOTLOADER/backupHandler")
local Config = require("BOOTLOADER/config")
local UI = require("BOOTLOADER/ui")

local Updater = {}

local function doUpdate(newBuild,fileList)
    print("Updating to build "..newBuild.."...")

    local backup, backup_err = Backup_Handler.doBackup(Config.data["PROGRAM_FOLDER"])
    if backup then
        local download_success, download_error = pcall(function()
            for i=1,#fileList do
                fs.delete(Config.data["PROGRAM_FOLDER"].."/"..fileList[i])
                print("Downloading",fileList[i])
                local response,http_error = http.get(Config.data["UPDATE_CHANNEL"]:match("^(.+)buildNumber%.txt$")..fileList[i],Config.http_headers)
                if response then
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
        if download_success then
            Backup_Handler.cleanup(Config.data["PROGRAM_FOLDER"])
            Config.data["CURRENT_BUILD_NUMBER"] = newBuild
            Config.save()
        else
            print("------------------")
            print("DOWNLOAD FAILED: "..download_error)
            print("Restoring old files from backup")
            local restore, restore_err = Backup_Handler.restoreBackup(Config.data["PROGRAM_FOLDER"])
            if restore then
                print("Backup successfully restored. Files not updated")
            else
                print("WARNING: COULD NOT RESTORE BACKUP. Files may be lost:",restore_err)
            end

            print("PRESS ENTER TO CONTINUE.."); read()
        end
    else
        print("Unable to backup current files: ",backup_err)
        print("Files were not changed.")
        print("PRESS ENTER TO CONTINUE.."); read()
    end
end

function Updater.checkAndRun(_pullEvent)
    if Config.data["UPDATE_CHANNEL"] ~= "" then
        print("Checking for updates...")
        local response,http_error = http.get(Config.data["UPDATE_CHANNEL"],Config.http_headers)
        if response then
            local buildNumber = textutils.unserialise(response.readAll())
            response.close()
            if type(buildNumber) ~= "table" or type(buildNumber[1]) ~= "number" or type(buildNumber[2]) ~= "table" then
                print("FAIL: buildNumber.txt is malformed!")
                os.sleep(5)
            else
                if buildNumber[1] > Config.data["CURRENT_BUILD_NUMBER"] then
                    
                    UI.resetTerminal()

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
                        os.sleep(0.5)
                    end

                else
                    print("Up to date! Running build "..Config.data["CURRENT_BUILD_NUMBER"])
                    os.sleep(0.5)
                end
            end
        else
            print("FAIL: Could not check update channel:",http_error)
            os.sleep(5)
        end
    end

    if Config.data["RESTORE_PULLEVENT"] == "true" then
        os.pullEvent = _pullEvent
    end
    shell.run(Config.data["PROGRAM_FOLDER"].."/"..Config.data["STARTUP_PROGRAM"])
end

return Updater