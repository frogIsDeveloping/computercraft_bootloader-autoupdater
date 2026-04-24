-- MIT License
-- Copyright (c) 2026 frogIsDeveloping

-- Bootloader v2.0.0-alpha

local _pullEvent = os.pullEvent -- for later restore (if needed)
os.pullEvent = os.pullEventRaw
settings.set("shell.allow_disk_startup",false)
settings.save()


-- load config first, other modules may rely on config being loaded
local Config = require("BOOTLOADER/config") 
local Config_loadSuccess, Config_loadError = Config.load()
if not Config_loadSuccess then
    error("Error while loading bootloader config: "..Config_loadError)
end

local UI = require("BOOTLOADER/ui")
local Updater = require("BOOTLOADER/updater")

UI.resetTerminal()

local interrupt = UI.runBootTimer("v2.0.0-alpha")

if interrupt == 0 then -- Continue booting
    UI.normalBoot(_pullEvent, Updater.checkAndRun)
elseif interrupt == 1 then -- Interrupt booting, enter config
    UI.configInterrupt()
elseif interrupt == 2 then -- Interrupt booting, enter startup program change
    UI.startupInterrupt()
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