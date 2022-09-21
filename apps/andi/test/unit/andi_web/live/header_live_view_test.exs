defmodule AndiWeb.HeaderLiveViewTest do
  use AndiWeb.Test.AuthConnCase.UnitCase
  use Placebo

  alias AndiWeb.HeaderLiveView

  import Phoenix.LiveViewTest

  describe "Header Live View" do
    test "Displays default header text when none is provided" do
      html = render_component(AndiWeb.HeaderLiveView, is_curator: true, path: "test")

      header_text = Floki.parse_fragment!(html)
      |> Floki.filter_out(".log-out-link")
      |> Floki.find(".page-header__primary")
      |> Floki.text()

      assert header_text == "Data Submission Tool"
    end

    test "Displays provided header text" do
      allow(Application.get_env(:andi, :header_text), return: "Definitely Not Data Submission Tool")

      html = render_component(AndiWeb.HeaderLiveView, is_curator: true, path: "test")

      header_text = Floki.parse_fragment!(html)
      |> Floki.filter_out(".log-out-link")
      |> Floki.find(".page-header__primary")
      |> Floki.text()

      assert header_text == "Definitely Not Data Submission Tool"
    end
  end
end
