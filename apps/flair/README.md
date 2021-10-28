# Flair

Computes data processing statistics off of Kafka data messages and stores them in Presto.

## To run the tests

  * Run `mix test` to run the tests a single time
  * Run `mix test.watch` to re-run the tests when a file changes
  * Run `mix test.watch --stale` to only rerun the tests for modules that have changes
  * Run `mix test.integration` to run the integration tests

## To run inside a container(from the root directory):
  * `docker build . -t <image_name:tag>`

## Running Locally

You can use [Divo](https://hexdocs.pm/divo/) to stand up the external dependencies locally using docker and docker-compose.

```bash
MIX_ENV=integration mix docker.start
MIX_ENV=integration iex -S mix
```

## License

Released under [Apache 2 license](https://github.com/UrbanOS-Public/smartcitiesdata/blob/master/LICENSE).
