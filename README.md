# project
Management and documentation hub for the Smart Cities Data platform and component repos

## Starting master chart
```bash
docker-compose up -d
```

## Stopping resources
```bash
docker-compose down
```

## Port Mappings
| Application       | Port     | URL                                  |
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

## Notes
ws://localhost:8087/socket/websocket
