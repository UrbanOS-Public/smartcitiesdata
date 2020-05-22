defmodule DiscoveryApiWeb.Plugs.SecureHeaders do
  @behaviour :cowboy_stream

  @moduledoc """
  A plug to add secure response headers on http traffic
  """
  def init(default), do: default

  def call(conn, _default) do
    Phoenix.Controller.put_secure_browser_headers(conn)
  end

  def info(stream_id, {:response, status, headers, body}, state) do
    headers = Map.drop(headers, ["server"])
    :cowboy_stream.info(stream_id, {:response, status, headers, body}, state)
  end

  def info(stream_id, info, state) do
    :cowboy_stream.info(stream_id, info, state)
  end

  def init(stream_id, req, opts) do
    :cowboy_stream.init(stream_id, req, opts)
  end

  def data(stream_id, is_fin, info, state) do
    :cowboy_stream.data(stream_id, is_fin, info, state)
  end

  def early_error(stream_id, reason, partial_req, resp, opts) do
    :cowboy_stream.early_error(stream_id, reason, partial_req, resp, opts)
  end

  def terminate(stream_id, reason, state) do
    :cowboy_stream.terminate(stream_id, reason, state)
  end
end
