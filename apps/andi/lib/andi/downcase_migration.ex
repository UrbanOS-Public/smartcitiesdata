defmodule Andi.DowncaseMigration do
  alias Andi.SchemaDowncaser
  import SmartCity.Event, only: [dataset_update: 0]

  @instance Andi.instance_name()

  def do_migration() do
    Brook.get_all_values!(@instance, :dataset)
    |> Enum.each(&migrate_dataset/1)
  end

  defp migrate_dataset(dataset) do
    downcase_schema = SchemaDowncaser.downcase_schema(dataset.technical.schema)
    downcase_technical =
      dataset.technical
      |> Map.from_struct()
      |> Map.put(:schema, downcase_schema)

    dataset_map =
      dataset
      |> Map.from_struct()

    {:ok, downcased_dataset} =
      dataset_map
      |> Map.put(:technical, downcase_technical)
      |> Map.put(:business, Map.from_struct(dataset.business))
      |> SmartCity.Dataset.new()

    Brook.Event.send(@instance, dataset_update(), :andi, downcased_dataset)
    Brook.ViewState.merge(:dataset, downcased_dataset.id, downcased_dataset)
  end
end
