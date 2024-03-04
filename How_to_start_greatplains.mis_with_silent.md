#### how do I create silent install with setup.exe for Microsoft's Dynamics GreatPlains.msi to be able to run it with Powershell on the command line? 

### To create a silent install for Microsoft's Dynamics Great Plains, Microsoft provides you with the process in the following steps.

1. First, extract the setup.exe file. Most of the setup.exe files can be extracted using command line switches. For example:
   ```
   setup.exe /a
   ```
   In some cases, other tools might have to be used to extract the MSI from the EXE file like 7-zip.

2. Once you get the MSI file, you can use the `/quiet` switch which installs the program without displaying any user interface.
   
   The command you can use for silent install in PowerShell would be:
   ```ps
   Start-Process 'msiexec.exe' -ArgumentList '/i C:\\path\\to\\your\\file.msi /quiet' -NoNewWindow -Wait
   ```
   Replace 'C:\\path\\to\\your\\file.msi' with the actual path to your Dynamics GreatPlains MSI file.

3. As some installation setups have their own set of parameters, you should refer to specific documentation for Microsoft Dynamics' GreatPlains silent install.

Please note that if Dynamics GreatPlains doesn't provide a '.msi' but only a 'setup.exe', you will have to contact Microsoft support or refer to the specific software documentation for silent installation.

For more information regarding silent installs with msiexec.exe, you may refer to the official Microsoft Docs [here](https://docs.microsoft.com/en-us/windows-server/administration/windows-commands/msiexec).

Please make sure the path to the MSI file is correct and the PowerShell is run with administrator privileges.

