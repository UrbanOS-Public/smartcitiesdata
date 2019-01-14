defmodule DiscoveryApi.Search.FacetFilteratorTest do
  use ExUnit.Case
  alias DiscoveryApi.Search.FacetFilterator

  describe "filter_by_facets" do
    test "given a list of datasets, it filters them with an AND" do
      datasets = [
        %{
          title: "Ben's head canon",
          organization: "OrgA",
          tags: ["BAR"]
        },
        %{
          title: "Ben's Caniac Combo",
          organization: "OrgA",
          tags: ["BAZ"]
        },
        %{
          title: "Jarred's irrational attachment to natorism's",
          organization: "OrgB",
          tags: ["BAZ", "BAR"]
        }
      ]

      facets = %{organization: ["OrgA"], tags: ["BAZ"]}

      assert FacetFilterator.filter_by_facets(datasets, facets) == [
               %{
                 title: "Ben's Caniac Combo",
                 organization: "OrgA",
                 tags: ["BAZ"]
               }
             ]
    end

    test "given a facet that has an empty value, it returns datasets with that value unset" do
      datasets = [
        %{
          title: "Ben's head canon",
          organization: "",
          tags: ["BAR"]
        },
        %{
          title: "Ben's Caniac Combo",
          organization: "OrgA",
          tags: ["BAZ"]
        },
        %{
          title: "Jarred's irrational attachment to natorism's",
          organization: "",
          tags: ["BAZ", "BAR"]
        }
      ]

      facets = %{organization: [""], tags: ["BAR"]}

      assert FacetFilterator.filter_by_facets(datasets, facets) == [
               %{
                 title: "Ben's head canon",
                 organization: "",
                 tags: ["BAR"]
               },
               %{
                 title: "Jarred's irrational attachment to natorism's",
                 organization: "",
                 tags: ["BAZ", "BAR"]
               }
             ]
    end

    test "given multiple values in a facet, it does an AND" do
      datasets = [
        %{
          title: "Ben's head canon",
          organization: "",
          tags: ["BOR"]
        },
        %{
          title: "Ben's Caniac Combo",
          organization: "OrgA",
          tags: ["BAZ"]
        },
        %{
          title: "Jarred's irrational attachment to natorism's",
          organization: "",
          tags: ["BAZ", "BOO", "BOR"]
        }
      ]

      facets = %{organization: [""], tags: ["BAZ", "BOR"]}

      assert FacetFilterator.filter_by_facets(datasets, facets) == [
               %{
                 title: "Jarred's irrational attachment to natorism's",
                 organization: "",
                 tags: ["BAZ", "BOO", "BOR"]
               }
             ]
    end
  end
end
