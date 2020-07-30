# AnnotatedRetry

Add retry logic to functions with a module annotation.
The library executes macros at compile-time to inject
the necessary code for handling the replay of the function
until the specific limit is reached.

Based on the [`:retry` libray](https://hex.pm/packages/retry)
available on Hex.pm

## Usage

```elixir
  defmodule Example do
    use Annotated.Retry

    @retry with: constant_backoff(100) |> take(10)
    def do_something(arg) do
      ...do stuff...
    end
```

## Installation

```elixir
def deps do
  [
    {:annotated_retry, in_umbrella: true}
  ]
end
```
