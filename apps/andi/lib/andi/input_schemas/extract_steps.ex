defmodule Andi.InputSchemas.ExtractSteps do
  @moduledoc false
  alias Andi.InputSchemas.Datasets.ExtractHttpStep
  alias Andi.InputSchemas.Datasets.ExtractHeader
  alias Andi.InputSchemas.Datasets.ExtractQueryParam
  alias Andi.Repo
  alias Andi.InputSchemas.StructTools

  import Ecto.Query, only: [from: 2]

  require Logger

  def get(extract_http_step_id) do
    Repo.get(ExtractHttpStep, extract_http_step_id)
    |> ExtractHttpStep.preload()
  end

  def update(%ExtractHttpStep{} = from_extract_step, changes) do
    changes_as_map = StructTools.to_map(changes)

    from_extract_step
    |> ExtractHttpStep.changeset_for_draft(changes_as_map)
    |> Repo.insert_or_update()
  end

  def add_extract_header(extract_http_step_id) do
    from_extract_step = get(extract_http_step_id)

    added =
      Map.update(from_extract_step, :headers, [%ExtractHeader{}], fn extract_headers ->
        extract_headers ++ [%ExtractHeader{}]
      end)

    update(from_extract_step, added)
  end

  def add_extract_query_param(extract_http_step_id) do
    from_extract_step = get(extract_http_step_id)

    added =
      Map.update(from_extract_step, :queryParams, [%ExtractQueryParam{}], fn extract_query_params ->
        extract_query_params ++ [%ExtractQueryParam{}]
      end)

    update(from_extract_step, added)
  end

  def remove_extract_query_param(extract_step_id, extract_query_param_id) do
    Repo.delete(%ExtractQueryParam{id: extract_query_param_id})
    from_extract_step = get(extract_step_id)

    updated = Map.update(from_extract_step, :url, [], fn url ->
      Andi.URI.update_url_with_params(url, from_extract_step.queryParams)
    end)

    update(from_extract_step, updated)
  rescue
    _e in Ecto.StaleEntryError ->
      Logger.error("attempted to remove a source query param (id: #{extract_query_param_id}) that does not exist.")
      {:ok, get(extract_step_id)}
  end

  def remove_extract_header(extract_step_id, extract_header_id) do
    Repo.delete(%ExtractHeader{id: extract_header_id})

    {:ok, get(extract_step_id)}
  rescue
    _e in Ecto.StaleEntryError ->
      Logger.error("attempted to remove a source query param (id: #{extract_header_id}) that does not exist.")
    {:ok, get(extract_step_id)}
  end

end
