defmodule Andi.DatasetMigrationTest do
  use ExUnit.Case
  use Placebo

  alias Andi.Migrations
  require Andi

  @instance Andi.instance_name()

  test "send the modified date migration event if it has not succeeded yet" do
    allow(Brook.get!(@instance, :migration, "modified_date_migration"), return: nil)
    allow(Brook.Event.send(any(), any(), any(), any()), return: :ok)

    Migrations.migrate_modified_dates()

    assert_called Brook.Event.send(@instance, "migration:modified_dates", :andi, %{})
  end

  test "Do not send the modified date migration event if it already succeeded" do
    allow(Brook.get!(@instance, any(), any()), return: true)
    allow(Brook.Event.send(any(), any(), any(), any()), return: :ok)

    Migrations.migrate_modified_dates()

    refute_called Brook.get_all_values!(@instance, :dataset)
    refute_called Brook.Event.send(@instance, any(), any(), any())
  end

  # test "do thing" do
  #   # get("datasets") -> [TDG.generate x2]

  #   # assert_called post(expected_datasets)
  # end
end
