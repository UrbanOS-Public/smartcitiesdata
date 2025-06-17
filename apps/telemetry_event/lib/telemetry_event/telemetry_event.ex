defmodule TelemetryEvent do
  @moduledoc """
  Provides telemetry event handling functionality.

  This module implements the `TelemetryEvent.Behaviour` and provides the default
  implementation for telemetry event handling. The implementation can be overridden
  in the application configuration for testing or other purposes.
  """
  @behaviour TelemetryEvent.Behaviour

  alias TelemetryEvent.Helper.TelemetryEventHelper

  @impl true
  def add_event_metrics(event_metadata, event_name, measurements \\ %{}) do
    implementation().add_event_metrics(event_metadata, event_name, measurements)
  end

  @doc """
  Configures the telemetry server for the application.
  """
  def config_init_server(child, app_name) do
    child
    |> add_metrics_prometheus(app_name)
    |> add_poller()
  end

  # Returns the configured implementation module, defaults to the default implementation
  defp implementation do
    Application.get_env(:telemetry_event, :implementation, __MODULE__.DefaultImpl)
  end

  defmodule DefaultImpl do
    @moduledoc false
    @behaviour TelemetryEvent.Behaviour

    @impl true
    def add_event_metrics(event_metadata, event_name, measurements) do
      :telemetry.execute(
        event_name,
        measurements,
        TelemetryEventHelper.tags_and_values(event_metadata)
      )
    rescue
      error -> {:error, error}
    end
  end

  defp add_metrics_prometheus(child, app_name) do
    case Application.get_env(:telemetry_event, :init_server) do
      false -> child
      _ -> [{TelemetryMetricsPrometheus, TelemetryEventHelper.metrics_config(app_name)} | child]
    end
  end

  defp add_poller(child) do
    case Application.get_env(:telemetry_event, :add_poller) do
      true -> [{:telemetry_poller, measurements: [], period: :timer.seconds(5)} | child]
      _ -> child
    end
  end
end
