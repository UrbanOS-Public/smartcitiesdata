defmodule Andi.DatasetSchema do
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field(:dataset_id, :string)
    embeds_one(:technical, Andi.DatasetTechnicalSchema)
    embeds_one(:business, Andi.DatasetBusinessSchema)
  end

  def changeset(params \\ %{}) do
    %Andi.DatasetSchema{}
    |> cast(params, [:dataset_id])
    |> cast_embed(:technical)
    |> cast_embed(:business)

    # |> validate_required([:dataset_id], message: "This field is required.")
  end
end

defmodule Andi.DatasetTechnicalSchema do
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field(:sourceFormat, :string)
    field(:private, :boolean)
  end

  def changeset(tech, params \\ %{}) do
    tech
    |> cast(params, [:sourceFormat, :private])
    |> validate_required([:sourceFormat], message: "Format is required.")
  end
end

defmodule Andi.DatasetBusinessSchema do
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field(:dataTitle, :string)
    field(:description, :string)
    field(:contactName, :string)
    field(:contactEmail, :string)
    field(:issuedDate, :string)
    field(:license, :string)
    field(:publishFrequency, :string)
    field(:keywords, {:array, :string})
    field(:modifiedDate, :string)
    field(:spatial, :string)
    field(:temporal, :string)
    field(:orgTitle, :string)
    field(:language, :string)
    field(:homepage, :string)
  end

  def changeset(biz, params \\ %{}) do
    biz
    |> cast(params, [
      :dataTitle,
      :description,
      :contactName,
      :contactEmail,
      :issuedDate,
      :license,
      :publishFrequency,
      :keywords,
      :modifiedDate,
      :spatial,
      :temporal,
      :orgTitle,
      :language,
      :homepage
    ])
    |> validate_required([:dataTitle], message: "Dataset Title is required.")
    |> validate_required([:description], message: "Description is required.")
    |> validate_required([:contactName], message: "Maintainer Name is required.")
    |> validate_required([:contactEmail], message: "Maintainer Email is required.")
    |> validate_required([:issuedDate], message: "Release Date is required.")
    |> validate_required([:license], message: "License is required.")
    |> validate_required([:publishFrequency], message: "Publish Frequency is required.")
    |> validate_required([:orgTitle], message: "Organization is required.")
  end
end
