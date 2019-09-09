defmodule Reaper.Collections.BaseDataset do
  @moduledoc false

  defmacro __using__(opts) do
    collection = Keyword.fetch!(opts, :collection)

    quote do
      def update_dataset(%SmartCity.Dataset{} = dataset) do
        Brook.ViewState.merge(unquote(collection), dataset.id, %{
          dataset: dataset,
          started_timestamp: DateTime.utc_now()
        })
      end

      def update_last_fetched_timestamp(id) do
        Brook.ViewState.merge(unquote(collection), id, %{last_fetched_timestamp: DateTime.utc_now()})
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
      end

      defp should_start(%{started_timestamp: start_time, last_fetched_timestamp: end_time}) do
        DateTime.compare(start_time, end_time) == :gt
      end

      defp should_start(_), do: true
    end
  end
end
