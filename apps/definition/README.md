# Definition

Definition is a core library for defining complex data types
throughout Hindsight as Elixir structs, validating their contents,
and managing their behavior and functionality throughout the life
of the system as requirements change.

The primary module defines a `__using__/1` macro that accepts a
schema definition for the definition type being implemented and
implements functions for creating new instances of the definition
struct from maps, keyword lists, or JSON-formatted strings.

The basic default functions include a pre-compile `migrate/1` function
for defining a migration path to upgrade the specification of the
definition as its needs change and a getter function for
returning the schema definition of the struct instance.

Finally, definition provides an overridable `on_new/1` function that allows
you to define customizable behavior for struct instances to perform
arbitrary operations on instances and their internal data upon creation.

Definition relies on the [Norm](https://hexdocs.pm/norm/Norm.html) validation
library for conforming struct instances to their desired specifications.

## Usage

Below is a simple implementation of Foo type that contains three fields.
On first creation of a new instance of Foo, if not nil, the data in the
`baz` field is converted to an upper-case string. The schema of the current
version of Foo is passed to the `use Definition` macro via the `:schema` argument
which must return a Norm-compatible schema struct.

Foo also includes a legacy definition of its original version 1 specification
in which the data in the `bar` field is required to be a binary, and the current
definition of its version 2 specification updating the data in `bar` to be an integer.

The current version of Foo's `migrate/1` function performs the necessary upgrade of
the Foo schema when `new/1` is called by checking if the instance being created is
of the older "version: 1" type and automatically converts the data in the `:bar` field
from a binary to an integer.

```elixir
defmodule Foo do
  use Definition, schema: Foo.V2
  defstruct [:version, :bar, :baz]

  def on_new(foo) do
    new_baz =
      case foo.baz do
        nil -> nil
        x -> String.upcase(x)
      end

    %{foo | baz: new_baz}
  end

  def migrate(%__MODULE__{version: 1} = old) do
    struct(__MODULE__, %{version: 2, bar: String.to_integer(old.bar)})
  end

  defmodule V1 do
    use Definition.Schema

    def s do
      schema(%Foo{version: spec(fn v -> v == 1 end), bar: spec(is_binary())})
    end
  end

  defmodule V2 do
    use Definition.Schema

    def s do
      schema(%Foo{version: spec(fn v -> v == 2 end), bar: spec(is_integer())})
    end
  end
end

```

## Installation

```elixir
def deps do
  [
    {:definition, in_umbrella: true}
  ]
end
```
