defmodule DiscoveryApiWeb.DataController.DownloadTest do
  use DiscoveryApiWeb.ConnCase
  use Placebo
  import Checkov
  alias DiscoveryApi.Data.{Model, SystemNameCache}
  alias DiscoveryApi.Services.PrestoService

  @dataset_id "1234-4567-89101"
  @system_name "foobar__company_data"
  @org_name "org1"
  @data_name "data1"

  setup do
    model =
      Helper.sample_model(%{
        id: @dataset_id,
        systemName: @system_name,
        name: @data_name,
        private: false,
        lastUpdatedDate: nil,
        queries: 7,
        downloads: 9,
        organizationDetails: %{
          orgName: @org_name
        },
        schema: [
          %{description: "a number", name: "number", type: "integer"},
          %{description: "a number", name: "number", type: "integer"},
          %{description: "a number", name: "number", type: "integer"}
        ]
      })

    allow(SystemNameCache.get(@org_name, @data_name), return: @dataset_id)
    allow(Model.get(@dataset_id), return: model)

    allow(PrestoService.preview_columns(@system_name),
      return: ["id", "name", "age"]
    )

    allow(Prestige.execute("select * from #{@system_name}"),
      return: [[1, "Joe", 21], [2, "Robby", 32]]
    )

    allow(Redix.command!(any(), any()), return: :does_not_matter)

    :ok
  end

  describe "fetching csv data with array of integers" do
    test "returns flattened array as string in single column in CSV format", %{conn: conn} do
      dataset_id = "pedro"
      url = "/api/v1/dataset/#{dataset_id}/download"

      model =
        Helper.sample_model(%{
          id: dataset_id,
          systemName: "#{@org_name}__paco",
          name: "paco",
          private: false,
          lastUpdatedDate: nil,
          queries: 7,
          downloads: 9,
          organizationDetails: %{
            orgName: @org_name
          },
          schema: [
            %{description: "a number", name: "number", type: "integer"},
            %{description: "a number", name: "number", type: "integer"},
            %{description: "a number", name: "number", type: "integer"}
          ]
        })

      allow(SystemNameCache.get(@org_name, model.name), return: dataset_id)
      allow(Model.get(dataset_id), return: model)

      allow(PrestoService.preview_columns(model.systemName),
        return: ["id", "int_array"]
      )

      allow(Prestige.execute("select * from #{model.systemName}"),
        return: [[1, [2, 3, 4]]]
      )

      allow(Prestige.prefetch(any()),
        return: [["id", "1"], ["int_array", [2, 3, 4]]]
      )

      allow(Redix.command!(any(), any()), return: :does_not_matter)

      actual = conn |> get(url) |> response(200)

      assert "id,int_array\n1,\"2,3,4\"\n" == actual
    end
  end

  describe "metrics" do
    data_test "increments dataset download count when dataset download is requested", %{conn: conn} do
      conn |> get(url) |> response(200)
      assert_called(Redix.command!(:redix, ["INCR", "smart_registry:downloads:count:#{@dataset_id}"]))

      where(
        url: [
          "/api/v1/dataset/1234-4567-89101/download?_format=csv",
          "/api/v1/organization/org1/dataset/data1/download?_format=csv",
          "/api/v1/dataset/1234-4567-89101/download?_format=json",
          "/api/v1/organization/org1/dataset/data1/download?_format=json"
        ]
      )
    end
  end
end
