# Pre-installation

## Vagrant

Follow the directions found at `http://sourabhbajaj.com/mac-setup/Vagrant/README.html` to install virtualbox and vagrant.

Download Ubuntu for Vagrant box using the command

    `vagrant box add ubuntu/xenial64`

## provisioner

A local system used to provision Azure resources.

1. You must first install the DevOps single box secrets.

The single box secrets can be found in Thycotic server in the NucleusHealth/DevOps/Development/Dev-K8S-Secrets binary attachment.
Download the attached tgz file and unpack it following teh directions
given in the Notes section on Thycotic.

2. From the /KNucleus-cs/projects/provisioner directory spin up the Jenkins VM using the command

   `vagrant up`

3. SSH into the provisioner. From inside the /KNucleus-cs/projects/provisioner directory run the command

    `vagrant ssh`

4. Once you have logged into the provisioner, the various subsystems can be found in the ~/scripts/terraform directory.
The available subsystems are ci, mcp, nsb, and snapshot for a Jenkins ci. a master control program, a nucleus single box,
and a snap server respectively.  CD into the appropriate directory. To spin up a system run the command

    `./terraform.sh <env> apply -var "login=<login-username>" -var "resourceName=<environment-name>"`

The <env> defines which subscription to deploy to, <login-username> is the user name you will use to log into this
environment, and <environment-name> is the name of the resource group to create the VM in.  Once created you will be to
log into the environment using

    `ssh -i <mcp-user-key> <login-username>@<environment-name>.<deploy-address>`

The `<mcp-user-key>` is found in ~/secrets/<dev|prod>/terraform/mcpuser_rsa. The `<login-username>` and
`<environment-name>` are what you provided during the provisioning step. Lastly `<deploy-address>` is nucleushealthdev.io
(nucleus.io) for dev (prod).

Finally to tear down a system, use the following command

    `./terraform.sh <dev|prod> destroy -var "login=<login-username>" -var "resourceName=<environment-name>"`
