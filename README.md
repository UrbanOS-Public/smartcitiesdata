# project
Management and documentation hub for the Smart Cities Data platform and component repos

## architecture
![scdp architecture diagram](./scdp_arch.png?raw=true "scdp architecture")

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
