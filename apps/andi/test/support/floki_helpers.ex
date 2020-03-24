defmodule FlokiHelpers do
  @moduledoc false
  import Phoenix.LiveViewTest

  def get_text(html, selector) do
    html
    |> Floki.parse_fragment!()
    |> Floki.find(selector)
    |> Floki.text()
    |> String.trim()
  end

  def get_texts(html, selector) do
    html
    |> Floki.parse_fragment!()
    |> Floki.find(selector)
    |> Enum.map(&Floki.text/1)
    |> Enum.map(&String.trim/1)
  end

  def get_attributes(html, selector, attribute_name) do
    html
    |> Floki.parse_fragment!()
    |> Floki.attribute(selector, attribute_name)
  end

  def get_values(html, selector) do
    get_attributes(html, selector, "value")
  end

  def get_value(html, selector) do
    get_values(html, selector) |> List.first()
  end

  def get_select(html, selector) do
    {_, [{_, value} | _], [text]} =
      html
      |> Floki.parse_fragment!()
      |> Floki.find(selector)
      |> Floki.find("select option")
      |> Enum.filter(fn {_, list, _} -> list |> Enum.any?(&(&1 == {"selected", "selected"})) end)
      |> List.first()

    {value, text}
  end

  def find_elements(html, selector) do
    html
    |> Floki.parse_fragment!()
    |> Floki.find(selector)
  end
end
