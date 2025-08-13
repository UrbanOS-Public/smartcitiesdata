defmodule DiscoveryApiWeb.Utilities.QueryAccessUtils do
  @moduledoc """
  Provides authentication and authorization helper methods
  """
  alias RaptorService
  alias DiscoveryApi.Services.PrestoService
  alias DiscoveryApi.Data.Model
  alias DiscoveryApiWeb.Utilities.ModelAccessUtils
  use Properties, otp_app: :discovery_api

  getter(:raptor_url, generic: true)

  # Allow configuring the service modules for testing
  @presto_service_impl Application.compile_env(:discovery_api, :presto_service, PrestoService)
  @model_impl Application.compile_env(:discovery_api, :model, Model)
  @model_access_utils_impl Application.compile_env(:discovery_api, :model_access_utils, ModelAccessUtils)
  @raptor_service_impl Application.compile_env(:discovery_api, :raptor_service, RaptorService)

  def authorized_session(conn, affected_models) do
    current_user = conn.assigns.current_user
    api_key = Plug.Conn.get_req_header(conn, "api_key")

    if api_key_can_access_models?(affected_models, api_key) || user_can_access_models?(affected_models, current_user) do
      session_opts = DiscoveryApi.prestige_opts()
      session = Prestige.new_session(session_opts)
      {:ok, session}
    else
      {:error, "Session not authorized"}
    end
  end

  def user_is_authorized?(affected_models, current_user, api_key) do
    api_key_can_access_models?(affected_models, api_key) || user_can_access_models?(affected_models, current_user)
  end

  def get_affected_models(statement) do
    with true <- @presto_service_impl.is_select_statement?(statement),
         session_opts <- DiscoveryApi.prestige_opts(),
         session <- Prestige.new_session(session_opts),
         {:ok, affected_tables} <- @presto_service_impl.get_affected_tables(session, statement),
         affected_models <- map_affected_tables_to_models(affected_tables),
         true <- valid_tables?(affected_tables, affected_models) do
      {:ok, affected_models}
    else
      {:sql_error, error} -> {:sql_error, error}
      _ -> {:error, "Query statement is invalid"}
    end
  end

  def user_can_access_models?(affected_models, user) do
    Enum.all?(affected_models, &@model_access_utils_impl.has_access?(&1, user))
  end

  def api_key_can_access_models?(_affected_models, []) do
    false
  end

  def api_key_can_access_models?(affected_models, [api_key]) do
    Enum.all?(affected_models, &@raptor_service_impl.is_authorized(raptor_url(), api_key, &1[:systemName]))
  end

  defp map_affected_tables_to_models(affected_tables) do
    all_models = @model_impl.get_all()

    Enum.filter(all_models, &(String.downcase(&1.systemName) in affected_tables))
  end

  defp valid_tables?(affected_tables, affected_models) do
    affected_system_names =
      affected_models
      |> Enum.map(&Map.get(&1, :systemName))
      |> Enum.map(&String.downcase/1)

    MapSet.new(affected_tables) == MapSet.new(affected_system_names)
  end
end
