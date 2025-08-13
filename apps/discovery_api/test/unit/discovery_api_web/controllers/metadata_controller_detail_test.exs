defmodule DiscoveryApiWeb.MetadataController.DetailTest do
  use DiscoveryApiWeb.Test.AuthConnCase.UnitCase
  import Mox
  alias DiscoveryApi.Test.Helper
  alias DiscoveryApi.Data.Model
  alias DiscoveryApi.Schemas.Users
  alias DiscoveryApi.Schemas.Users.User

  setup :verify_on_exit!
  setup :set_mox_from_context

  @dataset_id "123"
  @org_id "456"

  setup %{auth_conn_case: auth_conn_case} do
    auth_conn_case.disable_revocation_list.()
    :ok
  end
  
  setup %{authorized_conn: conn} do
    if conn do
      # Manually set current_user for unit tests since Guardian middleware requires database
      current_user = %{id: "test_user_id"}
      updated_conn = Plug.Conn.assign(conn, :current_user, current_user)
      [authorized_conn: updated_conn]
    else
      []
    end
  end

  describe "fetch dataset detail" do
    test "retrieves dataset + organization from retriever when organization found", %{anonymous_conn: conn} do
      schema = [
        %{
          description: "a number",
          name: "number",
          type: "integer",
          pii: "false",
          biased: "false",
          masked: "N/A",
          demographic: "None"
        },
        %{
          description: "a name",
          name: "name",
          type: "string",
          pii: "true",
          biased: "true",
          masked: "yes",
          demographic: "Other"
        }
      ]

      model =
        Helper.sample_model(%{id: @dataset_id})
        |> Map.put(:schema, schema)

      :meck.expect(Model, :get, fn "123" -> model end)

      actual = conn |> get("/api/v1/dataset/#{@dataset_id}") |> json_response(200)

      expected_schema = [
        %{"name" => "number", "type" => "integer", "description" => "a number"},
        %{"name" => "name", "type" => "string", "description" => "a name"}
      ]

      assert %{
               "id" => model.id,
               "name" => model.name,
               "title" => model.title,
               "description" => model.description,
               "keywords" => model.keywords,
               "organization" => %{
                 "name" => model.organizationDetails.orgName,
                 "title" => model.organizationDetails.orgTitle,
                 "image" => model.organizationDetails.logoUrl,
                 "description" => model.organizationDetails.description,
                 "homepage" => model.organizationDetails.homepage
               },
               "schema" => expected_schema,
               "sourceType" => model.sourceType,
               "sourceFormat" => model.sourceFormat,
               "sourceUrl" => model.sourceUrl,
               "lastUpdatedDate" => nil,
               "contactName" => model.contactName,
               "contactEmail" => model.contactEmail,
               "license" => model.license,
               "rights" => model.rights,
               "homepage" => model.homepage,
               "spatial" => model.spatial,
               "temporal" => model.temporal,
               "publishFrequency" => model.publishFrequency,
               "conformsToUri" => model.conformsToUri,
               "describedByUrl" => model.describedByUrl,
               "describedByMimeType" => model.describedByMimeType,
               "parentDataset" => model.parentDataset,
               "issuedDate" => model.issuedDate,
               "language" => model.language,
               "referenceUrls" => model.referenceUrls,
               "categories" => model.categories,
               "modified" => model.modifiedDate,
               "downloads" => model.downloads,
               "queries" => model.queries,
               "accessLevel" => model.accessLevel,
               "completeness" => model.completeness,
               "systemName" => model.systemName,
               "fileTypes" => model.fileTypes
             } == actual
    end

    test "returns 404", %{conn: conn} do
      :meck.expect(Model, :get, fn _dataset_id -> nil end)

      conn |> get("/api/v1/dataset/xyz123") |> json_response(404)
    end
  end

  describe "fetch restricted dataset detail" do
    setup do
      model =
        Helper.sample_model(%{
          id: @dataset_id,
          private: true,
          lastUpdatedDate: nil,
          queries: 7,
          downloads: 9,
          organizationDetails: %{
            id: @org_id,
            orgName: "name",
            orgTitle: "whatever",
            description: "description",
            logoUrl: "logo url",
            homepage: "homepage"
          }
        })

      :meck.expect(Model, :get, fn "123" -> model end)

      :ok
    end

    test "retrieves a restricted dataset if the given user has access to it, via token", %{
      authorized_conn: conn,
      authorized_subject: subject
    } do
      :meck.expect(Users, :get_user_with_organizations, fn ^subject, :subject_id -> {:ok, %User{organizations: [%{id: @org_id}]}} end)
      stub(RaptorServiceMock, :is_authorized_by_user_id, fn _arg1, _arg2, _arg3 -> true end)

      # Manually assign current_user to bypass Guardian middleware database requirement
      conn = Plug.Conn.assign(conn, :current_user, %{id: "test_user_id"})

      conn
      |> get("/api/v1/dataset/#{@dataset_id}")
      |> json_response(200)
    end
  end
end
