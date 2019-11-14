defmodule DiscoveryApiWeb.Utilities.AuthUtils do
  @moduledoc """
  Provides authentication and authorization helper methods
  """
  alias DiscoveryApi.Services.PrestoService
  alias DiscoveryApi.Data.Model

  def authorized_to_query?(statement, username, access_module \\ DiscoveryApiWeb.Utilities.LdapAccessUtils) do
    with true <- PrestoService.is_select_statement?(statement),
         {:ok, affected_tables} <- PrestoService.get_affected_tables(statement),
         affected_models <- get_affected_models(affected_tables) do
      valid_tables?(affected_tables, affected_models) && can_access_models?(affected_models, username, access_module)
    else
      _ -> false
    end
  end

  defp get_affected_models(affected_tables) do
    all_models = Model.get_all()

    Enum.filter(all_models, &(String.downcase(&1.systemName) in affected_tables))
  end

  defp valid_tables?(affected_tables, affected_models) do
    affected_system_names =
      affected_models
      |> Enum.map(&Map.get(&1, :systemName))
      |> Enum.map(&String.downcase/1)

    MapSet.new(affected_tables) == MapSet.new(affected_system_names)
  end

  defp can_access_models?(affected_models, username, access_module) do
    Enum.all?(affected_models, &access_module.has_access?(&1, username))
  end
end
