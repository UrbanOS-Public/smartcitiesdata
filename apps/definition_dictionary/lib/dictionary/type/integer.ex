defmodule Dictionary.Type.Integer do
  @moduledoc """
  Integer type supporting `nil` values.

  During normalization, string values will be converted to integers. Empty
  strings will be converted to `nil`.
  """
  use Definition, schema: Dictionary.Type.Integer.V1
  use JsonSerde, alias: "dictionary_integer"

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

    def normalize(_field, value) when is_integer(value), do: Ok.ok(value)

    def normalize(_field, value) do
      case Integer.parse(value) do
        {parsed_value, _} -> Ok.ok(parsed_value)
        :error -> Ok.error(:invalid_integer)
      end
    end
  end
end

defmodule Dictionary.Type.Integer.V1 do
  @moduledoc false
  use Definition.Schema

  @impl true
  def s do
    schema(%Dictionary.Type.Integer{
      version: version(1),
      name: lowercase_string(),
      description: string()
    })
  end
end
