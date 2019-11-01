defmodule Andi.Migrations do
  @instance Andi.instance_name()
  def migrate_downcase do
    if is_nil(Brook.get!(@instance, :migration, "downcase_migration")) do
      Brook.Event.send(@instance, "migration:downcase_columns", :andi, %{})
    end
  end
end
