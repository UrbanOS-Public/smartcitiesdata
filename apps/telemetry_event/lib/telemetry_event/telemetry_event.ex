defmodule TelemetryEvent do
  @moduledoc false
  alias Telemetry.Metrics

  def metrics() do
    Application.get_env(:telemetry_event, :metrics_options)
    |> Enum.map(fn metrics_option ->
      Metrics.counter(Keyword.fetch!(metrics_option, :metric_name),
        tags: Keyword.fetch!(metrics_option, :tags)
      )
    end)
  end

  def add_event_count(event_measurements, event_name) do
    :telemetry.execute(event_name, %{}, measurements(event_measurements))
  rescue
    error -> {:error, error}
  end

  def metrics_port() do
    case Application.get_env(:telemetry_event, :metrics_port) do
      nil -> create_port_no()
      port_no -> port_no
    end
  end

  defp measurements(options) do
    options
    |> Enum.filter(fn {k, v} -> reject_nil(k, v) == true end)
    |> Map.new()
  end

  defp reject_nil(keyword_name, value) do
    if keyword_name == :dataset_id or value != nil do
      true
    else
      raise "Keyword :#{keyword_name} cannot be nil"
    end
  end

  defp create_port_no() do
    1_000..9_999
    |> Enum.random()
    |> verify_port_no()
  end

  defp verify_port_no(port_no) do
    case :gen_tcp.listen(port_no, []) do
      {:ok, port} ->
        Port.close(port)
        Application.put_env(:telemetry_event, :metrics_port, port_no)
        port_no

      {:error, :eaddrinuse} ->
        create_port_no()
    end
  end
end
