defmodule Dictionary.Type.String do
  @moduledoc """
  String type. Normalization will convert values to string via
  `String.Chars` protocol and return an error value if the value's type
  doesn't implement `String.Chars`.
  """
  use Definition, schema: Dictionary.Type.String.V1
  use JsonSerde, alias: "dictionary_string"

  @type t :: %__MODULE__{
          version: integer,
          name: String.t(),
          description: String.t()
        }

  defstruct version: 1,
            name: nil,
            description: ""

  defimpl Dictionary.Type.Normalizer, for: __MODULE__ do
    def normalize(_field, value) do
      case String.Chars.impl_for(value) do
        nil -> Ok.error(:invalid_string)
        _ -> value |> to_string |> String.trim() |> Ok.ok()
      end
    end
  end
end

defmodule Dictionary.Type.String.V1 do
  @moduledoc false
  use Definition.Schema

  @impl true
  def s do
    schema(%Dictionary.Type.String{
      version: version(1),
      name: lowercase_string(),
      description: string()
    })
  end
end
