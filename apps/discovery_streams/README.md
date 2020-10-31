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
MIX_ENV=integration mix docker.start
```

## Connecting to Websocket

Install [websocat](https://github.com/vi/websocat)

```bash
websocat wss://streams.smartcolumbusos.com/socket/websocket
{"topic": "streaming:central_ohio_transit_authority__cota_stream","event":"phx_join","payload":{},"ref":"1"}
```

### Setting a Filter
A filter can be provided in the `phx_join` event by giving a filter key and value as the payload:

```bash
# Stream only vehicles with an id of 11409

websocat wss://streams.smartcolumbusos.com/socket/websocket
{"topic": "streaming:central_ohio_transit_authority__cota_stream","event":"phx_join","payload":{"vehicle.vehicle.id":"11409"},"ref":"1"}
```

## Environment Variables

| Variable | Description | Example |
| -------- | ----------- | ------- |
| MIV_ENV | Environment for Mix build | `dev`, `test`, `integration`, or `prod` |
| KAFKA_BROKERS | comma delimited list of kafka brokers | kafka1.com:9092,kafka2.com:9092 |
| SECRET_KEY_BASE | Pheonix uses this to verify cookies. Generate with `mix phx.gen.secret` or pass in your own | |


### To run the tests

  * Run `mix test` to run the tests a single time
  * Run `mix test.watch` to re-run the tests when a file changes
  * Run `mix test.watch --stale` to only rerun the tests for modules that have changes
  * Run `mix test.integration` to run the integration tests
