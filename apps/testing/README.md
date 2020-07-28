# Testing

Application for collecting convenience modules and
functions for testing.

## Usage

### AssertAsync
Asynchronously check test outcomes that are expected to
validate but may not immediately.

AssertAsync implements a macro that injects the necessary
retry logic for validating test assertions with a configurable
delay between checks and maximum number of attempted checks.

```elixir
  defmodule Example do
    use ExUnit.Case
    import AssertAsync

    test "tests a thing" do
      do_something(args)

      assert_async do
        assert result == check_some_condition()
      end
    end
  end
```

### Temp.Env
Set configuration values in applications' env temporarily
in individual test files, describe blocks or single tests.

`Temp.Env` stores the current application env value for the
values being overridden and resets them at the close of the
block being overridden. Reduces the need for application-wide
configuration overrides in the `config/test.exs` file by only
overriding the specific values in the places they're needed.

```elixir
  defmodule Example do
    require Temp.Env

    Temp.Env.modify([
      %{app: :my_app, key: MyApp.BusinessLogic, set: [writer: BizMock]}
    ]

    test "tests my internal logic" do
      ... does stuff with overridden value ...
    end
  end
```

## Installation

```elixir
def deps do
  [
    {:testing, in_umbrella: true}
  ]
end
```
