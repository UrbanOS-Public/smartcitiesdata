# Dlq

Application to write a list of [DeadLetter](../definition_deadletter/README.md) messages
to a dead-letter-queue.

## Usage

Pulling `:dlq` app into your app/service will cause the [server](lib/dlq/server.ex) to
start automatically. Using the running application is as easy as passing your messages
to `Dlq.write/1`.

```elixir
DeadLetter.new(...)
|> List.wrap()
|> Dlq.write()
```

### Dlq and testing

For tests and local development, you may not want to spin up your `:dlq` dependency.
You can turn off auto-start with the `:init?` config option. By default, auto-start
is toggled on.

```elixir
config :dlq, Dlq.Application, init?: false
```

The `Dlq` module adheres to a [behaviour](lib/dlq.ex) for testing purposes.
Mock `Dlq.write/1` usage with `Mox` in your tests to make usage verification easy.

## Installation

```elixir
def deps do
  [
    {:dlq, in_umbrella: true}
  ]
end
```
