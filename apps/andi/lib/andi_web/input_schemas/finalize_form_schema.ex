defmodule AndiWeb.InputSchemas.FinalizeFormSchema do
  @moduledoc false

  use Ecto.Schema
  alias Ecto.Changeset

  alias Andi.InputSchemas.StructTools
  alias Andi.Schemas.Validation.CadenceValidator

  embedded_schema do
    field(:cadence, :string)
  end

  def changeset(current, changes) do
    current
    |> Changeset.cast(changes, [:cadence])

    # |> Changeset.validate_required(:cadence, message: "is required")
  end

  # def changeset_from_andi_dataset(dataset) do
  #   dataset = StructTools.to_map(dataset)
  #   technical_changes = dataset.technical

  #   changeset(technical_changes)
  # end

  # def changeset_from_andi_ingestion(ingestion) do
  #   ingestion = StructTools.to_map(ingestion)

  #   changeset(ingestion)
  # end

  # def changeset_from_form_data(form_data) do
  #   form_data
  #   |> AtomicMap.convert(safe: false, underscore: false)
  #   |> changeset()
  # end

  def extract_from_ingestion_changeset(%Ecto.Changeset{data: %Andi.InputSchemas.Ingestion{}} = ingestion_changeset) do
    ingestion_data =
      ingestion_changeset
      |> Changeset.apply_changes()

    extracted_data = %__MODULE__{
      cadence: ingestion_data.cadence
    }

    mapped_errors =
      ingestion_changeset.errors
      |> Enum.map(fn
        {:cadence, {msg, opts}} -> {:cadence, {msg, opts}}
        _other_errors -> nil
      end)
      |> Enum.reject(&is_nil/1)

    changeset(extracted_data, %{})
    |> Map.put(:errors, mapped_errors)
    |> Map.put(:action, :display_errors)
  end
end
