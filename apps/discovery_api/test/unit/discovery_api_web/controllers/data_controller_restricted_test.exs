defmodule DiscoveryApiWeb.DataController.RestrictedTest do
  use DiscoveryApiWeb.ConnCase
  use Placebo
  import Checkov
  alias DiscoveryApi.Data.{Model, SystemNameCache}
  alias DiscoveryApi.Schemas.Users
  alias DiscoveryApi.Schemas.Users.User
  alias DiscoveryApi.Services.{PrestoService, MetricsService}
  alias DiscoveryApiWeb.Auth.TokenHandler
  alias DiscoveryApi.Test.AuthHelper

  @dataset_id "1234-4567-89101"
  @system_name "foobar__company_data"
  @org_id "org1_id"
  @org_name "org1"
  @data_name "data1"

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
    allow(Prestige.stream!(any(), "select * from #{@system_name}"), return: [:result])

    allow(Prestige.Result.as_maps(:result),
      return: [%{"id" => 1, "name" => "Joe"}, %{"id" => 2, "name" => "Robby"}]
    )

    :ok
  end

  describe "accessing restricted datasets" do
    setup do
      %{subject_id: subject_id, token: token, exit_fn: exit_fn} = Helper.auth0_setup()
      on_exit(exit_fn)

      %{subject_id: subject_id, token: token}
    end

    data_test "downloads a restricted dataset if the given user has access to it, via token", %{
      conn: conn,
      subject_id: subject_id,
      token: token
    } do
      allow(TokenHandler.on_verify(any(), any(), any()), exec: &AuthHelper.guardian_verify_passthrough/3, meck_options: [:passthrough])
      allow(Users.get_user_with_organizations(subject_id, :subject_id), return: {:ok, %User{organizations: [%{id: @org_id}]}})

      conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> put_req_header("accept", accepts)
      |> get(url)
      |> json_response(response_code)

      where([
        [:url, :accepts, :response_code],
        # hmac token is datasetid/timestamp encrypted with a key
        # :crypto.hmac(:sha256, "test_presign_key", "1234-4567-89101/2556118800") |> Base.encode16()
        [
          "/api/v1/dataset/1234-4567-89101/download?key=A2C4E59FA2FEDAAA3AB3059DB07C78CDFE61AA5088CE0F07DC4E326D865E593D&expires=2556118800",
          "application/json",
          200
        ],
        ["/api/v1/dataset/1234-4567-89101/query", "application/json", 200],
        ["/api/v1/dataset/1234-4567-89101/preview", "application/json", 200]
      ])
    end
  end
end
