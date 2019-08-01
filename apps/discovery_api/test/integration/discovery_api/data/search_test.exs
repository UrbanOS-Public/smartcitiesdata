defmodule DiscoveryApi.Data.SearchTest do
  use ExUnit.Case
  use Divo, services: [:redis]
  alias DiscoveryApi.Data.Model
  alias DiscoveryApi.Test.Helper
  alias SmartCity.TestDataGenerator, as: TDG
  alias SmartCity.{Dataset, Organization}


  setup do
    Redix.command!(:redix, ["FLUSHALL"])

    model_one =
      Helper.sample_model(%{
        private: false,
        title: "one",
        keywords: ["model", "one"],
        organization: "one",
        description: "one"
      })

    model_two =
      Helper.sample_model(%{
        private: false,
        title: "two",
        keywords: ["model", "two"],
        organization: "two",
        description: "two"
      })

    Model.save(model_one)
    Model.save(model_two)

    :ok
  end

  describe "/api/v1/search" do
    test "returns zero count facets when no results are found" do
      params_that_return_nothing = Plug.Conn.Query.encode(%{query: "zero", facets: %{keywords: ["model"]}})

      %{status_code: _status_code, body: body} =
        "http://localhost:4000/api/v1/dataset/search/?#{params_that_return_nothing}"
        |> HTTPoison.get!()

      assert 2 == Enum.count(String.split(String.downcase(body), "keywords")),
             "response body included too many keyword entries #{inspect(body)}"

      results = Jason.decode!(body)
      assert get_in(results, ["metadata", "facets", "keywords"]) == [%{"name" => "model", "count" => 0}]
    end

    test "does not error when a dataset in the search cache has been deleted from redis" do
      Redix.command!(:redix, ["FLUSHALL"])
      organization = TDG.create_organization(%{})
      Organization.write(organization)
      dataset = TDG.create_dataset(%{business: %{description: "Bob had a horse and this is its data"}, technical: %{orgId: organization.id}})
      Dataset.write(dataset)
      DiscoveryApi.Data.DatasetEventListener.handle_dataset(dataset)

      Process.sleep(5000)

      :ets.lookup(DiscoveryApi.Search.Storage, "Bob") |> IO.inspect(label: "BEFORE")
      Redix.command!(:redix, ["FLUSHALL"])
      :ets.lookup(DiscoveryApi.Search.Storage, "Bob") |> IO.inspect(label: "AFTER")


      %{status_code: status_code, body: body} =
        "http://localhost:4000/api/v1/dataset/search/?q=Bob"
        |> HTTPoison.get!()

      IO.inspect(body)
      assert status_code == 200
    end
  end
end
