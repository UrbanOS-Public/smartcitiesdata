# DiscoveryApi

Discovery API serves as middleware between our data storage and our Discovery UI.

### To run locally:
  * Step 1: Install mix dependencies in the smartcitiesdata directory not this directory.
    * Install dependencies with `mix deps.get`
  * Step 2: Start all docker microservices necessary for discovery_api.
    * `MIX_ENV=integration mix docker.start` (in this directory)
  * Step 3: Start raptor service to handle authentication
    * From discovery_api directory:
    * `cd ../raptor`
    * `AUTH0_CLIENT_SECRET={auth0_key} MIX_ENV=integration iex -S mix start`
  * Step 4: Actually run the application
    * From discovery_api directory
    * `MIX_ENV=integration iex -S mix start --config config/auth0.exs` (in this directory)
    or just `MIX_ENV=integration iex -S mix start` if you want to try it without an auth config
  * Step 5: When you are done using the app you can run this to stop the docker microservices.
    * `MIX_ENV=integration mix docker.stop` (in this directory)

  ## Add Organizations and Datasets by executing the following in the iex session:
  ```elixir
  # Create Elasticsearch Index
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


### To build a discovery_api docker image:
  * Go up to the smartcitiesdata directory `cd ../../`
  * `./scripts/build.sh discovery_api 1.0`
  * You should now see smartcitiesdata/discovery_api in your list of docker images.

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
