defmodule DiscoveryApi.Search.FacetFilteratorTest do
  use ExUnit.Case
  alias DiscoveryApi.Search.FacetFilterator

  describe "filter_by_facets" do
    test "given a list of datasets, it filters them with an AND" do
      datasets = [
        %{
          title: "Ben's head canon",
          organization: "OrgA",
          foo: "BAR"
        },
        %{
          title: "Ben's Caniac Combo",
          organization: "OrgA",
          foo: "BAZ"
        },
        %{
          title: "Jarred's irrational attachment to natorism's",
          organization: "OrgB",
          foo: "BAR"
        }
      ]

      facets = %{"organization" => ["OrgA"], "foo" => ["BAZ"]}

      assert FacetFilterator.filter_by_facets(datasets, facets) == [
               %{
                 title: "Ben's Caniac Combo",
                 organization: "OrgA",
                 foo: "BAZ"
               }
             ]
    end

    test "given a facet that has an empty value, it returns datasets with that value unset" do
      datasets = [
        %{
          title: "Ben's head canon",
          organization: "",
          foo: "BAR"
        },
        %{
          title: "Ben's Caniac Combo",
          organization: "OrgA",
          foo: "BAZ"
        },
        %{
          title: "Jarred's irrational attachment to natorism's",
          organization: nil,
          foo: "BAR"
        }
      ]

      facets = %{"organization" => [""]}

      assert FacetFilterator.filter_by_facets(datasets, facets) == [
               %{
                 title: "Ben's head canon",
                 organization: "",
                 foo: "BAR"
               },
               %{
                 title: "Jarred's irrational attachment to natorism's",
                 organization: nil,
                 foo: "BAR"
               }
             ]
    end
  end
end
