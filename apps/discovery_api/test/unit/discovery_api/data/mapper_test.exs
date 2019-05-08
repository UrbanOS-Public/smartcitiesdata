defmodule DiscoveryApi.Data.MapperTest do
  use ExUnit.Case
  use Placebo
  alias DiscoveryApi.Data.{Mapper, Model}
  alias SmartCity.TestDataGenerator, as: TDG
  import Checkov

  describe "to_data_model/2 hard overrides" do
    data_test "with #{inspect(overrides)} should default #{inspect(field)} to #{inspect(value)}" do
      dataset = TDG.create_dataset(overrides)
      organization = TDG.create_organization(%{})

      %Model{} = result = Mapper.to_data_model(dataset, organization)

      assert get_in(result, field) == value

      where([
        [:overrides, :field, :value],
        [%{technical: %{private: false}}, [:license], "http://opendefinition.org/licenses/cc-by/"],
        [%{technical: %{private: true}, business: %{license: "MIT"}}, [:license], "MIT"],
        [%{technical: %{private: false}}, [:accessLevel], "public"],
        [%{technical: %{private: true}}, [:accessLevel], "non-public"],
        [%{business: %{conformsToUri: "what"}}, [:conformsToUri], "https://project-open-data.cio.gov/v1.1/schema/"],
        [%{technical: %{sourceFormat: "json"}}, [:fileTypes], ["JSON"]],
        [%{technical: %{sourceFormat: "gtfs"}}, [:fileTypes], ["JSON"]],
        [%{technical: %{sourceFormat: "cSv"}}, [:fileTypes], ["CSV"]]
      ])
    end
  end
end
