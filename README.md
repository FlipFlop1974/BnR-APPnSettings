# BnR-AnS

- BnR = Backup and Restore
- AnS = Apps and Settings

An attempt to make a Windows reinstallation less painful. This project is intended to help back up apps and their settings and restore them after a Windows reinstallation.
Every time you want or even have to reinstall, you automatically think about the next 2 days in which you have to set up your Windows with apps and settings again. A time I don't like to spend like this.

It was and is important to me that the backup and restore is as easy as possible to configure. That's why there is only one json file with the config for backup and restore. The **config.json** file is therefore one and the same file for backup and restore. 

## The content oft the config.json file
The content of the config file (in json format) is as follows:
"Title" is freely selectable and should be meaningful to you, see **config.json** for examples
Under "Title" you can specify ***one or more*** of the following
 - Local Path to Dirs or Files
 - Path to Reg Hives
 - Package available in choco 
 - URL to executable to be downloaded

| Type                         | How it's detected    | Example                                                |
|------------------------------|----------------------|--------------------------------------------------------|
| Local Path to Dirs or Files  | ```(^[a-zA-Z]:\\)``` | "C:\path\to\some\data"                                 |
| Path to Reg Hives            | ```'^HKEY'```        | "HKEY_CURRENT_USER\\Software\\Some Hive\\Another Hive" |
| choco Package                | ```'^choco'```       | "choco:vscode"                                         |
| Download URL                 | ```'^https:'```      | "https://www.someurl.tld/somepath/donwload.exe"        |


## The structure of the config.json file
Note that all details are within the object or linked. This means that they can be repeated or simply occur individually. See the file **config.json** as an example.
It is not necessary to classify. The script automatically detects which type is in question.
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
