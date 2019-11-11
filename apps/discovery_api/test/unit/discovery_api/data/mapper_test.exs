defmodule DiscoveryApi.Data.MapperTest do
  use ExUnit.Case
  use Placebo
  alias DiscoveryApi.Data.{Mapper, Model}
  alias DiscoveryApi.TestDataGenerator, as: TDG
  import Checkov

  describe "to_data_model/2 hard overrides" do
    data_test "with #{inspect(overrides)} should default #{inspect(field)} to #{inspect(value)}" do
      dataset =
        overrides
        |> TDG.create_dataset()
        # NOTE: *for now* we need to re-apply the overrides to make sure that our provided source format does not get converted to a mime type
        # that we're not using yet in Discovery API.  This will change once we start consuming dataset update events from the event stream.
        |> SmartCity.Helpers.deep_merge(overrides)

      organization = TDG.create_schema_organization(%{})

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
        [%{technical: %{sourceFormat: "json"}}, [:fileTypes], ["JSON"]],
        [%{technical: %{sourceFormat: "gtfs"}}, [:fileTypes], ["JSON"]],
        [%{technical: %{sourceFormat: "cSv"}}, [:fileTypes], ["CSV"]]
      ])
    end
  end
end
