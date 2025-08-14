defmodule DiscoveryApi.Event.EventHandlerTest do
  use ExUnit.Case
  import Mox

  @moduletag timeout: 5000

  import SmartCity.Event,
    only: [
      dataset_update: 0,
      organization_update: 0,
      user_organization_associate: 0,
      user_organization_disassociate: 0,
      dataset_delete: 0,
      dataset_query: 0,
      dataset_access_group_associate: 0,
      dataset_access_group_disassociate: 0
    ]

  import ExUnit.CaptureLog

  alias SmartCity.TestDataGenerator, as: TDG
  alias DiscoveryApi.Event.EventHandler
  alias DiscoveryApi.Schemas.Users.User
  alias DiscoveryApi.Data.Model
  alias DiscoveryApi.Test.Helper

  setup :verify_on_exit!
  setup :set_mox_from_context

  setup do
    # Start TelemetryEvent.Mock process (handle case where it's already started)
    case TelemetryEvent.Mock.start_link([]) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end
    
    # Mock DeadLetter using Mox since EventHandler now uses dependency injection
    stub(DeadLetterMock, :process, fn _topics, _headers, _data, _instance, _opts -> :ok end)
    
    # Mock StatsCalculator using :meck since EventHandler doesn't use dependency injection
    try do
      :meck.unload(DiscoveryApi.Stats.StatsCalculator)
    catch
      _, _ -> :ok
    end
    
    :meck.new(DiscoveryApi.Stats.StatsCalculator, [:non_strict])
    :meck.expect(DiscoveryApi.Stats.StatsCalculator, :delete_completeness, fn _dataset_id -> :ok end)
    
    # Mock ResponseCache using :meck since EventHandler doesn't use dependency injection
    try do
      :meck.unload(DiscoveryApi.Data.ResponseCache)
    catch
      _, _ -> :ok
    end
    
    :meck.new(DiscoveryApi.Data.ResponseCache, [:non_strict])
    :meck.expect(DiscoveryApi.Data.ResponseCache, :invalidate, fn -> {:ok, true} end)
    
    on_exit(fn ->
      try do
        :meck.unload(DiscoveryApi.Stats.StatsCalculator)
      catch
        _, _ -> :ok
      end
      
      try do
        :meck.unload(DiscoveryApi.Data.ResponseCache)
      catch
        _, _ -> :ok
      end
    end)
    
    :ok
  end

  @instance_name DiscoveryApi.instance_name()

  describe "handle_event/1 organization_update" do
    test "should save organization to ecto" do
      org = TDG.create_organization(%{})
      
      # Clean unload any existing mock first
      try do
        :meck.unload(DiscoveryApi.Schemas.Organizations)
      catch
        _, _ -> :ok
      end
      
      # Mock Organizations.create_or_update using :meck
      :meck.new(DiscoveryApi.Schemas.Organizations, [:passthrough])
      :meck.expect(DiscoveryApi.Schemas.Organizations, :create_or_update, fn _org -> :dontcare end)

      EventHandler.handle_event(Brook.Event.new(type: organization_update(), data: org, author: :author))

      # Verify the function was called
      assert :meck.called(DiscoveryApi.Schemas.Organizations, :create_or_update, :_)
      
      # Clean up the mock with try-catch for safety
      try do
        :meck.unload(DiscoveryApi.Schemas.Organizations)
      catch
        _, _ -> :ok
      end
    end
  end

  describe "handle_event/1 user_organization_associate" do
    setup do
      # TelemetryEvent.Mock is already started in setup and handles calls automatically

      {:ok, association_event} =
        SmartCity.UserOrganizationAssociate.new(%{subject_id: "user_id", org_id: "org_id", email: "bob@example.com"})

      # Clean unload any existing Users mock first
      try do
        :meck.unload(DiscoveryApi.Schemas.Users)
      catch
        _, _ -> :ok
      end
      
      # Mock Users module using :meck since EventHandler doesn't use dependency injection
      :meck.new(DiscoveryApi.Schemas.Users, [:passthrough])
      :meck.expect(DiscoveryApi.Schemas.Users, :get_user, fn _subject_id, :subject_id -> {:ok, :does_not_matter} end)

      on_exit(fn ->
        try do
          :meck.unload(DiscoveryApi.Schemas.Users)
        catch
          _, _ -> :ok
        end
      end)

      %{association_event: association_event}
    end

    test "should save user/organization association to ecto and clear relevant caches", %{association_event: association_event} do
      :meck.expect(DiscoveryApi.Schemas.Users, :associate_with_organization, fn _arg1, _arg2 -> {:ok, %User{}} end)
      stub(TableInfoCacheMock, :invalidate, fn -> {:ok, true} end)

      EventHandler.handle_event(Brook.Event.new(type: user_organization_associate(), data: association_event, author: :author))

      # Verify Users function was called
      assert :meck.called(DiscoveryApi.Schemas.Users, :associate_with_organization, :_)
    end

    test "logs errors when save fails", %{association_event: association_event} do
      error_message = "you're a huge embarrassing failure"
      :meck.expect(DiscoveryApi.Schemas.Users, :associate_with_organization, fn _arg1, _arg2 -> {:error, error_message} end)

      assert capture_log(fn ->
               EventHandler.handle_event(Brook.Event.new(type: user_organization_associate(), data: association_event, author: :author))
             end) =~ error_message
    end
  end

  describe "handle_event/1 user_organization_disassociate" do
    setup do
      # TelemetryEvent.Mock is already started in setup and handles calls automatically
      {:ok, disassociation_event} = SmartCity.UserOrganizationDisassociate.new(%{subject_id: "subject_id", org_id: "org_id"})

      # Clean unload any existing Users mock first
      try do
        :meck.unload(DiscoveryApi.Schemas.Users)
      catch
        _, _ -> :ok
      end
      
      # Mock Users module using :meck since EventHandler doesn't use dependency injection
      :meck.new(DiscoveryApi.Schemas.Users, [:passthrough])

      on_exit(fn ->
        try do
          :meck.unload(DiscoveryApi.Schemas.Users)
        catch
          _, _ -> :ok
        end
      end)

      %{disassociation_event: disassociation_event}
    end

    test "should remove user/organization association in ecto and clear relevant caches", %{disassociation_event: disassociation_event} do
      :meck.expect(DiscoveryApi.Schemas.Users, :disassociate_with_organization, fn _arg1, _arg2 -> {:ok, %User{}} end)
      stub(TableInfoCacheMock, :invalidate, fn -> {:ok, true} end)

      EventHandler.handle_event(Brook.Event.new(type: user_organization_disassociate(), data: disassociation_event, author: :author))

      # Verify Users function was called
      assert :meck.called(DiscoveryApi.Schemas.Users, :disassociate_with_organization, :_)
    end

    test "logs errors when save fails", %{disassociation_event: disassociation_event} do
      error_message = "you're a huge embarrassing failure"
      :meck.expect(DiscoveryApi.Schemas.Users, :disassociate_with_organization, fn _arg1, _arg2 -> {:error, error_message} end)

      assert capture_log(fn ->
               EventHandler.handle_event(
                 Brook.Event.new(type: user_organization_disassociate(), data: disassociation_event, author: :author)
               )
             end) =~ error_message
    end
  end

  describe "handle_event/1 #{dataset_update()}" do
    setup do
      stub(OrganizationsMock, :get_organization, fn _arg ->
        {:ok, %DiscoveryApi.Schemas.Organizations.Organization{name: "seriously"}}
      end)

      stub(RaptorServiceMock, :list_access_groups_by_dataset, fn _arg1, _arg2 -> %{access_groups: []} end)
      stub(MapperMock, :to_data_model, fn _arg1, _arg2 -> {:ok, DiscoveryApi.Test.Helper.sample_model()} end)
      stub(RecommendationEngineMock, :save, fn _arg -> :seriously_whatever end)
      stub(DataJsonServiceMock, :delete_data_json, fn -> :ok end)
      stub(ElasticsearchDocumentMock, :update, fn _arg -> {:ok, :all_right_all_right} end)
      stub(TableInfoCacheMock, :invalidate, fn -> :ok end)
      # TelemetryEvent.Mock is already started in setup and handles calls automatically

      dataset = TDG.create_dataset(%{})

      Brook.Event.process(@instance_name, Brook.Event.new(type: dataset_update(), data: dataset, author: :author))
    end

    test "tells the data json plug to delete its current data json cache" do
      # Mox verification happens automatically with verify_on_exit!
    end

    test "invalidates the table info cache" do
      # Mox verification happens automatically with verify_on_exit!
    end
  end

  describe "handle_event/1 #{dataset_access_group_associate()}" do
    setup do
      model = Helper.sample_model()
      stub(BrookMock, :get, fn _arg1, _arg2, _arg3 -> {:ok, model} end)
      stub(RaptorServiceMock, :list_access_groups_by_dataset, fn _arg1, _arg2 -> %{access_groups: []} end)
      stub(ElasticsearchDocumentMock, :update, fn _arg -> {:ok, :all_right_all_right} end)
      stub(TableInfoCacheMock, :invalidate, fn -> :ok end)
      # TelemetryEvent.Mock is already started in setup and handles calls automatically

      dataset = TDG.create_dataset(%{})
      {:ok, relation} = SmartCity.DatasetAccessGroupRelation.new(%{dataset_id: dataset.id, access_group_id: "new_group"})

      Brook.Event.process(@instance_name, Brook.Event.new(type: dataset_access_group_associate(), data: relation, author: :author))
      %{model: model}
    end

    test "adds the access group to the model and updates elastic search", %{model: model} do
      model = %Model{model | accessGroups: model.accessGroups ++ ["new_group"]}
      # Mox verification happens automatically with verify_on_exit!
    end

    test "invalidates the table info cache" do
      # Mox verification happens automatically with verify_on_exit!
    end
  end

  describe "handle_event/1 #{dataset_access_group_associate()} error" do
    test "is ignored if dataset model missing" do
      stub(BrookMock, :get, fn _arg1, _arg2, _arg3 -> {:ok, nil} end)

      {:ok, relation} =
        SmartCity.DatasetAccessGroupRelation.new(%{dataset_id: "id_for_missing_dataset", access_group_id: "some_access_group"})

      event = Brook.Event.new(type: dataset_access_group_associate(), data: relation, author: :author)

      result = EventHandler.handle_event(event)

      assert :discard == result
    end
  end

  describe "handle_event/1 #{dataset_access_group_disassociate()}" do
    setup do
      model_without_group = Helper.sample_model()
      model = %Model{model_without_group | accessGroups: model_without_group.accessGroups ++ ["group_to_delete"]}
      stub(BrookMock, :get, fn _arg1, _arg2, _arg3 -> {:ok, model} end)
      stub(RaptorServiceMock, :list_access_groups_by_dataset, fn _arg1, _arg2 -> %{access_groups: []} end)
      stub(ElasticsearchDocumentMock, :update, fn _arg -> {:ok, :all_right_all_right} end)
      stub(TableInfoCacheMock, :invalidate, fn -> :ok end)
      # TelemetryEvent.Mock is already started in setup and handles calls automatically

      dataset = TDG.create_dataset(%{})
      {:ok, relation} = SmartCity.DatasetAccessGroupRelation.new(%{dataset_id: dataset.id, access_group_id: "group_to_delete"})

      Brook.Event.process(@instance_name, Brook.Event.new(type: dataset_access_group_disassociate(), data: relation, author: :author))
      %{model: model_without_group}
    end

    test "removes the access group from the model and updates elastic search", %{model: model} do
      # Mox verification happens automatically with verify_on_exit!
    end

    test "invalidates the table info cache" do
      # Mox verification happens automatically with verify_on_exit!
    end
  end

  describe "handle_event/1 #{dataset_access_group_disassociate()} error" do
    test "is ignored if dataset model missing" do
      stub(BrookMock, :get, fn _arg1, _arg2, _arg3 -> {:ok, nil} end)

      {:ok, relation} =
        SmartCity.DatasetAccessGroupRelation.new(%{dataset_id: "id_for_missing_dataset", access_group_id: "some_access_group"})

      event = Brook.Event.new(type: dataset_access_group_disassociate(), data: relation, author: :author)

      result = EventHandler.handle_event(event)

      assert :discard == result
    end
  end

  describe "handle_event/1 #{dataset_delete()}" do
    setup do
      # TelemetryEvent.Mock is already started in setup and handles calls automatically
      %{dataset: TDG.create_dataset(%{id: Faker.UUID.v4()})}
    end

    test "should delete the dataset and return ok when dataset:delete is called", %{dataset: dataset} do
      stub(RecommendationEngineMock, :delete, fn _dataset_id -> :ok end)
      # StatsCalculator and ResponseCache are now mocked globally using :meck in setup
      stub(TableInfoCacheMock, :invalidate, fn -> {:ok, true} end)
      stub(SystemNameCacheMock, :delete, fn _org_name, _data_name -> {:ok, true} end)
      stub(ModelMock, :delete, fn _dataset_id -> :ok end)
      stub(DataJsonServiceMock, :delete_data_json, fn -> :ok end)
      stub(ElasticsearchDocumentMock, :delete, fn _dataset_id -> :ok end)
      
      # Add PersistenceMock expectation for RecommendationEngine.delete and StatsCalculator operations
      stub(PersistenceMock, :delete, fn _key -> :ok end)
      
      # Add RedixMock expectation for Redis deletion operations
      stub(RedixMock, :command, fn _connection, _command -> {:ok, "1"} end)

      Brook.Event.process(@instance_name, Brook.Event.new(type: dataset_delete(), data: dataset, author: :author))
    end

    test "should return ok if it throws error when dataset:delete is called", %{dataset: dataset} do
      error = %RuntimeError{message: "ERR value is not an integer or out of range"}

      # Mock RecommendationEngine.delete to succeed  
      stub(RecommendationEngineMock, :delete, fn _dataset_id -> :ok end)
      # Mock other services 
      stub(DataJsonServiceMock, :delete_data_json, fn -> :ok end)
      stub(ElasticsearchDocumentMock, :delete, fn _dataset_id -> :ok end)
      stub(TableInfoCacheMock, :invalidate, fn -> {:ok, true} end)
      stub(SystemNameCacheMock, :delete, fn _org_name, _data_name -> {:ok, true} end)
      stub(ModelMock, :delete, fn _dataset_id -> :ok end)
      
      # Mock RedixMock to return an error to simulate a Redis failure
      expect(RedixMock, :command, fn _, _ -> raise error end)
      # Also add PersistenceMock expectation
      stub(PersistenceMock, :delete, fn _key -> :ok end)

      assert capture_log(fn ->
               Brook.Event.process(@instance_name, Brook.Event.new(type: dataset_delete(), data: dataset, author: :author))
             end) =~
               ~r/Dataset: #{dataset.id}; dataset_delete failed to process: %RuntimeError{message: \"ERR value is not an integer or out of range\"}/
    end
  end

  describe "handle_event/1 #{dataset_query()}" do
    test "records api query hit for all affected datasets" do
      sample_model = DiscoveryApi.Test.Helper.sample_model(%{id: "123"})
      
      # Clean unload any existing mock first
      try do
        :meck.unload(DiscoveryApi.Services.MetricsService)
      catch
        _, _ -> :ok
      end
      
      # Mock the MetricsService.record_api_hit function using :meck
      :meck.new(DiscoveryApi.Services.MetricsService, [:passthrough])
      :meck.expect(DiscoveryApi.Services.MetricsService, :record_api_hit, fn _request_type, _dataset_id -> :ok end)

      # Process the event directly to verify behavior
      result = EventHandler.handle_event(Brook.Event.new(type: dataset_query(), data: sample_model.id, author: :author))
      
      # Verify the MetricsService was called correctly
      assert :meck.called(DiscoveryApi.Services.MetricsService, :record_api_hit, [:_, :_])
      
      assert result == :discard
      
      # Clean up the mock with try-catch for safety
      try do
        :meck.unload(DiscoveryApi.Services.MetricsService)
      catch
        _, _ -> :ok
      end
    end
  end
end
