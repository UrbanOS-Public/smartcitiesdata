defmodule DiscoveryApi.Search.DatasetFacinatorTest do
  use ExUnit.Case
  alias DiscoveryApi.Search.DatasetFacinator

  describe "facinate" do
    test "given a list of datasets, it extracts unique organizations and their counts" do
      datasets = [
        %{
          title: "Ben's head cannon",
          organization: "OrgA"
        },
        %{
          title: "Ben's Caniac Combo",
          organization: "OrgA"
        },
        %{
          title: "Jarred's irrational attachment to natorism's",
          organization: "OrgB"
        }
      ]

      assert DatasetFacinator.get_facets(datasets) == %{
               organization: %{
                 "OrgA" => 2,
                 "OrgB" => 1
               }
             }
    end

    test "given a list of datasets, and an empty filter it properly extracts empty attributes" do
      datasets = [
        %{
          title: "Ben's head cannon",
          organization: ""
        },
        %{
          title: "Ben's Caniac Combo",
          organization: "OrgA"
        },
        %{
          title: "Jarred's irrational attachment to natorism's",
          organization: "OrgB"
        }
      ]

      assert DatasetFacinator.get_facets(datasets) == %{
               organization: %{
                 "OrgA" => 1,
                 "OrgB" => 1,
                 "" => 1
               }
             }
    end

    test "given a list of datasets, and a filter for an empty attribute it properly extracts empty attributes" do
      datasets = [
        %{
          title: "Ben's head cannon",
          organization: ""
        },
        %{
          title: "Ben's Caniac Combo",
          organization: "OrgA"
        },
        %{
          title: "Jarred's irrational attachment to natorism's",
          organization: "OrgB"
        }
      ]

      assert DatasetFacinator.get_facets(datasets) == %{
               organization: %{
                 "OrgA" => 1,
                 "OrgB" => 1,
                 "" => 1
               }
             }
    end
  end
end
