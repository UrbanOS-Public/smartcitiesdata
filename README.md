[![Master](https://travis-ci.org/Datastillery/smartcitiesdata.svg?branch=master)](https://travis-ci.org/Datastillery/smartcitiesdata)

# Smart Cities Data Platform

Where to go to get started:
* [What is the project and how it works](https://github.com/Datastillery/smartcitiesdata/wiki/The-What)
* [What all those application names mean](https://github.com/Datastillery/smartcitiesdata/wiki/Names)
* [How to run and use the code](https://github.com/Datastillery/smartcitiesdata/wiki/Run)
* [How to contribute](https://github.com/Datastillery/smartcitiesdata/wiki/Contribute)
* [How to contact the team for help](https://github.com/Datastillery/smartcitiesdata/wiki/Contact)
* [Additional learning resources](https://github.com/Datastillery/smartcitiesdata/wiki/Resources)
* [A glossary of terms and technologies](https://github.com/Datastillery/smartcitiesdata/wiki/Glossary)

We look forward to growing a robust community around this project and doing some truly challenging and disruptive things in the space of Smart and Connected cities, industries, and organizations, IoT processing, and data analytics. Please join us and if you have any questions, feel free to reach out and ask!

~ Smart Cities Data core team

## architecture
![scdp architecture diagram](./scdp_arch.png?raw=true "scdp architecture")

The platform is a combination of Elixir micro services custom built to ingest, normalize, transform,
persist, and stream data from numerous sources, orchestrated via Kubernetes in any cloud provider or
on-prem Kubernetes deployment. The loosely coupled services pass data across the pipeline via Kafka
message queues and persist data to any hyper-scalable object store providing the S3 standard. They
coordinate and communicate via a single event bus, also running on top of Kafka. The distributed data
files are persisted and retrieved via SQL queries processed by the PrestoDB engine.
Finally, user access, discovery, and analysis is facilitated by a ReactJS web application user interface,
a RESTful API, or a web socket API for streaming data feeds.

## local development
### local environment setup
* [Setup needed to prepare workstation](https://github.com/Datastillery/smartcitiesdata/wiki/Setup)
* [Windows](https://github.com/Datastillery/smartcitiesdata/wiki/Windows-Setup)
* [macOS](https://github.com/Datastillery/smartcitiesdata/wiki/macOS-Setup)
* [Linux](https://github.com/Datastillery/smartcitiesdata/wiki/Linux-Setup)

### starting the entire stack in minikube or Docker Desktop embedded Kubernetes cluster
The current best approach to locally running the stack is in a local instance of Kubernetes, either in the minikube virtual machine or in the Kubernetes instance that can be run natively from Docker Desktop for Mac or Docker Desktop for Windows. Both options are viable, although in recent versions of the Docker version, exposing services via a `LoadBalancer` type allow the service to be reachable from the host machine without additional network manipulation.

Once you have a Kubernetes cluster running, check out the `Datastillery/charts` repo and the `platform` chart for standing up the complete platform or any ad hoc components you'd like to enable.


### port mappings
| application       | port     | url                                  |
| ----------------- | -------- | ------------------------------------ |
| discovery_api     | 8082     | http://localhost:8082                |
| discovery_ui      | 8085     | http://localhost:8085                |
| discovery_streams | 8087     | ws://localhost:8087/socket/websocket |
| presto            | 8081     | http://localhost:8081                |
| andi              | 8080     | http://localhost:8080                |
| kafka             | 9094     |                                      |
| metastore         | 9083     |                                      |
| redis             | 6379     |                                      |
| minio             | 9000     |                                      |
| ldap              | 389, 636 |                                      |
| zookeeper         | 2181     |                                      |
| postgres          | 5432     |                                      |

### Apps README
| application       | url                                                                                                        |
| ----------------- | ---------------------------------------------------------------------------------------------------------- |
| andi              | [Click Here](https://github.com/Datastillery/smartcitiesdata/blob/master/apps/andi/README.md)              |
| discovery_api     | [Click Here](https://github.com/Datastillery/smartcitiesdata/blob/master/apps/discovery_api/README.md)     |
| discovery_streams | [Click Here](https://github.com/Datastillery/smartcitiesdata/blob/master/apps/discovery_streams/README.md) |
| estuary           | [Click Here](https://github.com/Datastillery/smartcitiesdata/blob/master/apps/estuary/README.md)           |
| forklift          | [Click Here](https://github.com/Datastillery/smartcitiesdata/blob/master/apps/forklift/README.md)          |
| odo               | [Click Here](https://github.com/Datastillery/smartcitiesdata/blob/master/apps/odo/README.md)               |
| reaper            | [Click Here](https://github.com/Datastillery/smartcitiesdata/blob/master/apps/reaper/README.md)            |
| valkyrie          | [Click Here](https://github.com/Datastillery/smartcitiesdata/blob/master/apps/valkyrie/README.md)          |

### notes
ws://localhost:8087/socket/websocket

## To run E2E Test Locally
  * Run `mix test.e2e` in the root of the project
