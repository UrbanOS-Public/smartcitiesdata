defmodule AndiWeb.LayoutView do
  use AndiWeb, :view

  def get_primary_color() do
    Andi.Application.get_primary_color()
  end

  def get_secondary_color() do
    Andi.Application.get_secondary_color()
  end

  def get_success_color() do
    Andi.Application.get_success_color()
  end

  def get_error_color() do
    Andi.Application.get_error_color()
  end

  def get_primary_button_text_color() do
    color = CssColors.parse!(get_primary_color())

    case CssColors.get_lightness(color) < 0.5 do
      false -> "black"
      true -> "white"
    end
  end

  def get_primary_text_color() do
    color = CssColors.parse!(get_primary_color())

    case CssColors.get_lightness(color) < 0.5 do
      false -> to_string(CssColors.darken(color, 0.2))
      true -> to_string(color)
    end
  end

  def get_hover_color(type) do
    color = get_color(type)

    case CssColors.get_lightness(color) < 0.5 do
      false -> to_string(CssColors.darken(color, 0.1))
      true -> to_string(CssColors.lighten(color, 0.1))
    end
  end

  def get_active_primary_color() do
    color = CssColors.parse!(get_primary_color())

    case CssColors.get_lightness(color) < 0.5 do
      false -> to_string(CssColors.darken(color, 0.2))
      true -> to_string(CssColors.lighten(color, 0.2))
    end
  end

  def get_disabled_color(type) do
    color = get_color(type)

    case CssColors.get_lightness(color) < 0.5 do
      false -> to_string(CssColors.darken(color, 0.2))
      true -> to_string(CssColors.lighten(color, 0.2))
    end
  end

  defp get_color(type) do
    CssColors.parse!(
      case type do
        :primary -> get_primary_color()
        :secondary -> get_secondary_color()
        :success -> get_success_color()
        :error -> get_error_color()
        _ -> get_primary_color()
      end
    )
  end
end
