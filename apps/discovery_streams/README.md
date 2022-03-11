# Discovery Streams

Discovery Streams dynamically finds kafka topics and makes available corresponding channels on a public websocket.
Channels are named with the form of `streaming:{dataset systemName}` (example: `streaming:central_ohio_transit_authority__cota_stream`).

## Using Discovery Streams

### Connecting to Websocket

1. Install [websocat](https://github.com/vi/websocat).
1. Start websocat:
   ```bash
   websocat wss://streams.smartcolumbusos.com/socket/websocket -H='User-Agent: websocat'
   ```
1. Connect to a dataset:
   ```bash
   {"topic": "streaming:central_ohio_transit_authority__cota_stream","event":"phx_join","payload":{},"ref":"1"}
   ```
1. The following response indicates a successful connection:
   ```bash
   {"event":"phx_reply","payload":{"response":{},"status":"ok"},"ref":"1","topic":"streaming:central_ohio_transit_authority__cota_stream"}
   ```

### Running Locally

1. In the smartcitiesdata directory, install dependencies:
   ```bash
   mix deps.get
   ```
1. In this directory, start Docker:
   ```bash
   MIX_ENV=integration mix docker.start
   ```
1. Start the Phoenix server:

   ```bash
   MIX_ENV=integration mix phx.server

   # ...or start interactively:
   MIX_ENV=integration iex -S mix phx.server
   ```

### Setting up to stream data locally

1. Install [websocat](https://github.com/vi/websocat).
1. Start Docker from **Andi**. Run **Andi** and **Reaper** locally.
1. In `discovery_streams > config > config.exs`, under `config :discovery_streams`, set `topic_prefix` to `"raw-"`.
   - **Make sure** to change it back to `"transformed-"` when finished with local testing!
1. Run **Discovery Streams** by starting the Phoenix server:
   ```bash
   MIX_ENV=integration iex -S mix phx.server
   ```
1. Make a `PUT` request to the **Andi API** to add a dataset.
   - For help with the API, see the Postman collection located [here](https://github.com/UrbanOS-Public/smartcitiesdata/blob/master/apps/andi/ANDI.postman_collection.json).
   - Use the `central_ohio_transit_authority__cota_stream` dataset found [here](https://andi.prod.internal.smartcolumbusos.com/api/v1/dataset/90d51c3b-8c01-4ba4-ac24-a3206458f851), or create your own.
   - Before making the `PUT` request, make sure the dataset has `technical.sourceType` set to `"stream"`.
1. Start websocat:
   ```bash
   websocat ws://127.0.0.1:4001/socket/websocket -H='User-Agent: websocat'
   ```
1. Connect to your dataset:

   ```bash
   {"topic": "streaming:central_ohio_transit_authority__cota_stream","event":"phx_join","payload":{},"ref":"1"}
   ```

   - If using your own dataset, replace `central_ohio_transit_authority__cota_stream` with the system name of your dataset.

1. You should see the following success response:
   ```bash
   {"event":"phx_reply","payload":{"response":{},"status":"ok"},"ref":"1","topic":"streaming:central_ohio_transit_authority__cota_stream"}
   ```
   Every ten seconds (by default), you should see data events appear in the console.

### Connecting to a private dataset

A private dataset can be streamed by a client within the organization that owns the dataset. An API key can be provided in the `phx_join` event by including the key-value pair `"api_key":"<client API key>"` in the payload:

```bash
   {"topic": "streaming:central_ohio_transit_authority__cota_stream","event":"phx_join","payload":{"api_key":"1234567890abcdefg"},"ref":"1"}
```

### Setting a Filter

A filter can be provided in the `phx_join` event by giving a filter key and value as the payload:

```bash
# Stream only vehicles with an id of 11409
websocat wss://streams.smartcolumbusos.com/socket/websocket -H='User-Agent: websocat'
{"topic": "streaming:central_ohio_transit_authority__cota_stream","event":"phx_join","payload":{"vehicle.vehicle.id":"11409"},"ref":"1"}

# Include both a filter and an API key
websocat wss://streams.smartcolumbusos.com/socket/websocket -H='User-Agent: websocat'
{"topic": "streaming:central_ohio_transit_authority__cota_stream","event":"phx_join","payload":{"api_key":"1234567890abcdefg","vehicle.vehicle.id":"11409"},"ref":"1"}
```

## Environment Variables

| Variable        | Description                                                                                 | Example                                 |
| --------------- | ------------------------------------------------------------------------------------------- | --------------------------------------- |
| MIV_ENV         | Environment for Mix build                                                                   | `dev`, `test`, `integration`, or `prod` |
| KAFKA_BROKERS   | comma delimited list of kafka brokers                                                       | kafka1.com:9092,kafka2.com:9092         |
| SECRET_KEY_BASE | Pheonix uses this to verify cookies. Generate with `mix phx.gen.secret` or pass in your own |                                         |

### To run the tests

- Run `mix test` to run the tests a single time
- Run `mix test.watch` to re-run the tests when a file changes
- Run `mix test.watch --stale` to only rerun the tests for modules that have changes
- Run `mix test.integration` to run the integration tests
