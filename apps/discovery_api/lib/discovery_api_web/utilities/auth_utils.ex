defmodule DiscoveryApiWeb.Utilities.AuthUtils do
  @moduledoc """
  Provides authentication and authorization helper methods
  """
  alias DiscoveryApi.Services.{PaddleService, PrestoService}
  alias DiscoveryApi.Data.Model

  def get_user(conn) do
    case Guardian.Plug.current_claims(conn) do
      %{"sub" => uid} -> uid
      _ -> nil
    end
  end

  def authorized_to_query?(statement, username) do
    with true <- PrestoService.is_select_statement?(statement),
         {:ok, affected_tables} <- PrestoService.get_affected_tables(statement),
         affected_models <- get_affected_models(affected_tables) do
      valid_tables?(affected_tables, affected_models) && can_access_models?(affected_models, username)
    else
      _ -> false
    end
  end

  defp get_affected_models(affected_tables) do
    all_models = Model.get_all()

    Enum.filter(all_models, &(&1.systemName in affected_tables))
  end

  defp valid_tables?(affected_tables, affected_models) do
    affected_system_names = Enum.map(affected_models, & &1.systemName)

    MapSet.new(affected_tables) == MapSet.new(affected_system_names)
  end

  defp can_access_models?(affected_models, username) do
    Enum.all?(affected_models, &has_access?(&1, username))
  end

  def has_access?(%Model{private: false} = _dataset, _username), do: true

  def has_access?(%Model{private: true} = _dataset, nil), do: false

  def has_access?(%Model{private: true, organizationDetails: %{dn: dn}} = _dataset, username) do
    dn
    |> PaddleService.get_members()
    |> Enum.member?(username)
  end

  def has_access?(_base, _case), do: false
end
