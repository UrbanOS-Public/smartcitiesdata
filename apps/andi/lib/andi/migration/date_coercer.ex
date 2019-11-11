defmodule Andi.Migration.DateCoercer do
  def coerce_date(date) do
    IO.inspect(date, label: "what in tarnation")

    case DateTime.from_iso8601(date) do
      {:ok, parsed_date, offset} -> date
      _ -> fix_date(date)
    end
  end

  def fix_date(""), do: ""

  def fix_date(date) do
    {:ok, date} = Timex.parse(date, "%-m/%-d/%y", :strftime)

    DateTime.from_naive!(date, "Etc/UTC")
    |> DateTime.to_iso8601()
  end
end
