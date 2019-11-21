defmodule Andi.Migration.MigrationsTest do
  use ExUnit.Case
  use Placebo

  require Andi

  @instance Andi.instance_name()

  @modified_date_completed_flag "modified_date_migration_completed"
  @modified_date_event "migration:modified_date:start"

  alias Andi.Migration.Migrations

  test "send the modified date migration event if it has not succeeded yet" do
    allow(Brook.get!(@instance, :migration, "modified_date_migration_completed"), return: nil)
    allow(Brook.Event.send(any(), any(), any(), any()), return: :ok)

    Migrations.migrate_once(@modified_date_completed_flag, @modified_date_event)

    assert_called Brook.Event.send(@instance, @modified_date_event, :andi, %{})
  end

  test "Do not send the modified date migration event if it already succeeded" do
    allow(Brook.get!(@instance, any(), any()), return: true)
    allow(Brook.Event.send(any(), any(), any(), any()), return: :ok)

    Migrations.migrate_once(@modified_date_completed_flag, @modified_date_event)

    refute_called Brook.get_all_values!(@instance, :dataset)
    refute_called Brook.Event.send(@instance, any(), any(), any())
  end
end
