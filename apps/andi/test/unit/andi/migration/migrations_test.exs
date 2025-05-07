defmodule Andi.Migration.MigrationsTest do
  use ExUnit.Case

  import Mock

  require Andi

  @instance_name Andi.instance_name()

  @modified_date_completed_flag "modified_date_migration_completed"
  @modified_date_event "migration:modified_date:start"

  alias Andi.Migration.Migrations

  test "send the modified date migration event if it has not succeeded yet" do
    with_mocks([
      {Brook, [], [get!: fn @instance_name, :migration, "modified_date_migration_completed" -> nil end]},
      {Brook.Event, [], [send: fn _, _, _, _ -> :ok end]}
    ]) do
      Migrations.migrate_once(@modified_date_completed_flag, @modified_date_event)

      assert_called Brook.Event.send(@instance_name, @modified_date_event, :andi, %{})
    end
  end

  test "Do not send the modified date migration event if it already succeeded" do
    with_mocks([
      {Brook, [], [get!: fn @instance_name, _, _ -> true end]},
      {Brook.Event, [], [send: fn _, _, _, _ -> :ok end]}
    ]) do
      Migrations.migrate_once(@modified_date_completed_flag, @modified_date_event)

      assert_not_called(Brook.get_all_values!(@instance_name, :dataset))
      assert_not_called(Brook.Event.send(@instance_name, :_, :_, :_))
    end
  end
end
