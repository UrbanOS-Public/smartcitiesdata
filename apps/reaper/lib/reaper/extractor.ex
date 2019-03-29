defmodule Reaper.Extractor do
  @moduledoc false
  def extract(url) do
    case HTTPoison.get(url, [], follow_redirect: true) do
      {:ok, %HTTPoison.Response{body: body}} -> body
      {:error, reason} -> raise reason
    end
  end
end
