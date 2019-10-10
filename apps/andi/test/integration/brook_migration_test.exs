defmodule Andi.BrookMigrationTest do
  use ExUnit.Case
  use Divo

  import Andi
  import SmartCity.Event, only: [dataset_update: 0]

  use Placebo

  setup_all do
    :ok
  end

  describe "migrate_to_brook/0" do
    test "migrates datasets to brook events" do
      allow(Brook.Event.send(instance_name(), any(), :andi, any()), return: :does_not_matter)

      dataset1 = %SmartCity.Registry.Dataset{
        id: "dataset1",
        _metadata: %SmartCity.Registry.Dataset.Metadata{},
        business: %SmartCity.Registry.Dataset.Business{},
        technical: %SmartCity.Registry.Dataset.Technical{}
      }

      {:ok, dataset_event1} =
        SmartCity.Dataset.new(
          Map.from_struct(%{
            dataset1
            | _metadata: Map.from_struct(dataset1._metadata),
              business: Map.from_struct(dataset1.business),
              technical: Map.from_struct(dataset1.technical)
          })
        )

      dataset2 = %SmartCity.Registry.Dataset{
        id: "dataset2",
        _metadata: %SmartCity.Registry.Dataset.Metadata{},
        business: %SmartCity.Registry.Dataset.Business{},
        technical: %SmartCity.Registry.Dataset.Technical{}
      }

      {:ok, dataset_event2} =
        SmartCity.Dataset.new(
          Map.from_struct(%{
            dataset2
            | _metadata: Map.from_struct(dataset2._metadata),
              business: Map.from_struct(dataset2.business),
              technical: Map.from_struct(dataset2.technical)
          })
        )

      SmartCity.Registry.Dataset.write(dataset1)
      SmartCity.Registry.Dataset.write(dataset2)

      Andi.BrookMigration.migrate_to_brook()

      expect(Brook.Event.send(instance_name(), dataset_update(), :andi, dataset_event1))
      expect(Brook.Event.send(instance_name(), dataset_update(), :andi, dataset_event2))
    end
  end
end
