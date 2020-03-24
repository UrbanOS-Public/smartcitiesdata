defmodule DiscoveryApiWeb.Utilities.QueryAccessUtils do
  @moduledoc """
  Provides authentication and authorization helper methods
  """
  alias DiscoveryApi.Services.PrestoService
  alias DiscoveryApi.Data.Model
  alias DiscoveryApiWeb.Utilities.ModelAccessUtils

  def authorized_session(conn, statement) do
    current_user = conn.assigns.current_user

    case authorized_to_query?(statement, current_user) do
      true ->
        session_opts = DiscoveryApi.prestige_opts()
        session = Prestige.new_session(session_opts)
        {:ok, session}

      false ->
        {:error, "Session not authorized"}
    end
  end

  def authorized_to_query?(statement, user) do
    with true <- PrestoService.is_select_statement?(statement),
         session_opts <- DiscoveryApi.prestige_opts(),
         session <- Prestige.new_session(session_opts),
         {:ok, affected_tables} <- PrestoService.get_affected_tables(session, statement),
         affected_models <- get_affected_models(affected_tables),
         true <- valid_tables?(affected_tables, affected_models) do
      can_access_models?(affected_models, user)
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

  defp can_access_models?(affected_models, user) do
    Enum.all?(affected_models, &ModelAccessUtils.has_access?(&1, user))
  end
end
