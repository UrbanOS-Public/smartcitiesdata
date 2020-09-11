defmodule DiscoveryApi.EventHandlerTest do
  use ExUnit.Case
  use Placebo

  import SmartCity.Event, only: [dataset_update: 0, organization_update: 0, user_organization_associate: 0, dataset_delete: 0]
  import ExUnit.CaptureLog

  alias SmartCity.TestDataGenerator, as: TDG
  alias DiscoveryApi.EventHandler
  alias DiscoveryApi.RecommendationEngine
  alias DiscoveryApi.Schemas.Organizations
  alias DiscoveryApi.Schemas.Users
  alias DiscoveryApi.Schemas.Users.User
  alias DiscoveryApi.Data.{Model, SystemNameCache, TableInfoCache}
  alias DiscoveryApi.Stats.StatsCalculator
  alias DiscoveryApi.Search.Elasticsearch
  alias DiscoveryApiWeb.Plugs.ResponseCache
  alias DiscoveryApi.Services.DataJsonService

  describe "handle_event/1 organization_update" do
    test "should save organization to ecto" do
      org = TDG.create_organization(%{})
      allow(Organizations.create_or_update(any()), return: :dontcare)
      expect(TelemetryEvent.add_event_metrics(any(), [:events_handled]), return: :ok)

      EventHandler.handle_event(Brook.Event.new(type: organization_update(), data: org, author: :author))

      assert_called(Organizations.create_or_update(org))
    end
  end

  describe "handle_event/1 user_organization_associate" do
    setup do
      expect(TelemetryEvent.add_event_metrics(any(), [:events_handled]), return: :ok)
      {:ok, association_event} = SmartCity.UserOrganizationAssociate.new(%{user_id: "user_id", org_id: "org_id"})

      %{association_event: association_event}
    end

    test "should save user/organization association to ecto and clear relevant caches", %{association_event: association_event} do
      allow(Users.associate_with_organization(any(), any()), return: {:ok, %User{}})
      expect(TableInfoCache.invalidate(), return: {:ok, true})

      EventHandler.handle_event(Brook.Event.new(type: user_organization_associate(), data: association_event, author: :author))

      assert_called(Users.associate_with_organization(association_event.user_id, association_event.org_id))
    end

    test "logs errors when save fails", %{association_event: association_event} do
      error_message = "you're a huge embarrassing failure"
      allow(Users.associate_with_organization(any(), any()), return: {:error, error_message})

      assert capture_log(fn ->
               EventHandler.handle_event(Brook.Event.new(type: user_organization_associate(), data: association_event, author: :author))
             end) =~ error_message
    end
  end

  describe "handle_event/1 #{dataset_update()}" do
    setup do
      allow(DiscoveryApi.Schemas.Organizations.get_organization(any()),
        return: {:ok, %DiscoveryApi.Schemas.Organizations.Organization{name: "seriously"}}
      )

      allow(DiscoveryApi.Data.Mapper.to_data_model(any(), any()), return: DiscoveryApi.Test.Helper.sample_model())
      allow(RecommendationEngine.save(any()), return: :seriously_whatever)
      allow(DataJsonService.delete_data_json(), return: :ok)
      allow(DiscoveryApi.Search.Elasticsearch.Document.update(any()), return: {:ok, :all_right_all_right})
      allow(TableInfoCache.invalidate(), return: :ok)
      expect(TelemetryEvent.add_event_metrics(any(), [:events_handled]), return: :ok)
      expect(Brook.Event.send(DiscoveryApi.instance(), "add_dataset_count", :discovery_api, %{}), return: :ok)

      dataset = TDG.create_dataset(%{})

      Brook.Event.process(:discovery_api, Brook.Event.new(type: dataset_update(), data: dataset, author: :author))
    end

    test "tells the data json plug to delete its current data json cache" do
      assert_called(DataJsonService.delete_data_json())
    end

    test "invalidates the table info cache" do
      assert_called(TableInfoCache.invalidate())
    end
  end

  describe "handle_event/1 #{dataset_delete()}" do
    setup do
      expect(TelemetryEvent.add_event_metrics(any(), [:events_handled]), return: :ok)
      %{dataset: TDG.create_dataset(%{id: Faker.UUID.v4()})}
    end

    test "should delete the dataset and return ok when dataset:delete is called", %{dataset: dataset} do
      expect(RecommendationEngine.delete(dataset.id), return: :ok)
      expect(StatsCalculator.delete_completeness(dataset.id), return: :ok)
      expect(ResponseCache.invalidate(), return: {:ok, true})
      expect(TableInfoCache.invalidate(), return: {:ok, true})
      expect(SystemNameCache.delete(dataset.technical.orgName, dataset.technical.dataName), return: {:ok, true})
      expect(Model.delete(dataset.id), return: :ok)
      expect(DataJsonService.delete_data_json(), return: :ok)
      expect(Elasticsearch.Document.delete(dataset.id), return: :ok)
      expect(Brook.Event.send(DiscoveryApi.instance(), "add_dataset_count", :discovery_api, %{}), return: :ok)

      Brook.Event.process(:discovery_api, Brook.Event.new(type: dataset_delete(), data: dataset, author: :author))
    end

    test "should return ok if it throws error when dataset:delete is called", %{dataset: dataset} do
      error = "ERR value is not an integer or out of range"

      allow(RecommendationEngine.delete(dataset.id),
        exec: fn _ -> raise error end
      )

      assert capture_log(fn ->
               Brook.Event.process(:discovery_api, Brook.Event.new(type: dataset_delete(), data: dataset, author: :author))
             end) =~ ~r/Failed to delete dataset: #{dataset.id}.*#{inspect(error)}/
    end
  end
end
