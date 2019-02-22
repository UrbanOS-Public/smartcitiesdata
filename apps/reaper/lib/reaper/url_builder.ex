defmodule Reaper.UrlBuilder do
  @moduledoc false
  def build(url, nil), do: url

  def build(url, params) do
    params = Enum.map(params, fn {k, v} -> {k, EEx.eval_string(v)} end)
    string_params = URI.encode_query(params)
    "#{url}?#{string_params}"
  end
end
