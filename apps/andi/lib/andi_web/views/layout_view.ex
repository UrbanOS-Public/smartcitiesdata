defmodule AndiWeb.LayoutView do
  use AndiWeb, :view

  def get_primary_color() do
    Andi.Application.get_primary_color()
  end
end
