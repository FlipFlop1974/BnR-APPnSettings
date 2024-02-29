# BnR-AnS

BnR-AnS
  BnR = Backup and Restore
  AnS = Apps and Settings
An attempt to make a Windows reinstallation less painful. This project is intended to help back up apps and their settings and restore them after a Windows reinstallation.
Every time you want or even have to reinstall, you automatically think about the next 2 days in which you have to set up your Windows with apps and settings again. A time I don't like to spend like this.

It was and is important to me that the backup and restore is as easy as possible to configure. That's why there is only one json file with the config for backup and restore.

## The content oft the config.json file
The content of the config file (in json format) is as follows:
"Title" is freely selectable and should be meaningful to you, see config.json for examples
Under "Title" you can specify **one or more** of the following
 - Path to Dirs or Files
 - Path to Reg Hives
 - Package available in choco 
 - URL to executable to be downloaded

## The structure of the config.json file
```
{
  "Title": [
    "Path to Dir or File",
    "Path to Reg Hives",
    "choco:PackageName",
    "URL to executable"
  ],
  ...repeat it as often as you need to
}
```
