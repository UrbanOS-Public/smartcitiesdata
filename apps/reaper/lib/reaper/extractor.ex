defmodule Reaper.Extractor do
  @moduledoc false
  use Tesla

  plug(Tesla.Middleware.FollowRedirects)
  plug(Tesla.Middleware.Retry, delay: 500, max_retries: 10)

  def extract(url) do
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
