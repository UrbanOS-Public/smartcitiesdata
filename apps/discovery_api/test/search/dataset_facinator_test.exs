defmodule DiscoveryApi.Search.DatasetFacinatorTest do
  use ExUnit.Case
  alias DiscoveryApi.Search.DatasetFacinator

  describe "facinate" do
    setup context do
      {:ok,
       [
         datasets: [
           %{
             title: "Ben's head canon",
             organization: "OrgA",
             tags: ["my cool tag", "another tag"]
           },
           %{
             title: "Ben's Caniac Combo",
             organization: "OrgA",
             tags: []
           },
           %{
             title: "Jarred's irrational attachment to natorism's",
             organization: "OrgB",
             tags: ["my cool tag"]
           },
           %{
             title: "hi its erin",
             organization: "",
             tags: ["uncool tag"]
           }
         ]
       ]}
    end

    test "given a list of datasets, it extracts unique facets and their counts", context do
      assert DatasetFacinator.get_facets(context[:datasets]) == %{
              organization: [
                %{name: "", count: 1},
                %{name: "OrgA", count: 2},
                %{name: "OrgB", count: 1}
              ],
              tags: [
                %{name: "another tag", count: 1},
                %{name: "my cool tag", count: 2},
                %{name: "uncool tag", count: 1}
              ]
             }
    end
  end
end
