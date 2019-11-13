defmodule Andi.Migration.DateCoercer do
  @moduledoc """
  Either parse to valid iso8601 or convert to empty string.
  """
  def coerce_date(date) do
    case DateTime.from_iso8601(date) do
      {:ok, _parsed_date, _offset} -> date
      _ -> fix_date(date)
    end
  end

  def fix_date(""), do: ""

  def fix_date(date) do
    format_strings = [
      "%-m/%-d/%y",
      "%-m/%-d/%Y",
      "%-m-%-d-%y",
      "%-m-%-d-%Y",
      "%B %-d, %Y",
      "%Y-%m-%d",
      "%b %-d, %Y"
    ]

    Enum.reduce_while(format_strings, "", fn format, _acc -> parse_with_format(format, date) end)
  end

  defp parse_with_format(format, date) do
    case Timex.parse(date, format, :strftime) do
      {:ok, parsed_date} ->
        {:halt,
         parsed_date
         |> DateTime.from_naive!("Etc/UTC")
         |> DateTime.to_iso8601()}

      _ ->
        {:cont, ""}
    end
  end
end
