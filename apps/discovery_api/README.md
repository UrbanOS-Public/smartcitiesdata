# DiscoveryApi

Discovery API serves as middleware between our metadata store and our Data Discovery UI.

### To start your Phoenix server(from the root directory):
  * `MIX_ENV=integration mix docker.start`
  * Install dependencies with `mix deps.get`
  * Start Phoenix endpoint with `MIX_ENV=integration iex -S mix start`
  * `MIX_ENV=integration mix docker.stop`

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
