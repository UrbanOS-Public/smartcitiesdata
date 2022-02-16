# Pipeline

Behaviours describing component edges with some common concrete implementations.

## Installation

Add `:pipeline` to any umbrella sub-project that implements an edge behaviour or uses one
of the implementations.

```elixir
def deps do
  [
    {:pipeline, in_umbrella: true}
  ]
end
```

## Commands

- `mix test` to run unit tests
- `mix integration` to run integration tests
