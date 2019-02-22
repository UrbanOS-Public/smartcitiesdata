defmodule DiscoveryApi.Search.FacetFilteratorTest do
  use ExUnit.Case
  alias DiscoveryApi.Search.FacetFilterator

  describe "filter_by_facets" do
    test "given a list of datasets, it filters them with an AND" do
      datasets = [
        %{
          title: "Ben's head canon",
          organization: "OrgA",
          keywords: ["BAR"]
        },
        %{
          title: "Ben's Caniac Combo",
          organization: "OrgA",
          keywords: ["BAZ"]
        },
        %{
          title: "Jarred's irrational attachment to natorism's",
          organization: "OrgB",
          keywords: ["BAZ", "BAR"]
        }
      ]

      facets = %{organization: ["OrgA"], keywords: ["BAZ"]}

      assert FacetFilterator.filter_by_facets(datasets, facets) == [
               %{
                 title: "Ben's Caniac Combo",
                 organization: "OrgA",
                 keywords: ["BAZ"]
               }
             ]
    end

    test "given a facet that has an empty value, it returns datasets with that value unset" do
      datasets = [
        %{
          title: "Ben's head canon",
          organization: "",
          keywords: ["BAR"]
        },
        %{
          title: "Ben's Caniac Combo",
          organization: "OrgA",
          keywords: ["BAZ"]
        },
        %{
          title: "Jarred's irrational attachment to natorism's",
          organization: "",
          keywords: ["BAZ", "BAR"]
        }
      ]

      facets = %{organization: [""], keywords: ["BAR"]}

      assert FacetFilterator.filter_by_facets(datasets, facets) == [
               %{
                 title: "Ben's head canon",
                 organization: "",
                 keywords: ["BAR"]
               },
               %{
                 title: "Jarred's irrational attachment to natorism's",
                 organization: "",
                 keywords: ["BAZ", "BAR"]
               }
             ]
    end

    test "given multiple values in a facet, it does an AND" do
      datasets = [
        %{
          title: "Ben's head canon",
          organization: "",
          keywords: ["BOR"]
        },
        %{
          title: "Ben's Caniac Combo",
          organization: "OrgA",
          keywords: ["BAZ"]
        },
        %{
          title: "Jarred's irrational attachment to natorism's",
          organization: "",
          keywords: ["BAZ", "BOO", "BOR"]
        }
      ]

      facets = %{organization: [""], keywords: ["BAZ", "BOR"]}

      assert FacetFilterator.filter_by_facets(datasets, facets) == [
               %{
                 title: "Jarred's irrational attachment to natorism's",
                 organization: "",
                 keywords: ["BAZ", "BOO", "BOR"]
               }
             ]
    end
  end
end
