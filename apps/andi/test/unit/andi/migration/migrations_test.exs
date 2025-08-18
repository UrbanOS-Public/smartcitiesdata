defmodule Andi.Migration.MigrationsTest do
  use ExUnit.Case

  require Andi

  @moduletag timeout: 5000
  @instance_name Andi.instance_name()

  @modified_date_completed_flag "modified_date_migration_completed"
  @modified_date_event "migration:modified_date:start"

  alias Andi.Migration.Migrations

  test "send the modified date migration event if it has not succeeded yet" do
    # Set up :meck for modules that will be mocked
    modules_to_mock = [Brook, Brook.Event]
    
    # Clean up any existing mocks first
    Enum.each(modules_to_mock, fn module ->
      try do
        :meck.unload(module)
      catch
        _, _ -> :ok
      end
    end)
    
    # Set up fresh mocks
    Enum.each(modules_to_mock, fn module ->
      try do
        :meck.new(module, [:passthrough])
      catch
        :error, {:already_started, _} -> :ok
      end
    end)
    
    # Set up expectations for this test
    instance_name = @instance_name
    :meck.expect(Brook, :get!, fn ^instance_name, :migration, "modified_date_migration_completed" -> nil end)
    :meck.expect(Brook.Event, :send, fn _, _, _, _ -> :ok end)
    
    Migrations.migrate_once(@modified_date_completed_flag, @modified_date_event)

    # Verify calls were made with expected arguments
    assert :meck.called(Brook.Event, :send, [@instance_name, @modified_date_event, :andi, %{}])
    
    # Clean up
    Enum.each(modules_to_mock, fn module ->
      try do
        :meck.unload(module)
      catch
        _, _ -> :ok
      end
    end)
  end

  test "Do not send the modified date migration event if it already succeeded" do
    # Set up :meck for modules that will be mocked
    modules_to_mock = [Brook, Brook.Event]
    
    # Clean up any existing mocks first
    Enum.each(modules_to_mock, fn module ->
      try do
        :meck.unload(module)
      catch
        _, _ -> :ok
      end
    end)
    
    # Set up fresh mocks
    Enum.each(modules_to_mock, fn module ->
      try do
        :meck.new(module, [:passthrough])
      catch
        :error, {:already_started, _} -> :ok
      end
    end)
    
    # Set up expectations for this test
    instance_name = @instance_name
    :meck.expect(Brook, :get!, fn ^instance_name, _, _ -> true end)
    :meck.expect(Brook.Event, :send, fn _, _, _, _ -> :ok end)
    
    Migrations.migrate_once(@modified_date_completed_flag, @modified_date_event)

    # Verify calls were NOT made (migration already completed)
    refute :meck.called(Brook, :get_all_values!, [@instance_name, :dataset])
    refute :meck.called(Brook.Event, :send, [@instance_name, :_, :_, :_])
    
    # Clean up
    Enum.each(modules_to_mock, fn module ->
      try do
        :meck.unload(module)
      catch
        _, _ -> :ok
      end
    end)
  end
end
