# Smart Cities Data Platform

# Project Description
The platform is a combination of Elixir micro services custom built to ingest, normalize, transform,
persist, and stream data from numerous sources, orchestrated via Kubernetes in any cloud provider or
on-prem Kubernetes deployment. The loosely coupled services pass data across the pipeline via Kafka
message queues and persist data to any hyper-scalable object store providing the S3 standard. They
coordinate and communicate via a single event bus, also running on top of Kafka. The distributed data
files are persisted and retrieved via SQL queries processed by the PrestoDB engine.
Finally, user access, discovery, and analysis is facilitated by a ReactJS web application user interface,
a RESTful API, or a web socket API for streaming data feeds.

![scdp architecture diagram](./scdp_arch.png?raw=true "scdp architecture")

## Microservices
| Application       | Short Description | Build Status |
| ----------------- | ----------------- | ------------ |
| [Andi](https://github.com/Datastillery/smartcitiesdata/blob/master/apps/andi/README.md)                             | Admin Interface for creating/editing datasets to be ingested  | ![](https://github.com/Datastillery/smartcitiesdata/actions/workflows/andi.yml/badge.svg)  |
| [Discovery API](https://github.com/Datastillery/smartcitiesdata/blob/master/apps/discovery_api/README.md)           | API to search for and query datasets                          | ![](https://github.com/Datastillery/smartcitiesdata/actions/workflows/discovery_api.yml/badge.svg) |
| [Discovery Streams](https://github.com/Datastillery/smartcitiesdata/blob/master/apps/discovery_streams/README.md)   | Websocket connection to listen to streaming data              | ![](https://github.com/Datastillery/smartcitiesdata/actions/workflows/discovery_streams.yml/badge.svg)  |
| [Estuary](https://github.com/Datastillery/smartcitiesdata/blob/master/apps/estuary/README.md)                       | Microservice to persist event stream events                   | ![](https://github.com/Datastillery/smartcitiesdata/actions/workflows/estuary.yml/badge.svg)  |
| [Forklift](https://github.com/Datastillery/smartcitiesdata/blob/master/apps/forklift/README.md)                     | Microservice for saving data to Presto DB                     | ![](https://github.com/Datastillery/smartcitiesdata/actions/workflows/forklift.yml/badge.svg)  |
| [Odo](https://github.com/Datastillery/smartcitiesdata/blob/master/apps/odo/README.md)                               | Microservice to convert Shapefiles to GeoJSON                 | ![](https://github.com/Datastillery/smartcitiesdata/actions/workflows/odo.yml/badge.svg)  |
| [Reaper](https://github.com/Datastillery/smartcitiesdata/blob/master/apps/reaper/README.md)                         | Microservice to retrieve data                                 | ![](https://github.com/Datastillery/smartcitiesdata/actions/workflows/reaper.yml/badge.svg)  |
| [Valkyrie](https://github.com/Datastillery/smartcitiesdata/blob/master/apps/valkyrie/README.md)                     | Microservice to validate data structure during ingestion      | ![](https://github.com/Datastillery/smartcitiesdata/actions/workflows/valkyrie.yml/badge.svg)  |

# Prerequisites
### General Prerequisites
* [Elixir](https://elixir-lang.org/) - The primary language that all of the microservices are written in
* [Docker](https://www.docker.com/) - All microservices are built as docker images
* [Apache Kafka](https://kafka.apache.org/) -  Communication mechanism between microservices
* [Redis](https://redis.io/) - General purpose storage and caching
* [Elasticsearch](https://www.elastic.co/) - Used by Discovery API for search
* [PostgreSQL](https://www.postgresql.org/) - General purpoase storage
* [Presto](https://prestodb.io/) - Big Data storage of ingested data
* [Vault](https://www.vaultproject.io/) - Secure storage of secrets

### Development Enviornment Prerequisites
* [General Setup Information](https://github.com/Datastillery/smartcitiesdata/wiki/Setup)
* [Windows](https://github.com/Datastillery/smartcitiesdata/wiki/Windows-Setup)
* [macOS](https://github.com/Datastillery/smartcitiesdata/wiki/macOS-Setup)
* [Linux](https://github.com/Datastillery/smartcitiesdata/wiki/Linux-Setup)


# Usage
The microservices written in Elixir use [Mix](https://elixir-lang.org/getting-started/mix-otp/introduction-to-mix.html) as the build tool.
## Building
Each microservice under the [apps/](https://github.com/Datastillery/smartcitiesdata/tree/master/apps) directory has a `Dockerfile` that can be used to build that microservice individually by running the following command:
```
docker build .
```

Additional app specific build steps will be in the relative readme at `apps/{app}`.

## Testing
* Unit Tests can be executed from the root of this repository or a specific application under the [apps/](https://github.com/Datastillery/smartcitiesdata/tree/master/apps) directory
```
mix test
```
* Integration Tests can be executed from the root of this repository or a specific application under the [apps/](https://github.com/Datastillery/smartcitiesdata/tree/master/apps) directory
```
mix test.integration
```
* End to End (E2E) Tests can be executed from the root of this repository.
```
mix test.e2e
```
## Execution
[How to run and use the code](https://github.com/Datastillery/smartcitiesdata/wiki/Run)

# Additional Notes
* [What is the project and how it works](https://github.com/Datastillery/smartcitiesdata/wiki/The-What)
* [What all those application names mean](https://github.com/Datastillery/smartcitiesdata/wiki/Names)
* [Additional learning resources](https://github.com/Datastillery/smartcitiesdata/wiki/Resources)
* [A glossary of terms and technologies](https://github.com/Datastillery/smartcitiesdata/wiki/Glossary)
* [Starting All of the Microservices](https://github.com/Datastillery/smartcitiesdata/wiki/Run)
# Version History and Retention
Each microservice is released independently and can be found here in the [Releases](https://github.com/Datastillery/smartcitiesdata/releases) section.  All releases will be kept indefinitely.
# License
Released under [Apache 2 license](https://github.com/Datastillery/smartcitiesdata/blob/master/LICENSE).
# Contributions
[How to contribute](https://github.com/Datastillery/smartcitiesdata/wiki/Contribute)
# Contact Information
# Acknowledgements
