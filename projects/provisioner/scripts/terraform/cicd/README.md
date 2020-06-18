# CI/CD

This sets up a resource group with multiple machines that perform all the CI and CD
tasks for development.

## Jenkins

This is a Point-of-Presence machine for Jenkins. It does not run any of the compile steps
but does spawn build agents to do all the work.

This machine is almost completely provisioned by the scripts and this includes fully connecting
to the Azure AD. Therefore, once up, you will need your Statrad login creds to access the UI.

There is one little bit of setup that can't be done via Ansible and the Config as Code plugin.
The JenkinsServicePrincipal credential must be setup before you can run jobs.

### Jenkins Principal

This principal has the permissions to interact with Azure via the Jenkins Azure plugins.
It has Contributor permission to the Jenkins resource group specifically so it can create
new resources like VM and Container agents.

Note that this permission can be specifically scoped to the Jenkins resource group, but it is
handy to scope it higher up (subscription level) so that when you re-create the whole subscription,
the principal is automatically assigned the right access.

- Open Azure Active Directory in the subscription
- Register an application in AAD
  - copy the Application ID, it will be used as Client ID and is the `jenkinsSvcClientId` secret
  - copy the Directory ID, it will be used as Tenent ID and is the `jenkinsSvcTenantId` secret.
- In Authentication page
  - set the `ID tokens` checkbox under Advanced Settings
- In the Certificates and Secrets page, generate a new client secret. Copy the generated value
and save it as the `jenkinsSvcAPIKey` secret.

#### Jenkins Dev Principal

The Jenkins Dev Principal *can* be the same as the Jenkins Principal if AD tenant covers both
Production and Dev subscriptions. However, a separate Jenkins Azure Credential must be configured
with the **Dev** subscription even if the service prinicipal is the same identity. The Jenkins plugin
uses the subscription ID associated with the credential to find resource groups and stuff.

The code does not assume that the dev and prod principals are the same though. So, you still have to provide
the Client, Tenant IDs and the password (secret). You also have to provide the dev subscription ID because
that cannot be inferred from the current subscription state.

### Jenkins Azure AD Setup

[Setup Plugin](https://wiki.jenkins.io/display/JENKINS/Azure+AD+Plugin)
[Step By Step for Principal](http://cloud.badalkotecha.com/2018/09/jenkins-role-based-access-control-rbac-with-azure-ad-step-by-step.html)

These are the instructions slightly modified for the current Azure UI.

**Note** The main Jenkins Service Principal can be used if the AD is in the same tenant.
The additional steps are marked below.

- Open Azure Active Directory in the subscription
- Register an application in AAD
  - copy the Application ID, it will be used as Client ID and is the `jenkinsAadClientId` secret
  - copy the Directory ID, it will be used as Tenent ID and is the `jenkinsAadTenantId` secret.
- In Authentication page
  - (for AD) add a Redirect URL `https://prod-cicd.nucleushealthdev.io/securityRealm/finishLogin`.
  - set the `ID tokens` checkbox under Advanced Settings
- In the Certificates and Secrets page, generate a new client secret. Copy the generated value
and save it as the `jenkinsAadAPIKey` secret.
- (for AD) In the API Permissions page
  - Add the Microsoft.Graph, Delegated permissions:
    - User.Read
    - Directory.Read.All (optional if you don;t need auto complete in the Jenkins UI)

#### If it goes wrong

[Disable Security](https://wiki.jenkins.io/display/JENKINS/Disable+security)
