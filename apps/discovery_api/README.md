# DiscoveryApi

Discovery API serves as middleware between our data storage and our Discovery UI.

### To run locally:
  * `mix deps.get`
  * `MIX_ENV=integration mix docker.start`
  * `MIX_ENV=integration iex -S mix start --config config/auth0.exs`
  * `MIX_ENV=integration mix docker.stop`

  ## Add Organizations and Datasets by executing the following in the iex session:
  ```elixir
  // Create Elasticearch Index
  DiscoveryApi.Search.Elasticsearch.DatasetIndex.create()
  // Create an Organization
  organization = SmartCity.TestDataGenerator.create_organization(%{})
  Brook.Event.send(DiscoveryApi.instance(), "organization:update", :testing, organization)
  //Create a Dataset
  dataset = SmartCity.TestDataGenerator.create_dataset(%{technical: %{orgId: organization.id}})
  Brook.Event.send(DiscoveryApi.instance(), "dataset:update", :testing, dataset)
  ```

### To run the tests

  * Run `mix test` to run the tests a single time
  * Run `mix test.watch` to re-run the tests when a file changes
  * Run `mix test.watch --stale` to only rerun the tests for modules that have changes
  * Run `mix test.integration` to run the integration tests

### To run inside a container(from the root directory):
  * `docker build . -t <image_name:tag>`

### To see the application live:
  * Go to localhost:4000/metrics
  * Go to http://localhost:4000/api/v2/dataset/search
  * You can get paginated results using the url http://localhost:4000/api/v2/dataset/search?offset=10&limit=5&sort=name_asc

### Tableau Web Data Connector
This application hosts a Tableau Web Data Connector that uses this API for interfacing with Tableau. More information can be found in its [README](./priv/static/tableau/README.md)

### To reindex the entire Elasticsearch index
```elixir
Brook.get_all_values!(DiscoveryApi.instance(), :models)
|> Elasticsearch.Document.replace_all()
```

### Calculating Completeness scores manually

For all datasets:

`DiscoveryApi.Stats.StatsCalculator.produce_completeness_stats()`

For a single dataset:

`SmartCity.Dataset.get!(dataset_id) |> DiscoveryApi.Stats.StatsCalculator.calculate_and_save_completeness()`

Datasets will be calculated and persisted to Redis with a key of `discovery-api:stats:{{dataset_id}}`

