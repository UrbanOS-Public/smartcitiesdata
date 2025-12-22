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
    require Logger
    current_user = conn.assigns.current_user
    api_key = Plug.Conn.get_req_header(conn, "api_key")

    api_key_authorized = api_key_can_access_models?(affected_models, api_key)
    user_authorized = user_can_access_models?(affected_models, current_user)

    Logger.info(
      "authorized_session - checking authorization: api_key_present=#{not Enum.empty?(api_key)}, api_key_authorized=#{api_key_authorized}, user_authorized=#{user_authorized}, affected_models_count=#{length(affected_models)}"
    )

    if api_key_authorized || user_authorized do
      session_opts = DiscoveryApi.prestige_opts()
      Logger.debug("authorized_session - creating Prestige session with opts: #{inspect(session_opts)}")
      session = Prestige.new_session(session_opts)
      {:ok, session}
    else
      Logger.error(
        "authorized_session - session not authorized: current_user=#{inspect(current_user)}, api_key_present=#{not Enum.empty?(api_key)}, affected_models=#{inspect(Enum.map(affected_models, & &1.systemName))}"
      )

      {:error, "Session not authorized"}
    end
  end

  def user_is_authorized?(affected_models, current_user, api_key) do
    api_key_can_access_models?(affected_models, api_key) || user_can_access_models?(affected_models, current_user)
  end

  def get_affected_models(statement) do
    require Logger

    with true <- @presto_service_impl.is_select_statement?(statement),
         session_opts <- DiscoveryApi.prestige_opts(),
         session <- Prestige.new_session(session_opts),
         {:ok, affected_tables} <- @presto_service_impl.get_affected_tables(session, statement),
         affected_models <- map_affected_tables_to_models(affected_tables),
         true <- valid_tables?(affected_tables, affected_models) do
      {:ok, affected_models}
    else
      {:sql_error, error} ->
        Logger.error("get_affected_models - SQL error: #{inspect(error)}")
        {:sql_error, error}

      false ->
        Logger.error("get_affected_models - statement is not a SELECT statement or tables invalid. Statement: #{inspect(statement)}")
        {:error, "Query statement is invalid"}

      {:error, reason} ->
        Logger.error("get_affected_models - error getting affected tables, reason: #{inspect(reason)}")
        {:error, "Query statement is invalid: #{inspect(reason)}"}

      other ->
        Logger.error("get_affected_models - unexpected error: #{inspect(other)}, statement: #{inspect(statement)}")
        {:error, "Query statement is invalid"}
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
    require Logger

    affected_system_names =
      affected_models
      |> Enum.map(&Map.get(&1, :systemName))
      |> Enum.map(&String.downcase/1)

    tables_set = MapSet.new(affected_tables)
    models_set = MapSet.new(affected_system_names)

    if tables_set != models_set do
      tables_only = MapSet.difference(tables_set, models_set)
      models_only = MapSet.difference(models_set, tables_set)

      Logger.error("valid_tables? - Table/Model mismatch!")
      Logger.error("  Tables queried from Trino: #{inspect(Enum.to_list(tables_set))}")
      Logger.error("  Models found in Brook: #{inspect(Enum.to_list(models_set))}")
      Logger.error("  Tables in Trino but NOT in Brook: #{inspect(Enum.to_list(tables_only))}")
      Logger.error("  Models in Brook but NOT in Trino: #{inspect(Enum.to_list(models_only))}")
    end

    tables_set == models_set
  end
end
