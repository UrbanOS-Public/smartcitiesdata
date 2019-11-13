defmodule Andi.Migration.ModifiedDateMigrationTest do
  use ExUnit.Case
  use Placebo
  import SmartCity.Event, only: [dataset_update: 0]
  import ExUnit.CaptureLog
  alias SmartCity.TestDataGenerator, as: TDG
  require Andi

  @instance Andi.instance_name()

  test "Sends dataset update event when dataset has been migrated" do
    dataset =
      TDG.create_dataset(
        id: "abc123",
        business: %{modifiedDate: "9/14/09"}
      )

    updated_business =
      dataset.business
      |> Map.from_struct()
      |> Map.put(:modifiedDate, "2009-09-14T00:00:00Z")

    {:ok, updated_dataset} =
      dataset
      |> Map.from_struct()
      |> Map.put(:technical, Map.from_struct(dataset.technical))
      |> Map.put(:business, updated_business)
      |> SmartCity.Dataset.new()

    allow(Brook.get_all_values!(@instance, :dataset), return: [dataset])
    allow(Brook.Event.send(any(), any(), any(), any()), return: :ok)
    allow(Brook.ViewState.merge(:dataset, any(), any()), return: :ok)

    Andi.Migration.ModifiedDateMigration.do_migration()

    assert_called Brook.ViewState.merge(:dataset, updated_dataset.id, updated_dataset)
    assert_called Brook.Event.send(@instance, dataset_update(), :andi, updated_dataset)
  end

  test "does not send dataset update event if there was no change" do
    dataset =
      TDG.create_dataset(
        id: "abc123",
        business: %{modifiedDate: "2017-08-08T13:03:48.000Z"}
      )

    allow(Brook.get_all_values!(@instance, :dataset), return: [dataset])
    allow(Brook.Event.send(any(), any(), any(), any()), return: :ok)
    allow(Brook.ViewState.merge(:dataset, any(), any()), return: :ok)

    Andi.Migration.ModifiedDateMigration.do_migration()

    refute_called Brook.Event.send(@instance, dataset_update(), :andi, dataset)
    refute_called Brook.ViewState.merge(:dataset, dataset.id, any())
  end

  @moduletag capture_log: true
  test "Logs dates that can not be parsed" do
    dataset =
      TDG.create_dataset(
        id: "abc1234",
        business: %{modifiedDate: "not an actual date"}
      )

    allow(Brook.get_all_values!(@instance, :dataset), return: [dataset])
    allow(Brook.Event.send(any(), any(), any(), any()), return: :ok)
    allow(Brook.ViewState.merge(:dataset, any(), any()), return: :ok)

    expected = "[abc1234] unable to parse business.modifiedDate '\"not an actual date\"' in modified_date_migration"

    captured = capture_log([level: :warn], fn -> Andi.Migration.ModifiedDateMigration.do_migration() end)

    assert String.contains?(captured, expected)
  end
end
