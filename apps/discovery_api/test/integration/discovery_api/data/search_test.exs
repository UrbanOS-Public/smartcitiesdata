defmodule DiscoveryApi.Data.SearchTest do
  use ExUnit.Case
  use Divo, services: [:redis]
  alias DiscoveryApi.Data.Model
  alias DiscoveryApi.Test.Helper

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
  end
end
