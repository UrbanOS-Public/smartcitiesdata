defmodule Andi.InputSchemas.ExtractSteps do
  @moduledoc false
  alias Andi.InputSchemas.Datasets.ExtractDateStep
  alias Andi.InputSchemas.Datasets.ExtractHttpStep
  alias Andi.Repo
  alias Andi.InputSchemas.StructTools

  import Ecto.Query, only: [from: 2]

  require Logger

  def get(extract_date_step_id, schema_module) do
    Repo.get(schema_module, extract_date_step_id)
    |> schema_module.preload()
  end

  #TODO revisit this
  def all_for_technical(technical_id) do
    http_step_query =
      from(http_step in ExtractHttpStep,
        where: http_step.technical_id == ^technical_id
      )

    date_step_query =
      from(date_step in ExtractDateStep,
        where: date_step.technical_id == ^technical_id,
      )

    Repo.all(date_step_query) ++ Repo.all(http_step_query)
  end

  def update(%struct{} = from_extract_step, changes) do
    changes_as_map = StructTools.to_map(changes)

    from_extract_step
    |> struct.changeset_for_draft(changes_as_map)
    |> Repo.insert_or_update()
  end

  def update(changes, schema_module) do
    from_step =
      case get(changes.id, schema_module) do
        nil -> struct(schema_module)
        struct -> struct
      end

    update(from_step, changes)
  end

  def changeset_for_draft(extract_steps) when is_list(extract_steps) do
    extract_steps
    |> Enum.map(fn step -> changeset_for_draft(step) end)
  end

  def changeset_for_draft(%struct{} = extract_step) do
    struct.changeset_for_draft(extract_step)
  end
end
