
# Smart Cities Data Platform!

Where to go to get started:
* [What is the project and how it works](https://github.com/smartcitiesdata/smartcitiesdata/wiki/The-What)
* [What all those application names mean](https://github.com/smartcitiesdata/smartcitiesdata/wiki/Names)
* [How to run and use the code](https://github.com/smartcitiesdata/smartcitiesdata/wiki/Run)
* [How to contribute](https://github.com/smartcitiesdata/smartcitiesdata/wiki/Contribute)
* [How to contact the team for help](https://github.com/smartcitiesdata/smartcitiesdata/wiki/Contact)
* [Additional learning resources](https://github.com/smartcitiesdata/smartcitiesdata/wiki/Resources)
* [A glossary of terms and technologies](https://github.com/smartcitiesdata/smartcitiesdata/wiki/Glossary)

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
### starting the entire stack in docker compose
```bash
docker pull && docker-compose up -d
```

### stopping resources
```bash
docker-compose down
```

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

### notes
ws://localhost:8087/socket/websocket
