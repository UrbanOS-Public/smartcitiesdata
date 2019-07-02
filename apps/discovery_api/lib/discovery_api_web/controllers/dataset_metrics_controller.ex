defmodule DiscoveryApiWeb.DatasetMetricsController do
  use DiscoveryApiWeb, :controller
  require Logger
  alias DiscoveryApi.Data.Persistence

  def get(conn, params) do
    metrics =
      params["dataset_id"]
      |> get_count_maps()

    json(conn, metrics)
  end

  defp get_count_maps(dataset_id) do
    case Persistence.get_keys("smart_registry:*:count:" <> dataset_id) do
      [] ->
        %{}

      all_keys ->
        friendly_keys = Enum.map(all_keys, fn x -> Enum.at(String.split(x, ":"), 1) end)
        all_values = Persistence.get_many(all_keys)

        Enum.into(0..(Enum.count(friendly_keys) - 1), %{}, fn x ->
          {Enum.at(friendly_keys, x), Enum.at(all_values, x)}
        end)
    end
  end
end
