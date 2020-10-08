defmodule Andi.InputSchemas.Datasets.ExtractHttpStep do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias Andi.InputSchemas.Datasets.ExtractQueryParam
  alias Andi.InputSchemas.Datasets.ExtractHeader
  alias Andi.InputSchemas.Datasets.Technical
  alias Andi.InputSchemas.StructTools

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  schema "extract_http_step" do
    field(:assigns, :map)
    field(:body, :string)
    field(:method, :string)
    field(:type, :string)
    field(:url, :string)
    has_many(:headers, ExtractHeader, on_replace: :delete)
    has_many(:queryParams, ExtractQueryParam, on_replace: :delete)
    belongs_to(:technical, Technical, type: Ecto.UUID, foreign_key: :technical_id)
  end

  use Accessible

  @cast_fields [:id, :type, :method, :url, :body, :assigns]
  @required_fields [:type, :method, :url, :assigns]

  def changeset(changes), do: changeset(%__MODULE__{}, changes)

  def changeset(extract_step, changes) do
    changes_with_id = StructTools.ensure_id(extract_step, changes)

    extract_step
    |> cast(changes_with_id, @cast_fields, empty_values: [])
    |> cast_assoc(:headers, with: &ExtractHeader.changeset/2)
    |> cast_assoc(:queryParams, with: &ExtractQueryParam.changeset/2)
    |> validate_required(@required_fields, message: "is required")
  end
end
