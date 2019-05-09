defmodule DiscoveryApi.Data.MapperTest do
  use ExUnit.Case
  use Placebo
  alias DiscoveryApi.Data.{Mapper, Model}
  alias SmartCity.TestDataGenerator, as: TDG
  import Checkov

  describe "to_data_model/2 hard overrides" do
    cc_license_url = "http://opendefinition.org/licenses/cc-by/"
    podms_url = "https://project-open-data.cio.gov/v1.1/schema/"

    data_test "with #{inspect(overrides)} should default #{inspect(field)} to #{inspect(value)}" do
      dataset = TDG.create_dataset(overrides)
      organization = TDG.create_organization(%{})

      %Model{} = result = Mapper.to_data_model(dataset, organization)

      assert get_in(result, field) == value

      where([
        [:overrides, :field, :value],
        [%{technical: %{private: false}, business: %{license: nil}}, [:license], cc_license_url],
        [%{technical: %{private: true}, business: %{license: nil}}, [:license], nil],
        [%{technical: %{private: false}, business: %{license: "overridden"}}, [:license], "overridden"],
        [%{technical: %{private: true}, business: %{license: "overridden"}}, [:license], "overridden"],
        [%{technical: %{private: false}}, [:accessLevel], "public"],
        [%{technical: %{private: true}}, [:accessLevel], "non-public"],
        [%{business: %{conformsToUri: nil}}, [:conformsToUri], podms_url],
        [%{business: %{conformsToUri: "overridden"}}, [:conformsToUri], podms_url],
        [%{technical: %{sourceFormat: "json"}}, [:fileTypes], ["JSON"]],
        [%{technical: %{sourceFormat: "gtfs"}}, [:fileTypes], ["JSON"]],
        [%{technical: %{sourceFormat: "cSv"}}, [:fileTypes], ["CSV"]]
      ])
    end
  end
end
