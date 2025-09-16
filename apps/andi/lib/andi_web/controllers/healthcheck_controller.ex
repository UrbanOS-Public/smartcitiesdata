defmodule AndiWeb.HealthCheckController do
  @moduledoc """
  Module handles requests to validate the system is up.
  """
  use AndiWeb, :controller
  require Logger
  alias Andi.Services.IngestionStore

  access_levels(index: [:private, :public], readiness: [:private, :public])

  @spec index(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def index(conn, _params) do
    text(conn, "Up")
  end

  @spec readiness(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def readiness(conn, _params) do
    checks = %{
      brook_redis: check_brook_redis(),
      database: check_database(),
      ingestion_store: check_ingestion_store()
    }

    all_healthy = Enum.all?(checks, fn {_key, status} -> status == :ok end)

    status_code = if all_healthy, do: 200, else: 503

    conn
    |> put_status(status_code)
    |> json(%{
      status: if(all_healthy, do: "ready", else: "not_ready"),
      checks: checks,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  defp check_brook_redis do
    try do
      # Test Brook storage by attempting to retrieve something
      case Brook.get_all_values(Andi.instance_name(), :datasets) do
        {:ok, _} -> :ok
        {:error, _} -> :error
      end
    rescue
      error ->
        Logger.debug("Brook/Redis check failed: #{inspect(error)}")
        :error
    end
  end

  defp check_database do
    try do
      # Simple database connectivity check
      case Andi.Repo.query("SELECT 1", []) do
        {:ok, _} -> :ok
        {:error, _} -> :error
      end
    rescue
      error ->
        Logger.debug("Database check failed: #{inspect(error)}")
        :error
    end
  end

  defp check_ingestion_store do
    try do
      # Test the specific component that was failing
      # IngestionStore.get_all() returns values directly, not {:ok, _} tuples
      _result = IngestionStore.get_all()
      :ok
    rescue
      error ->
        Logger.debug("IngestionStore check failed: #{inspect(error)}")
        :error
    end
  end
end
