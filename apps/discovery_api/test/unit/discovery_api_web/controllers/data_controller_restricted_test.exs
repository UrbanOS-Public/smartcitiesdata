defmodule DiscoveryApiWeb.DataController.RestrictedTest do
  use DiscoveryApiWeb.ConnCase
  use Placebo
  import Checkov
  alias DiscoveryApi.Data.{Model, SystemNameCache}
  alias DiscoveryApi.Schemas.Users
  alias DiscoveryApi.Schemas.Users.User
  alias DiscoveryApi.Services.{PrestoService, MetricsService}

  @dataset_id "1234-4567-89101"
  @system_name "foobar__company_data"
  @org_id "org1_id"
  @org_name "org1"
  @data_name "data1"
  @subject_id "bigbadbob"

  setup do
    model =
      Helper.sample_model(%{
        id: @dataset_id,
        systemName: @system_name,
        name: @data_name,
        private: true,
        lastUpdatedDate: nil,
        queries: 7,
        downloads: 9,
        organizationDetails: %{
          id: @org_id,
          orgName: @org_name
        },
        schema: [
          %{name: "id", type: "integer"},
          %{name: "name", type: "string"}
        ]
      })

    allow(SystemNameCache.get(@org_name, @data_name), return: @dataset_id)
    allow(Model.get(@dataset_id), return: model)
    allow(Model.get_all(), return: [model])
    allow(MetricsService.record_api_hit(any(), any()), return: :does_not_matter)

    # these clearly need to be condensed
    allow(PrestoService.get_column_names(any(), any(), any()), return: {:ok, ["id", "name"]})
    allow(PrestoService.preview_columns(any(), @system_name), return: ["id", "name"])
    allow(PrestoService.preview(any(), @system_name), return: [[1, "Joe"], [2, "Robby"]])
    allow(PrestoService.build_query(any(), any()), return: {:ok, "select * from #{@system_name}"})
    allow(PrestoService.is_select_statement?("select * from #{@system_name}"), return: true)
    allow(PrestoService.get_affected_tables(any(), "select * from #{@system_name}"), return: {:ok, ["#{@system_name}"]})

    allow(Prestige.new_session(any()), return: :connection)
    allow(Prestige.query!(any(), "select * from #{@system_name}"), return: :result)

    allow(Prestige.Result.as_maps(:result),
      return: [%{"id" => 1, "name" => "Joe"}, %{"id" => 2, "name" => "Robby"}]
    )

    :ok
  end

  describe "accessing restricted datasets" do
    data_test "does not download a restricted dataset via #{url} if the given user is not a member of the dataset's group", %{conn: conn} do
      allow(Users.get_user_with_organizations(@subject_id, :subject_id), return: {:ok, %User{organizations: []}})

      {:ok, token, _} = DiscoveryApi.Auth.Guardian.encode_and_sign(@subject_id, %{}, token_type: "refresh")

      conn
      |> put_req_cookie(Helper.default_guardian_token_key(), token)
      |> put_req_header("accept", accepts)
      |> get(url)
      |> json_response(response_code)

      where([
        [:url, :accepts, :response_code],
        ["/api/v1/dataset/1234-4567-89101/download", "application/json", 404],
        ["/api/v1/dataset/1234-4567-89101/query", "application/json", 404],
        ["/api/v1/dataset/1234-4567-89101/preview", "application/json", 404]
      ])
    end

    data_test "downloads a restricted dataset via #{url} if the given user has access to it, via cookie", %{conn: conn} do
      allow(Users.get_user_with_organizations(@subject_id, :subject_id), return: {:ok, %User{organizations: [%{id: @org_id}]}})

      {:ok, token, _} = DiscoveryApi.Auth.Guardian.encode_and_sign(@subject_id, %{}, token_type: "refresh")

      conn
      |> put_req_cookie(Helper.default_guardian_token_key(), token)
      |> put_req_header("accept", accepts)
      |> get(url)
      |> json_response(response_code)

      where([
        [:url, :accepts, :response_code],
        ["/api/v1/dataset/1234-4567-89101/download", "application/json", 200],
        ["/api/v1/dataset/1234-4567-89101/query", "application/json", 200],
        ["/api/v1/dataset/1234-4567-89101/preview", "application/json", 200]
      ])
    end

    data_test "downloads a restricted dataset via #{url} if the given user has access to it, via token", %{conn: conn} do
      allow(Users.get_user_with_organizations(@subject_id, :subject_id), return: {:ok, %User{organizations: [%{id: @org_id}]}})

      {:ok, token, _} = DiscoveryApi.Auth.Guardian.encode_and_sign(@subject_id, %{}, token_type: "refresh")

      conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> put_req_header("accept", accepts)
      |> get(url)
      |> json_response(response_code)

      where([
        [:url, :accepts, :response_code],
        ["/api/v1/dataset/1234-4567-89101/download", "application/json", 200],
        ["/api/v1/dataset/1234-4567-89101/query", "application/json", 200],
        ["/api/v1/dataset/1234-4567-89101/preview", "application/json", 200]
      ])
    end
  end
end
