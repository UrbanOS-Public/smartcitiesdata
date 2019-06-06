# Valkyrie

Validates data by evaluating each message and verifying that it has the required fields as specified by the [`SmartCity.Dataset.Technical.schema`](https://github.com/smartcitiesdata/smart_city_registry/blob/master/lib/smart_city/dataset/technical.ex) Valid messages will be produced to the next topic, and invalid or bad messages will be sent to a dead letter queue.

### To run the tests

  * Run `mix test` to run the tests a single time
  * Run `mix test.watch` to re-run the tests when a file changes
  * Run `mix test.watch --stale` to only rerun the tests for modules that have changes
  * Run `mix test.integration` to run the integration tests

### To run inside a container(from the root directory):
  * `docker build . -t <image_name:tag>`