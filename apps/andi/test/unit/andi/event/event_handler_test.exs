defmodule Andi.Event.EventHandlerTest do
  @moduledoc false
  use ExUnit.Case
  use AndiWeb.Test.AuthConnCase.UnitCase
  use Placebo

  import SmartCity.Event

  import SmartCity.TestHelper, only: [eventually: 1]

  alias Andi.Event.EventHandler
  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.Datasets
  alias Andi.Harvest.Harvester
  alias Andi.InputSchemas.Organizations
  alias Andi.Services.OrgStore
  alias Andi.InputSchemas.Ingestions
  alias Andi.Services.IngestionStore
  alias SmartCity.DatasetAccessGroupRelation

  @instance_name Andi.instance_name()

  test "should successfully handle a dataset_access_group_associate() event" do
    dataset_id = UUID.uuid4()
    access_group_id = UUID.uuid4()
    {:ok, assoc} = DatasetAccessGroupRelation.new(%{dataset_id: dataset_id, access_group_id: access_group_id})
    allow(Andi.InputSchemas.Datasets.Dataset.associate_with_access_group(access_group_id, dataset_id), return: :ok)
    expect(TelemetryEvent.add_event_metrics(any(), [:events_handled]), return: :ok)

    event = Brook.Event.new(type: dataset_access_group_associate(), data: assoc, author: :author)
    EventHandler.handle_event(event)

    assert_called(Andi.InputSchemas.Datasets.Dataset.associate_with_access_group(access_group_id, dataset_id))
  end

  test "should successfully handle a dataset_access_group_disassociate() event" do
    dataset_id = UUID.uuid4()
    access_group_id = UUID.uuid4()
    {:ok, assoc} = SmartCity.DatasetAccessGroupRelation.new(%{dataset_id: dataset_id, access_group_id: access_group_id})
    allow(Andi.InputSchemas.Datasets.Dataset.disassociate_with_access_group(access_group_id, dataset_id), return: :ok)
    expect(TelemetryEvent.add_event_metrics(any(), [:events_handled]), return: :ok)

    Brook.Event.new(type: dataset_access_group_disassociate(), data: assoc, author: :author)
    |> EventHandler.handle_event()

    assert_called(Andi.InputSchemas.Datasets.Dataset.disassociate_with_access_group(access_group_id, dataset_id))
  end

  test "should successfully handle a user_access_group_associate() event" do
    user_id = UUID.uuid4()
    access_group_id = UUID.uuid4()
    {:ok, assoc} = SmartCity.UserAccessGroupRelation.new(%{subject_id: user_id, access_group_id: access_group_id})
    allow(Andi.Schemas.User.associate_with_access_group(user_id, access_group_id), return: :ok)
    expect(TelemetryEvent.add_event_metrics(any(), [:events_handled]), return: :ok)

    event = Brook.Event.new(type: user_access_group_associate(), data: assoc, author: :author)
    EventHandler.handle_event(event)

    assert_called(Andi.Schemas.User.associate_with_access_group(user_id, access_group_id))
  end

  test "should delete the view state and the postgres entry when ingestion delete event is called" do
    ingestion = TDG.create_ingestion(%{id: Faker.UUID.v4()})
    allow(IngestionStore.delete(any()), return: :ok)
    allow(Ingestions.delete(any()), return: {:ok, "good"})
    expect(TelemetryEvent.add_event_metrics(any(), [:events_handled]), return: :ok)

    Brook.Event.new(type: ingestion_delete(), data: ingestion, author: :author)
    |> EventHandler.handle_event()

    assert_called Ingestions.delete(ingestion.id)
    assert_called IngestionStore.delete(ingestion.id)
  end

  test "should update the view state and the postgres entry when ingestion update event is called" do
    ingestion = TDG.create_ingestion(%{id: Faker.UUID.v4()})
    allow(IngestionStore.update(any()), return: :ok)
    allow(Ingestions.update(any()), return: {:ok, "good"})
    allow(Ingestions.update_ingested_time(any(), any()), return: :ok)
    current_time = DateTime.utc_now()
    allow(DateTime.utc_now(), return: current_time)
    expect(TelemetryEvent.add_event_metrics(any(), [:events_handled]), return: :ok)

    Brook.Event.new(type: ingestion_update(), data: ingestion, author: :author)
    |> EventHandler.handle_event()

    assert_called Ingestions.update_ingested_time(ingestion.id, DateTime.utc_now())
    assert_called Ingestions.update(ingestion)
    assert_called IngestionStore.update(ingestion)
  end

  test "should delete the view state when dataset delete event is called" do
    dataset = TDG.create_dataset(%{id: Faker.UUID.v4()})
    allow(Brook.ViewState.delete(any(), any()), return: :ok)
    allow(Datasets.delete(any()), return: {:ok, "good"})
    allow(Organizations.delete_harvested_dataset(any()), return: any())
    expect(TelemetryEvent.add_event_metrics(any(), [:events_handled]), return: :ok)

    Brook.Event.new(type: dataset_delete(), data: dataset, author: :author)
    |> EventHandler.handle_event()

    assert_called Datasets.delete(dataset.id)
  end

  test "data_harvest_start event triggers harvesting" do
    org = TDG.create_organization(%{})
    allow(Harvester.start_harvesting(any()), return: :ok)

    Brook.Test.send(@instance_name, dataset_harvest_start(), :andi, org)

    eventually(fn ->
      assert_called(Harvester.start_harvesting(org))
    end)
  end

  describe "data harvest event is triggered when organization is updated" do
    test "data:harvest:start event is triggered" do
      allow(Brook.Event.send(@instance_name, dataset_harvest_start(), :andi, any()), return: :ok, meck_options: [:passthrough])
      allow(OrgStore.update(any()), return: :ok)
      allow(Organizations.update(any()), return: :ok)

      org = TDG.create_organization(%{dataJsonUrl: "www.google.com"})
      Brook.Event.send(@instance_name, organization_update(), :andi, org)

      assert_called(Brook.Event.send(@instance_name, dataset_harvest_start(), :andi, org), once())
    end

    test "data:harvest:start event isnt called for orgs missing data json url" do
      allow(Brook.Event.send(@instance_name, dataset_harvest_start(), :andi, any()), return: :ok, meck_options: [:passthrough])
      allow(OrgStore.update(any()), return: :ok)
      allow(Organizations.update(any()), return: :ok)

      org = TDG.create_organization(%{dataJsonUrl: nil})
      Brook.Event.send(@instance_name, organization_update(), :andi, org)

      refute_called(Brook.Event.send(@instance_name, dataset_harvest_start(), :andi, org), once())
    end
  end
end
