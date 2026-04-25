-- MIT License
-- Copyright (c) 2026 frogIsDeveloping

-- Installer build 1

local initLink = "https://raw.githubusercontent.com/frogIsDeveloping/computercraft_bootloader-autoupdater/refs/heads/"
local branch = nil
local bootloader = "/computer-example/startup.lua"
local moduleFolder = "/computer-example/BOOTLOADER/"
local modules = {
    "backupHandler.lua";
    "config.lua";
    "ui.lua";
    "updater.lua";
}

local function doInstall(path,link,showText)
    print("Downloading",showText)

    local download_success, download_error = pcall(function()
        fs.delete(path)
        local response,http_error = http.get(link)
        if response then
            local file = fs.open(path,"w")
            file.write(response.readAll())
            file.close()
            response.close()
        else
            error("File download failed: "..http_error)
        end
    end)

    os.sleep(1)
    if not download_success then
        print("Download ERROR: ",download_error)
        print("Install is incomplete")
        print("Try again")

        pcall(function() fs.delete("BOOTLOADER") end)
        pcall(function() fs.delete("startup.lua") end)
        os.sleep(10)
        os.reboot()
    end
end

while true do
    term.setBackgroundColor(colors.lightGray)
    term.setTextColor(colors.black)
    term.clear()
    term.setCursorPos(1,1)

    print("---------------")
    print("computercraft_bootloader-autoupdater installer")
    print("")
    print("Select branch:")
    print("")
    print("latest (RECOMMENDED / DEFAULT)")
    print("main (may contain alpha/indev versions)")
    print("")
    write("Choice > ")
    local choice = string.lower(read())
    if choice == "latest" or choice == "main" or choice == "other" then
        if choice == "other" then
            write("Branch > ")
            choice = read()
        end
        branch = choice
        print("Selected "..choice)

        if fs.exists("BOOTLOADER") then
            print("WARNING: Bootloader already installed. This will overwrite it.")
            print("This will NOT overwrite your settings.")
            print("Continue? (Y/N) > ")
            if string.lower(read()) ~= "y" then
                return
            end
        end

        if fs.exists("SETTINGS.txt") then -- for v1
            print("ATTENTION: Configuration from v1 bootloader detected")
            print("Do you want to transfer it over? (Y/N)")
            if string.lower(read()) == "y" then
                pcall(function()
                    fs.copy("SETTINGS.txt","BOOTLOADER/CONFIG_DATA.txt")
                    fs.delete("SETTINGS.txt")
                end)
            end
        end

        doInstall("startup.lua",initLink..branch..bootloader,"BOOTLOADER")
        for i=1,#modules do
            doInstall("BOOTLOADER/"..modules[i],initLink..branch..moduleFolder..modules[i],"MODULE:"..modules[i])
        end
        print("Install successful!")
        os.sleep(5)
        os.reboot()

    else
        print("Invalid option !")
        os.sleep(1)
    end
end