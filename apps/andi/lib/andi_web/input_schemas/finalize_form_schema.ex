defmodule AndiWeb.InputSchemas.FinalizeFormSchema do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Andi.InputSchemas.StructTools
  alias Andi.Schemas.Validation.CadenceValidator

  embedded_schema do
    field(:cadence, :string)
  end

  def changeset(changes), do: changeset(%__MODULE__{}, changes)
  def changeset(%__MODULE__{} = current, %{"cadence" => cadence}), do: changeset(current, %{cadence: cadence})

  def changeset(%__MODULE__{} = current, changes) do
    current
    |> cast(changes, [:cadence])
    |> validate_required(:cadence, message: "is required")
    |> CadenceValidator.validate()
  end

  def changeset_from_andi_dataset(dataset) do
    dataset = StructTools.to_map(dataset)
    technical_changes = dataset.technical

    changeset(technical_changes)
  end

  def changeset_from_form_data(form_data) do
    form_data
    |> AtomicMap.convert(safe: false, underscore: false)
    |> changeset()
  end
end
