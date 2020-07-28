defmodule Dictionary.Type.Boolean do
  @moduledoc """
  Boolean type supporting `nil` values.

  During normalization, strings of `"true"` and `"false"` will be converted
  to proper boolean types. Empty strings will be converted to `nil`.
  """
  use Definition, schema: Dictionary.Type.Boolean.V1
  use JsonSerde, alias: "dictionary_boolean"

  @type t :: %__MODULE__{
          version: integer,
          name: String.t(),
          description: String.t()
        }

  defstruct version: 1,
            name: nil,
            description: ""

  defimpl Dictionary.Type.Normalizer, for: __MODULE__ do
    def normalize(_field, value) when value in [nil, ""], do: Ok.ok(nil)

    def normalize(_field, value) when is_boolean(value), do: Ok.ok(value)

    def normalize(_field, value) when value in ["true", "false"] do
      value |> String.to_atom() |> Ok.ok()
    end

    def normalize(_field, _value), do: Ok.error(:invalid_boolean)
  end
end

defmodule Dictionary.Type.Boolean.V1 do
  @moduledoc false
  use Definition.Schema

  @impl true
  def s do
    schema(%Dictionary.Type.Boolean{
      version: version(1),
      name: lowercase_string(),
      description: string()
    })
  end
end
