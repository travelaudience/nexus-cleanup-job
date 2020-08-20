# nexus-cleanup-job

This repo is for a docker image used to allow Nexus admins to create custom cleanup rules for docker-repo.

## TL/DR

You can run this job as a docker image simply by replacing the env variables with your environment data:
```
docker run -it -e NEXUS_AUTH="[username:password]" -e NEXUS_URL="[your_nexus_url]" quay.io/travelaudience/nexus-cleanup-job:latest  -p "60 '^v2\/.*\/manifests\/([a-f0-9]{64})$' last_downloaded false"
```
This will do a soft delete of all images tagged with 64-chars SHA that haven't been downloaded for over 60 days. In order to run hard delete and clear the storage size, please read the section '[Setting up tasks to run after cleanup](#about-arguments)'.

## Getting Started

This image was aimed to be used on a kubernetes cron-job for periodic cleanup, but you can use it however you want to.

## Prerequisites

The image works well with [Nexus chart](https://github.com/helm/charts/tree/master/stable/sonatype-nexus) configuration.

From Nexus version `3.21.2` Groovy scripting was disabled by default. In order to make this tool work, you will need to enable them: https://support.sonatype.com/hc/en-us/articles/360045220393-Scripting-Nexus-Repository-Manager-3#how-to-enable

## How to use this image?
The arguments that need to be passed to the image have a strict organisation and format, please follow it when using this image in your solution.

### About Arguments

| Argument (-x) | Description | Structure |
| ------- |----------| -------------|
| p | parameters for setting up custom cleanup script | "[days] [regex_for_db] [date_query_field] [not_downloaded]"|
| t | Nexus tasks IDs to run after custom cleanup | "[ID1] [ID2] [ID3]"|

__*Setting up cleanup script (-p)*__

The custom cleanup is based on Nexus's OrientDB query. The parameters that you need to pass after `-p` are parameters array for querying the DB (for more info look into [Query.java](https://github.com/sonatype/nexus-public/blob/master/components/nexus-repository/src/main/java/org/sonatype/nexus/repository/storage/Query.java)). You can pass multiple parameters arrays by using multiple `-p` declarations. Each Array will create a different query to the DB.
Each set of `-p` parameters will create the following type of query :
```
SELECT * FROM asset WHERE name MATCHES '[regex_for_db]' AND [date_query_field] < [current_date - days]
```
** UPDATE: When using `last_downloaded` as [date_query_field] , the script until now didn't delete artefacts that were never downloaded ( Null field wasn't included in the query). From now, by adding another cleanup task with [not_downloaded] set to `true` on the script in the `-p` argument, The tool will create a cleanup task that will use the following DB query:
```
SELECT * FROM asset WHERE blob_updated < [current_date - days] AND name MATCHES '[regex_for_db]' AND last_downloaded IS NULL
```
The [days] argument will be used for limiting the non downloaded artefacts to ones that were only updated before [days] days.
__*Setting up tasks to run after cleanup (-t)*__

Argument `-t` is meant to be trigger Nexus pre-configured tasks after the custom cleanup. This tasks should be configured manually in Nexus, and their ID should be passed to the image.
The most important task ID to pass is for the `Admin - Compact blob store` task. The custom cleanup is a soft delete and only by running this task, HD space will be actually freed.
**It is important to pass this task as the last one in `-t` argument spaced string, as it runs synchronically.**
To understand better which pre-configured tasks should be run, please look into Docker cleanup strategies in  [Nexus guide ](https://help.sonatype.com/repomanager3/cleanup-policies).

### Image Configurations

| ENV_VAR | Description | Default Value |
| ------- |----------| -------------|
| NEXUS_AUTH | Authorisation for your Nexus api. it will be in the format of 'username:password'.<br> If `nexusProxy.env.cloudIamAuthEnabled' is used , please use an [auth token](https://github.com/travelaudience/kubernetes-nexus/blob/master/docs/admin/configuring-nexus-proxy.md#using-command-line-tools) | "abcd:1234" |
| NEXUS_URL | Your Nexus external URL | "https://nexus.example.com" |
| NEXUS_REPO | Docker repo name | 'docker-hosted' |

## Architecture

[Workflow diagram](./img/Workflow-Diagram.jpg)

## Contributing

Contributions are welcomed! Read the [Contributing Guide](CONTRIBUTING.md) for more information.

## Licensing

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details
