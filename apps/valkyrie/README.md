# Valkyrie

Validates data by evaluating each message and verifying that it has the required fields as specified by the [`SmartCity.Dataset.Technical.schema`](https://github.com/smartcitiesdata/smart_city/blob/master/lib/smart_city/dataset/technical.ex) Valid messages will be produced to the next topic, and invalid or bad messages will be sent to a dead letter queue.

### Setup

  * Run `mix deps.get` to install dependencies

### To run locally:
  * To startup external dependancies in docker:
    ```bash
    `MIX_ENV=integration mix docker.start`
    ```
  * To run a single instance with no data in it:
    ```bash
    `MIX_ENV=integration iex -S mix`
    ```
  * To run a single instance with test data added to it:
    ```bash
    `MIX_ENV=integration iex -S mix test --no-start`
    ```
  * To stop the docker:
    ```bash
    `MIX_ENV=integration mix docker.stop`
    ```
  * To kill the docker:
    ```bash
    `MIX_ENV=integration mix docker.kill`
    ```

### To run the tests

  * Run `mix test` to run the tests a single time
  * Run `mix test.watch` to re-run the tests when a file changes
  * Run `mix test.watch --stale` to only rerun the tests for modules that have changes
  * Run `mix test.integration` to run the integration tests

### To run inside a container(from the root directory):
  * `docker build . -t <image_name:tag>`
