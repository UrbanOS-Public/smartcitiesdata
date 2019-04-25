defmodule Reaper.Extractor do
  @moduledoc false
  use Tesla

  plug(Tesla.Middleware.FollowRedirects)
  plug(Tesla.Middleware.Retry, delay: 500, max_retries: 10)

  def extract(url, "csv") do
    filename = inspect(self())
    file = File.open!(filename, [:write])
    Downstream.get!(url, file)
    File.close(file)
    {:file, filename}
  end

  def extract(url, _format) do
    case get(url) do
      {:ok, response} ->
        response.body

      {:error, reason} ->
        target =
          url
          |> String.split("?")
          |> List.first()

        raise "Failed calling '" <> target <> "': " <> inspect(reason)
    end
  end
end
