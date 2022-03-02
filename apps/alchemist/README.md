# Alchemist

Validates data by evaluating each message and verifying that it has the required fields as specified by the [`SmartCity.Dataset.Technical.schema`](https://github.com/smartcitiesdata/smart_city/blob/master/lib/smart_city/dataset/technical.ex) Valid messages will be produced to the next topic, and invalid or bad messages will be sent to a dead letter queue.

### Setup

- Run `mix deps.get` (in the smartcitiesdata directory) to install dependencies

### To run locally:

- To startup external dependancies in docker:
  ```bash
  `MIX_ENV=integration mix docker.start`
  ```
- To run a single instance with no data in it:
  ```bash
  `MIX_ENV=integration iex -S mix`
  ```
- To run a single instance with test data added to it:
  ```bash
  `MIX_ENV=integration iex -S mix test --no-start`
  ```
- To stop the docker:
  ```bash
  `MIX_ENV=integration mix docker.stop`
  ```
- To kill the docker:
  ```bash
  `MIX_ENV=integration mix docker.kill`
  ```

### To run the tests

- Run `mix test` to run the tests a single time
- Run `mix test.watch` to re-run the tests when a file changes
- Run `mix test.watch --stale` to only rerun the tests for modules that have changes
- Run `mix test.integration` to run the integration tests

### To run inside a container(from the smartcitiesdata folder):

- Build the docker with `./scripts/build.sh alchemist <your tag>`

Creating ingestion events

```
  ingestion = SmartCity.TestDataGenerator.create_ingestion(%{})
  Brook.Event.send(Alchemist.instance_name(), "ingestion:update", :testing, ingestion)
```

### How alchemist interacts with kafka topics (message sequence)

- Alchemist listens for an `ingestion_update()` event on the `event_streams` topic.
  - The ingestion supervisor / processor setup the `broadway` library to listen
    to the associated data topic `raw-{datasetid}`. It's created if it doesn't
    already exist. Data from datasets being fetched will be placed on that topic
    from reaper.
  - `handle_message` performs the transform on data, and what's returned from
    that method is sent to the output topic. The output topic is configured as
    `transformed-{datasetid}`.

### Example Transformations

These commands can be run in the elixir console while alchemist is running
to demonstrate transformations running correctly. Transformed messages
can be viewed on the output kafka topic.

```
datasetId = "2222demo"
ingestId = "1111demo"
rawTopic = "raw-#{ingestId}"

payloadToTransform = %{"thing" => "123abc"}

t1 =
  %SmartCity.Ingestion.Transformation{
    type: "regex_extract",
    parameters: %{
      regex: "^([0-9])",
      sourceField: "thing",
      targetField: "number"
    }
  }

# Resulting in:
# %{"thing" => "123abc", "number": "1"}

t2 =
  %SmartCity.Ingestion.Transformation{
    type: "conversion",
    parameters: %{
      field: "number",
      sourceType: "string",
      targetType: "integer"
    }
  }

# Resulting in:
# %{"thing" => "123abc", "number": 1}

ingestion =
  SmartCity.TestDataGenerator.create_ingestion(%{
    id: ingestId,
    targetDataset: datasetId,
    transformations: [t1, t2]
  })

Brook.Event.send(Alchemist.instance_name(), "ingestion:update", :testing, ingestion)

msg = %SmartCity.Data{
  _metadata: %{name: "fake name", org: "fake org"},
  dataset_id: datasetId,
  operational: %{timing: []},
  payload: payloadToTransform,
  version: "0.1"
}

Elsa.Producer.produce(
      Application.get_env(:alchemist, :elsa_brokers),
      rawTopic,
      {"jerks", Jason.encode!(msg)},
      partition: 0
    )
```
