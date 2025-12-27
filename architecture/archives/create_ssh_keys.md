##### Q: Step by step How-To create a SSH Public Key, on Azure Cloud Shell, to upload to Azure DevOps to connect git using ssh

1.Open Azure Cloud Shell

Azure Cloud Shell is a free, interactive shell that you can use to run the steps in this article. It has common Azure tools preinstalled and configured to use with your account.

Open Azure Cloud Shell by clicking on this link: Azure Cloud Shell
2. Create the SSH Key Pair

In the Cloud Shell, use the ssh-keygen command to create SSH public and private key files. The keys are stored in the .ssh directory in your home directory. When you run the command, it will prompt you for a location to save the keys, and a passphrase for the keys. You can press enter to accept the defaults.
- ssh-keygen -t rsa -b 2048  
 
This creates a new ssh key, using the provided email as a label.
Generating public/private rsa key pair.

3. Check the SSH Key Pair

Once the key pair is generated, it's time to check and display your public key with the following command:
- cat ~/.ssh/id_rsa.pub  
 
4. Copy the SSH Public Key

- You'll see a long string that starts with ssh-rsa. That's your public key. Copy it entirely.

5. Add the SSH Public Key to Azure DevOps
- Go to Azure DevOps and sign in to your account.
- Click on the user settings icon in the top right corner and select 'SSH Public Keys'.
- Click on '+ New Key'.
- Paste the copied public key into the 'Public Key Data' field, give it a name and then click 'Save'.
- Clone the Repo with SSH

Now you can clone your repository using the SSH URL:
- git clone git@ssh.dev.azure.com:v3/Your-Project/Your-Repo  
 
Replace [Your-Project] and [Your-Repo] with your own project's and repository's name.

Remember to always use this SSH URL to connect to your git repository from the Azure Cloud Shell.

And that's it, you've successfully created an SSH public key on Azure Cloud Shell, uploaded it to Azure DevOps, and connected to git using SSH.

Resources:

- https://learn.microsoft.com/en-us/azure/devops/repos/git/use-ssh-keys-to-authenticate?view=azure-devops
