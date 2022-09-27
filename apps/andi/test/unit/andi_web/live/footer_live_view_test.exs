defmodule AndiWeb.FooterLiveViewTest do
  use AndiWeb.Test.AuthConnCase.UnitCase
  use Placebo

  describe "Footer Live View" do
    test "Should get links" do
      links = AndiWeb.FooterLiveView.get_links()

      assert %{"linkText" => "ANDI", "url" => "https://127.0.0.1.nip.io:4443"} == Enum.at(links, 0)
      assert %{"linkText" => "DiscoveryUI", "url" => "https://discovery.urbanos-demo.com/dataset"} == Enum.at(links, 1)
      assert %{"linkText" => "Policies", "url" => "https://www.michigan.gov/som/footer/policies"} == Enum.at(links, 2)
    end

    test "Should get left side text" do
      leftSideText = AndiWeb.FooterLiveView.get_left_side_text()

      assert "Copyright 2022 State of Michigan" == leftSideText
    end
  end
end
