# DiscoveryStreams

Discovery Streams dynamically finds kafka topics and makes available corresponding channels on a public websocket.
Channels are named with the form of `streaming:{dataset systemName}` (example: `streaming:central_ohio_transit_authority__cota_stream`).

## Getting Started

To start your Phoenix server:

```bash
mix deps.get
mix phx.server
```

To start interactively:

```bash
iex -S mix phx.server
```

If you would like to run the app with its dependencies:
```bash
MIX_ENV=integration docker.start
```

## Connecting to Websocket

Install [wsta](https://github.com/esphen/wsta)

```bash
wsta -I --ping 50 \
--ping-msg '{"topic":"streaming:central_ohio_transit_authority__cota_stream","event":"heartbeat","payload":{},"ref":"1"}' \
'wss://streams.smartcolumbusos.com/socket/websocket' \
'{"topic":"streaming:central_ohio_transit_authority__cota_stream","event":"phx_join","payload":{},"ref":"1"}'
```

### Setting a Filter
A filter can be provided in the `phx_join` event by giving a filter key and value as the payload:

```bash
# Stream only vehicles with an id of 11409

wsta -I --ping 50 \
--ping-msg '{"topic":"streaming:central_ohio_transit_authority__cota_stream","event":"heartbeat","payload":{},"ref":"1"}' \
'wss://streams.smartcolumbusos.com/socket/websocket' \
'{"topic":"streaming:central_ohio_transit_authority__cota_stream","event":"phx_join","payload":{"vehicle.vehicle.id":"11409"},"ref":"1"}'
```

## Environment Variables

| Variable | Description | Example |
| -------- | ----------- | ------- |
| MIV_ENV | Environment for Mix build | `dev`, `test`, `integration`, or `prod` |
| KAFKA_BROKERS | comma delimited list of kafka brokers | kafka1.com:9092,kafka2.com:9092 |
| SECRET_KEY_BASE | Pheonix uses this to verify cookies. Generate with `mix phx.gen.secret` or pass in your own | |


## Running Tests

Unit Tests:
```bash
mix test
```

Integration Tests:
```bash
mix test.integration
```
