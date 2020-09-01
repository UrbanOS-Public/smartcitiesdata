defmodule AndiWeb.Plugs.Telemetry do
  @behaviour Plug

  @impl true
  def init(opts), do: Plug.Telemetry.init(opts)

  @impl true
  def call(conn, {start_event, stop_event, opts}) do
    IO.inspect(conn, label: "Conn")
    Plug.Telemetry.call(conn, {start_event, stop_event, Keyword.put(opts, :log, :debug)})
  end
  def call(conn, args), do: Plug.Telemetry.call(conn, args)
end
