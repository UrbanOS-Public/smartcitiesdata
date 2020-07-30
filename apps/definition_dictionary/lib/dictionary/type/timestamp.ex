defmodule Dictionary.Type.Timestamp do
  @moduledoc """
  Timestamp type in ISO8601 format.

  Timestamp format must be supplied for conversion to ISO8601. `nil` values will
  be converted to empty strings regardless of specified string format. Empty
  string values are supported as well.

  See [Timex](https://hexdocs.pm/timex/Timex.Format.DateTime.Formatters.Strftime.html)
  for possible format field values.

  Timestamps will be converted to UTC timezone if `timezone` is supplied. If no
  `timezone` value is supplied, UTC is assumed.

  ## Init options

  * `format` - Format to parse string into `DateTime`.
  * `timezone` - Value's timezone. Defaults to UTC.
  """
  use Definition, schema: Dictionary.Type.Timestamp.V1
  use JsonSerde, alias: "dictionary_timestamp"

  @type t :: %__MODULE__{
          version: integer,
          name: String.t(),
          description: String.t(),
          format: String.t(),
          timezone: String.t()
        }

  defstruct version: 1,
            name: nil,
            description: "",
            format: "%FT%T.%f",
            timezone: "Etc/UTC"

  defimpl Dictionary.Type.Normalizer, for: __MODULE__ do
    @tokenizer Timex.Parse.DateTime.Tokenizers.Strftime
    @utc "Etc/UTC"

    def normalize(_, value) when value in [nil, ""] do
      Ok.ok("")
    end

    def normalize(%{format: format, timezone: timezone}, value) do
      with {:ok, date} <- Timex.parse(value, format, @tokenizer) do
        date
        |> attach_timezone(timezone)
        |> Ok.map(&to_utc/1)
        |> Ok.map(&NaiveDateTime.to_iso8601/1)
      end
    end

    defp attach_timezone(%NaiveDateTime{} = datetime, timezone) do
      DateTime.from_naive(datetime, timezone)
    end

    defp attach_timezone(datetime, _), do: Ok.ok(datetime)

    defp to_utc(%DateTime{} = datetime) do
      DateTime.shift_zone(datetime, @utc)
    end

    defp to_utc(datetime), do: Ok.ok(datetime)
  end
end

defmodule Dictionary.Type.Timestamp.V1 do
  @moduledoc false
  use Definition.Schema

  @impl true
  def s do
    schema(%Dictionary.Type.Timestamp{
      version: version(1),
      name: lowercase_string(),
      description: string(),
      format: required_string(),
      timezone: required_string()
    })
  end
end
