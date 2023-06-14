defmodule Andi.Migration.ModifiedDateMigrationTest do
  use ExUnit.Case

  import SmartCity.Event, only: [dataset_update: 0]
  import ExUnit.CaptureLog
  import Mock

  alias SmartCity.TestDataGenerator, as: TDG

  require Andi

  @instance_name Andi.instance_name()

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

    with_mocks([
      {Brook, [], [get_all_values!: fn(:andi, :dataset) -> [dataset] end]},
      {Brook.Event, [], [send: fn(_, _, _, _) -> :ok end]},
      {Brook.ViewState, [], [merge: fn(:dataset, _, _) -> :ok end]}
    ]) do
      Andi.Migration.ModifiedDateMigration.do_migration()

      assert_called Brook.ViewState.merge(:dataset, updated_dataset.id, updated_dataset)
      assert_called Brook.Event.send(@instance_name, dataset_update(), :andi, updated_dataset)
    end
  end

  test "does not send dataset update event if there was no change" do
    dataset =
      TDG.create_dataset(
        id: "abc123",
        business: %{modifiedDate: "2017-08-08T13:03:48.000Z"}
      )

    with_mocks([
      {Brook, [], [get_all_values!: fn(:andi, :dataset) -> [dataset] end]},
      {Brook.Event, [], [send: fn(_, _, _, _) -> :ok end]},
      {Brook.ViewState, [], [merge: fn(:dataset, _, _) -> :ok end]}
    ]) do
      Andi.Migration.ModifiedDateMigration.do_migration()

      assert_not_called Brook.Event.send(@instance_name, dataset_update(), :andi, dataset)
      assert_not_called Brook.ViewState.merge(:dataset, dataset.id, :_)
    end
  end

  @moduletag capture_log: true
  test "Logs dates that can not be parsed" do
    dataset =
      TDG.create_dataset(
        id: "abc1234",
        business: %{modifiedDate: "not an actual date"}
      )

    with_mocks([
      {Brook, [], [get_all_values!: fn(:andi, :dataset) -> [dataset] end]},
      {Brook.Event, [], [send: fn(_, _, _, _) -> :ok end]},
      {Brook.ViewState, [], [merge: fn(:dataset, _, _) -> :ok end]}
    ]) do
      expected = "[abc1234] unable to parse business.modifiedDate '\"not an actual date\"' in modified_date_migration"

      captured = capture_log([level: :warn], fn -> Andi.Migration.ModifiedDateMigration.do_migration() end)

      assert String.contains?(captured, expected)
    end
  end
end
