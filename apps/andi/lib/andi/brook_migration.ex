defmodule Andi.BrookMigration do
  @moduledoc """
    This module can be used to repost datasets in smart city registry to
    the brook data event stream as dataset_update events.

    All events will be posted automatically with an invocation of migrate_to_brook
  """
  import SmartCity.Event, only: [dataset_update: 0]

  def migrate_to_brook do
    SmartCity.Registry.Dataset.get_all!()
    |> Enum.map(&convert_dataset_to_event/1)
    |> Enum.each(&migrate_dataset_to_brook/1)
  end

  defp convert_dataset_to_event(dataset) do
    {:ok, dataset_event} =
      SmartCity.Dataset.new(
        Map.from_struct(%{
          dataset
          | id: dataset.id,
            _metadata: Map.from_struct(dataset._metadata),
            business: Map.from_struct(dataset.business),
            technical: Map.from_struct(dataset.technical)
        })
      )

    dataset_event
  end

  defp migrate_dataset_to_brook(dataset_event) do
    Brook.Event.send(:andi, dataset_update(), :andi, dataset_event)
  end
end
