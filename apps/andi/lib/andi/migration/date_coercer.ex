defmodule Andi.Migration.DateCoercer do
  def fix_date("2017-08-08T13:03:48.000Z"), do: "2017-08-08T13:03:48.000Z"
  def fix_date("Jan 13, 2018"), do: "2018-01-13T00:00:00.000Z"

  def fix_date(date) do
    IO.inspect(date, label: "got weird date")
    "2019-01-01T00:00:00.000Z"
  end
end
