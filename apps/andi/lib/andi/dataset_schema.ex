defmodule Andi.DatasetSchema do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    embeds_one(:technical, Andi.DatasetTechnicalSchema)
    embeds_one(:business, Andi.DatasetBusinessSchema)
  end

  def changeset(params \\ %{}) do
    %Andi.DatasetSchema{}
    |> cast(params, [:id])
    |> cast_embed(:technical)
    |> cast_embed(:business)
  end
end

defmodule Andi.DatasetTechnicalSchema do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field(:allow_duplicates, :boolean)
    field(:authHeaders, :map)
    field(:authUrl, :string)
    field(:cadence, :string)
    field(:credentials, :boolean)
    field(:dataName, :string)
    field(:orgId, :string)
    field(:orgName, :string)
    field(:private, :boolean)
    field(:protocol, :string)
    field(:schema, {:array, :map})
    field(:sourceFormat, :string)
    field(:sourceHeaders, :map)
    field(:sourceQueryParams, :map)
    field(:sourceType, :string)
    field(:sourceUrl, :string)
    field(:systemName, :string)
    field(:topLevelSelector, :string)
  end

  def changeset(tech, params \\ %{}) do
    tech
    |> cast(params, __MODULE__.__schema__(:fields))
    |> validate_required([:sourceFormat], message: "Format is required.")
  end
end

defmodule Andi.DatasetBusinessSchema do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field(:authorEmail, :string, default: nil)
    field(:authorName, :string)
    field(:categories, :string)
    field(:conformsToUri, :string)
    field(:contactEmail, :string)
    field(:contactName, :string)
    field(:dataTitle, :string)
    field(:describedByMimeType, :string)
    field(:describedByUrl, :string)
    field(:description, :string)
    field(:homepage, :string)
    field(:issuedDate, :string)
    field(:keywords, {:array, :string})
    field(:language, :string)
    field(:license, :string)
    field(:modifiedDate, :string)
    field(:orgTitle, :string)
    field(:parentDataset, :string)
    field(:publishFrequency, :string)
    field(:referenceUrls, :string)
    field(:rights, :string)
    field(:spatial, :string)
    field(:temporal, :string)
  end

  def changeset(biz, params \\ %{}) do
    biz
    |> cast(params, __MODULE__.__schema__(:fields))
    |> validate_required([:dataTitle], message: "Dataset Title is required.")
    |> validate_required([:description], message: "Description is required.")
    |> validate_required([:contactName], message: "Maintainer Name is required.")
    |> validate_required([:contactEmail], message: "Maintainer Email is required.")
    |> validate_format(:contactEmail, ~r/^[A-Za-z0-9._%+-+']+@[A-Za-z0-9.-]+\.[A-Za-z]+$/, message: "Email is invalid.")
    |> validate_required([:issuedDate], message: "Release Date is required.")
    |> validate_required([:license], message: "License is required.")
    |> validate_required([:publishFrequency], message: "Publish Frequency is required.")
    |> validate_required([:orgTitle], message: "Organization is required.")
  end
end
