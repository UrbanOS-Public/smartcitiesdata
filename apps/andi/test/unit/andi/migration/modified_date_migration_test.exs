defmodule Andi.Migration.ModifiedDateMigrationTest do
  use ExUnit.Case
  use Placebo

  alias Andi.Migration.Migrations
  require Andi

  @instance Andi.instance_name()

  test "Sends dataset update event when dataset has been migrated" do
    allow(Brook.get!(@instance, any(), any()), return: true)
    allow(Brook.Event.send(any(), any(), any(), any()), return: :ok)

    Migrations.migrate_modified_dates()

    refute_called Brook.get_all_values!(@instance, :dataset)
    refute_called Brook.Event.send(@instance, any(), any(), any())
  end
end
