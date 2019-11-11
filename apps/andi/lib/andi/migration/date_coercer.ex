defmodule Andi.Migration.DateCoercer do
  def coerce_date(date) do
    case DateTime.from_iso8601(date) do
      {:ok, parsed_date, offset} -> date
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

    formatted_dates =
      Enum.map(format_strings, fn format ->
        Timex.parse(date, format, :strftime)
      end)

    ok_dates = for {:ok, date} <- formatted_dates, do: date

    if length(ok_dates) > 0 do
      ok_dates
      |> List.first()
      |> DateTime.from_naive!("Etc/UTC")
      |> DateTime.to_iso8601()
    else
      ""
    end
  end
end
