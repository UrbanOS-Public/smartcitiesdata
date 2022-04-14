defmodule Raptor.Schemas.UserAccessGroupRelation do
  @moduledoc """
  This module defines the structure for a user access group relation
  """

  @derive Jason.Encoder

  @type t :: %__MODULE__{
          user_id: String.t(),
          access_group_id: String.t()
        }

  defstruct [
    :user_id,
    :access_group_id
  ]

  @doc """
  Converts a `SmartCity.UserAccessGroupRelation` to a `Raptor.Schemas.UserAccessGroupRelation`
  """
  @spec from_smrt_relation(SmartCity.UserAccessGroupRelation.t()) ::
          {:ok, Raptor.Schemas.UserAccessGroupRelation.t()}
  def from_smrt_relation(%SmartCity.UserAccessGroupRelation{} = assoc) do
    struct = %__MODULE__{
      user_id: assoc.subject_id,
      access_group_id: assoc.access_group_id
    }

    {:ok, struct}
  end

  @spec encode(Raptor.Schemas.UserAccessGroupRelation.t()) ::
          {:ok, String.t()} | {:error, Jason.EncodeError.t() | Exception.t()}
  def encode(%__MODULE__{} = user_access_group_relation) do
    Jason.encode(user_access_group_relation)
  end

  def encode!(%__MODULE__{} = user_access_group_relation) do
    Jason.encode!(user_access_group_relation)
  end
end
