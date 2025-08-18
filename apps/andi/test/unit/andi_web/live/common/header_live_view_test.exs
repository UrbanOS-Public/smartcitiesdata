defmodule AndiWeb.HeaderLiveViewTest do
  use AndiWeb.Test.AuthConnCase.UnitCase

  import Phoenix.LiveViewTest
  
  @moduletag timeout: 5000

  describe "Header Live View" do
    setup do
      # Set up :meck for modules without dependency injection
      modules_to_mock = [Application]
      
      # Clean up any existing mocks first
      Enum.each(modules_to_mock, fn module ->
        try do
          :meck.unload(module)
        catch
          _, _ -> :ok
        end
      end)
      
      # Set up fresh mocks
      Enum.each(modules_to_mock, fn module ->
        try do
          :meck.new(module, [:passthrough])
        catch
          :error, {:already_started, _} -> :ok
        end
      end)
      
      on_exit(fn ->
        Enum.each(modules_to_mock, fn module ->
          try do
            :meck.unload(module)
          catch
            _, _ -> :ok
          end
        end)
      end)
      
      :ok
    end
    
    test "Displays default logo when none is provided" do
      html = render_component(AndiWeb.HeaderLiveView, is_curator: true, path: "test")

      header_logo =
        Floki.parse_fragment!(html)
        |> Floki.attribute("img", "src")
        |> List.first()

      assert header_logo == "/images/UrbanOS.svg"
    end

    test "Displays provided logo" do
      # Set up specific expectations for this test
      :meck.expect(Application, :get_env, fn
        :andi, :logo_url -> "/images/RuralOS.svg"
        app, env -> :meck.passthrough([app, env])
      end)
      
      :meck.expect(Application, :get_env, fn app, env, opts -> :meck.passthrough([app, env, opts]) end)
      
      html = render_component(AndiWeb.HeaderLiveView, is_curator: true, path: "test")

      header_logo =
        Floki.parse_fragment!(html)
        |> Floki.attribute("img", "src")
        |> List.first()

      assert header_logo == "/images/RuralOS.svg"
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
      # Set up specific expectations for this test
      :meck.expect(Application, :get_env, fn
        :andi, :header_text -> "Definitely Not Data Submission Tool"
        app, env -> :meck.passthrough([app, env])
      end)
      
      :meck.expect(Application, :get_env, fn app, env, opts -> :meck.passthrough([app, env, opts]) end)
      
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
