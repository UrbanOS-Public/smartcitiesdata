defmodule DiscoveryApi.Data.MapperTest do
  use ExUnit.Case
  use Placebo
  alias DiscoveryApi.Data.{Mapper, Model}
  alias DiscoveryApi.Test.Helper
  alias SmartCity.TestDataGenerator, as: TDG
  import Checkov

  describe "to_data_model/2 hard overrides" do
    data_test "with #{inspect(overrides)} should default #{inspect(field)} to #{inspect(value)}" do
      dataset =
        overrides
        |> TDG.create_dataset()

      organization = DiscoveryApi.Test.Helper.create_schema_organization(%{})

      allow(RaptorService.list_access_groups_by_dataset(any(), any()), return: [])

      %Model{} = result = Mapper.to_data_model(dataset, organization)

      assert get_in(result, field) == value

      where([
        [:overrides, :field, :value],
        [%{technical: %{private: false}, business: %{license: nil}}, [:license], "http://opendefinition.org/licenses/cc-by/"],
        [%{technical: %{private: true}, business: %{license: nil}}, [:license], nil],
        [%{technical: %{private: false}, business: %{license: "overridden"}}, [:license], "overridden"],
        [%{technical: %{private: true}, business: %{license: "overridden"}}, [:license], "overridden"],
        [%{technical: %{private: false}}, [:accessLevel], "public"],
        [%{technical: %{private: true}}, [:accessLevel], "non-public"],
        [%{business: %{conformsToUri: nil}}, [:conformsToUri], "https://project-open-data.cio.gov/v1.1/schema/"],
        [%{business: %{conformsToUri: "overridden"}}, [:conformsToUri], "https://project-open-data.cio.gov/v1.1/schema/"],
        [%{technical: %{sourceFormat: "application/json"}}, [:fileTypes], ["JSON"]],
        [%{technical: %{sourceFormat: "application/gtfs+protobuf"}}, [:fileTypes], ["JSON"]],
        [%{technical: %{sourceFormat: "text/csv"}}, [:fileTypes], ["CSV"]]
      ])
    end
  end

  describe "add_access_group/2" do
    test "an access group can be successfully added to an empty list of access groups" do
      model = Mapper.add_access_group(Helper.sample_model(), "some_id")
      assert model.accessGroups == ["some_id"]
    end

    test "an access group can be successfully added to an existing list of access groups" do
      model = Mapper.add_access_group(Helper.sample_model(%{accessGroups: ["previous_id"]}), "some_id")
      assert model.accessGroups == ["previous_id", "some_id"]
    end
  end

  describe "remove_access_group/2" do
    test "an access group can be successfully removed from an existing list of access groups" do
      model = Mapper.remove_access_group(Helper.sample_model(%{accessGroups: ["id", "id_to_remove"]}), "id_to_remove")
      assert model.accessGroups == ["id"]
    end
  end
end
