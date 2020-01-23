defmodule Andi.Services.UrlTest do
  use Tesla

  plug Tesla.Middleware.JSON

  def test(url) do
    with {time, {:ok, %{status: status, body: body}}} <- :timer.tc(&head/1, [url]) do
      timed_status(time, status, body)
    else
      {time, {:error, :nxdomain}} ->
        timed_status(time, "Domain not found")

      {time, {:error, _}} ->
        timed_status(time, "Could not complete request")
    end
  end

  defp timed_status(time, status, body \\ "") do
    %{time: time / 1000, status: status, body: body}
  end
end
