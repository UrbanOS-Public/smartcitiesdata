defmodule DiscoveryApiWeb.Utilities.ModelAccessUtils do
  @moduledoc """
  This module is the implementation of the DiscoveryApiWeb.Utilities.AccessUtils behavior for auth rules stored in Ecto
  """
  @behaviour DiscoveryApiWeb.Utilities.AccessUtils
  alias RaptorService
  alias DiscoveryApi.Data.Model
  use Properties, otp_app: :discovery_api

  getter(:raptor_url, generic: true)
  getter(:raptor_list_url, generic: true)

  def has_access?(%Model{private: false} = _dataset, _username), do: true
  def has_access?(%Model{private: true} = _dataset, nil), do: false

  def has_access?(%Model{private: true, systemName: system_name} = _dataset, %{subject_id: subject_id}) do
    RaptorService.is_authorized_by_user_id(raptor_url(), subject_id, system_name)
  end

  def has_access?(%Model{private: true, systemName: systemName} = _dataset, [apiKey]) do
    RaptorService.is_authorized(raptor_url(), apiKey, systemName)
  end

  def has_access?(_base, _case), do: false
end
