# Ok

Provides functions for standardizing function
results to `{:ok, result}` or `{:error, reason}`
tuples.

## Usage

```elixir
  {:ok, some_result} = some_result |> Ok.ok()

  {:ok, 10} = Ok.map({:ok, 5}, fn x -> x * 2 end)
```

## Installation

```elixir
def deps do
  [
    {:ok, in_umbrella: true}
  ]
end
```
