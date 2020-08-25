# Initializer

Defines a GenServer that monitors a supervisor process
and performs some (initialization) operation for another
application out-of-band.

Used to re-hydrate the child processes underneath a
dynamic supervisor in the event of supervisor failure.

## Usage

```elixir
  defmodule ExampleInitServer do
    use Initializer, name: __MODULE__, supervisor: ExampleSupervisor

    def on_start(%{supervisor: unfinished_jobs: jobs} = state) do
      jobs
      |> get_stuff_from_view()
      |> start_children(ExampleSupervisor)

      {:ok, state}
    end
  end
```

## Installation

```elixir
def deps do
  [
    {:initializer, in_umbrella: true}
  ]
end
```
