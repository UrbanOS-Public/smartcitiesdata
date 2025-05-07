defmodule AndiWeb.HeaderLiveViewTest do
  use AndiWeb.Test.AuthConnCase.UnitCase

  import Phoenix.LiveViewTest
  import Mock

  describe "Header Live View" do
    test "Displays default logo when none is provided" do
      html = render_component(AndiWeb.HeaderLiveView, is_curator: true, path: "test")

      header_logo =
        Floki.parse_fragment!(html)
        |> Floki.attribute("img", "src")
        |> List.first()

      assert header_logo == "/images/UrbanOS.svg"
    end

    test "Displays provided logo" do
      with_mock(Application,
        get_env: fn
          :andi, :logo_url -> "/images/RuralOS.svg"
          app, env -> passthrough([app, env])
        end,
        get_env: fn app, env, opts -> passthrough([app, env, opts]) end
      ) do
        html = render_component(AndiWeb.HeaderLiveView, is_curator: true, path: "test")

        header_logo =
          Floki.parse_fragment!(html)
          |> Floki.attribute("img", "src")
          |> List.first()

        assert header_logo == "/images/RuralOS.svg"
      end
    end

    test "Displays default header text when none is provided" do
      html = render_component(AndiWeb.HeaderLiveView, is_curator: true, path: "test")

      header_text =
        Floki.parse_fragment!(html)
        |> Floki.filter_out(".log-out-link")
        |> Floki.find(".page-header__primary")
        |> Floki.text()

      assert header_text == "Data Submission Tool"
    end

    test "Displays provided header text" do
      with_mock(Application,
        get_env: fn
          :andi, :header_text -> "Definitely Not Data Submission Tool"
          app, env -> passthrough([app, env])
        end,
        get_env: fn app, env, opts -> passthrough([app, env, opts]) end
      ) do
        html = render_component(AndiWeb.HeaderLiveView, is_curator: true, path: "test")

        header_text =
          Floki.parse_fragment!(html)
          |> Floki.filter_out(".log-out-link")
          |> Floki.find(".page-header__primary")
          |> Floki.text()

        assert header_text == "Definitely Not Data Submission Tool"
      end
    end
  end
end
