defmodule Andi.InputSchemas.Datasets do
  @moduledoc false
  alias Andi.InputSchemas.Datasets.Dataset
  alias Andi.InputSchemas.Datasets.Header
  alias Andi.InputSchemas.Datasets.QueryParam
  alias Andi.Repo
  alias Andi.InputSchemas.InputConverter
  alias Andi.InputSchemas.StructTools
  alias Ecto.Changeset

  import Ecto.Query, only: [from: 2]

  require Logger

  def get(nil), do: nil

  def get(id) do
    Repo.get(Dataset, id)
    |> Dataset.preload()
  end

  def get_all() do
    query =
      from(dataset in Dataset,
        join: technical in assoc(dataset, :technical),
        join: business in assoc(dataset, :business),
        preload: [business: business, technical: technical]
      )

    Repo.all(query)
  end

  def create(owner) do
    current_date = Date.utc_today()
    new_dataset_id = UUID.uuid4()
    new_dataset_title = "New Dataset - #{current_date}"
    new_dataset_name = data_title_to_data_name(new_dataset_title)

    new_changeset =
      Dataset.changeset_for_draft(
        %Dataset{},
        %{
          id: new_dataset_id,
          business: %{dataTitle: new_dataset_title, contactEmail: owner.email, issuedDate: current_date, modifiedDate: current_date},
          technical: %{dataName: new_dataset_name},
          owner: owner
        }
      )

    {:ok, new_dataset} = save(new_changeset)
    new_dataset
  end

  def update(%SmartCity.Dataset{} = smrt_dataset) do
    andi_dataset =
      case get(smrt_dataset.id) do
        nil -> %Dataset{}
        dataset -> dataset
      end

    changes = InputConverter.prepare_smrt_dataset_for_casting(smrt_dataset)

    andi_dataset
    |> Andi.Repo.preload([:business, :technical])
    |> Dataset.changeset_for_draft(changes)
    |> save()
  end

  def update(%Dataset{} = andi_dataset) do
    original_dataset =
      case get(andi_dataset.id) do
        nil -> %Dataset{}
        dataset -> dataset
      end

    update(original_dataset, andi_dataset)
  end

  def update(%Dataset{} = from_dataset, changes) do
    changes_as_map = StructTools.to_map(changes)

    from_dataset
    |> Andi.Repo.preload([:business, :technical])
    |> Dataset.changeset_for_draft(changes_as_map)
    |> save()
  end

  def save(%Ecto.Changeset{} = changeset) do
    Repo.insert_or_update(changeset)
  end

  def save_form_changeset(dataset_id, form_changeset) do
    form_changes = InputConverter.form_changes_from_changeset(form_changeset)
    update_from_form(dataset_id, form_changes)
  end

  def update_from_form(dataset_id, form_changes) do
    existing_dataset = get(dataset_id)
    changeset = InputConverter.andi_dataset_to_full_ui_changeset(existing_dataset)

    technical_changes =
      changeset
      |> Changeset.get_change(:technical)
      |> Changeset.apply_changes()
      |> StructTools.to_map()
      |> Map.merge(form_changes)

    business_changes =
      changeset
      |> Changeset.get_change(:business)
      |> Changeset.apply_changes()
      |> StructTools.to_map()
      |> Map.merge(form_changes)

    new_changes = %{technical: technical_changes, business: business_changes, id: dataset_id} |> StructTools.to_map()

    existing_dataset
    |> Andi.Repo.preload([:business, :technical])
    |> Dataset.changeset_for_draft(new_changes)
    |> save()
  end

  def update_ingested_time(dataset_id, ingested_time) do
    from_dataset = get(dataset_id) || %Dataset{id: dataset_id}
    iso_ingested_time = DateTime.to_iso8601(ingested_time)

    update(from_dataset, %{ingestedTime: iso_ingested_time})
  end

  def update_cadence(dataset_id, cadence) do
    from_dataset = get(dataset_id) || %Dataset{id: dataset_id}

    updated =
      Map.update!(from_dataset, :technical, fn technical ->
        Map.put(technical, :cadence, cadence)
      end)

    update(from_dataset, updated)
  end

  def update_latest_dlq_message(%{"dataset_id" => dataset_id} = message) do
    case get(dataset_id) do
      nil -> Logger.info("Message does not pertain to any andi dataset: #{inspect(message)}")
      dataset -> update(dataset, %{dlq_message: message})
    end
  end

  def delete(dataset_id) do
    Repo.delete(%Dataset{id: dataset_id})
  rescue
    _e in Ecto.StaleEntryError ->
      {:error, "attempted to remove a dataset (id: #{dataset_id}) that does not exist."}
  end

  def add_source_header(dataset_id) do
    from_dataset = get(dataset_id)

    added =
      Map.update!(from_dataset, :technical, fn technical ->
        Map.update(technical, :sourceHeaders, [%Header{}], fn source_headers ->
          source_headers ++ [%Header{}]
        end)
      end)

    update(from_dataset, added)
  end

  def add_source_query_param(dataset_id) do
    from_dataset = get(dataset_id)

    added =
      Map.update!(from_dataset, :technical, fn technical ->
        Map.update(technical, :sourceQueryParams, [%QueryParam{}], fn source_query_params ->
          source_query_params ++ [%QueryParam{}]
        end)
      end)

    update(from_dataset, added)
  end

  def remove_source_header(dataset_id, source_header_id) do
    Repo.delete(%Header{id: source_header_id})

    {:ok, get(dataset_id)}
  rescue
    _e in Ecto.StaleEntryError ->
      Logger.error("attempted to remove a source header (id: #{source_header_id}) that does not exist.")
      {:ok, get(dataset_id)}
  end

  def remove_source_query_param(dataset_id, source_query_param_id) do
    Repo.delete(%QueryParam{id: source_query_param_id})

    from_dataset = get(dataset_id)

    updated =
      Map.update!(from_dataset, :technical, fn technical ->
        Map.update(technical, :sourceUrl, "", fn source_url ->
          Andi.URI.update_url_with_params(source_url, Map.get(technical, :sourceQueryParams, []))
        end)
      end)

    update(from_dataset, updated)
  rescue
    _e in Ecto.StaleEntryError ->
      Logger.error("attempted to remove a source query param (id: #{source_query_param_id}) that does not exist.")
      {:ok, get(dataset_id)}
  end

  def is_unique?(_id, data_name, org_name) when is_nil(data_name) or is_nil(org_name), do: true

  def is_unique?(id, data_name, org_name) do
    from(technical in Andi.InputSchemas.Datasets.Technical,
      where: technical.dataName == ^data_name and technical.orgName == ^org_name and technical.dataset_id != ^id
    )
    |> Repo.all()
    |> Enum.empty?()
  end

  def data_title_to_data_name(data_title) do
    data_title
    |> String.replace(" ", "_", global: true)
    |> String.replace(~r/[^[:alnum:]_]/, "", global: true)
    |> String.replace(~r/_+/, "_", global: true)
    |> String.downcase()
  end
end
