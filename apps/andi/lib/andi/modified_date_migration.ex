defmodule Andi.ModifiedDateMigration do
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
    corrected_date = fix_modified_date(dataset.business.modifiedDate)

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

    # Brook.Event.send(@instance, dataset_update(), :andi, updated_dataset)
    Brook.ViewState.merge(:dataset, updated_dataset.id, updated_dataset)
  end

  defp migrate_dataset(invalid_dataset) do
    Logger.warn("Could not migrate invalid dataset #{inspect(invalid_dataset)}")
  end

  defp fix_modified_date("2017-08-08T13:03:48.000Z"), do: "2017-08-08T13:03:48.000Z"
  defp fix_modified_date("Jan 13, 2018"), do: "2018-01-13T00:00:00.000Z"

  defp fix_modified_date(date) do
    IO.inspect(date, label: "got weird date")
    "2019-01-01T00:00:00.000Z"
  end
end
