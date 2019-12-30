# DiscoveryApi

Discovery API serves as middleware between our metadata store and our Data Discovery UI.

### To start your Phoenix server(from the root directory):
  * `MIX_ENV=integration mix docker.start`
  * Install dependencies with `mix deps.get`
  * Start Phoenix endpoint with `MIX_ENV=integration iex -S mix start`
  * `MIX_ENV=integration mix docker.stop`
  * Optionally, run the app with Auth0 as an auth provider: `MIX_ENV=integration iex -S mix start --config config/auth0.exs`

### To run the tests

  * Run `mix test` to run the tests a single time
  * Run `mix test.watch` to re-run the tests when a file changes
  * Run `mix test.watch --stale` to only rerun the tests for modules that have changes
  * Run `mix test.integration` to run the integration tests

### To run inside a container(from the root directory):
  * `docker build . -t <image_name:tag>`

### To see the application live:
  * Go to localhost:4000/metrics
  * Go to http://localhost:4000/api/v1/dataset/search
  * You can get paginated results using the url http://localhost:4000/api/v1/dataset/search?offset=10&limit=5&sort=name_asc

### Calculating Completeness scores manually

For all datasets:

`DiscoveryApi.Stats.StatsCalculator.produce_completeness_stats()`

For a single dataset:

`SmartCity.Dataset.get!(dataset_id) |> DiscoveryApi.Stats.StatsCalculator.calculate_and_save_completeness()`

Datasets will be calculated and persisted to Redis with a key of `discovery-api:stats:{{dataset_id}}`


### Creating Datasets Locally
  * Start the app and use `iex` to run the following commands:
```
org = SmartCity.TestDataGenerator.create_organization([])
datasets = Enum.map(1..3, fn _ -> SmartCity.TestDataGenerator.create_dataset(%{technical: %{orgId: org.id}}) end)
Brook.Event.send(DiscoveryApi.instance(), "organization:update", :andi, org)
Enum.each(datasets, &(Brook.Event.send(DiscoveryApi.instance(), "dataset:update", :andi, &1)))

session = DiscoveryApi.prestige_opts() |> Prestige.new_session()
Enum.each(datasets, fn %{technical: %{orgName: orgName, dataName: dataName}} -> Prestige.query!(session, "create table if not exists #{orgName}__#{dataName} (key varchar, value varchar)") end)
```

