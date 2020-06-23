defmodule TelemetryEvent do
  @moduledoc false
  alias Telemetry.Metrics

  def metrics() do
    metrics_options = Application.get_env(:telemetry_event, :metrics_options)

    [
      Metrics.counter(fetch_required(metrics_options, :metric_name), tags: fetch_required(metrics_options, :tags))
    ]
  end

  def add_event_count(options) do
    :telemetry.execute([:events_handled], %{}, %{
      app: fetch_required(options, :app),
      author: fetch_required(options, :author),
      dataset_id: Keyword.fetch!(options, :dataset_id),
      event_type: fetch_required(options, :event_type)
    })
  rescue
    error -> {:error, error}
  end

  defp fetch_required(options, keyword_name) do
    Keyword.fetch!(options, keyword_name)
    |> reject_nil(keyword_name)
  end

  defp reject_nil(value, keyword_name) when is_nil(value) do
    raise "Keyword :#{keyword_name} cannot be nil"
  end

  defp reject_nil(value, _) when not is_nil(value) do
    value
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
