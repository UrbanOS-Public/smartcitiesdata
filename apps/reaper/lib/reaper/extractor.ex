defmodule Reaper.Extractor do
  @moduledoc false
  use Tesla

  plug(Tesla.Middleware.FollowRedirects)
  plug(Tesla.Middleware.Retry, delay: 500, max_retries: 10)

  def extract(%Reaper.ReaperConfig{dataset_id: id, sourceUrl: "sftp" <> _rest = url}) do
    case Reaper.SftpExtractor.extract(id, url) do
      {:ok, data} ->
        data

      {:error, reason} ->
        raise "Failed calling '" <> url <> "': " <> inspect(reason)
    end
  end

  def extract(%Reaper.ReaperConfig{sourceUrl: url}) do
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
