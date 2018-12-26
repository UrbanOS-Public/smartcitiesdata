defmodule DiscoveryApi.Search.DatasetFacinatorTest do
  use ExUnit.Case
  alias DiscoveryApi.Search.DatasetFacinator


  describe "facinate" do
    setup context do
      {:ok, [
          datasets: [
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
            },
            %{
              title: "hi its erin",
              organization: ""
            },
          ]
        ]
      }
    end

    test "given a list of datasets, it extracts unique organizations and their counts", context do
      assert DatasetFacinator.get_facets(context[:datasets]) == %{
        organization: %{
          "OrgA" => 2,
          "OrgB" => 1,
          "" => 1
        }
      }
    end
  end
end
