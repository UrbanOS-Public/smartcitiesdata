defmodule Andi.Migration.ModifiedDateMigrationTest do
  use ExUnit.Case

  import SmartCity.Event, only: [dataset_update: 0]
  import ExUnit.CaptureLog

  alias SmartCity.TestDataGenerator, as: TDG

  require Andi

  @moduletag timeout: 5000
  @instance_name Andi.instance_name()
  
  setup do
    # Set up :meck for modules that will be mocked across tests
    modules_to_mock = [Brook, Brook.Event, Brook.ViewState]
    
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
    
    on_exit(fn ->
      Enum.each(modules_to_mock, fn module ->
        try do
          :meck.unload(module)
        catch
          _, _ -> :ok
        end
      end)
    end)
    
    :ok
  end

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

    # Set up expectations for this test
    :meck.expect(Brook, :get_all_values!, fn :andi, :dataset -> [dataset] end)
    :meck.expect(Brook.Event, :send, fn _, _, _, _ -> :ok end)
    :meck.expect(Brook.ViewState, :merge, fn :dataset, _, _ -> :ok end)
    
    Andi.Migration.ModifiedDateMigration.do_migration()

    # Verify calls were made with expected arguments
    assert :meck.called(Brook.ViewState, :merge, [:dataset, updated_dataset.id, updated_dataset])
    assert :meck.called(Brook.Event, :send, [@instance_name, dataset_update(), :andi, updated_dataset])
  end

  test "does not send dataset update event if there was no change" do
    dataset =
      TDG.create_dataset(
        id: "abc123",
        business: %{modifiedDate: "2017-08-08T13:03:48.000Z"}
      )

    # Set up expectations for this test
    :meck.expect(Brook, :get_all_values!, fn :andi, :dataset -> [dataset] end)
    :meck.expect(Brook.Event, :send, fn _, _, _, _ -> :ok end)
    :meck.expect(Brook.ViewState, :merge, fn :dataset, _, _ -> :ok end)
    
    Andi.Migration.ModifiedDateMigration.do_migration()

    # Verify no calls were made (dataset already has correct format)
    refute :meck.called(Brook.Event, :send, [@instance_name, dataset_update(), :andi, dataset])
    refute :meck.called(Brook.ViewState, :merge, [:dataset, dataset.id, :_])
  end

  @tag capture_log: true
  test "Logs dates that can not be parsed" do
    dataset =
      TDG.create_dataset(
        id: "abc1234",
        business: %{modifiedDate: "not an actual date"}
      )

    # Set up expectations for this test
    :meck.expect(Brook, :get_all_values!, fn :andi, :dataset -> [dataset] end)
    :meck.expect(Brook.Event, :send, fn _, _, _, _ -> :ok end)
    :meck.expect(Brook.ViewState, :merge, fn :dataset, _, _ -> :ok end)
    
    expected = "[abc1234] unable to parse business.modifiedDate '\"not an actual date\"' in modified_date_migration"

    captured = capture_log([level: :warn], fn -> Andi.Migration.ModifiedDateMigration.do_migration() end)

    assert String.contains?(captured, expected)
  end
end
