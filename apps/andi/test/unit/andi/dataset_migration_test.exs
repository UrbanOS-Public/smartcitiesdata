defmodule Andi.DatasetMigrationTest do
  use ExUnit.Case
  use Placebo

  alias Andi.Migrations

  @instance Andi.instance_name()

  test "send the downcase migration event if it has not succeeded yet" do
    allow(Brook.get!(@instance, :migration, "downcase_migration"), return: nil)
    allow(Brook.Event.send(any(), any(), any(), any()), return: :ok)

    Migrations.migrate_downcase()

    assert_called Brook.Event.send(@instance, "migration:downcase_columns", :andi, %{})
  end

  test "Do not send the downcase migration event if it already succeeded" do
    allow(Brook.get!(@instance, any(), any()), return: true)
    allow(Brook.Event.send(any(), any(), any(), any()), return: :ok)

    Migrations.migrate_downcase()

    refute_called Brook.get_all_values!(@instance, :dataset)
    refute_called Brook.Event.send(@instance, any(), any(), any())
  end

  # test "do thing" do
  #   # get("datasets") -> [TDG.generate x2]

  #   # assert_called post(expected_datasets)
  # end
end
