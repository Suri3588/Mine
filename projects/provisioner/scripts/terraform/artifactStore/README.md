# Artifact Store

This will setup resources to store the artifacts from builds.

## Registry

This adds a registry for application images built in the CI pipelines. The subscription is determined by the
secrets bundle applied.

## Service Principals

There are two main principals to setup and grant access to this storage group.

Contributor access needs to be granted to a Jenkins Principal **in the same subscription** as this resource group.
Unfortunately, the Jenkins plugin that handle ACR quick tasks does not work across subscriptions even if the prinipal
is in the same tenant.

Reader access needs to be granted to a separate principal so that kubectl can pull the images from the registries.
This principal can be in a different subscription as long as the tenant applied to this subscription.

## Manually Terraforming

- `cd` to the `dev` or `prod` directories and then login as appropriate for the dev/prod subscriptions.
- extract the secrets using: `. /Deployment/extract-secrets.sh --dest=`
  - **Note** The `--dest=` puts the secrets file into the current directory which is needed for this deployment.
- run `terraform plan` or `terraform apply` and read the prompts.

