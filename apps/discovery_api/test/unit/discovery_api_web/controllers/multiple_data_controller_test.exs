defmodule DiscoveryApiWeb.MultipleDataControllerTest do
  use DiscoveryApiWeb.ConnCase
  use Placebo
  alias DiscoveryApi.Data.Model
  alias DiscoveryApi.Services.PrestoService
  alias DiscoveryApiWeb.Utilities.QueryAccessUtils
  alias DiscoveryApiWeb.Utilities.ModelAccessUtils

  setup do
    public_one_dataset =
      DiscoveryApi.Test.Helper.sample_model(%{
        private: false,
        systemName: "public__one"
      })

    public_two_dataset =
      DiscoveryApi.Test.Helper.sample_model(%{
        private: false,
        systemName: "public__two"
      })

    private_one_dataset =
      DiscoveryApi.Test.Helper.sample_model(%{
        private: true,
        systemName: "private__one"
      })

    private_two_dataset =
      DiscoveryApi.Test.Helper.sample_model(%{
        private: true,
        systemName: "private__two"
      })

    coda_dataset =
      DiscoveryApi.Test.Helper.sample_model(%{
        private: false,
        systemName: "coda__test_dataset"
      })

    geojson_dataset =
      DiscoveryApi.Test.Helper.sample_model(%{
        private: false,
        systemName: "geojson__geojson"
      })

    datasets = [
      public_one_dataset,
      public_two_dataset,
      private_one_dataset,
      private_two_dataset,
      coda_dataset,
      geojson_dataset
    ]

    {
      :ok,
      %{
        prestige_session: :connection,
        public_models: [public_one_dataset, public_two_dataset],
        private_models: [private_one_dataset, private_two_dataset],
      }
    }
  end

  @moduletag capture_log: true
  describe "query multiple datasets" do
    setup do
      json_from_execute = [
        %{"a" => 2, "b" => 2},
        %{"a" => 3, "b" => 3},
        %{"a" => 1, "b" => 1}
      ]

      csv_from_execute = "a,b\n2,2\n3,3\n1,1\n"

      {
        :ok,
        %{
          json_response: json_from_execute,
          csv_response: csv_from_execute
        }
      }
    end

    test "can select from some public datasets as json", %{
      conn: conn,
      public_models: public_models,
      json_response: expected_response
    } do
      statement = """
        WITH public_one AS (select a from public__one), public_two AS (select b from public__two)
        SELECT * FROM public_one JOIN public_two ON public_one.a = public_two.b
      """

      allow(Prestige.stream!(any(), any()), return: [:result])
      allow(Prestige.Result.as_maps(:result), return: expected_response)
      allow(QueryAccessUtils.get_affected_models(statement), return: {:ok, public_models})
      allow(QueryAccessUtils.user_can_access_models?(public_models, any()), return: true)

      response_body =
        conn
        |> put_req_header("accept", "application/json")
        |> put_req_header("content-type", "text/plain")
        |> post("/api/v1/query", statement)
        |> response(200)
        |> Jason.decode!()

      assert expected_response == response_body
    end

    test "can select from some public datasets as csv", %{
      conn: conn,
      public_models: public_models,
      json_response: allowed_response,
      csv_response: expected_response
    } do
      statement = """
        WITH public_one AS (select a from public__one), public_two AS (select b from public__two)
        SELECT * FROM public_one JOIN public_two ON public_one.a = public_two.b
      """

      allow(Prestige.stream!(any(), any()), return: [:result])
      allow(Prestige.Result.as_maps(:result), return: allowed_response)
      allow(QueryAccessUtils.get_affected_models(statement), return: {:ok, public_models})
      allow(QueryAccessUtils.user_can_access_models?(public_models, any()), return: true)

      response_body =
        conn
        |> put_req_header("accept", "text/csv")
        |> put_req_header("content-type", "text/plain")
        |> post("/api/v1/query", statement)
        |> response(200)

      assert expected_response == response_body
    end

    test "can select from some authorized private datasets", %{
      conn: conn,
      prestige_session: prestige_session,
      private_models: private_models,
      json_response: allowed_response
    } do
      statement = """
        WITH private_one AS (select a from private__one), private_two AS (select b from private__two)
        SELECT * FROM private_one JOIN private_two ON private_one.a = private_two.b
      """

      allow(Prestige.stream!(any(), statement), return: [:result])
      allow(Prestige.Result.as_maps(:result), return: allowed_response)
      allow(QueryAccessUtils.get_affected_models(statement), return: {:ok, private_models})
      allow(QueryAccessUtils.authorized_session(conn, private_models), return: {:ok, prestige_session})

      assert conn
             |> put_req_header("accept", "application/json")
             |> put_req_header("content-type", "text/plain")
             |> post("/api/v1/query", statement)
             |> response(200)
    end

    test "can't select from some unauthorized private datasets", %{
      conn: conn,
      private_models: private_models,
      json_response: allowed_response
    } do
      statement = """
        WITH private_one AS (select a from private__one), private_two AS (select b from private__two)
        SELECT * FROM private_one JOIN private_two ON private_one.a = private_two.b
      """

      # allow(Prestige.query!(any(), any()), return: :result)
      # allow(Prestige.Result.as_maps(:result), return: allowed_response)
      allow(QueryAccessUtils.get_affected_models(statement), return: {:ok, private_models})
      allow(QueryAccessUtils.user_can_access_models?(private_models, any()), return: false)

      assert conn
             |> put_req_header("accept", "application/json")
             |> put_req_header("content-type", "text/plain")
             |> post("/api/v1/query", statement)
             |> response(400)
    end

    test "can't describe queries for unauthorized private datasets", %{
      conn: conn,
      private_models: private_models
    } do
      statement = """
      WITH private_one AS (select a from private__one), private_two AS (select b from private__two)
      SELECT * FROM private_one JOIN private_two ON private_one.a = private_two.b
      """

      allow(QueryAccessUtils.get_affected_models(statement), return: {:ok, private_models})
      allow(QueryAccessUtils.user_can_access_models?(private_models, any()), return: false)

      assert conn
             |> put_req_header("accept", "application/json")
             |> put_req_header("content-type", "text/plain")
             |> post("/api/v1/query", statement)
             |> response(400)
    end

    test "does not accept requests with no statement in the body", %{conn: conn} do
      statement = ""

      assert conn
             |> put_req_header("accept", "application/json")
             |> put_req_header("content-type", "text/plain")
             |> post("/api/v1/query", statement)
             |> response(400)
    end

    test "returns prestige error details if prestige throws", %{conn: conn, public_models: public_models} do
      statement = "select quantity*2131241224124412124 from public__one"
      failure_message = "bigint multiplication overflow: 7694 * 2131241224124412124"
      expected_response = "{\"message\":\"#{failure_message}\"}"

      allow(QueryAccessUtils.get_affected_models(statement), return: {:ok, public_models})
      allow(QueryAccessUtils.user_can_access_models?(public_models, any()), return: true)
      allow(Prestige.stream!(any(), any()), exec: fn _, _ -> raise Prestige.Error, failure_message end)

      assert expected_response ==
               conn
               |> put_req_header("accept", "application/json")
               |> put_req_header("content-type", "text/plain")
               |> post("/api/v1/query", statement)
               |> response(400)
    end

    test "records api hit to all affected tables", %{
      conn: conn,
      public_models: public_models,
      json_response: allowed_response
    } do
      statement = """
      WITH public_one AS (select a from public__one), public_two AS (select b from public__two)
      SELECT * FROM public_one JOIN public_two ON public_one.a = public_two.b
      """

      allow(Prestige.stream!(any(), any()), return: [:result])
      allow(Prestige.Result.as_maps(:result), return: allowed_response)
      allow(QueryAccessUtils.get_affected_models(statement), return: {:ok, public_models})
      allow(QueryAccessUtils.user_can_access_models?(public_models, any()), return: true)
      allow(Redix.command!(:redix, any()), return: :ok)

      conn
      |> put_req_header("accept", "text/csv")
      |> put_req_header("content-type", "text/plain")
      |> post("/api/v1/query", statement)
      |> response(200)

      [public_model_one, public_model_two] = public_models

      assert_called Redix.command!(:redix, ["INCR", "smart_registry:free_form_query:count:#{public_model_one.id}"])
      assert_called Redix.command!(:redix, ["INCR", "smart_registry:free_form_query:count:#{public_model_two.id}"])
    end
  end

  describe "query geojson" do
    setup %{conn: conn} do
      geojson_model = DiscoveryApi.Test.Helper.sample_model(%{
        private: false,
        systemName: "geojson__geojson"
      })
      statement = "SELECT * FROM #{geojson_model.systemName}"

      allow(Prestige.stream!(any(), any()), return: [:result])
      allow(Prestige.Result.as_maps(:result),
        return: [
          %{"feature" => "{\"geometry\": {\"coordinates\": [1, 0]}}"},
          %{"feature" => "{\"geometry\": {\"coordinates\": [[0, 1]]}}"}
        ]
      )
      allow(QueryAccessUtils.get_affected_models(statement), return: {:ok, [geojson_model]})
      allow(QueryAccessUtils.user_can_access_models?([geojson_model], any()), return: true)

      %{statement: statement}
    end

    test "returns geojson with bounding box", %{conn: conn, statement: statement} do
      actual =
        conn
        |> put_req_header("accept", "application/json")
        |> put_req_header("content-type", "text/plain")
        |> post("/api/v1/query?_format=geojson", statement)
        |> response(200)

      assert Jason.decode!(actual) == %{
               "type" => "FeatureCollection",
               "bbox" => [0, 0, 1, 1],
               "features" => [
                 %{
                   "geometry" => %{
                     "coordinates" => [1, 0]
                   }
                 },
                 %{
                   "geometry" => %{
                     "coordinates" => [[0, 1]]
                   }
                 }
               ]
             }
    end
  end
end
