defmodule Raptor.Schemas.Dataset do
  @moduledoc """
  This module defines the structure for a user organization association
  """

  @derive Jason.Encoder

  @type t :: %__MODULE__{
          dataset_id: String.t(),
          system_name: String.t(),
          org_id: String.t(),
          is_private: boolean()
        }

  defstruct [
    :dataset_id,
    :system_name,
    :org_id,
    :is_private
  ]

  @doc """
  Converts a `SmartCity.UserOrgAssociation` to a `Raptor.Schemas.UserOrgAssoc`
  """
  @spec from_event(SmartCity.Dataset.t()) :: {:ok, Raptor.Schemas.Dataset.t()}
  def from_event(%SmartCity.Dataset{} = dataset) do
    struct = %__MODULE__{
      dataset_id: dataset.id,
      system_name: dataset.technical.systemName,
      org_id: dataset.technical.orgId,
      is_private: dataset.technical.private
    }

    {:ok, struct}
  end

  @doc """
  Convert a `Raptor.Schemas.UserOrgAssoc` into JSON
  """
  @spec encode(Raptor.Schemas.Dataset.t()) ::
          {:ok, String.t()} | {:error, Jason.EncodeError.t() | Exception.t()}
  def encode(%__MODULE__{} = dataset) do
    Jason.encode(dataset)
  end

  def encode!(%__MODULE__{} = dataset) do
    Jason.encode!(dataset)
  end
end
