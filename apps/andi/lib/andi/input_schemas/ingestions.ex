defmodule Andi.InputSchemas.Ingestions do
  @moduledoc false
  alias Andi.InputSchemas.Ingestion
  alias Andi.Repo
  alias Andi.InputSchemas.InputConverter
  alias Andi.InputSchemas.StructTools

  use Properties, otp_app: :andi

  import Ecto.Query, only: [from: 2]

  require Logger

  def get(nil), do: nil

  def get(id) do
    Repo.get(Ingestion, id)
    |> Ingestion.preload()
  end

  def get_all() do
    query =
      from(ingestion in Ingestion,
        join: extractSteps in assoc(ingestion, :extractSteps),
        join: schema in assoc(ingestion, :schema),
        preload: [extractSteps: extractSteps, schema: schema]
      )

    Repo.all(query)
  end

  def create(dataset_id) do
    new_ingestion_id = UUID.uuid4()

    new_changeset =
      Ingestion.changeset_for_draft(
        %Ingestion{},
        %{
          id: new_ingestion_id,
          targetDataset: dataset_id
        }
      )

    {:ok, new_ingestion} = save(new_changeset)
    new_ingestion
  end

  def create() do
    new_ingestion_id = UUID.uuid4()

    new_changeset =
      Ingestion.changeset_for_draft(
        %Ingestion{},
        %{
          id: new_ingestion_id
        }
      )

    {:ok, new_ingestion} = save(new_changeset)
    new_ingestion
  end

  def update(%SmartCity.Ingestion{} = smrt_ingestion) do
    andi_ingestion =
      case get(smrt_ingestion.id) do
        nil -> %Ingestion{}
        ingestion -> ingestion
      end

    changes = InputConverter.prepare_smrt_ingestion_for_casting(smrt_ingestion)

    andi_ingestion
    |> Andi.Repo.preload([:extractSteps, :schema, :transformations])
    |> Ingestion.changeset(changes)
    |> save()
  end

  def update(%Ingestion{} = andi_ingestion) do
    original_ingestion =
      case get(andi_ingestion.id) do
        nil -> %Ingestion{}
        ingestion -> ingestion
      end

    update(original_ingestion, andi_ingestion)
  end

  def update(%Ingestion{} = from_ingestion, changes) do
    changes_as_map = StructTools.to_map(changes)

    from_ingestion
    |> Andi.Repo.preload([:extractSteps, :schema])
    |> Ingestion.changeset_for_draft(changes_as_map)
    |> save()
  end

  def save(%Ecto.Changeset{} = changeset) do
    Repo.insert_or_update(changeset)
  end

  def save_form_changeset(ingestion_id, form_changeset) do
    form_changes = InputConverter.form_changes_from_changeset(form_changeset)
    update_from_form(ingestion_id, form_changes)
  end

  def update_from_form(ingestion_id, form_changes) do
    existing_ingestion = get(ingestion_id)
    changeset = InputConverter.andi_ingestion_to_full_ui_changeset(existing_ingestion)

    ingestion_changes =
      changeset
      |> Map.merge(form_changes)

    update(existing_ingestion, ingestion_changes)
  end

  def update_cadence(ingestion_id, cadence) do
    from_ingestion = get(ingestion_id) || %Ingestion{id: ingestion_id}

    updated = Map.put(from_ingestion, :cadence, cadence)

    update(from_ingestion, updated)
  end

  # Todo: Internal/#540 handle dlq messages when dataset info is what's provided
  # def update_latest_dlq_message(%{"dataset_id" => dataset_id} = message) do
  #   case get(dataset_id) do
  #     nil -> Logger.info("Message does not pertain to any andi dataset: #{inspect(message)}")
  #     dataset -> update(dataset, %{dlq_message: message})
  #   end
  # end

  def delete(ingestion_id) do
    Repo.delete(%Ingestion{id: ingestion_id})
  rescue
    _e in Ecto.StaleEntryError ->
      {:error, "attempted to remove an ingestion (id: #{ingestion_id}) that does not exist."}
  end

  def full_validation_changeset_for_publish(schema, changes) do
    Ingestion.changeset(schema, changes)
  end

  def full_validation_submission_changeset_for_publish(schema, changes) do
    Ingestion.submission_changeset(schema, changes)
  end

  def update_ingested_time(ingestion_id, ingested_time) do
    from_ingestion = get(ingestion_id) || %Ingestion{id: ingestion_id}
    iso_ingested_time = DateTime.to_iso8601(ingested_time)

    update(from_ingestion, %{ingestedTime: iso_ingested_time})
  end
end
