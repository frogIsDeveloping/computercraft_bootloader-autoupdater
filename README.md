# ComputerCraft Bootloader / Autoupdater

A custom bootloader made to protect the computer from unauthorized changes (e.g. program termination to access files) and to (optionally) support auto/manual updating directly from GitHub repositories (public and private repos supported). It can also be used to lock the computer entirely by setting a user password.  
The bootloader itself does not auto-update.  
It's also possible to use it to initiate many computers, as the files to autoupdate (if any) do not have to be present initially on the computer to be downloaded.
  
**DISCLAIMER**: I have created this for my own, amateur use. You are free to use it but it may not fit your exact needs.

## Images
On computer boot  
<img width="697" height="416" alt="2026-04-15_21-33-36" src="https://github.com/user-attachments/assets/7c2ca39f-e280-4e40-bb77-b107fd30a10b" />

Interrupt (settings) interface  
<img width="717" height="413" alt="2026-04-14_22-40-29" src="https://github.com/user-attachments/assets/a954439e-532b-4351-ba54-e4e6a941543f" />

Changing boot program  
<img width="710" height="421" alt="2026-04-15_21-30-42" src="https://github.com/user-attachments/assets/8d554260-6fbf-4ecd-bea7-3a80f0c0695f" />



## Installation & setup
###### To install the bootloader, run the following 
`wget run https://raw.githubusercontent.com/frogIsDeveloping/computercraft_bootloader-autoupdater/refs/heads/latest/INSTALLER.lua`  
  
Latest is always latest beta release (Even though I have extensively tested this, I consider it too soon to consider anything 'stable')  
Main may contain alpha or indev versions  
Other releases are available on the [Releases](https://github.com/frogIsDeveloping/computercraft_bootloader-autoupdater/releases) page.

###### To set up auto-update
Create a GitHub repo and set up a folder with the files you want to be autoupdated.  
Have a file called `buildNumber.txt` with a basic Lua table as contents following the structure: `{buildNumer :: number, projectFileNames :: table}`.  
Have all your files that you want auto-updated in the same folder.  
When it's time for an update, update your files in that folder, then wait 5 minutes (for `raw.githubusercontent.com` to properly update files instead of old cached versions), then increment your buildNumber in the buildNumber.txt file by 1.  
If you have added files, add them to the projectFileNames table. **DO NOT** remove files! If a computer is a few versions behind, it could desync. Instead just empty them.  
[Example structure](auto-update_example)

*Attention:* In the computer itself, files supported by the autoupdate feature should never be on the root folder. Place them in a folder like `src/`. This is necessary so that if an update fails to complete, files can be restored from a bootloader-handled backup instead of ending up corrupted or missing.


## Settings
**ADMIN_PASSWORD**: Similar to a BIOS boot, password to enter when startup sequence is interrupted. Disabled (no password) if empty.  
  
**AUTO_UPDATE**: If set to `true`, will automatically update program(s) on boot (if a newer version was found) from the `UPDATE_CHANNEL`. If set to `false`, then it will prompt to update on boot if an update is available. This can be accepted or denied, and if there is no user input for a set amount of time, the bootloader will load the program(s) without updating.  
  
**BOOT_TIME**: The initial boot timer, essentially the number of seconds one has to interrupt the boot and access the settings.  

**END_OF_SEQUENCE**: When the loaded program has finished, it triggers an "end of sequennce". This can be set to `shutdown`, `reboot`, `wait` (to do nothing) or `terminate` (default computercraft behavior). 

**PROGRAM_FOLDER**: All program(s) loaded by the bootloader must be in a separate folder from root. This is the name of the folder.  

**RESTORE_PULLEVENT**: By default, the bootloader and program(s) are loaded with `os.pullEvent = os.pullEventRaw` to prevent termination. However, if `RESTORE_PULLEVENT` is set to `true`, then `pullEvent` will be restored when the startup program is loaded. In this case, there is essentially no more termination security from the bootloader; this can then be handled by the program itself.  

**STARTUP_PROGRAM**: This is the name and extension (`.lua`) of the program to load on boot.  

**TOKEN_FOR_PRIVATE_REPO**: This is the github_pat_[token] (only "Contents" read-only permissions required) needed to access a `buildNumber.txt` raw file from a ___private___ repo.
  
**UPDATE_CHANNEL**: For auto-update. If empty, disables this feature. To enable, link to a `buildNumber.txt` raw file link. If you are reading `buildNumber.txt` from a private repo, remove the token at the end of the raw link (so it ends with `buildNumber.txt`).
  
**USER_PASSWORD**: Similar to a BIOS boot, password to enter to boot the computer. Disabled (no password, autoboot) if empty. *Attention*: If no admin password is set, then this does not act as a security measure, but rather just a measure to confirm a boot.
