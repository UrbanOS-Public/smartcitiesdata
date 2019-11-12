defmodule Andi.Migration.ModifiedDateMigrationTest do
  use ExUnit.Case
  use Placebo
  import SmartCity.Event, only: [dataset_update: 0]
  import ExUnit.CaptureLog
  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.Migration.Migrations
  require Andi

  @instance Andi.instance_name()

  test "Sends dataset update event when dataset has been migrated" do
    dataset =
      TDG.create_dataset(
        id: "abc123",
        business: %{modifiedDate: "2017-08-08T13:03:48.000Z"}
      )

    allow(Brook.get_all_values!(@instance, :dataset), return: [dataset])
    allow(Brook.Event.send(any(), any(), any(), any()), return: :ok)
    allow(Brook.ViewState.merge(:dataset, any(), any()), return: :ok)

    Andi.Migration.ModifiedDateMigration.do_migration()

    assert_called Brook.Event.send(@instance, dataset_update(), :andi, dataset)
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
