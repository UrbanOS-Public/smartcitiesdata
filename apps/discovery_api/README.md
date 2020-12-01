# DiscoveryApi

Discovery API serves as middleware between our data storage and our Discovery UI.

### To run locally:
  * Install dependencies with `mix deps.get` (in the smartcitiesdata directory)
  * `MIX_ENV=integration mix docker.start` (in this directory)
  # TODO: Create a config/auth0.exs file and test it
  * `MIX_ENV=integration iex -S mix start --config config/auth0.exs` (in this directory)
    or just `MIX_ENV=integration iex -S mix start` if you want to try it without an auth config
  * `MIX_ENV=integration mix docker.stop` (in this directory)

  ## Add Organizations and Datasets by executing the following in the iex session:
  ```elixir
  # Create Elasticearch Index
  DiscoveryApi.Search.Elasticsearch.DatasetIndex.create()
  # Create an Organization
  organization = SmartCity.TestDataGenerator.create_organization(%{})
  Brook.Event.send(DiscoveryApi.instance_name(), "organization:update", :testing, organization)
  # Create a Dataset
  dataset = SmartCity.TestDataGenerator.create_dataset(%{technical: %{orgId: organization.id}})
  Brook.Event.send(DiscoveryApi.instance_name(), "dataset:update", :testing, dataset)
  ```

### To run the tests

  * Run `mix test` to run the tests a single time
  * Run `mix test.watch` to re-run the tests when a file changes
  * Run `mix test.watch --stale` to only rerun the tests for modules that have changes
  * Run `mix test.integration` to run the integration tests

### To run inside a container:
  * Go up to the smartcitiesdata directory `cd ../../`
  * `./scripts/build.sh discovery_api 1.0`
  * TODO: update this to include actual running the container

### To see the application live:
  * In your iex session type
    ```elixir
      "localhost:#{Application.get_env(:telemetry_event, :metrics_port)}/metrics"
    ```
    and go to the url printed out it in your browser.
  * Go to http://localhost:4000/api/v2/dataset/search
  * You can get paginated results using the url http://localhost:4000/api/v2/dataset/search?offset=10&limit=5&sort=name_asc

### Tableau Web Data Connector
This application hosts a Tableau Web Data Connector that uses this API for interfacing with Tableau. More information can be found in its [README](./priv/static/tableau/README.md)
<!--- TODO: Ask Jarred if he wants more details in the Tableau readme or if it is fine the way it is. -->

### To reindex the entire Elasticsearch index
```elixir
Brook.get_all_values!(DiscoveryApi.instance_name(), :models) \
|> DiscoveryApi.Search.Elasticsearch.Document.replace_all()
```

### Calculating Completeness scores manually

For all datasets:

```elixir
DiscoveryApi.Stats.StatsCalculator.produce_completeness_stats()
```

Datasets will be calculated and persisted to Redis with a key of `discovery-api:view:state:models:{{dataset_id}}`

To get the value of a key in Redis from the iex session do
```elixir
Redix.command!(:redix, ["GET", "mykey"])
```
To get a list of all keys in Redis from the iex session do
```elixir
Redix.command!(:redix, ["KEYS", "*"])  
```
For more information: https://hexdocs.pm/redix/Redix.html