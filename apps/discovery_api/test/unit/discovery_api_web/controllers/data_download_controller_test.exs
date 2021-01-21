defmodule DiscoveryApiWeb.DataDownloadControllerTest do
  use DiscoveryApiWeb.Test.AuthConnCase.UnitCase
  use Placebo
  use Properties, otp_app: :discovery_api

  import Checkov
  import SmartCity.TestHelper
  alias DiscoveryApi.Services.ObjectStorageService
  alias DiscoveryApi.Data.{Model, SystemNameCache}
  alias DiscoveryApi.Services.PrestoService
  alias DiscoveryApi.Schemas.Users
  alias DiscoveryApi.Test.Helper

  @dataset_id "1234-4567-89101"
  @system_name "foobar__company_data"
  @org_name "org1"
  @data_name "data1"
  @user_id "user_id"

  getter(:presign_key, generic: true)
  getter(:download_link_expire_seconds, generic: true)

  setup %{auth_conn_case: auth_conn_case} do
    auth_conn_case.disable_revocation_list.()

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
          %{name: "id", type: "integer"},
          %{name: "name", type: "string"}
        ]
      })

    allow(SystemNameCache.get(@org_name, @data_name), return: @dataset_id)
    allow(Model.get(@dataset_id), return: model)

    allow(PrestoService.preview_columns(any(), @system_name),
      return: ["id", "name"]
    )

    allow(Prestige.new_session(any()), return: :connection)

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
            %{name: "number", type: "integer"},
            %{name: "number", type: "integer"}
          ]
        })

      allow(SystemNameCache.get(@org_name, model.name), return: dataset_id)
      allow(Model.get(dataset_id), return: model)

      allow(PrestoService.preview_columns(any(), model.systemName),
        return: ["id", "int_array"]
      )

      allow(Redix.command!(any(), any()), return: :ok)

      allow(Prestige.stream!(any(), "select * from #{model.systemName}"), return: [:result])

      allow(Prestige.Result.as_maps(:result),
        return: [%{"id" => 1, "int_array" => [2, 3, 4]}]
      )

      allow(Redix.command!(any(), any()), return: :does_not_matter)

      actual = conn |> get(url) |> response(200)

      assert "id,int_array\n1,\"2,3,4\"\n" == actual
    end

    test "does not return bbox calculation when feature list is empty", %{conn: conn} do
      dataset_id = "stanislav"
      url = "/api/v1/dataset/#{dataset_id}/download"

      model =
        Helper.sample_model(%{
          id: dataset_id,
          systemName: "#{@org_name}__stan",
          name: "stan",
          private: false,
          lastUpdatedDate: nil,
          queries: 7,
          downloads: 9,
          organizationDetails: %{
            orgName: @org_name
          },
          schema: [
            %{name: "feature", type: "json"}
          ]
        })

      allow(SystemNameCache.get(@org_name, model.name), return: dataset_id)
      allow(Model.get(dataset_id), return: model)

      allow(PrestoService.preview_columns(any(), model.systemName),
        return: ["feature"]
      )

      allow(Prestige.stream!(any(), "select * from #{model.systemName}"), return: [:result])

      allow(Prestige.Result.as_maps(:result), return: [])

      allow(Redix.command!(any(), any()), return: :does_not_matter)

      actual = conn |> put_req_header("accept", "application/geo+json") |> get(url) |> response(200)

      expected = %{
        "type" => "FeatureCollection",
        "name" => "#{@org_name}__stan",
        "features" => []
      }

      assert expected == actual |> Jason.decode!()
    end

    test "returns json fields as valid json", %{conn: conn} do
      dataset_id = "stanislav"
      url = "/api/v1/dataset/#{dataset_id}/download"

      model =
        Helper.sample_model(%{
          id: dataset_id,
          systemName: "#{@org_name}__stan",
          name: "stan",
          private: false,
          lastUpdatedDate: nil,
          queries: 7,
          downloads: 9,
          organizationDetails: %{
            orgName: @org_name
          },
          schema: [
            %{name: "feature", type: "json"}
          ]
        })

      allow(SystemNameCache.get(@org_name, model.name), return: dataset_id)
      allow(Model.get(dataset_id), return: model)

      allow(PrestoService.preview_columns(any(), model.systemName),
        return: ["feature"]
      )

      allow(Prestige.stream!(any(), "select * from #{model.systemName}"), return: [:result])

      allow(Prestige.Result.as_maps(:result),
        return: [%{"feature" => "{\"geometry\":{\"coordinates\":[0,1]}}"}]
      )

      allow(Redix.command!(any(), any()), return: :does_not_matter)

      actual = conn |> put_req_header("accept", "application/geo+json") |> get(url) |> response(200)

      expected = %{
        "type" => "FeatureCollection",
        "name" => "#{@org_name}__stan",
        "features" => [
          %{
            "geometry" => %{
              "coordinates" => [0, 1]
            }
          }
        ],
        "bbox" => [0, 1, 0, 1]
      }

      assert expected == actual |> Jason.decode!()
    end

    test "returns columns in correct order even if dictionary is out of order", %{conn: conn} do
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
            %{name: "bob", type: "integer"},
            %{name: "andi", type: "integer"}
          ]
        })

      allow(SystemNameCache.get(@org_name, model.name), return: dataset_id)
      allow(Model.get(dataset_id), return: model)

      allow(PrestoService.preview_columns(any(), model.systemName),
        return: ["bob", "andi"]
      )

      allow(Prestige.stream!(any(), "select * from #{model.systemName}"), return: [:result])

      allow(Prestige.Result.as_maps(:result),
        return: [%{"andi" => 1, "bob" => 2}]
      )

      allow(Redix.command!(any(), any()), return: :does_not_matter)

      actual = conn |> get(url) |> response(200)

      assert "andi,bob\n1,2\n" == actual
    end
  end

  describe "metrics" do
    setup do
      allow(Prestige.stream!(any(), "select * from #{@system_name}"), return: [:result])

      allow(Prestige.Result.as_maps(:result),
        return: [%{"id" => 1, name: "Joe"}, %{"id" => 2, name: "Robby"}]
      )

      :ok
    end

    data_test "increments dataset download count when user requests download", %{conn: conn} do
      conn
      |> get(url)
      |> response(200)

      eventually(fn -> assert_called(Redix.command!(:redix, ["INCR", "smart_registry:downloads:count:#{@dataset_id}"])) end)

      where(
        url: [
          "/api/v1/dataset/1234-4567-89101/download?_format=csv",
          "/api/v1/organization/org1/dataset/data1/download?_format=csv",
          "/api/v1/dataset/1234-4567-89101/download?_format=json",
          "/api/v1/organization/org1/dataset/data1/download?_format=json"
        ]
      )
    end

    data_test "does not increment dataset download count when ui requests download", %{conn: conn} do
      conn
      |> Plug.Conn.put_req_header("origin", "data.integration.tests.example.com")
      |> get(url)
      |> response(200)

      refute_called(Redix.command!(:redix, ["INCR", "smart_registry:downloads:count:#{@dataset_id}"]))

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

  describe "presign_url" do
    test "returns a presigned url for public datasets when bearer token is not passed", %{conn: conn} do
      key = presign_key()
      dataset_id = "public_dataset"

      model =
        Helper.sample_model(%{
          id: dataset_id,
          systemName: "#{@org_name}__presign_public",
          name: "presign_public",
          private: false,
          lastUpdatedDate: nil,
          queries: 7,
          downloads: 9,
          organizationDetails: %{
            orgName: @org_name
          },
          schema: [
            %{name: "feature", type: "json"}
          ]
        })

      allow(SystemNameCache.get(@org_name, model.name), return: dataset_id)
      allow(Model.get(dataset_id), return: model)

      expires_in_seconds = download_link_expire_seconds()

      expires = DateTime.utc_now() |> DateTime.add(expires_in_seconds, :second) |> DateTime.to_unix()
      hmac = :crypto.hmac(:sha256, key, "#{dataset_id}/#{expires}") |> Base.encode16()

      url = "https://data.tests.example.com/api/v1/dataset/#{dataset_id}/download/presigned_url"
      actual_response = conn |> get(url) |> response(200)
      assert "\"https://data.tests.example.com/api/v1/dataset/#{dataset_id}/download?key=#{hmac}&expires=#{expires}\"" == actual_response
    end

    test "returns an error if we try to download a private dataset with no hmac token", %{conn: conn} do
      dataset_id = "private_dataset"

      model =
        Helper.sample_model(%{
          id: dataset_id,
          systemName: "#{@org_name}__presign_private",
          name: "presign_private",
          private: true,
          lastUpdatedDate: nil,
          queries: 7,
          downloads: 9,
          organizationDetails: %{
            orgName: @org_name
          },
          schema: [
            %{name: "feature", type: "json"}
          ]
        })

      allow(SystemNameCache.get(@org_name, model.name), return: dataset_id)
      allow(Model.get(dataset_id), return: model)

      url = "/api/v1/dataset/#{dataset_id}/download/presigned_url"
      actual_response = conn |> get(url) |> response(404)
      assert "{\"message\":\"Not Found\"}" == actual_response
    end

    test "returns 404 for private dataset presign request when user is not authorized to view the dataset", %{conn: conn} do
      dataset_id = "private_dataset"

      model =
        Helper.sample_model(%{
          id: dataset_id,
          systemName: "#{@org_name}__presign_private",
          name: "presign_private",
          private: true,
          lastUpdatedDate: nil,
          queries: 7,
          downloads: 9,
          organizationDetails: %{
            orgName: @org_name
          },
          schema: [
            %{name: "feature", type: "json"}
          ]
        })

      allow(SystemNameCache.get(@org_name, model.name), return: dataset_id)
      allow(Model.get(dataset_id), return: model)

      url = "/api/v1/dataset/#{dataset_id}/download/presigned_url"
      actual_response = conn |> get(url) |> response(404)
      assert "{\"message\":\"Not Found\"}" == actual_response
    end
  end

  describe "with Auth0 auth provider" do
    test "returns a presigned url for private datasets when valid token is passed", %{
      authorized_conn: conn,
      authorized_subject: subject
    } do
      dataset_id = "private_dataset"

      allow(Users.get_user_with_organizations(subject, :subject_id), return: {:ok, %{id: @user_id, organizations: [%{id: "org_id"}]}})

      model =
        Helper.sample_model(%{
          id: dataset_id,
          systemName: "#{@org_name}__presign_private",
          name: "presign_private",
          private: true,
          lastUpdatedDate: nil,
          queries: 7,
          downloads: 9,
          organizationDetails: %{
            orgName: @org_name,
            id: "org_id"
          },
          schema: [
            %{name: "feature", type: "json"}
          ]
        })

      allow(SystemNameCache.get(@org_name, model.name), return: dataset_id)
      allow(Model.get(dataset_id), return: model)
      hmac = "IAMANHMACTOKENFORREAL"
      date_time = DateTime.utc_now()
      allow(DiscoveryApiWeb.Utilities.HmacToken.create_hmac_token(any(), any()), return: "IAMANHMACTOKENFORREAL")
      allow(DateTime.utc_now(), return: date_time, meck_options: [:passthrough])

      expires_in_seconds = download_link_expire_seconds()
      expires = DateTime.utc_now() |> DateTime.add(expires_in_seconds, :second) |> DateTime.to_unix()
      url = "https://data.tests.example.com/api/v1/dataset/#{dataset_id}/download/presigned_url"

      actual_response =
        get(conn, url)
        |> response(200)

      assert "\"https://data.tests.example.com/api/v1/dataset/#{dataset_id}/download?key=#{hmac}&expires=#{expires}\"" == actual_response
    end
  end

  test "public hosted file works", %{anonymous_conn: conn} do
    dataset_id = "kenny_and_austin"

    model =
      Helper.sample_model(%{
        id: dataset_id,
        systemName: "#{@org_name}__akd",
        name: "akd",
        private: false,
        lastUpdatedDate: nil,
        queries: 7,
        downloads: 9,
        sourceType: "host",
        describeByMimeType: "text/csv",
        organizationDetails: %{
          orgName: @org_name
        },
        schema: [
          %{name: "bob", type: "integer"},
          %{name: "andi", type: "integer"}
        ]
      })

    allow(SystemNameCache.get(@org_name, model.name), return: dataset_id)
    allow(Model.get(dataset_id), return: model)
    allow(ObjectStorageService.download_file_as_stream(any(), any()), return: {:ok, ["anything"], "csv"})
    allow(Redix.command!(any(), any()), return: :ok)


    url = "/api/v1/dataset/#{dataset_id}/download"

    conn
    |> put_req_header("accept", "text/csv")
    |> get(url)

    assert_called(ObjectStorageService.download_file_as_stream("#{@org_name}/akd", ["csv"]))
  end
end
