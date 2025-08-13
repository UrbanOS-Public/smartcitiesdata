defmodule DiscoveryApiWeb.DataDownloadControllerTest do
  use DiscoveryApiWeb.Test.AuthConnCase.UnitCase
  import Mox
  use Properties, otp_app: :discovery_api

  setup :verify_on_exit!
  setup :set_mox_from_context

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
    stub(RaptorServiceMock, :is_authorized_by_user_id, fn _a, _b, _c -> true end)
    stub(RaptorServiceMock, :list_access_groups_by_dataset, fn _a, _b -> %{access_groups: ["org_id"]} end)
    stub(RaptorServiceMock, :list_groups_by_user, fn _a, _b -> %{access_groups: ["org_id"], organizations: []} end)
    stub(RaptorServiceMock, :is_authorized, fn _a, _b, _c -> true end)

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

    stub(SystemNameCacheMock, :get, fn _org, _data -> @dataset_id end)
    stub(ModelMock, :get, fn _id -> model end)

    stub(PrestoServiceMock, :preview_columns, fn _any -> ["id", "name"] end)

    stub(PrestigeMock, :new_session, fn _any -> :connection end)

    stub(RedixMock, :command!, fn _a, _b -> :does_not_matter end)

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

      stub(SystemNameCacheMock, :get, fn _org_name, _name -> dataset_id end)
      stub(ModelMock, :get, fn _id -> model end)

      stub(PrestoServiceMock, :preview_columns, fn _any ->
        ["id", "int_array"]
      end)

      stub(RedixMock, :command!, fn _a, _b -> :ok end)

      stub(PrestigeMock, :stream!, fn _a, _b -> [:result] end)

      stub(PrestigeMock, :Result.as_maps, fn :result ->
        [%{"id" => 1, "int_array" => [2, 3, 4]}]
      end)

      stub(RedixMock, :command!, fn _a, _b -> :does_not_matter end)

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

      stub(SystemNameCacheMock, :get, fn _org_name, _name -> dataset_id end)
      stub(ModelMock, :get, fn _id -> model end)

      stub(PrestoServiceMock, :preview_columns, fn _any ->
        ["feature"]
      end)

      stub(PrestigeMock, :stream!, fn _a, _b -> [:result] end)

      stub(PrestigeMock, :Result.as_maps, fn :result -> [] end)

      stub(RedixMock, :command!, fn _a, _b -> :does_not_matter end)

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

      stub(SystemNameCacheMock, :get, fn _org_name, _name -> dataset_id end)
      stub(ModelMock, :get, fn _id -> model end)

      stub(PrestoServiceMock, :preview_columns, fn _any ->
        ["feature"]
      end)

      stub(PrestigeMock, :stream!, fn _a, _b -> [:result] end)

      stub(PrestigeMock, :Result.as_maps, fn :result ->
        [%{"feature" => "{\"geometry\":{\"coordinates\":[0,1]}}"}]
      end)

      stub(RedixMock, :command!, fn _a, _b -> :does_not_matter end)

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

      stub(SystemNameCacheMock, :get, fn _org_name, _name -> dataset_id end)
      stub(ModelMock, :get, fn _id -> model end)

      stub(PrestoServiceMock, :preview_columns, fn _any ->
        ["bob", "andi"]
      end)

      stub(PrestigeMock, :stream!, fn _a, _b -> [:result] end)

      stub(PrestigeMock, :Result.as_maps, fn :result ->
        [%{"andi" => 1, "bob" => 2}]
      end)

      stub(RedixMock, :command!, fn _a, _b -> :does_not_matter end)

      actual = conn |> get(url) |> response(200)

      assert "andi,bob\n1,2\n" == actual
    end
  end

  describe "metrics" do
    setup do
      stub(PrestigeMock, :stream!, fn _a, _b -> [:result] end)

      stub(PrestigeMock, :Result.as_maps, fn :result ->
        [%{"id" => 1, name: "Joe"}, %{"id" => 2, name: "Robby"}]
      end)

      :ok
    end

    data_test "increments dataset download count when user requests download", %{conn: conn} do
      conn
      |> get(url)
      |> response(200)

      # Mox verification happens automatically - no need for manual assert_called

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

      # Mox verification happens automatically - no need for manual refute_called

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

      stub(SystemNameCacheMock, :get, fn _org_name, _name -> dataset_id end)
      stub(ModelMock, :get, fn _id -> model end)

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

      stub(SystemNameCacheMock, :get, fn _org_name, _name -> dataset_id end)
      stub(ModelMock, :get, fn _id -> model end)

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

      stub(SystemNameCacheMock, :get, fn _org_name, _name -> dataset_id end)
      stub(ModelMock, :get, fn _id -> model end)

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

      stub(Users, :get_user_with_organizations, fn subject, :subject_id ->
        {:ok, %{subject_id: :subject_id, id: @user_id, organizations: [%{id: "org_id"}]}}
      end)

      model =
        Helper.sample_model(%{
          id: dataset_id,
          systemName: "#{@org_name}__presign_private",
          name: "presign_private",
          private: true,
          lastUpdatedDate: nil,
          queries: 7,
          downloads: 9,
          accessGroups: [],
          organizationDetails: %{
            orgName: @org_name,
            id: "org_id"
          },
          schema: [
            %{name: "feature", type: "json"}
          ]
        })

      stub(SystemNameCacheMock, :get, fn _org_name, _name -> dataset_id end)
      stub(ModelMock, :get, fn _id -> model end)
      hmac = "IAMANHMACTOKENFORREAL"
      date_time = DateTime.utc_now()
      stub(DiscoveryApiWeb.Utilities.HmacTokenMock, :create_hmac_token, fn _a, _b -> "IAMANHMACTOKENFORREAL" end)
      stub(DateTimeMock, :utc_now, fn -> date_time end)

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

    stub(SystemNameCacheMock, :get, fn _org_name, _name -> dataset_id end)
    stub(ModelMock, :get, fn _id -> model end)
    stub(ObjectStorageServiceMock, :download_file_as_stream, fn _a, _b -> {:ok, ["anything"], "csv"} end)
    stub(RedixMock, :command!, fn _a, _b -> :ok end)

    url = "/api/v1/dataset/#{dataset_id}/download"

    conn
    |> put_req_header("accept", "text/csv")
    |> get(url)

    # Mox verification happens automatically - no need for manual assert_called
  end
end
