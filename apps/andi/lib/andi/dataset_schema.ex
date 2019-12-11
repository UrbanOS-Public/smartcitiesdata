# defmodule Andi.DatasetSchema do
#   use Ecto.Schema
#   import Ecto.Changeset

#   embedded_schema do
#     field(:dataset_id, :string)
#     embeds_one(:technical, Andi.DatasetTechnicalSchema)
#     embeds_one(:business, Andi.DatasetBusinessSchema)
#   end

#   def changeset(params \\ %{}) do
#     %Andi.DatasetSchema{}
#     |> cast(params, [:dataset_id])
#     |> cast_embed(:technical)
#     |> cast_embed(:business)
#     |> validate_required([:dataset_id], message: "This field is required.")
#   end
# end

# defmodule Andi.DatasetTechnicalSchema do
#   use Ecto.Schema
#   import Ecto.Changeset

#   embedded_schema do
#     field(:sourceFormat, :string)
#   end

#   def changeset(tech, params \\ %{}) do
#     tech
#     |> cast(params, [:sourceFormat])
#     |> validate_required([:sourceFormat], message: "This field is required.")
#   end
# end

# defmodule Andi.DatasetBusinessSchema do
#   use Ecto.Schema
#   import Ecto.Changeset

#   embedded_schema do
#     field(:dataTitle, :string)
#   end

#   def changeset(biz, params \\ %{}) do
#     biz
#     |> cast(params, [:dataTitle])
#     |> validate_required([:dataTitle], message: "This field is required.")
#   end
# end
