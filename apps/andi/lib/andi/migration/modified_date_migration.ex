defmodule Andi.Migration.ModifiedDateMigration do
  @moduledoc """
  For all existing dataset.business.modifiedDate, either parse to valid iso8601 or convert to empty string.
  """

  alias SmartCity.Dataset
  import SmartCity.Event, only: [dataset_update: 0]

  require Logger
  require Andi
  @instance Andi.instance_name()

  def do_migration() do
    Brook.get_all_values!(@instance, :dataset)
    |> Enum.each(&migrate_dataset/1)
  end

  defp migrate_dataset(%Dataset{} = dataset) do
    corrected_date = Andi.Migration.DateCoercer.coerce_date(dataset.business.modifiedDate)

    log_bad_date(dataset.id, dataset.business.modifiedDate, corrected_date)

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

    Brook.Event.send(@instance, dataset_update(), :andi, updated_dataset)
    Brook.ViewState.merge(:dataset, updated_dataset.id, updated_dataset)
  end

  defp migrate_dataset(invalid_dataset) do
    Logger.warn("Could not migrate invalid dataset #{inspect(invalid_dataset)}")
  end

  defp log_bad_date(id, old_date, new_date) do
    if new_date == "" && old_date != "" do
      Logger.warn("[#{id}] unable to parse business.modifiedDate '#{inspect(old_date)}' in modified_date_migration")
    end
  end
end
