defmodule Andi.InputSchemas.ExtractSteps do
  @moduledoc false
  alias Andi.InputSchemas.Datasets.ExtractDateStep
  alias Andi.InputSchemas.Datasets.ExtractHttpStep
  alias Andi.InputSchemas.Datasets.ExtractStep
  alias Andi.Repo
  alias Andi.InputSchemas.StructTools

  import Ecto.Query, only: [from: 2]

  require Logger

  # TODO test this
  def create(step_type, technical_id) do
    changes =
      %{type: step_type, context: %{}, technical_id: technical_id}
      |> ExtractStep.changeset()
      |> Ecto.Changeset.apply_changes()
      |> StructTools.to_map()

    update(%ExtractStep{}, changes)
  end

  def get(extract_date_step_id) do
    Repo.get(ExtractStep, extract_date_step_id)
    |> ExtractStep.preload()
  end

  def all_for_technical(technical_id) do
    query =
      from(extract_step in ExtractStep,
        where: extract_step.technical_id == ^technical_id
      )

    Repo.all(query)
  end

  def update(changes) do
    from_step =
      case get(changes.id) do
        nil -> %ExtractStep{}
        struct -> struct
      end

    update(from_step, changes)
  end

  def update(from_extract_step, changes) do
    changes_as_map = StructTools.to_map(changes)

    from_extract_step
    |> ExtractStep.changeset_for_draft(changes_as_map)
    |> Repo.insert_or_update()
  end

  def add_extract_header(extract_http_step_id) do
    from_extract_step = get(extract_http_step_id) |> IO.inspect()

    # added =
    #   Map.update(from_extract_step, :headers, [%ExtractHeader{}], fn extract_headers ->
    #     extract_headers ++ [%ExtractHeader{}]
    #   end)

    # update(from_extract_step, added)
  end

  def add_extract_query_param(extract_http_step_id) do
    from_extract_step = get(extract_http_step_id) |> IO.inspect()

    # added =
    #   Map.update(from_extract_step, :queryParams, [%ExtractQueryParam{}], fn extract_query_params ->
    #     extract_query_params ++ [%ExtractQueryParam{}]
    #   end)

    # update(from_extract_step, added)
  end

  # def remove_extract_query_param(extract_step_id, extract_query_param_id) do
  #   Repo.delete(%ExtractQueryParam{id: extract_query_param_id})
  #   from_extract_step = get(extract_step_id)

  #   updated =
  #     Map.update(from_extract_step, :url, [], fn url ->
  #       Andi.URI.update_url_with_params(url, from_extract_step.queryParams)
  #     end)

  #   update(from_extract_step, updated)
  # rescue
  #   _e in Ecto.StaleEntryError ->
  #     Logger.error("attempted to remove a source query param (id: #{extract_query_param_id}) that does not exist.")
  #     {:ok, get(extract_step_id)}
  # end

  # def remove_extract_header(extract_step_id, extract_header_id) do
  #   Repo.delete(%ExtractHeader{id: extract_header_id})

  #   {:ok, get(extract_step_id)}
  # rescue
  #   _e in Ecto.StaleEntryError ->
  #     Logger.error("attempted to remove a source query param (id: #{extract_header_id}) that does not exist.")
  #     {:ok, get(extract_step_id)}
  # end
end
