defmodule Andi.Services.UrlTest do
  @moduledoc """
  Tests urls with a head request, returning the time to execute and status.
  """
  use Tesla

  plug Tesla.Middleware.JSON

  def test(url) do
    case :timer.tc(&head/1, [url]) do
      {time, {:ok, %{status: status}}} ->
        timed_status(time, status)

      {time, {:error, :nxdomain}} ->
        timed_status(time, "Domain not found")

      {time, _} ->
        timed_status(time, "Could not complete request")
    end
  end

  defp timed_status(time, status) do
    %{time: time / 1000, status: status}
  end
end
