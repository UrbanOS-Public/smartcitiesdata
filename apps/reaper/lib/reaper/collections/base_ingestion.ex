defmodule Reaper.Collections.BaseIngestion do
  @moduledoc false

  defmacro __using__(opts) do
    instance = Keyword.fetch!(opts, :instance)
    collection = Keyword.fetch!(opts, :collection)

    quote do
      def update_ingestion(%SmartCity.Ingestion{} = ingestion) do
        Brook.ViewState.merge(unquote(collection), ingestion.id, %{
          "ingestion" => ingestion
        })
      end

      def update_last_fetched_timestamp(id, fetched_time \\ DateTime.utc_now()) do
        Brook.ViewState.merge(unquote(collection), id, %{"last_fetched_timestamp" => fetched_time})
      end

      def update_started_timestamp(id, started_time \\ DateTime.utc_now()) do
        Brook.ViewState.merge(unquote(collection), id, %{"started_timestamp" => started_time})
      end

      def delete_ingestion(ingestion_id) do
        Brook.ViewState.delete(unquote(collection), ingestion_id)
      end

      def disable_ingestion(ingestion_id) do
        Brook.ViewState.merge(unquote(collection), ingestion_id, %{
          "enabled" => false
        })
      end

      def is_enabled?(ingestion_id) do
        Brook.get!(unquote(instance), unquote(collection), ingestion_id)
        |> is_ingestion_entry_enabled?()
      end

      defp is_ingestion_entry_enabled?(nil = _missing_ingestion_entry), do: false

      defp is_ingestion_entry_enabled?(%{"ingestion" => _} = ingestion_entry_we_have_seen_an_update_for),
        do: Map.get(ingestion_entry_we_have_seen_an_update_for, "enabled", true)

      defp is_ingestion_entry_enabled?(incomplete_ingestion_entry),
        do: Map.get(incomplete_ingestion_entry, "enabled", false)

      def get_ingestion!(id) do
        case Brook.get!(unquote(instance), unquote(collection), id) do
          nil -> nil
          value -> value["ingestion"]
        end
      end

      def get_started_timestamp!(ingestion_id) do
        case Brook.get!(unquote(instance), unquote(collection), ingestion_id) do
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
        |> Enum.map(&Map.get(&1, "ingestion"))
      end

      defp should_start(%{"started_timestamp" => start_time, "last_fetched_timestamp" => end_time} = ingestion_entry)
           when not is_nil(start_time) and not is_nil(end_time) do
        is_ingestion_entry_enabled?(ingestion_entry) && DateTime.compare(start_time, end_time) == :gt
      end

      defp should_start(%{"started_timestamp" => start_time} = ingestion_entry) when not is_nil(start_time) do
        is_ingestion_entry_enabled?(ingestion_entry)
      end

      defp should_start(_), do: false
    end
  end
end
