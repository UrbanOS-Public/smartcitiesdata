# Forklift

An application for reading data off kafka topics, batching it up and sending it to Presto in a SQL insert query for long-term storage based on data retrieved from a schema registry.

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc).


# Running Locally

You can use [Divo](https://hexdocs.pm/divo/) to stand up the external dependencies locally using docker and docker-compose.

```bash
MIX_ENV=integration mix docker.start
MIX_ENV=integration iex -S mix
```

## Testing

### Running the Unit Tests

```bash
mix test
```

### Running the Integration Tests

```bash
mix test.integration
```
