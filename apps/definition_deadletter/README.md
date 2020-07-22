# DefinitionDeadletter

Defines a `DeadLetter` struct used to capture data processing errors in Hindsight
and functions for formatting said errors.

## Usage

Create a `DeadLetter` with its `new/1` function.

**NOTE**: This struct does not use [definition](../definition/README.md). No field
validation occurs, which is as designed. This means it does not return an `:ok/:error`
tuple.

`DeadLetter` objects should be written to the dead-letter-queue through [dlq](../dlq/README.md).

## Installation

```elixir
def deps do
  [
    {:definition_deadletter, in_umbrella: true}
  ]
end
```
