#### Creating a new Windows Domain Controller with Azure Active Directory:

1. **Create an Azure VM:**

After creating the virtual network, the next step is to create a Windows Server VM in Azure, which will function as your domain controller.

[Link to Azure VM creation instructions](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/quick-create-portal)

2. **Install Active Directory Domain Services (AD DS):**

Once you've deployed your Windows Server VM, you need to install Active Directory Domain Services on that VM to make it a domain controller.

[Link to AD DS installation instructions](https://docs.microsoft.com/en-us/windows-server/identity/ad-ds/deploy/install-active-directory-domain-services--level-100-)

3. **Create a forest for your domain:**

After the installation of AD DS, you need to create a new forest for your domain (cargill-fms.com).

[Link to creating a new forest instructions](https://docs.microsoft.com/en-us/windows-server/identity/ad-ds/manage/components/create-a-new-forest)

4. **Administer Azure AD Connect and synchronization:**

Azure AD Connect is what you'll use to synchronize your on-premises directory with Azure Active Directory. This will allow your users and groups to be available in Azure AD, and enable Azure VMs to login with these user credentials.

[Link to Azure AD Connect and synch instructions](https://docs.microsoft.com/en-us/azure/active-directory/hybrid/how-to-connect-install)

5. **Configure Azure AD for Domain Services:**

Azure AD Domain Services enables you to configure a full set of AD features. It can be integrated with your existing AD if you also have an on-premises setup.

[Link to Azure AD Domain service](https://docs.microsoft.com/en-us/azure/active-directory-domain-services/overview)

6. **Backup and Migration of Users**

If you have users in other servers that you want to migrate to this new server, you can use Azure Backup Solutions or Azure Migrate for this.

[Link to Azure Migrate](https://docs.microsoft.com/en-us/azure/migrate/tutorial-migrate-physical-virtual-machines)

[Link to Azure Backup](https://docs.microsoft.com/en-us/azure/backup/backup-azure-vms-introduction)

7. **Application Authentication with Azure AD:**

Azure Active Directory also supports B2C and B2B scenarios which allow your applications to authenticate with Azure AD.

[Link to Application Authentication](https://docs.microsoft.com/en-us/azure/active-directory/develop/quickstart-register-app) 
