defmodule DiscoveryApiWeb.Plugs.RecordMetrics do
  @moduledoc false
  alias DiscoveryApi.Services.MetricsService

  def init(default), do: default

  def call(
        %Plug.Conn{private: %{phoenix_action: action}, assigns: %{model: %{id: id}, allowed_origin: allowed_origin}} = conn,
        action_to_label
      )
      when allowed_origin in [false, nil] do
    case Keyword.get(action_to_label, action) do
      nil ->
        conn

      label ->
        MetricsService.record_api_hit(label, id)
        conn
    end
  end

  def call(%Plug.Conn{} = conn, _opts), do: conn
end
