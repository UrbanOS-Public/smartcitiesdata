defmodule DiscoveryApi.Search.DataModelFilteratorTest do
  use ExUnit.Case
  alias DiscoveryApi.Search.DataModelFilterator
  alias DiscoveryApi.Test.Helper

  describe "filter_by_facets" do
    test "given a list of models, it filters them with an AND" do
      models = [
        Helper.sample_model(%{
          title: "Ben's head canon",
          organization: "OrgA",
          keywords: ["BAR"]
        }),
        Helper.sample_model(%{
          title: "Ben's Caniac Combo",
          organization: "OrgA",
          keywords: ["BAZ"]
        }),
        Helper.sample_model(%{
          title: "Jarred's irrational attachment to natorism's",
          organization: "OrgB",
          keywords: ["BAZ", "BAR"]
        })
      ]

      facets = %{organization: ["OrgA"], keywords: ["BAZ"]}
      expected_models = [Enum.at(models, 1)]

      assert DataModelFilterator.filter_by_facets(models, facets) == expected_models
    end

    test "given a facet that has an empty value, it returns models with that value unset" do
      models = [
        Helper.sample_model(%{
          title: "Ben's head canon",
          organization: "",
          keywords: ["BAR"]
        }),
        Helper.sample_model(%{
          title: "Ben's Caniac Combo",
          organization: "OrgA",
          keywords: ["BAZ"]
        }),
        Helper.sample_model(%{
          title: "Jarred's irrational attachment to natorism's",
          organization: "",
          keywords: ["BAZ", "BAR"]
        })
      ]

      facets = %{organization: [""], keywords: ["BAR"]}

      expected_models = [Enum.at(models, 0), Enum.at(models, 2)]

      assert DataModelFilterator.filter_by_facets(models, facets) == expected_models
    end

    test "given multiple values in a facet, it does an AND" do
      models = [
        Helper.sample_model(%{
          title: "Ben's head canon",
          organization: "",
          keywords: ["BOR"]
        }),
        Helper.sample_model(%{
          title: "Ben's Caniac Combo",
          organization: "OrgA",
          keywords: ["BAZ"]
        }),
        Helper.sample_model(%{
          title: "Jarred's irrational attachment to natorism's",
          organization: "",
          keywords: ["BAZ", "BOO", "BOR"]
        })
      ]

      facets = %{organization: [""], keywords: ["BAZ", "BOR"]}

      expected_models = [Enum.at(models, 2)]

      assert DataModelFilterator.filter_by_facets(models, facets) == expected_models
    end
  end
end
