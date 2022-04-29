defmodule DiscoveryApi.Event.EventHandlerTest do
  use ExUnit.Case
  use Placebo

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
  alias DiscoveryApi.RecommendationEngine
  alias DiscoveryApi.Schemas.Organizations
  alias DiscoveryApi.Schemas.Users
  alias DiscoveryApi.Schemas.Users.User
  alias DiscoveryApi.Data.{Model, SystemNameCache, TableInfoCache}
  alias DiscoveryApi.Stats.StatsCalculator
  alias DiscoveryApi.Search.Elasticsearch
  alias DiscoveryApiWeb.Plugs.ResponseCache
  alias DiscoveryApi.Services.DataJsonService
  alias DiscoveryApi.Test.Helper

  @instance_name DiscoveryApi.instance_name()

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

      {:ok, association_event} =
        SmartCity.UserOrganizationAssociate.new(%{subject_id: "user_id", org_id: "org_id", email: "bob@example.com"})

      allow(Users.get_user(association_event.subject_id, :subject_id), return: {:ok, :does_not_matter})

      %{association_event: association_event}
    end

    test "should save user/organization association to ecto and clear relevant caches", %{association_event: association_event} do
      allow(Users.associate_with_organization(any(), any()), return: {:ok, %User{}})
      expect(TableInfoCache.invalidate(), return: {:ok, true})

      EventHandler.handle_event(Brook.Event.new(type: user_organization_associate(), data: association_event, author: :author))

      assert_called(Users.associate_with_organization(association_event.subject_id, association_event.org_id))
    end

    test "logs errors when save fails", %{association_event: association_event} do
      error_message = "you're a huge embarrassing failure"
      allow(Users.associate_with_organization(any(), any()), return: {:error, error_message})

      assert capture_log(fn ->
               EventHandler.handle_event(Brook.Event.new(type: user_organization_associate(), data: association_event, author: :author))
             end) =~ error_message
    end
  end

  describe "handle_event/1 user_organization_disassociate" do
    setup do
      expect(TelemetryEvent.add_event_metrics(any(), [:events_handled]), return: :ok)
      {:ok, disassociation_event} = SmartCity.UserOrganizationDisassociate.new(%{subject_id: "subject_id", org_id: "org_id"})

      %{disassociation_event: disassociation_event}
    end

    test "should remove user/organization association in ecto and clear relevant caches", %{disassociation_event: disassociation_event} do
      allow(Users.disassociate_with_organization(any(), any()), return: {:ok, %User{}})
      expect(TableInfoCache.invalidate(), return: {:ok, true})

      EventHandler.handle_event(Brook.Event.new(type: user_organization_disassociate(), data: disassociation_event, author: :author))

      assert_called(Users.disassociate_with_organization(disassociation_event.subject_id, disassociation_event.org_id))
    end

    test "logs errors when save fails", %{disassociation_event: disassociation_event} do
      error_message = "you're a huge embarrassing failure"
      allow(Users.disassociate_with_organization(any(), any()), return: {:error, error_message})

      assert capture_log(fn ->
               EventHandler.handle_event(
                 Brook.Event.new(type: user_organization_disassociate(), data: disassociation_event, author: :author)
               )
             end) =~ error_message
    end
  end

  describe "handle_event/1 #{dataset_update()}" do
    setup do
      allow(DiscoveryApi.Schemas.Organizations.get_organization(any()),
        return: {:ok, %DiscoveryApi.Schemas.Organizations.Organization{name: "seriously"}}
      )

      allow(RaptorService.list_access_groups_by_dataset(any(), any()), return: [])
      allow(DiscoveryApi.Data.Mapper.to_data_model(any(), any()), return: DiscoveryApi.Test.Helper.sample_model())
      allow(RecommendationEngine.save(any()), return: :seriously_whatever)
      allow(DataJsonService.delete_data_json(), return: :ok)
      allow(DiscoveryApi.Search.Elasticsearch.Document.update(any()), return: {:ok, :all_right_all_right})
      allow(TableInfoCache.invalidate(), return: :ok)
      expect(TelemetryEvent.add_event_metrics(any(), [:events_handled]), return: :ok)

      dataset = TDG.create_dataset(%{})

      Brook.Event.process(@instance_name, Brook.Event.new(type: dataset_update(), data: dataset, author: :author))
    end

    test "tells the data json plug to delete its current data json cache" do
      assert_called(DataJsonService.delete_data_json())
    end

    test "invalidates the table info cache" do
      assert_called(TableInfoCache.invalidate())
    end
  end

  describe "handle_event/1 #{dataset_access_group_associate()}" do
    setup do
      model = Helper.sample_model()
      allow(Brook.get(any(), any(), any()), return: {:ok, model})
      allow(RaptorService.list_access_groups_by_dataset(any(), any()), return: [])
      allow(DiscoveryApi.Search.Elasticsearch.Document.update(any()), return: {:ok, :all_right_all_right})
      allow(TableInfoCache.invalidate(), return: :ok)
      expect(TelemetryEvent.add_event_metrics(any(), [:events_handled]), return: :ok)

      dataset = TDG.create_dataset(%{})
      {:ok, relation} = SmartCity.DatasetAccessGroupRelation.new(%{dataset_id: dataset.id, access_group_id: "new_group"})

      Brook.Event.process(@instance_name, Brook.Event.new(type: dataset_access_group_associate(), data: relation, author: :author))
      %{model: model}
    end

    test "adds the access group to the model and updates elastic search", %{model: model} do
      model = %Model{model | accessGroups: model.accessGroups ++ ["new_group"]}
      assert_called(DiscoveryApi.Search.Elasticsearch.Document.update(model))
    end

    test "invalidates the table info cache" do
      assert_called(TableInfoCache.invalidate())
    end
  end

  describe "handle_event/1 #{dataset_access_group_disassociate()}" do
    setup do
      model_without_group = Helper.sample_model()
      model = %Model{model_without_group | accessGroups: model_without_group.accessGroups ++ ["group_to_delete"]}
      allow(Brook.get(any(), any(), any()), return: {:ok, model})
      allow(RaptorService.list_access_groups_by_dataset(any(), any()), return: [])
      allow(DiscoveryApi.Search.Elasticsearch.Document.update(any()), return: {:ok, :all_right_all_right})
      allow(TableInfoCache.invalidate(), return: :ok)
      expect(TelemetryEvent.add_event_metrics(any(), [:events_handled]), return: :ok)

      dataset = TDG.create_dataset(%{})
      {:ok, relation} = SmartCity.DatasetAccessGroupRelation.new(%{dataset_id: dataset.id, access_group_id: "group_to_delete"})

      Brook.Event.process(@instance_name, Brook.Event.new(type: dataset_access_group_disassociate(), data: relation, author: :author))
      %{model: model_without_group}
    end

    test "removes the access group from the model and updates elastic search", %{model: model} do
      assert_called(DiscoveryApi.Search.Elasticsearch.Document.update(model))
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

      Brook.Event.process(@instance_name, Brook.Event.new(type: dataset_delete(), data: dataset, author: :author))
    end

    test "should return ok if it throws error when dataset:delete is called", %{dataset: dataset} do
      error = "ERR value is not an integer or out of range"

      allow(RecommendationEngine.delete(dataset.id),
        exec: fn _ -> raise error end
      )

      assert capture_log(fn ->
               Brook.Event.process(@instance_name, Brook.Event.new(type: dataset_delete(), data: dataset, author: :author))
             end) =~ ~r/Failed to delete dataset: #{dataset.id}.*#{inspect(error)}/
    end
  end

  describe "handle_event/1 #{dataset_query()}" do
    setup do
      sample_model = DiscoveryApi.Test.Helper.sample_model(%{id: "123"})

      allow(Redix.command!(any(), any()), return: :ok)

      Brook.Event.process(
        @instance_name,
        Brook.Event.new(type: dataset_query(), data: sample_model.id, author: :author)
      )

      [sample_model: sample_model]
    end

    test "records api query hit for all affected datasets", %{sample_model: sample_model} do
      assert_called Redix.command!(:redix, ["INCR", "smart_registry:#{dataset_query()}:count:#{sample_model.id}"])
    end
  end
end
