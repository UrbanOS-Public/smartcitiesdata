defmodule AndiWeb.FooterLiveViewTest do
  use AndiWeb.Test.AuthConnCase.UnitCase
  use Placebo

  describe "Footer Live View" do
    test "Should get links" do
      links = AndiWeb.FooterLiveView.get_links()

      assert %{"linkText" => "Example 1", "url" => "https://www.example.com"} == Enum.at(links, 0)
      assert %{"linkText" => "Example 2", "url" => "https://www.google.com"} == Enum.at(links, 1)
    end

    test "Should get left side text" do
      leftSideText = AndiWeb.FooterLiveView.get_left_side_text()

      assert "Some Left Side Text" == leftSideText
    end
  end
end
