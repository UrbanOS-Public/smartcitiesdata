defmodule TelemetryEvent do
  @moduledoc false
  alias Telemetry.Metrics

  def metrics() do
    metrics_options = Application.get_env(:telemetry_event, :metrics_options)

    [
      Metrics.counter(fetch_required(metrics_options, :metric_name),
        tags: Keyword.fetch!(metrics_options, :tags)
      )
    ]
  end

  def add_event_count(options) do
    :telemetry.execute([:events_handled], %{}, measurements(options))
  rescue
    error -> {:error, error}
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

  def metrics_port() do
    case Application.get_env(:telemetry_event, :metrics_port) do
      nil -> create_port_no()
      port_no -> port_no
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
