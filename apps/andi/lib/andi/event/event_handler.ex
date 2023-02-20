defmodule Andi.Event.EventHandler do
  @moduledoc "Event Handler for event stream"
  alias DeadLetter

  use Brook.Event.Handler

  require Logger

  import SmartCity.Event,
    only: [
      dataset_update: 0,
      organization_update: 0,
      user_organization_associate: 0,
      user_organization_disassociate: 0,
      data_ingest_end: 0,
      dataset_delete: 0,
      dataset_harvest_start: 0,
      dataset_harvest_end: 0,
      user_login: 0,
      ingestion_update: 0,
      ingestion_delete: 0
    ]

  alias SmartCity.{Dataset, Organization, Ingestion}
  alias SmartCity.UserOrganizationAssociate
  alias SmartCity.UserOrganizationDisassociate

  alias Andi.Services.DatasetStore
  alias Andi.Services.OrgStore
  alias Andi.Harvest.Harvester
  alias Andi.Schemas.User
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Organizations
  alias Andi.InputSchemas.Ingestions
  alias Andi.Services.IngestionStore

  @instance_name Andi.instance_name()

  def handle_event(%Brook.Event{type: dataset_update(), data: %Dataset{} = data, author: author}) do
    dataset_update()
    |> add_event_count(author, data.id)

    Andi.DatasetCache.add_dataset_info(data)

    Task.start(fn -> add_dataset_count() end)
    Datasets.update_ingested_time(data.id, DateTime.utc_now())

    Datasets.update(data)
    DatasetStore.update(data)
    IO.inspect("FINISHED", label: "RYAN - FINISHED")
    :ok
  end

  def handle_event(%Brook.Event{type: ingestion_update(), data: %Ingestion{} = data, author: author}) do
    ingestion_update()
    |> add_event_count(author, data.id)

    0/0

    data
    |> Map.put(:ingestionTime, %{ingestionTime: DateTime.to_iso8601(DateTime.utc_now())})
    |> Ingestions.update()

    IngestionStore.update(data)

  rescue
    _e ->
      Logger.error("Message failed to process.")
      DeadLetter.process("DatasetIDHere", "IngestionIDHere", "ValueHere", "Andi", reason: "For Science")
      :discard
  end

  def handle_event(%Brook.Event{
        type: ingestion_delete(),
        data: %Ingestion{} = ingestion,
        author: author
      }) do
    ingestion_delete()
    |> add_event_count(author, ingestion.id)

    Ingestions.delete(ingestion.id)
    IngestionStore.delete(ingestion.id)
  end

  def handle_event(%Brook.Event{type: organization_update(), data: %Organization{} = data, author: author}) do
    organization_update()
    |> add_event_count(author, data.id)

    data_harvest_event(data)

    Organizations.update(data)
    OrgStore.update(data)
  end

  def handle_event(%Brook.Event{
        type: user_organization_associate(),
        data: %UserOrganizationAssociate{subject_id: subject_id, org_id: org_id, email: _email},
        author: author
      }) do
    user_organization_associate()
    |> add_event_count(author, nil)

    case User.associate_with_organization(subject_id, org_id) do
      {:error, error} ->
        Logger.error("Unable to associate user with organization #{org_id}: #{inspect(error)}. This event has been discarded.")

      _ ->
        :ok
    end

    :discard
  end

  def handle_event(
        %Brook.Event{type: user_organization_disassociate(), data: %UserOrganizationDisassociate{} = disassociation, author: author} =
          _event
      ) do
    user_organization_disassociate()
    |> add_event_count(author, nil)

    case User.disassociate_with_organization(disassociation.subject_id, disassociation.org_id) do
      {:error, error} ->
        Logger.error(
          "Unable to disassociate user with organization #{disassociation.org_id}: #{inspect(error)}. This event has been discarded."
        )

      _ ->
        :ok
    end

    :discard
  end

  def handle_event(%Brook.Event{type: dataset_harvest_start(), data: %Organization{} = data, author: author}) do
    dataset_harvest_start()
    |> add_event_count(author, data.id)

    Task.start_link(Harvester, :start_harvesting, [data])

    :discard
  end

  def handle_event(%Brook.Event{type: dataset_harvest_end(), data: data}) do
    Organizations.update_harvested_dataset(data)
    :discard
  end

  def handle_event(%Brook.Event{type: "migration:modified_date:start", author: author}) do
    "migration:modified_date:start"
    |> add_event_count(author, nil)

    Andi.Migration.ModifiedDateMigration.do_migration()
    {:create, :migration, "modified_date_migration_completed", true}
  end

  def handle_event(%Brook.Event{type: data_ingest_end(), data: %Dataset{id: id}, create_ts: create_ts, author: author}) do
    data_ingest_end()
    |> add_event_count(author, id)

    {:create, :ingested_time, id, %{"id" => id, "ingested_time" => create_ts}}
  end

  def handle_event(%Brook.Event{
        type: dataset_delete(),
        data: %Dataset{} = dataset,
        author: author
      }) do
    dataset_delete()
    |> add_event_count(author, dataset.id)

    Task.start(fn -> add_dataset_count() end)
    Datasets.delete(dataset.id)
    DatasetStore.delete(dataset.id)
  end

  def handle_event(%Brook.Event{type: user_login(), data: %{subject_id: subject_id, email: email, name: name}, author: author}) do
    user_login()
    |> add_event_count(author, nil)

    create_user_if_not_exists(subject_id, email, name)
  end

  defp create_user_if_not_exists(subject_id, email, name) do
    case User.get_by_subject_id(subject_id) do
      nil ->
        User.create_or_update(subject_id, %{subject_id: subject_id, email: email, name: name})
        :ok

      _user ->
        :ok
    end
  end

  defp add_event_count(event_type, author, dataset_id) do
    [
      app: "andi",
      author: author,
      dataset_id: dataset_id,
      event_type: event_type
    ]
    |> TelemetryEvent.add_event_metrics([:events_handled])
  end

  defp add_dataset_count() do
    # This will sleep for 5 seconds, before getting most recently updated dataset count by the Brook Event
    Process.sleep(5_000)

    count =
      DatasetStore.get_all!()
      |> Enum.count()

    [
      app: "andi"
    ]
    |> TelemetryEvent.add_event_metrics([:dataset_total], value: %{count: count})
  end

  defp data_harvest_event(org) do
    case org.dataJsonUrl do
      nil -> :ok
      _ -> Brook.Event.send(@instance_name, dataset_harvest_start(), :andi, org)
    end
  end
end
