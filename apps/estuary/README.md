# Estuary

**Persists events from the eventstream topic**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `estuary` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:estuary, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/estuary](https://hexdocs.pm/estuary).

### Setup

  * Run `mix deps.get` to install dependencies

### To run locally:
  * To startup external dependancies in docker:
    ```bash
    `MIX_ENV=integration mix docker.start`
    ```
  * To run a single instance with no data in it:
    ```bash
    `MIX_ENV=integration iex -S mix phx.server`
    ```
  * To kill the docker:
    ```bash
    `MIX_ENV=integration mix docker.kill`
    ```

  It will be started in port `http:\\localhost:4010`

### To run the tests

  * Run `mix test` to run the tests a single time
  * Run `mix test.watch` to re-run the tests when a file changes
  * Run `mix test.watch --stale` to only rerun the tests for modules that have changes
  * Run `mix test.integration` to run the integration tests
