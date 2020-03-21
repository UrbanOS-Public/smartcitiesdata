defmodule Reaper.Collections.BaseDataset do
  @moduledoc false

  defmacro __using__(opts) do
    instance = Keyword.fetch!(opts, :instance)
    collection = Keyword.fetch!(opts, :collection)

    quote do
      def update_dataset(%SmartCity.Dataset{} = dataset) do
        Brook.ViewState.merge(unquote(collection), dataset.id, %{
          "dataset" => dataset
        })
      end

      def update_last_fetched_timestamp(id, fetched_time \\ DateTime.utc_now()) do
        Brook.ViewState.merge(unquote(collection), id, %{"last_fetched_timestamp" => fetched_time})
      end

      def update_started_timestamp(id, started_time \\ DateTime.utc_now()) do
        Brook.ViewState.merge(unquote(collection), id, %{"started_timestamp" => started_time})
      end

      def disable_dataset(dataset_id) do
        Brook.ViewState.merge(unquote(collection), dataset_id, %{
          "enabled" => false
        })
      end

      def delete_dataset(dataset_id) do
        Brook.ViewState.delete(unquote(collection), dataset_id)
      end

      def is_enabled?(dataset_id) do
        Brook.get!(unquote(instance), unquote(collection), dataset_id)
        |> is_dataset_entry_enabled?()
      end

      defp is_dataset_entry_enabled?(nil = _missing_dataset_entry), do: false

      defp is_dataset_entry_enabled?(%{"dataset" => _} = dataset_entry_we_have_seen_an_update_for),
        do: Map.get(dataset_entry_we_have_seen_an_update_for, "enabled", true)

      defp is_dataset_entry_enabled?(incomplete_dataset_entry), do: Map.get(incomplete_dataset_entry, "enabled", false)

      def get_dataset!(id) do
        case Brook.get!(unquote(instance), unquote(collection), id) do
          nil -> nil
          value -> value["dataset"]
        end
      end

      def get_started_timestamp!(dataset_id) do
        case Brook.get!(unquote(instance), unquote(collection), dataset_id) do
          nil -> nil
          value -> Map.get(value, "started_timestamp", nil)
        end
      end

      def get_last_fetched_timestamp!(id) do
        case Brook.get!(unquote(instance), unquote(collection), id) do
          nil -> nil
          value -> Map.get(value, "last_fetched_timestamp", nil)
        end
      end

      def get_all_non_completed!() do
        Brook.get_all_values!(unquote(instance), unquote(collection))
        |> Enum.filter(&should_start/1)
        |> Enum.map(&Map.get(&1, "dataset"))
      end

      defp should_start(%{"started_timestamp" => start_time, "last_fetched_timestamp" => end_time} = dataset_entry)
           when not is_nil(start_time) and not is_nil(end_time) do
        is_dataset_entry_enabled?(dataset_entry) && DateTime.compare(start_time, end_time) == :gt
      end

      defp should_start(%{"started_timestamp" => start_time} = dataset_entry) when not is_nil(start_time) do
        is_dataset_entry_enabled?(dataset_entry)
      end

      defp should_start(_), do: false
    end
  end
end
