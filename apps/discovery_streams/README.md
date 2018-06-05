# cota-streaming-consumer

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
wsta -I 'ws://localhost:4000/socket/websocket' '{"topic":"vehicle_position","event":"phx_join","payload":{},"ref":"1"}'
```

The json is the required payload to join the `vehicle_position` channel.

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
| COTA_DATA_TOPIC | kafka topic for vehicle position messages | |
| SECRET_KEY_BASE | Pheonix uses this to verify cookies. Generate with `mix phx.gen.secret` or pass in your own | |
