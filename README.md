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
| [Andi](https://github.com/UrbanOS-Public/smartcitiesdata/blob/master/apps/andi/README.md)                             | Admin Interface for creating/editing datasets to be ingested  | ![](https://github.com/UrbanOS-Public/smartcitiesdata/actions/workflows/andi.yml/badge.svg)  |
| [Discovery API](https://github.com/UrbanOS-Public/smartcitiesdata/blob/master/apps/discovery_api/README.md)           | API to search for and query datasets                          | ![](https://github.com/UrbanOS-Public/smartcitiesdata/actions/workflows/discovery_api.yml/badge.svg) |
| [Discovery Streams](https://github.com/UrbanOS-Public/smartcitiesdata/blob/master/apps/discovery_streams/README.md)   | Websocket connection to listen to streaming data              | ![](https://github.com/UrbanOS-Public/smartcitiesdata/actions/workflows/discovery_streams.yml/badge.svg)  |
| [Estuary](https://github.com/UrbanOS-Public/smartcitiesdata/blob/master/apps/estuary/README.md)                       | Microservice to persist event stream events                   | ![](https://github.com/UrbanOS-Public/smartcitiesdata/actions/workflows/estuary.yml/badge.svg)  |
| [Forklift](https://github.com/UrbanOS-Public/smartcitiesdata/blob/master/apps/forklift/README.md)                     | Microservice for saving data to Presto DB                     | ![](https://github.com/UrbanOS-Public/smartcitiesdata/actions/workflows/forklift.yml/badge.svg)  |
| [Reaper](https://github.com/UrbanOS-Public/smartcitiesdata/blob/master/apps/reaper/README.md)                         | Microservice to retrieve data                                 | ![](https://github.com/UrbanOS-Public/smartcitiesdata/actions/workflows/reaper.yml/badge.svg)  |
| [Valkyrie](https://github.com/UrbanOS-Public/smartcitiesdata/blob/master/apps/valkyrie/README.md)                     | Microservice to validate data structure during ingestion      | ![](https://github.com/UrbanOS-Public/smartcitiesdata/actions/workflows/valkyrie.yml/badge.svg)  |
| [Alchemist](https://github.com/UrbanOS-Public/smartcitiesdata/blob/master/apps/alchemist/README.md)                   | Microservice to alter data from its original format           | ![](https://github.com/UrbanOS-Public/smartcitiesdata/actions/workflows/alchemist.yml/badge.svg)  |

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

### Development Enviornment Setup

[Setup guide available on our wiki](https://github.com/UrbanOS-Public/smartcitiesdata/wiki/Setup)

# Usage
The microservices written in Elixir use [Mix](https://elixir-lang.org/getting-started/mix-otp/introduction-to-mix.html) as the build tool.
## Building
Each microservice under the [apps/](https://github.com/UrbanOS-Public/smartcitiesdata/tree/master/apps) directory has a `Dockerfile` that can be used to build that microservice individually by running the following command:
```
docker build .
```

Additional app specific build steps will be in the relative readme at `apps/{app}/readme.md`.

## Testing
* Unit tests can be executed from the root of this repository or a specific application under the [apps/](https://github.com/UrbanOS-Public/smartcitiesdata/tree/master/apps) directory
```
mix test
```
* Integration tests can be executed from the root of this repository or a specific application under the [apps/](https://github.com/UrbanOS-Public/smartcitiesdata/tree/master/apps) directory
```
mix test.integration
```
* End to End (E2E) Tests can be executed from the root of this repository.
```
mix test.e2e
```
## Execution
[How to run and use the code](https://github.com/UrbanOS-Public/smartcitiesdata/wiki/Run)

# Additional Notes
* [What is the project and how it works](https://github.com/UrbanOS-Public/smartcitiesdata/wiki/The-What)
* [What all those application names mean](https://github.com/UrbanOS-Public/smartcitiesdata/wiki/Names)
* [Additional learning resources](https://github.com/UrbanOS-Public/smartcitiesdata/wiki/Resources)
* [A glossary of terms and technologies](https://github.com/UrbanOS-Public/smartcitiesdata/wiki/Glossary)
* [Starting All of the Microservices](https://github.com/UrbanOS-Public/smartcitiesdata/wiki/Run)
# Version History and Retention
Each microservice is released independently and can be found here in the [Releases](https://github.com/UrbanOS-Public/smartcitiesdata/releases) section.  All releases will be kept indefinitely.

Versioning conforms to the standard versioning pattern of <major>.<minor>.<patch>, for example 3.0.1. 3 being major, 0 being minor, and 1 being patch.

Patch version increments should introduce no breaking changes to the existing public chart. Docker images/Elixir apps are able to be updated in-place with no changes needed.
Minor version increments may require chart changes to function properly. These changes should be reviewed and charts should be adjusted accordingly before updating.
Major version increments likely introduce wide-spread or structural changes that require many configuration changes. 

## Building Individual Microservices with Make (OTP23)

`build_pods/Makefile` provides a target per microservice that wraps `scripts/build-local.sh`.
Run it from the **project root**:

```bash
# Build a single app (image stays local)
make -f build_pods/Makefile discovery_api

# Build and push to quay.io/urbanos
make -f build_pods/Makefile discovery_api PUSH=1

# PUSH can also be set as an environment variable
PUSH=1 make -f build_pods/Makefile forklift
```

Available targets: `alchemist`, `andi`, `discovery_api`, `forklift`, `reaper`, `valkyrie`

`PUSH=1` passes `--push` to `build-local.sh`. Any non-empty value works (`PUSH=true`, `PUSH=yes`, etc.).
Log into quay.io before pushing:
```bash
~/bin/podman login quay.io
```

## Local Build with Podman (OTP23)

The GitHub Actions pipelines for this repository target Ubuntu 20.04, which has been deprecated and
may produce broken or unavailable runners. As a workaround, `scripts/build-local.sh` provides an
equivalent local build using [Podman](https://podman.io/) instead of Docker.

### Prerequisites

- Podman available at `~/bin/podman` (version 3.4+ recommended)
- Internet access to pull `docker.io/hexpm/elixir:1.10.4-erlang-23.2.7.5-alpine-3.16.0` on first run
- A `quay.io` account with push access to `quay.io/urbanos` (for publishing)

### How it works

The script mirrors the two-stage build used by CI:

1. **Base image** — builds `smartcitiesdata:build` from the root `Dockerfile`. This image contains
   the full monorepo source tree, all Elixir/OTP23 dependencies fetched, and the Alpine SDK and
   Node.js toolchain needed to compile assets. It is reused across all app builds in a session.

2. **App image** — for each target app, runs `MIX_ENV=prod mix distillery.release` inside the base
   image and packages the compiled release into a minimal Alpine runtime image, then tags it as
   both `smartcitiesdata/<app>:<version>` and `quay.io/urbanos/<app>:<version>`.

### Usage

```bash
# Build all apps with recent local changes (andi, discovery_api, forklift, reaper, valkyrie)
scripts/build-local.sh

# Build specific apps only
scripts/build-local.sh discovery_api forklift

# Build and push to quay.io/urbanos
scripts/build-local.sh --push discovery_api

# Force-rebuild the base image (needed after mix.lock or shared dependency changes)
scripts/build-local.sh --rebuild-base

# Full release: rebuild base and push all changed apps
scripts/build-local.sh --rebuild-base --push
```

Log into quay.io before using `--push`:
```bash
~/bin/podman login quay.io
```

### Available flags

| Flag | Description |
|------|-------------|
| `--rebuild-base` | Force rebuild of `smartcitiesdata:build` even if it already exists |
| `--push` | Push each built image to `quay.io/urbanos` |
| `--no-cache` | Pass `--no-cache` to all podman build invocations |

### Apps that can be built

Any app under `apps/` that has a `Dockerfile`:
`alchemist`, `andi`, `discovery_api`, `discovery_streams`, `estuary`, `flair`,
`forklift`, `raptor`, `reaper`, `valkyrie`

Each app's image version is read automatically from its `mix.exs`.

### Listing locally built images

```bash
# Show the base builder and all locally built app images
~/bin/podman images | grep smartcitiesdata

# Show the quay.io-tagged copies ready to push
~/bin/podman images | grep quay.io/urbanos
```

Example output after building `discovery_api`:
```
quay.io/urbanos/discovery_api           1.3.19   b140299f2f56  ...  254 MB
localhost/smartcitiesdata/discovery_api 1.3.19   b140299f2f56  ...  254 MB
localhost/smartcitiesdata               build    81a0c54d7004  ...  459 MB
```

The `localhost/smartcitiesdata:build` entry is the shared base builder image.
The `localhost/smartcitiesdata/<app>:<version>` and `quay.io/urbanos/<app>:<version>` entries
are the same image ID with two tags — the quay.io tag is what `--push` uploads.

### Image versioning

Each app's image is tagged with the version declared in `version:` inside its `mix.exs`. For
example, `apps/discovery_api/mix.exs` contains:

```elixir
version: "1.3.19",
```

To release a new version, increment that field before running `build-local.sh`:

```bash
# Edit the version in the relevant app's mix.exs, e.g.:
#   version: "1.3.20",
vi apps/discovery_api/mix.exs

# Then build and push — the new tag is picked up automatically
scripts/build-local.sh --push discovery_api
```

Versioning follows `<major>.<minor>.<patch>` semantics consistent with the rest of the project
(see [Version History and Retention](#version-history-and-retention) below).

# License
Released under [Apache 2 license](https://github.com/UrbanOS-Public/smartcitiesdata/blob/master/LICENSE).
# Contributions
[How to contribute](https://github.com/UrbanOS-Public/smartcitiesdata/wiki/Contribute)
# Contact Information
# Acknowledgements
