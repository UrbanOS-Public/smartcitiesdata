defmodule DiscoveryApi.Data.DatasetUpdateEventHandlerTest do
  use ExUnit.Case
  use Placebo
  alias DiscoveryApi.Data.SystemNameCache
  alias DiscoveryApiWeb.Plugs.ResponseCache
  alias DiscoveryApi.Schemas.Organizations
  alias SmartCity.TestDataGenerator, as: TDG

  import SmartCity.Event, only: [dataset_update: 0]

  import DiscoveryApi.Test.Helper
  import Checkov

  @instance DiscoveryApi.instance()

  describe "handle_dataset/1" do
    setup do
      clear_saved_models()
      allow(ResponseCache.invalidate(), return: :ok)
      allow(DiscoveryApi.Search.Storage.index(any()), return: :ok)
      allow(DiscoveryApi.RecommendationEngine.save(any()), return: :ok)

      dataset = TDG.create_dataset(%{id: "123"})
      allow(Redix.command!(any(), any()), return: ["not_in_redis"])

      organization = create_schema_organization(%{id: dataset.technical.orgId})
      allow(Organizations.get_organization(dataset.technical.orgId), return: {:ok, organization})
      {:ok, %{dataset: dataset, organization: organization}}
    end

    test "should save the dataset as a model", %{dataset: dataset} do
      Brook.Test.send(@instance, dataset_update(), "unit", dataset)

      assert {:ok, model} = Brook.ViewState.get(@instance, :models, dataset.id)
    end

    test "the model should be accessible via the view state", %{dataset: %{id: id, business: %{dataTitle: title}} = dataset} do
      Brook.Test.send(@instance, dataset_update(), "unit", dataset)

      assert %DiscoveryApi.Data.Model{id: ^id, title: ^title} = DiscoveryApi.Data.Model.get(id)
    end

    @tag capture_log: true
    test "should not persist the model when organization get fails" do
      dataset = TDG.create_dataset(%{id: "123"})

      allow(Organizations.get_organization(dataset.technical.orgId), return: {:error, :failure})

      Brook.Test.send(DiscoveryApi.instance(), dataset_update(), "unit", dataset)

      assert {:ok, nil} = Brook.ViewState.get(@instance, :models, dataset.id)
    end

    @tag capture_log: true
    test "should not persist the model when system cache put fails", %{dataset: dataset} do
      allow(SystemNameCache.put(any(), any()), return: {:error, :failure})

      Brook.Test.send(DiscoveryApi.instance(), dataset_update(), "unit", dataset)

      assert {:ok, nil} = Brook.ViewState.get(@instance, :models, dataset.id)
    end

    test "should invalidate the ResponseCache when dataset is received", %{dataset: dataset} do
      Brook.Test.send(DiscoveryApi.instance(), dataset_update(), "unit", dataset)
      assert_called(ResponseCache.invalidate(), once())
    end

    test "creates orgName/dataName mapping to dataset_id", %{dataset: dataset, organization: organization} do
      Brook.Test.send(DiscoveryApi.instance(), dataset_update(), "unit", dataset)

      assert SystemNameCache.get(organization.name, dataset.technical.dataName) == "123"
    end

    test "indexes model for search", %{dataset: dataset, organization: organization} do
      expected_model = DiscoveryApi.Data.Mapper.to_data_model(dataset, organization)

      Brook.Test.send(DiscoveryApi.instance(), dataset_update(), "unit", dataset)

      assert_called(DiscoveryApi.Search.Storage.index(expected_model))
    end

    data_test "sends dataset to recommendation engine" do
      dataset = TDG.create_dataset(dataset_map)
      organization = create_schema_organization(%{id: dataset.technical.orgId})
      allow(Organizations.get_organization(dataset.technical.orgId), return: {:ok, organization})

      Brook.Test.send(DiscoveryApi.instance(), dataset_update(), "unit", dataset)

      assert called == called?(DiscoveryApi.RecommendationEngine.save(dataset))

      where([
        [:called, :dataset_map],
        [true, %{technical: %{private: false, schema: [%{name: "id", type: "string"}]}}],
        [false, %{technical: %{private: false, schema: []}}],
        [false, %{technical: %{private: true}}]
      ])
    end
  end

  describe "dataset:write_complete event" do
    setup do
      clear_saved_models()

      dataset = TDG.create_dataset(%{id: "123"})
      data_model = DiscoveryApi.Data.Mapper.to_data_model(dataset, %DiscoveryApi.Schemas.Organizations.Organization{})

      Brook.Test.with_event(@instance, fn ->
        Brook.ViewState.merge(:models, data_model.id, data_model)
      end)

      allow(Redix.command!(any(), any()), return: ["not_in_redis"])

      {:ok, [data_model: data_model]}
    end

    test "writes dataset:write_complete event once write is complete", %{data_model: %{id: id, title: title}} do
      write_complete_timestamp = DateTime.utc_now()
      Brook.Test.send(@instance, "dataset:write_complete", "unit", %{id: id, timestamp: write_complete_timestamp})

      assert %DiscoveryApi.Data.Model{id: ^id, title: ^title, lastUpdatedDate: ^write_complete_timestamp} = DiscoveryApi.Data.Model.get(id)
    end

    test "writes dataset:write_complete event once write is complete even if dataset is not in view state" do
      write_complete_timestamp = DateTime.utc_now()
      data_model_id = "not found"

      Brook.Test.send(@instance, "dataset:write_complete", "unit", %{id: data_model_id, timestamp: write_complete_timestamp})

      assert %DiscoveryApi.Data.Model{id: ^data_model_id, lastUpdatedDate: ^write_complete_timestamp} =
               DiscoveryApi.Data.Model.get(data_model_id)
    end

    test "if it is not sent (for a remote, for example), but dataset is already there, what do we get?!", %{
      data_model: %{id: id, title: title}
    } do
      assert %DiscoveryApi.Data.Model{id: ^id, title: ^title, lastUpdatedDate: nil} = DiscoveryApi.Data.Model.get(id)
    end
  end
end
