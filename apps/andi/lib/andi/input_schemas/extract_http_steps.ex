defmodule Andi.InputSchemas.ExtractHttpSteps do
  @moduledoc false
  alias Andi.InputSchemas.Datasets.ExtractHttpStep
  alias Andi.Repo
  alias Andi.InputSchemas.StructTools

  import Ecto.Query, only: [from: 2]

  require Logger

  def get(extract_http_step_id) do
    Repo.get(ExtractHttpStep, extract_http_step_id)
    |> ExtractHttpStep.preload()
  end

  def all_for_technical(technical_id) do
    query =
      from(httpStep in ExtractHttpStep,
        where: httpStep.technical_id == ^technical_id
      )

    Repo.all(query)
  end

  def update(changes) do
    from_step =
      case get(changes.id) do
        nil -> %ExtractHttpStep{}
        struct -> struct
      end

    update(from_step, changes)
  end

  def update(%ExtractHttpStep{} = from_extract_step, changes) do
    changes_as_map = StructTools.to_map(changes)

    from_extract_step
    |> ExtractHttpStep.changeset_for_draft(changes_as_map)
    |> Repo.insert_or_update()
  end
end
