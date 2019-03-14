# DiscoveryApi

Discovery API serves as middleware between our metadata store and our Data Discovery UI.

### To start your Phoenix server(from the root directory):
  * Start Redis
  * Start Kafka
  * Install dependencies with `mix deps.get`
  * Start Phoenix endpoint with `iex -S mix phx.server`

#### Running Kafka and Redis locally
```
docker-compose up -d
```

### To run the tests

  * Run `mix test` to run the tests a single time
  * Run `mix test.watch` to re-run the tests when a file changes
  * Run `mix test.watch --stale` to only rerun the tests for modules that have changes
  * Run `MIX_ENV=integration mix test.integration` to run the integration tests

### To run inside a container(from the root directory):
  * `docker build . -t <image_name:tag>`

### To see the application live:
  * Go to localhost:4000/metrics
  * Go to http://localhost:4000/api/v1/dataset/search
  * You can get paginated results using the url http://localhost:4000/api/v1/dataset/search?offset=10&limit=5&sort=name_asc

### Deploying to Sandbox

* This application can be deployed to the sandbox environment using the following Terraform commands:
  * `tf init`
  * `tf workspace new {NEW_WORKSPACE_NAME}`
  * `tf plan --var=file=variables/sandbox.tfvars --out=out.out`
  * `tf apply out.out`
# DiscoveryApi

Discovery API serves as middleware between Kylo and our Data Discovery UI.

### To start your Phoenix server(from the root directory):
  * Install dependencies with `mix deps.get`
  * Start Phoenix endpoint with `iex -S mix phx.server`

### To run the tests

  * Run `mix test` to run the tests a single time
  * Run `mix test.watch` to re-run the tests when a file changes
  * Run `mix test.watch --stale` to only rerun the tests for modules that have changes
  * Run `MIX_ENV=integration mix test.integration` to run the integration tests

### To run inside a container(from the root directory):
  * `docker build . -t <image_name:tag>`
  * `docker run -d -e DATA_LAKE_URL=https://mockylo.dev.internal.smartcolumbusos.com -p 4000:80 <image_name:tag>`
    * You will need to be on the vpn if you use the dev mockylo as your backing datalake

### To see the application live:
  * Go to localhost:4000/metrics
  * Go to http://localhost:4000/api/v1/dataset/search
  * You can get paginated results using the url http://localhost:4000/api/v1/dataset/search?offset=10&limit=5&sort=name_asc

### Deploying to Sandbox

* This application can be deployed to the sandbox environment using the following Terraform commands:
  * `tf init`
  * `tf workspace new {NEW_WORKSPACE_NAME}`
  * `tf plan --var=file=variables/sandbox.tfvars --out=out.out`
  * `tf apply out.out`


### Producing Messages to Kafka (using docker-compose)
docker exec -it discovery-api_kafka_1 sh -c "/opt/kafka/bin/kafka-console-producer.sh --broker-list localhost:9092 --topic dataset-registry < /data/dataset_2.json"
