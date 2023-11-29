##### How to Zip folders into app.zip 

use the zip command in terminal to zip your ./bin/publish folder into ./bin/app.zip on macOS. Here's the command you can use:

`zip -r ./bin/app.zip ./bin/publish/`  
 
###In this command:
- zip is the command that creates compressed zip files.
- -r is an option that tells zip to walk down the directory tree and include files in subdirectories.
- ./bin/app.zip is the path where you want to save the zipped file.
- ./bin/publish/ is the directory you want to zip.

Before running this command, you should navigate to the directory that contains your ./bin/publish folder using the cd commad

This zip command is included in most Unix-like systems like macOS, but if it's not installed in your system for any reason, you can install it using Homebrew by running brew install zip.
