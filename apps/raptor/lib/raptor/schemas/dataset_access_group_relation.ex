defmodule Raptor.Schemas.DatasetAccessGroupRelation do
  @moduledoc """
  This module defines the structure for a dataset access group relation
  """

  @derive Jason.Encoder

  @type t :: %__MODULE__{
          dataset_id: String.t(),
          access_group_id: String.t()
        }

  defstruct [
    :dataset_id,
    :access_group_id
  ]

  @doc """
  Converts a `SmartCity.DatasetAccessGroupRelation` to a `Raptor.Schemas.DatasetAccessGroupRelation`
  """
  @spec from_smrt_relation(SmartCity.DatasetAccessGroupRelation.t()) ::
          {:ok, Raptor.Schemas.DatasetAccessGroupRelation.t()}
  def from_smrt_relation(%SmartCity.DatasetAccessGroupRelation{} = assoc) do
    struct = %__MODULE__{
      dataset_id: assoc.dataset_id,
      access_group_id: assoc.access_group_id
    }

    {:ok, struct}
  end

  @spec encode(Raptor.Schemas.DatasetAccessGroupRelation.t()) ::
          {:ok, String.t()} | {:error, Jason.EncodeError.t() | Exception.t()}
  def encode(%__MODULE__{} = dataset_access_group_relation) do
    Jason.encode(dataset_access_group_relation)
  end

  def encode!(%__MODULE__{} = dataset_access_group_relation) do
    Jason.encode!(dataset_access_group_relation)
  end
end
