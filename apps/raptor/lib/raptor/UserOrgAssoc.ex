defmodule Raptor.UserOrgAssoc do
  @moduledoc """
  This module defines the structure for a user organization association
  """

  @derive Jason.Encoder

  @type t :: %__MODULE__{
          user_id: String.t(),
          org_id: String.t(),
          email: String.t()
        }

  defstruct [
    :user_id,
    :org_id,
    :email
  ]

  @doc """
  Converts a `SmartCity.UserOrgAssociation` to a `Raptor.UserOrgAssoc`
  """
  @spec from_associate_event(SmartCity.UserOrganizationAssociate.t()) :: {:ok, Raptor.UserOrgAssoc.t()}
  def from_associate_event(%SmartCity.UserOrganizationAssociate{} = assoc) do
    struct = %__MODULE__{
      user_id: assoc.subject_id,
      org_id: assoc.org_id,
      email: assoc.email
    }

    {:ok, struct}
  end

    @doc """
  Converts a `SmartCity.UserOrgDisassociation` to a `Raptor.UserOrgAssoc`
  """
  @spec from_disassociate_event(SmartCity.UserOrganizationDisassociate.t()) :: {:ok, Raptor.UserOrgAssoc.t()}
  def from_disassociate_event(%SmartCity.UserOrganizationDisassociate{} = assoc) do
    struct = %__MODULE__{
      user_id: assoc.subject_id,
      org_id: assoc.org_id,
      email: nil
    }

    {:ok, struct}
  end

  @doc """
  Convert a `Raptor.UserOrgAssoc` into JSON
  """
  @spec encode(Raptor.UserOrgAssoc.t()) :: {:ok, String.t()} | {:error, Jason.EncodeError.t() | Exception.t()}
  def encode(%__MODULE__{} = user_org_assoc) do
    Jason.encode(user_org_assoc)
  end

  def encode!(%__MODULE__{} = user_org_assoc) do
    Jason.encode!(user_org_assoc)
  end
end
