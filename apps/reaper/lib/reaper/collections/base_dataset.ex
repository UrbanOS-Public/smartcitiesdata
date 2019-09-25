defmodule Reaper.Collections.BaseDataset do
  @moduledoc false

  defmacro __using__(opts) do
    collection = Keyword.fetch!(opts, :collection)

    quote do
      def update_dataset(%SmartCity.Dataset{} = dataset, start_time \\ DateTime.utc_now()) do
        Brook.ViewState.merge(unquote(collection), dataset.id, %{
          dataset: dataset,
          started_timestamp: start_time,
          enabled: true
        })
      end

      def update_last_fetched_timestamp(id, fetched_time \\ DateTime.utc_now()) do
        Brook.ViewState.merge(unquote(collection), id, %{last_fetched_timestamp: fetched_time})
      end

      def disable_dataset(dataset_id) do
        Brook.ViewState.merge(unquote(collection), dataset_id, %{
          enabled: false
        })
      end

      def is_enabled?(dataset_id) do
        case Brook.get!(unquote(collection), dataset_id) do
          nil -> false
          value -> value.enabled
        end
      end

      def get_dataset!(id) do
        case Brook.get!(unquote(collection), id) do
          nil -> nil
          value -> value.dataset
        end
      end

      def get_last_fetched_timestamp!(id) do
        case Brook.get!(unquote(collection), id) do
          nil -> nil
          value -> Map.get(value, :last_fetched_timestamp, nil)
        end
      end

      def get_all_non_completed!() do
        Brook.get_all_values!(unquote(collection))
        |> Enum.filter(&should_start/1)
        |> Enum.map(&Map.get(&1, :dataset))
      end

      defp should_start(%{enabled: true, started_timestamp: start_time, last_fetched_timestamp: end_time})
           when not is_nil(start_time) and not is_nil(end_time) do
        DateTime.compare(start_time, end_time) == :gt
      end

      defp should_start(%{enabled: true, started_timestamp: start_time}) when not is_nil(start_time), do: true
      defp should_start(_), do: false
    end
  end
end
