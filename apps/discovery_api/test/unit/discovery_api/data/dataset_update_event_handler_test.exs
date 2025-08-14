defmodule DiscoveryApi.Data.DatasetUpdateEventHandlerTest do
  use ExUnit.Case
  import Mox

  setup :verify_on_exit!

  alias DiscoveryApi.Data.SystemNameCache
  alias DiscoveryApiWeb.Plugs.ResponseCache
  alias DiscoveryApi.Schemas.Organizations
  alias DiscoveryApi.Search.Elasticsearch

  import SmartCity.Event, only: [dataset_update: 0, data_write_complete: 0]

  alias SmartCity.TestDataGenerator, as: TDG
  import DiscoveryApi.Test.Helper
  import Checkov

  @instance_name DiscoveryApi.instance_name()

  describe "handle_dataset/1" do
    setup do
      clear_saved_models()
      stub(RaptorServiceMock, :list_access_groups_by_dataset, fn _, _ -> %{access_groups: []} end)
      stub(ElasticsearchDocumentMock, :update, fn _ -> {:ok, :all_right_all_right} end)
      stub(ResponseCacheMock, :invalidate, fn -> :ok end)
      stub(RecommendationEngineMock, :save, fn _ -> :ok end)
      stub(DeadLetterMock, :process, fn _, _, _, _, _ -> :ok end)

      stub(RedixMock, :command!, fn _, _ -> ["not_in_redis"] end)

      dataset = TDG.create_dataset(%{id: "123"})
      organization = create_schema_organization(%{id: dataset.technical.orgId})
      org_id = dataset.technical.orgId
      stub(OrganizationsMock, :get_organization, fn ^org_id -> {:ok, organization} end)
      {:ok, %{dataset: dataset, organization: organization}}
    end

    test "should save the dataset as a model", %{dataset: dataset} do
      # Allow any spawned processes to use the mocks
      brook_pid = GenServer.whereis({:via, Registry, {:brook_registry_discovery_api, Brook.Server}})
      if brook_pid, do: allow(DeadLetterMock, self(), brook_pid)

      Brook.Test.send(@instance_name, dataset_update(), "unit", dataset)

      assert {:ok, model} = Brook.ViewState.get(@instance_name, :models, dataset.id)
    end

    @tag capture_log: true
    test "should not persist the model when organization get fails" do
      dataset = TDG.create_dataset(%{id: "123"})

      org_id = dataset.technical.orgId
      stub(OrganizationsMock, :get_organization, fn ^org_id -> {:error, :failure} end)

      # Allow any spawned processes to use the mocks
      brook_pid = GenServer.whereis({:via, Registry, {:brook_registry_discovery_api, Brook.Server}})
      if brook_pid, do: allow(DeadLetterMock, self(), brook_pid)

      Brook.Test.send(DiscoveryApi.instance_name(), dataset_update(), "unit", dataset)

      assert {:ok, nil} = Brook.ViewState.get(@instance_name, :models, dataset.id)
    end

    @tag capture_log: true
    test "should not persist the model when system cache put fails", %{dataset: dataset} do
      stub(SystemNameCacheMock, :put, fn _, _, _ -> {:error, :failure} end)

      Brook.Test.send(@instance_name, dataset_update(), "unit", dataset)

      assert {:ok, nil} = Brook.ViewState.get(@instance_name, :models, dataset.id)
    end

    test "should invalidate the ResponseCache when dataset is received", %{dataset: dataset} do
      # Allow any spawned processes to use the mocks
      brook_pid = GenServer.whereis({:via, Registry, {:brook_registry_discovery_api, Brook.Server}})
      if brook_pid, do: allow(DeadLetterMock, self(), brook_pid)

      expect(ResponseCacheMock, :invalidate, 1, fn -> :ok end)
      Brook.Test.send(@instance_name, dataset_update(), "unit", dataset)
      verify!(ResponseCacheMock)
    end

    test "creates orgName/dataName mapping to dataset_id", %{dataset: dataset, organization: organization} do
      # Allow any spawned processes to use the mocks
      brook_pid = GenServer.whereis({:via, Registry, {:brook_registry_discovery_api, Brook.Server}})
      if brook_pid, do: allow(DeadLetterMock, self(), brook_pid)

      Brook.Test.send(@instance_name, dataset_update(), "unit", dataset)

      assert SystemNameCache.get(organization.name, dataset.technical.dataName) == "123"
    end

    test "the model should be accessible via the view state", %{dataset: %{id: id, business: %{dataTitle: title}} = dataset} do
      # Allow any spawned processes to use the mocks
      brook_pid = GenServer.whereis({:via, Registry, {:brook_registry_discovery_api, Brook.Server}})
      if brook_pid, do: allow(DeadLetterMock, self(), brook_pid)

      Brook.Test.send(@instance_name, dataset_update(), "unit", dataset)

      assert %DiscoveryApi.Data.Model{id: ^id, title: ^title} = DiscoveryApi.Data.Model.get(id)
    end

    data_test "sends dataset to recommendation engine" do
      dataset = TDG.create_dataset(dataset_map)
      organization = create_schema_organization(%{id: dataset.technical.orgId})
      org_id = dataset.technical.orgId
      stub(OrganizationsMock, :get_organization, fn ^org_id -> {:ok, organization} end)

      if called do
        expect(RecommendationEngineMock, :save, 1, fn ^dataset -> :ok end)
      else
        expect(RecommendationEngineMock, :save, 0, fn _ -> :ok end)
      end

      # Allow any spawned processes to use the mocks
      brook_pid = GenServer.whereis({:via, Registry, {:brook_registry_discovery_api, Brook.Server}})
      if brook_pid, do: allow(DeadLetterMock, self(), brook_pid)

      Brook.Test.send(@instance_name, dataset_update(), "unit", dataset)

      verify!(RecommendationEngineMock)

      where([
        [:called, :dataset_map],
        [true, %{technical: %{private: false, schema: [%{name: "id", type: "string"}]}}],
        [false, %{technical: %{private: false, schema: []}}],
        [false, %{technical: %{private: true}}]
      ])
    end
  end

  describe "data write complete events" do
    setup do
      clear_saved_models()
      stub(RaptorServiceMock, :list_access_groups_by_dataset, fn _, _ -> %{access_groups: []} end)
      stub(DeadLetterMock, :process, fn _, _, _, _, _ -> :ok end)
      dataset = TDG.create_dataset(%{id: "123"})
      {:ok, data_model} = DiscoveryApi.Data.Mapper.to_data_model(dataset, %DiscoveryApi.Schemas.Organizations.Organization{})

      Brook.Test.with_event(@instance_name, fn ->
        Brook.ViewState.merge(:models, data_model.id, data_model)
      end)

      stub(RedixMock, :command!, fn _, _ -> ["not_in_redis"] end)

      {:ok, [data_model: data_model]}
    end

    test "merges the write complete timsetamp into the model", %{data_model: %{id: id, title: title}} do
      write_complete_timestamp_iso = DateTime.utc_now() |> DateTime.to_iso8601()

      # Allow any spawned processes to use the mocks
      brook_pid = GenServer.whereis({:via, Registry, {:brook_registry_discovery_api, Brook.Server}})
      if brook_pid, do: allow(DeadLetterMock, self(), brook_pid)

      expect(ElasticsearchDocumentMock, :update, 1, fn _ -> {:ok, :does_not_matter} end)
      {:ok, event} = SmartCity.DataWriteComplete.new(%{id: id, timestamp: write_complete_timestamp_iso})

      Brook.Test.send(@instance_name, data_write_complete(), "unit", event)

      assert %DiscoveryApi.Data.Model{id: ^id, title: ^title, lastUpdatedDate: write_complete_timestamp_iso} =
               DiscoveryApi.Data.Model.get(id)
    end

    test "does not record write complete for datasets that are not in view state, as storing the partial can make other things blow up" do
      write_complete_timestamp = DateTime.utc_now()
      data_model_id = "not found"

      # Allow any spawned processes to use the mocks
      brook_pid = GenServer.whereis({:via, Registry, {:brook_registry_discovery_api, Brook.Server}})
      if brook_pid, do: allow(DeadLetterMock, self(), brook_pid)

      {:ok, event} =
        SmartCity.DataWriteComplete.new(%{
          id: data_model_id,
          timestamp: write_complete_timestamp
        })

      Brook.Test.send(@instance_name, data_write_complete(), "unit", event)

      assert nil == DiscoveryApi.Data.Model.get(data_model_id)
    end

    test "if an event was not received, lastUpdateDate should be nil", %{
      data_model: %{id: id, title: title}
    } do
      assert %DiscoveryApi.Data.Model{id: ^id, title: ^title, lastUpdatedDate: nil} = DiscoveryApi.Data.Model.get(id)
    end
  end
end
