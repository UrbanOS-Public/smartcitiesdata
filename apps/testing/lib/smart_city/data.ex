defmodule Testing.SmartCity.Data do
  @moduledoc """
  Testing utilities for working with SmartCity.Data messages
  """
  def fetch_data_messages(topic, endpoints) do
    Testing.Kafka.fetch_messages(topic, endpoints)
    |> Enum.map(fn m ->
      {:ok, d} = apply(SmartCity.Data, :new, [m])
      d
    end)
  end
end
