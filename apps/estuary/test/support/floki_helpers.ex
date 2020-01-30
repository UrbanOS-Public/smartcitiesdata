defmodule FlokiHelpers do
  @moduledoc false
  def floki_get_text(html, selector) do
    html
    |> Floki.find(selector)
    |> Floki.text()
  end
end
