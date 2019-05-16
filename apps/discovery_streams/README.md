# discovery-streams

To start your Phoenix server:

```bash
mix deps.get
mix phx.server
```

To start interactively:

```bash
iex -S mix phx.server
```

To view the data on the websocket:

Install [wsta](https://github.com/esphen/wsta)

```bash
wsta -I --ping 50 \
--ping-msg '{"topic":"phoenix","event":"heartbeat","payload":{},"ref":"1"}' \
'ws://localhost:4000/socket/websocket' \
'{"topic":"vehicle_position","event":"phx_join","payload":{},"ref":"1"}'
```

## Setting a filter
A filter can be provided in the `phx_join` event by giving a filter key and value as the payload:

```bash
# Stream only vehicles with an id of 11409

wsta -I --ping 50 \
--ping-msg '{"topic":"vehicle_position","event":"heartbeat","payload":{},"ref":"1"}' \
'wss://localhost:4000/socket/websocket' \
'{"topic":"vehicle_position","event":"phx_join","payload":{"vehicle.vehicle.id":"11409"},"ref":"1"}'
```

## Running containers locally

```bash
docker-compose up -d kafka
docker-compose exec kafka kafka-topics --zookeeper zookeeper:2181 --create --topic test --partitions 1 --replication-factor 1
docker-compose up -d --build consumer
```

## Environment Variables


| Variable | Description | Example |
| -------- | ----------- | ------- |
| MIV_ENV | Environment for Mix build | `dev` or `test` or `prod`
| KAFKA_BROKERS | comma delimited list of kafka brokers | kafka1.com:9092,kafka2.com:9092
| SECRET_KEY_BASE | Pheonix uses this to verify cookies. Generate with `mix phx.gen.secret` or pass in your own | |

## Local development with minikube

Ensure you have the Git submodules.

```bash
git submodule update --init --recursive
```

Point minikube at your local Docker environment and build the image.

```bash
eval $(minikube docker-env)
docker build -t discovery-streams .
```

Run a Helm upgrade with (mostly) default values.

```bash
helm upgrade --install discovery-streams ./chart \
  --namespace=discovery \
  --set image.repository=discovery-streams \
  --set image.tag=latest
```
