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
      ingestion_delete: 0,
      event_log_published: 0
    ]

  alias SmartCity.{Dataset, Organization, Ingestion, EventLog}
  alias SmartCity.UserOrganizationAssociate
  alias SmartCity.UserOrganizationDisassociate

  alias Andi.Services.DatasetStore
  alias Andi.Services.OrgStore
  alias Andi.Harvest.Harvester
  alias Andi.Schemas.User
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Organizations
  alias Andi.InputSchemas.Ingestions
  alias Andi.InputSchemas.EventLogs
  alias Andi.Services.IngestionStore

  @instance_name Andi.instance_name()

  def handle_event(%Brook.Event{type: dataset_update(), data: %Dataset{} = data, author: author}) do
    Logger.info("Dataset: #{data.id} - Received dataset_update event from #{author}")

    dataset_update()
    |> add_event_count(author, data.id)

    Andi.DatasetCache.add_dataset_info(data)

    Task.start(fn -> add_dataset_count() end)
    Datasets.update_ingested_time(data.id, DateTime.utc_now())

    Datasets.update(data)
    DatasetStore.update(data)
    :ok
  rescue
    error ->
      Logger.error("dataset_update failed to process: #{inspect(error)}")
      DeadLetter.process([data.id], nil, data, Atom.to_string(@instance_name), reason: inspect(error))
      :discard
  end

  def handle_event(%Brook.Event{type: event_log_published(), data: %SmartCity.EventLog{} = event_log, author: author}) do
    Logger.info("Dataset: #{event_log.dataset_id} - Received event_log_published event from #{author}")

    event_log_published()
    |> add_event_count(author, event_log.dataset_id)

    EventLogs.delete_all_before_date(7, "day")
    EventLogs.update(event_log)

    :ok
  rescue
    error ->
      Logger.error("Dataset ID: #{event_log.dataset_id}; Failed to write event to event log table: #{inspect(error)}")
      DeadLetter.process([event_log.dataset_id], nil, event_log, Atom.to_string(@instance_name), reason: inspect(error))
      :discard
  end

  def handle_event(%Brook.Event{type: ingestion_update(), data: %Ingestion{} = data, author: author}) do
    Logger.info("Ingestion: #{data.id} - Received ingestion_update event from #{author}")

    ingestion_update()
    |> add_event_count(author, data.id)

    IngestionStore.update(data)

    data
    |> Map.put(:ingestionTime, %{ingestionTime: DateTime.to_iso8601(DateTime.utc_now())})
    |> Ingestions.update()

    :ok
  rescue
    error ->
      Logger.error("ingestion_update failed to process: #{inspect(error)}")
      DeadLetter.process(data.targetDatasets, data.id, data, Atom.to_string(@instance_name), reason: inspect(error))
      :discard
  end

  def handle_event(%Brook.Event{type: ingestion_delete(), data: %Ingestion{} = data, author: author}) do
    Logger.info("Ingestion: #{data.id} - Received ingestion_delete event from #{author}")

    ingestion_delete()
    |> add_event_count(author, data.id)

    Ingestions.delete(data.id)
    IngestionStore.delete(data.id)

    :ok
  rescue
    error ->
      Logger.error("ingestion_delete failed to process: #{inspect(error)}")
      DeadLetter.process(data.targetDatasets, data.id, data, Atom.to_string(@instance_name), reason: inspect(error))
      :discard
  end

  def handle_event(%Brook.Event{type: organization_update(), data: %Organization{} = data, author: author}) do
    Logger.info("Organization: #{data.id} - Received organization_update event from #{author}")

    organization_update()
    |> add_event_count(author, data.id)

    data_harvest_event(data)

    Organizations.update(data)
    OrgStore.update(data)

    :ok
  rescue
    error ->
      Logger.error("organization_update failed to process: #{inspect(error)}")
      DeadLetter.process([], nil, data, Atom.to_string(@instance_name), reason: inspect(error))
      :discard
  end

  def handle_event(%Brook.Event{
        type: user_organization_associate(),
        data: %UserOrganizationAssociate{subject_id: subject_id, org_id: org_id, email: _email} = data,
        author: author
      }) do
    Logger.info("User: #{subject_id}; Organization: #{org_id} - Received user_organization_associate event from #{author}")

    user_organization_associate()
    |> add_event_count(author, nil)

    case User.associate_with_organization(subject_id, org_id) do
      {:error, error} ->
        Logger.error("Unable to associate user with organization #{org_id}: #{inspect(error)}. This event has been discarded.")

      _ ->
        :ok
    end

    :discard
  rescue
    error ->
      Logger.error("user_organization_associate failed to process: #{inspect(error)}")
      DeadLetter.process([], nil, data, Atom.to_string(@instance_name), reason: inspect(error))
      :discard
  end

  def handle_event(%Brook.Event{
        type: user_organization_disassociate(),
        data: %UserOrganizationDisassociate{subject_id: subject_id, org_id: org_id} = data,
        author: author
      }) do
    Logger.info("User: #{subject_id}; Organization: #{org_id} - Received user_organization_associate event from #{author}")

    user_organization_disassociate()
    |> add_event_count(author, nil)

    case User.disassociate_with_organization(subject_id, org_id) do
      {:error, error} ->
        Logger.error("Unable to disassociate user with organization #{org_id}: #{inspect(error)}. This event has been discarded.")

      _ ->
        :ok
    end

    :discard
  rescue
    error ->
      Logger.error("user_organization_disassociate failed to process: #{inspect(error)}")
      DeadLetter.process([], nil, data, Atom.to_string(@instance_name), reason: inspect(error))
      :discard
  end

  def handle_event(%Brook.Event{type: dataset_harvest_start(), data: %Organization{} = data, author: author}) do
    Logger.info("Organization: #{data.id} - Received dataset_harvest_start event from #{author}")

    dataset_harvest_start()
    |> add_event_count(author, data.id)

    Task.start_link(Harvester, :start_harvesting, [data])

    :discard
  rescue
    error ->
      Logger.error("dataset_harvest_start failed to process: #{inspect(error)}")
      DeadLetter.process([], nil, data, Atom.to_string(@instance_name), reason: inspect(error))
      :discard
  end

  def handle_event(%Brook.Event{type: dataset_harvest_end(), data: data}) do
    Logger.info("Dataset: #{data.id} - Received dataset_harvest_end event")

    Organizations.update_harvested_dataset(data)
    :discard
  rescue
    error ->
      Logger.error("dataset_harvest_end failed to process: #{inspect(error)}")
      DeadLetter.process([], nil, data, Atom.to_string(@instance_name), reason: inspect(error))
      :discard
  end

  def handle_event(%Brook.Event{type: "migration:modified_date:start", author: author} = event) do
    Logger.info("Received migration:modified_date:start event from #{author}")

    "migration:modified_date:start"
    |> add_event_count(author, nil)

    Andi.Migration.ModifiedDateMigration.do_migration()
    {:create, :migration, "modified_date_migration_completed", true}
  rescue
    error ->
      Logger.error("migration_modified_date_start failed to process: #{inspect(error)}")
      DeadLetter.process([], nil, event, Atom.to_string(@instance_name), reason: inspect(error))
      :discard
  end

  def handle_event(%Brook.Event{type: data_ingest_end(), data: %Dataset{id: id} = data, create_ts: create_ts, author: author}) do
    Logger.info("Dataset: #{id} - Received data_ingest_end event from #{author}")

    data_ingest_end()
    |> add_event_count(author, id)

    {:create, :ingested_time, id, %{"id" => id, "ingested_time" => create_ts}}
  rescue
    error ->
      Logger.error("data_ingest_end failed to process: #{inspect(error)}")
      DeadLetter.process([id], nil, data, Atom.to_string(@instance_name), reason: inspect(error))
      :discard
  end

  def handle_event(%Brook.Event{
        type: dataset_delete(),
        data: %Dataset{id: id} = data,
        author: author
      }) do
    Logger.info("Dataset: #{id} - Received dataset_delete event from #{author}")

    dataset_delete()
    |> add_event_count(author, data.id)

    Task.start(fn -> add_dataset_count() end)

    remove_dataset_from_ingestions(data)

    Datasets.delete(data.id)
    DatasetStore.delete(data.id)

    :ok
  rescue
    error ->
      Logger.error("dataset_delete failed to process: #{inspect(error)}")
      DeadLetter.process([data.id], nil, data, Atom.to_string(@instance_name), reason: inspect(error))
      :discard
  end

  def handle_event(%Brook.Event{type: user_login(), data: %{subject_id: subject_id, email: email, name: name} = data, author: author}) do
    Logger.info("User: #{subject_id}; Email: #{email}; Name: #{name} - Received user_login event from #{author}")

    user_login()
    |> add_event_count(author, nil)

    create_user_if_not_exists(subject_id, email, name)
    :ok
  rescue
    error ->
      Logger.error("user_login failed to process: #{inspect(error)}")
      DeadLetter.process([], nil, data, Atom.to_string(@instance_name), reason: inspect(error))
      :discard
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

  defp remove_dataset_from_ingestions(%Dataset{} = data) do
    Ingestions.get_all()
    |> Enum.filter(fn andi_ingestion -> Enum.member?(andi_ingestion.targetDatasets, data.id) end)
    |> Enum.map(fn andi_ingestion ->
      Map.update(andi_ingestion, :targetDatasets, [], fn datasets -> List.delete(datasets, data.id) end)
    end)
    |> Enum.each(fn
      %{submissionStatus: :published, targetDatasets: targetDatasets} = andi_ingestion ->
        updated_andi_ingestion =
          case Enum.empty?(andi_ingestion.targetDatasets) do
            true -> Map.put(andi_ingestion, :submissionStatus, :draft)
            false -> andi_ingestion
          end

        case Ingestions.update(updated_andi_ingestion) do
          {:ok, ingestion} ->
            :ok

          {:error, changeset} ->
            raise "Dataset #{data.id} could not be removed from Ingestion #{andi_ingestion.id} due to #{inspect(changeset.errors)}"
        end

        Brook.Event.send(@instance_name, ingestion_update(), :andi, updated_andi_ingestion)

      %{submissionStatus: :draft} = andi_ingestion ->
        case Ingestions.update(andi_ingestion) do
          {:ok, ingestion} ->
            :ok

          {:error, changeset} ->
            raise "Dataset #{data.id} could not be removed from Ingestion #{andi_ingestion.id} due to #{inspect(changeset.errors)}"
        end
    end)
  end
end
