defmodule Andi.Migration.ModifiedDateMigration do
  @moduledoc """
  For all existing dataset.business.modifiedDate, either parse to valid iso8601 or convert to empty string.
  """

  alias SmartCity.Dataset
  import SmartCity.Event, only: [dataset_update: 0]

  require Logger
  require Andi
  alias Andi.DatasetStore

  @instance Andi.instance_name()

  def do_migration() do
    DatasetStore.get_all_dataset!()
    |> Enum.each(&migrate_dataset/1)
  end

  defp migrate_dataset(%Dataset{} = dataset) do
    corrected_date = Andi.Migration.DateCoercer.coerce_date(dataset.business.modifiedDate)

    if dataset.business.modifiedDate != corrected_date do
      log_bad_date(dataset.id, dataset.business.modifiedDate, corrected_date)

      updated_dataset = update_modified_date(dataset, corrected_date)

      Brook.Event.send(@instance, dataset_update(), :andi, updated_dataset)
      DatasetStore.update(updated_dataset)
    end
  end

  defp migrate_dataset(invalid_dataset) do
    Logger.warn("Could not migrate invalid dataset #{inspect(invalid_dataset)}")
  end

  defp log_bad_date(id, old_date, "") when old_date != "" do
    Logger.warn("[#{id}] unable to parse business.modifiedDate '#{inspect(old_date)}' in modified_date_migration")
  end

  defp log_bad_date(_id, _old_date, _new_date), do: nil

  defp update_modified_date(dataset, corrected_date) do
    updated_business =
      dataset.business
      |> Map.from_struct()
      |> Map.put(:modifiedDate, corrected_date)

    {:ok, updated_dataset} =
      dataset
      |> Map.from_struct()
      |> Map.put(:technical, Map.from_struct(dataset.technical))
      |> Map.put(:business, updated_business)
      |> SmartCity.Dataset.new()

    updated_dataset
  end
end
