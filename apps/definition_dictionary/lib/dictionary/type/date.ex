defmodule Dictionary.Type.Date do
  @moduledoc """
  Date type in IS08601 format.

  Date format must be supplied for conversion to ISO8601. `nil` values will
  be converted to empty strings regardless of specified string format. Empty
  string values are supported as well.

  See [Timex](https://hexdocs.pm/timex/Timex.Format.DateTime.Formatters.Strftime.html)
  for possible format field values.

  ## Init options

  * `format` - Format to parse string into `Date`.
  """
  use Definition, schema: Dictionary.Type.Date.V1
  use JsonSerde, alias: "dictionary_date"

  @type t :: %__MODULE__{
          version: integer,
          name: String.t(),
          description: String.t(),
          format: String.t()
        }

  defstruct version: 1,
            name: nil,
            description: "",
            format: nil

  defimpl Dictionary.Type.Normalizer, for: __MODULE__ do
    @tokenizer Timex.Parse.DateTime.Tokenizers.Strftime

    def normalize(_field, value) when value in [nil, ""] do
      Ok.ok("")
    end

    def normalize(%{format: format}, value) do
      with {:ok, date} <- Timex.parse(value, format, @tokenizer) do
        date
        |> Date.to_iso8601()
        |> Ok.ok()
      end
    end
  end
end

defmodule Dictionary.Type.Date.V1 do
  @moduledoc false
  use Definition.Schema

  @impl true
  def s do
    schema(%Dictionary.Type.Date{
      version: version(1),
      name: lowercase_string(),
      description: string(),
      format: required_string()
    })
  end
end
