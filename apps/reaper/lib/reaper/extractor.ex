defmodule Reaper.Extractor do
  @moduledoc false
  def extract(url) do
    {:ok, %HTTPoison.Response{body: body}} = HTTPoison.get(url)
    body
  end
end
