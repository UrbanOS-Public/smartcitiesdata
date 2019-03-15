defmodule DiscoveryApi.Data.DataJsonTest do
  use DiscoveryApiWeb.ConnCase
  use Placebo

  @name_space "discovery-api:project-open-data:"

  describe "get_datasets" do
    test "returns project open data dataset catalog", %{conn: conn} do
      first_record = %{
        "some" => "data"
      }

      second_record = %{
        "some" => "data"
      }

      allow(Redix.command!(:redix, ["KEYS", @name_space <> "*"]),
        return: [@name_space <> "dataset.id", @name_space <> "dataset.id2"]
      )

      allow(Redix.command!(:redix, ["MGET", @name_space <> "dataset.id", @name_space <> "dataset.id2"]),
        return: [Jason.encode!(first_record), Jason.encode!(second_record)]
      )

      actual =
        conn
        |> get("/api/v1/data_json")
        |> json_response(200)

      expected = %{
        "conformsTo" => "https://project-open-data.cio.gov/v1.1/schema",
        "@context" => "https://project-open-data.cio.gov/v1.1/schema/catalog.jsonld",
        "dataset" => [
          first_record,
          second_record
        ]
      }

      assert expected == actual
    end
  end
end
