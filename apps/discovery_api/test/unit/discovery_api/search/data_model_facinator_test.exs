defmodule DiscoveryApi.Search.DataModelFacinatorTest do
  use ExUnit.Case
  alias DiscoveryApi.Search.DataModelFacinator
  alias DiscoveryApi.Test.Helper

  describe "extract_facets/1" do
    setup do
      {:ok,
       [
         models: [
           Helper.sample_model(%{
             title: "Ben's head canon",
             organization: "OrgA",
             keywords: ["my cool keywords", "another keywords"]
           }),
           Helper.sample_model(%{
             title: "Ben's Caniac Combo",
             organization: "OrgA",
             keywords: []
           }),
           Helper.sample_model(%{
             title: "Jarred's irrational attachment to natorism's",
             organization: "OrgB",
             keywords: ["my cool keywords"]
           }),
           Helper.sample_model(%{
             title: "hi its erin",
             organization: "",
             keywords: ["uncool keywords"]
           })
         ]
       ]}
    end

    test "given a list of models, it extracts unique facets and their counts", context do
      assert DataModelFacinator.extract_facets(context[:models]) == %{
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
