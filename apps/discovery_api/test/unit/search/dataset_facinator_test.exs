defmodule DiscoveryApi.Search.DatasetFacinatorTest do
  use ExUnit.Case
  alias DiscoveryApi.Search.DatasetFacinator

  describe "facinate" do
    setup do
      {:ok,
       [
         datasets: [
           %{
             title: "Ben's head canon",
             organization: "OrgA",
             keywords: ["my cool keywords", "another keywords"]
           },
           %{
             title: "Ben's Caniac Combo",
             organization: "OrgA",
             keywords: []
           },
           %{
             title: "Jarred's irrational attachment to natorism's",
             organization: "OrgB",
             keywords: ["my cool keywords"]
           },
           %{
             title: "hi its erin",
             organization: "",
             keywords: ["uncool keywords"]
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
               keywords: [
                 %{name: "another keywords", count: 1},
                 %{name: "my cool keywords", count: 2},
                 %{name: "uncool keywords", count: 1}
               ]
             }
    end
  end
end
