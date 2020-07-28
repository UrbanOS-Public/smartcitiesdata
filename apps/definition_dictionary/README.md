# DefinitionDictionary

Definition Dictionary defines the basic data types
accepted by Hindsight and provides the protocol for
accepting message payloads and validating their
contents against the schema provided for a dataset.

The primary Dictionary module accepts dataset schemas
and determines the correct type to assert each component
of the message payload must conform to.

When passed through the `normalize/2` function, the
`Dictionary.Type.Normalizer` protocol is invoked for that
particular message field and it's conformed to the
expected type or else an error message is generated.

## Usage

```elixir
  dictionary = [
    %Dictionary.Type.String{name: "name"},
    %Dictionary.Type.Integer{name: "age"}
  ]

  payload = %{
    "name" => :brian,
    "age" => "21"
  }

  {:ok, %{"name" => "brian", "age" => 21} = Dictionary.normalize(dictionary, payload)
```

## Installation

```elixir
def deps do
  [
    {:definition_dictionary, in_umbrella: true}
  ]
end
```
