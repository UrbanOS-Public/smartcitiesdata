defmodule DiscoveryApi.Data.SearchTest do
  use ExUnit.Case
  use DiscoveryApi.DataCase
  alias DiscoveryApi.Test.Helper
  alias SmartCity.TestDataGenerator, as: TDG
  import SmartCity.Event, only: [dataset_update: 0]
  import SmartCity.TestHelper
  alias DiscoveryApi.Data.Model

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

    Brook.Test.with_event(DiscoveryApi.instance(), fn ->
      Brook.ViewState.merge(:models, model_one.id, model_one)
      Brook.ViewState.merge(:models, model_two.id, model_two)
    end)

    :ok
  end

  describe "/api/v1/search" do
    test "discovery_api doesn't return server in response headers" do
      %HTTPoison.Response{status_code: _, headers: headers, body: _} =
        "http://localhost:4000/api/v1/dataset/search"
        |> HTTPoison.get!()

      refute headers |> Map.new() |> Map.has_key?("server")
    end

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
      organization = Helper.create_persisted_organization()

      dataset =
        TDG.create_dataset(%{
          business: %{description: "Bob had a horse and this is its data"},
          technical: %{orgId: organization.id, schema: []}
        })

      Brook.Event.send(DiscoveryApi.instance(), dataset_update(), __MODULE__, dataset)

      eventually(fn ->
        assert nil != Model.get(dataset.id)
      end)

      Redix.command!(:redix, ["FLUSHALL"])

      params = Plug.Conn.Query.encode(%{query: "Bob"})

      eventually(fn ->
        %{status_code: status_code, body: _body} =
          "http://localhost:4000/api/v1/dataset/search?#{params}"
          |> HTTPoison.get!()

        assert status_code == 200
      end)
    end
  end
end
