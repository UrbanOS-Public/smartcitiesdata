defmodule Andi.Services.UrlTest do
  @moduledoc """
  Tests urls with a head request, returning the time to execute and status.
  """
  use Tesla

  require Logger

  plug Tesla.Middleware.JSON

  def test(url, options \\ []) do
    query_params = Keyword.get(options, :query_params, [])
    headers = Keyword.get(options, :headers, [])
    request_opts = [query: query_params, headers: headers] ++ ssl_opts()

    case :timer.tc(&head/2, [url, request_opts]) do
      {time, {:ok, %{status: status}}} ->
        timed_status(time, status)

      {time, {:error, :nxdomain}} ->
        timed_status(time, "Domain not found")

      {time, error} ->
        Logger.debug("Could not complete request : #{inspect(error)}")
        timed_status(time, "Could not complete request")
    end
  end

  defp timed_status(time, status) do
    %{time: time / 1000, status: status}
  end

  # Uses the image's system CA bundle (kept up to date via `update-ca-certificates`
  # in the Dockerfile, alongside any internal/private CAs added there) instead of
  # Hackney's own default (certifi) bundle, when CA_CERTFILE_PATH is present. Falls
  # back to Hackney's default when unset, e.g. in local dev.
  defp ssl_opts do
    case System.get_env("CA_CERTFILE_PATH") do
      path when is_binary(path) and path != "" -> [opts: [adapter: [ssl_options: [cacertfile: path]]]]
      _ -> []
    end
  end
end
