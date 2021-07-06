defmodule DiscoveryApi.Data.DatasetUpdateEventHandlerTest do
  use ExUnit.Case
  use Placebo

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
      allow(DiscoveryApi.Search.Elasticsearch.Document.update(any()), return: {:ok, :all_right_all_right})
      allow(ResponseCache.invalidate(), return: :ok)
      allow(DiscoveryApi.RecommendationEngine.save(any(), any()), return: :ok)

      allow(Redix.command!(any(), any()), return: ["not_in_redis"])

      dataset = TDG.create_dataset(%{id: "123"})
      organization = create_schema_organization(%{id: dataset.technical.orgId})
      allow(Organizations.get_organization(dataset.technical.orgId), return: {:ok, organization})
      {:ok, %{dataset: dataset, organization: organization}}
    end

    test "should save the dataset as a model", %{dataset: dataset} do
      Brook.Test.send(@instance_name, dataset_update(), "unit", dataset)

      assert {:ok, model} = Brook.ViewState.get(@instance_name, :models, dataset.id)
    end

    @tag capture_log: true
    test "should not persist the model when organization get fails" do
      dataset = TDG.create_dataset(%{id: "123"})

      allow(Organizations.get_organization(dataset.technical.orgId), return: {:error, :failure})

      Brook.Test.send(DiscoveryApi.instance_name(), dataset_update(), "unit", dataset)

      assert {:ok, nil} = Brook.ViewState.get(@instance_name, :models, dataset.id)
    end

    @tag capture_log: true
    test "should not persist the model when system cache put fails", %{dataset: dataset} do
      allow SystemNameCache.put(any(), any(), any()), return: {:error, :failure}

      Brook.Test.send(@instance_name, dataset_update(), "unit", dataset)

      assert {:ok, nil} = Brook.ViewState.get(@instance_name, :models, dataset.id)
    end

    test "should invalidate the ResponseCache when dataset is received", %{dataset: dataset} do
      Brook.Test.send(@instance_name, dataset_update(), "unit", dataset)
      assert_called(ResponseCache.invalidate(), once())
    end

    test "creates orgName/dataName mapping to dataset_id", %{dataset: dataset, organization: organization} do
      Brook.Test.send(@instance_name, dataset_update(), "unit", dataset)

      assert SystemNameCache.get(organization.name, dataset.technical.dataName) == "123"
    end

    test "the model should be accessible via the view state", %{dataset: %{id: id, business: %{dataTitle: title}} = dataset} do
      Brook.Test.send(@instance_name, dataset_update(), "unit", dataset)

      assert %DiscoveryApi.Data.Model{id: ^id, title: ^title} = DiscoveryApi.Data.Model.get(id)
    end

    data_test "sends dataset to recommendation engine" do
      dataset = TDG.create_dataset(dataset_map)
      organization = create_schema_organization(%{id: dataset.technical.orgId})
      allow(Organizations.get_organization(dataset.technical.orgId), return: {:ok, organization})

      Brook.Test.send(@instance_name, dataset_update(), "unit", dataset)

      assert called == called?(DiscoveryApi.RecommendationEngine.save(dataset))

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

      dataset = TDG.create_dataset(%{id: "123"})
      data_model = DiscoveryApi.Data.Mapper.to_data_model(dataset, %DiscoveryApi.Schemas.Organizations.Organization{})

      Brook.Test.with_event(@instance_name, fn ->
        Brook.ViewState.merge(:models, data_model.id, data_model)
      end)

      allow(Redix.command!(any(), any()), return: ["not_in_redis"])

      {:ok, [data_model: data_model]}
    end

    test "merges the write complete timsetamp into the model", %{data_model: %{id: id, title: title}} do
      write_complete_timestamp_iso = DateTime.utc_now() |> DateTime.to_iso8601()

      expect(Elasticsearch.Document.update(any()), return: {:ok, :does_not_matter})
      {:ok, event} = SmartCity.DataWriteComplete.new(%{id: id, timestamp: write_complete_timestamp_iso})

      Brook.Test.send(@instance_name, data_write_complete(), "unit", event)

      assert %DiscoveryApi.Data.Model{id: ^id, title: ^title, lastUpdatedDate: write_complete_timestamp_iso} =
               DiscoveryApi.Data.Model.get(id)
    end

    test "does not record write complete for datasets that are not in view state, as storing the partial can make other things blow up" do
      write_complete_timestamp = DateTime.utc_now()
      data_model_id = "not found"

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
