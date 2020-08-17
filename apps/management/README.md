# Management

This app contains modules to help implement `DynamicSupervisor` and `Registry`
functionality with less boilerplate. These modules take care of the logic to start 
event objects as processes under service supervisors/registries.

## Usage

### Supervisor

`Management.Supervisor` folds helpful `DynamicSupervisor` functions into your own
`DynamicSupervisor` implementation without the boilerplate.

Use `Management.Supervisor` and implement callbacks to name and start child processes
under it. See [Broadcast.Stream.Supervisor](../service_broadcast/lib/broadcast/stream/supervisor.ex) as an example.

### Registry

`Management.Registry` folds helpful `Registry` functions into your own `Registry`
implementation without the boilerplate.

```elixir
defmodule Some.Registry do
  use Management.Registry, name: __MODULE__
end

{:via, Registry, {Some.Registry, :foobar}} = Some.Registry.via(:foobar)
pid = Some.Registry.whereis(:foobar)
```

## Installation

```elixir
def deps do
  [
    {:management, in_umbrella: true}
  ]
end
```
