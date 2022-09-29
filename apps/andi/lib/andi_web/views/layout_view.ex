defmodule AndiWeb.LayoutView do
  use AndiWeb, :view

  def get_primary_color() do
    Andi.Application.get_primary_color()
  end

  def get_primary_button_text_color() do
    color = CssColors.parse!(get_primary_color())

    case CssColors.get_lightness(color) < 0.25 do
      false -> "black"
      true -> "white"
    end
  end

  def get_primary_text_color() do
    color = CssColors.parse!(get_primary_color())

    case CssColors.get_lightness(color) < 0.25 do
      false -> to_string(CssColors.darken(color, 0.2))
      true -> to_string(color)
    end
  end

  def get_hover_primary_color() do
    color = CssColors.parse!(get_primary_color())

    case CssColors.get_lightness(color) < 0.25 do
      false -> to_string(CssColors.darken(color, 0.1))
      true -> to_string(CssColors.lighten(color, 0.1))
    end
  end

  def get_active_primary_color() do
    color = CssColors.parse!(get_primary_color())

    case CssColors.get_lightness(color) < 0.25 do
      false -> to_string(CssColors.darken(color, 0.2))
      true -> to_string(CssColors.lighten(color, 0.2))
    end
  end
end
