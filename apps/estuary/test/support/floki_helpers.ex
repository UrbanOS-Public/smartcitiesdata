defmodule FlokiHelpers do
  @moduledoc false
  def get_text(html, selector) do
    html
    |> Floki.parse_fragment!()
    |> Floki.find(selector)
    |> Floki.text()
  end
end
