defmodule DiscoveryApiWeb.MultipleDataControllerTest do
  use DiscoveryApiWeb.ConnCase
  import Mox
  alias DiscoveryApi.Data.Model
  alias DiscoveryApi.Services.PrestoService
  alias DiscoveryApiWeb.Utilities.ModelAccessUtils

  setup :verify_on_exit!

  import SmartCity.Event,
    only: [dataset_query: 0]

  alias DiscoveryApi.Data.Model
  alias DiscoveryApi.Services.PrestoService
  alias DiscoveryApiWeb.Utilities.ModelAccessUtils

  @presto_service Application.compile_env(:discovery_api, :presto_service)
  @model Application.compile_env(:discovery_api, :model)
  @model_access_utils Application.compile_env(:discovery_api, :model_access_utils)
  @brook Application.compile_env(:brook, :event_bus)

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

    stub(@model, :get_all, fn -> datasets end)

    stub(@brook, :send, fn _, _, _, _ ->
      :ok
    end)

    {
      :ok,
      %{ 
        public_model_ids: [public_one_dataset, public_two_dataset] |> Enum.map(&Map.get(&1, :id)),
        public_tables: [public_one_dataset, public_two_dataset] |> Enum.map(&Map.get(&1, :systemName)),
        private_tables: [private_one_dataset, private_two_dataset] |> Enum.map(&Map.get(&1, :systemName))
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
      public_tables: public_tables,
      json_response: expected_response
    } do
      statement = """
        WITH public_one AS (select a from public__one), public_two AS (select b from public__two) 
        SELECT * FROM public_one JOIN public_two ON public_one.a = public_two.b
      """

      stub(PrestigeMock, :stream!, fn _, _ ->
        Stream.map(expected_response, &{:ok, &1})
      end)

      stub(@presto_service, :is_select_statement?, fn _ -> true end)
      stub(@presto_service, :get_affected_tables, fn _, _ -> {:ok, public_tables} end)
      stub(@model_access_utils, :has_access?, fn _, _ -> true end)

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
      public_tables: public_tables,
      json_response: allowed_response,
      csv_response: expected_response
    } do
      statement = """
        WITH public_one AS (select a from public__one), public_two AS (select b from public__two) 
        SELECT * FROM public_one JOIN public_two ON public_one.a = public_two.b
      """

      stub(PrestigeMock, :stream!, fn _, _ ->
        Stream.map(allowed_response, &{:ok, &1})
      end)

      stub(@presto_service, :is_select_statement?, fn _ -> true end)
      stub(@presto_service, :get_affected_tables, fn _, _ -> {:ok, public_tables} end)
      stub(@model_access_utils, :has_access?, fn _, _ -> true end)

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
      private_tables: private_tables,
      json_response: allowed_response
    } do
      statement = """
        WITH private_one AS (select a from private__one), private_two AS (select b from private__two) 
        SELECT * FROM private_one JOIN private_two ON private_one.a = private_two.b
      """

      stub(PrestigeMock, :stream!, fn _, _ ->
        Stream.map(allowed_response, &{:ok, &1})
      end)

      stub(@presto_service, :is_select_statement?, fn _ -> true end)
      stub(@presto_service, :get_affected_tables, fn _, _ -> {:ok, private_tables} end)
      stub(@model_access_utils, :has_access?, fn _, _ -> true end)

      assert conn
             |> put_req_header("accept", "application/json")
             |> put_req_header("content-type", "text/plain")
             |> post("/api/v1/query", statement)
             |> response(200)
    end

    test "can't select from some unauthorized private datasets", %{
      conn: conn,
      private_tables: private_tables
    } do
      statement = """
        WITH private_one AS (select a from private__one), private_two AS (select b from private__two) 
        SELECT * FROM private_one JOIN private_two ON private_one.a = private_two.b
      """

      stub(@presto_service, :is_select_statement?, fn _ -> true end)
      stub(@presto_service, :get_affected_tables, fn _, _ -> {:ok, private_tables} end)
      stub(@model_access_utils, :has_access?, fn _, _ -> false end)

      assert conn
             |> put_req_header("accept", "application/json")
             |> put_req_header("content-type", "text/plain")
             |> post("/api/v1/query", statement)
             |> response(400)
    end

    test "can't describe queries for unauthorized private datasets", %{
      conn: conn,
      private_tables: private_tables
    } do
      statement = """
      WITH private_one AS (select a from private__one), private_two AS (select b from private__two)
      SELECT * FROM private_one JOIN private_two ON private_one.a = private_two.b
      """

      stub(@presto_service, :is_select_statement?, fn _ -> true end)
      stub(@presto_service, :get_affected_tables, fn _, _ -> {:ok, private_tables} end)
      stub(@model_access_utils, :has_access?, fn _, _ -> false end)

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

    test "returns prestige error details if prestige throws", %{conn: conn, public_tables: public_tables} do
      statement = "select quantity*2131241224124412124 from public__one"
      failure_message = "bigint multiplication overflow: 7694 * 2131241224124412124"
      expected_response = "{\"message\":\"Query Error: #{failure_message}\"}"

      stub(@presto_service, :is_select_statement?, fn _ -> true end)
      stub(@presto_service, :get_affected_tables, fn _, _ -> {:ok, public_tables} end)
      stub(@model_access_utils, :has_access?, fn _, _ -> true end)

      stub(PrestigeMock, :stream!, fn _, _ ->
        raise Prestige.Error, message: failure_message
      end)

      assert expected_response ==
               conn
               |> put_req_header("accept", "application/json")
               |> put_req_header("content-type", "text/plain")
               |> post("/api/v1/query", statement)
               |> response(400)
    end

    test "sends brook event to record api hit for all affected tables", %{
      conn: conn,
      public_model_ids: public_model_ids,
      public_tables: public_tables,
      json_response: allowed_response
    } do
      statement = """
      WITH public_one AS (select a from public__one), public_two AS (select b from public__two) 
      SELECT * FROM public_one JOIN public_two ON public_one.a = public_two.b
      """

      stub(PrestigeMock, :stream!, fn _, _ ->
        Stream.map(allowed_response, &{:ok, &1})
      end)

      stub(@presto_service, :is_select_statement?, fn _ -> true end)
      stub(@presto_service, :get_affected_tables, fn _, _ -> {:ok, public_tables} end)
      stub(@model_access_utils, :has_access?, fn _, _ -> true end)

      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("content-type", "text/plain")
      |> post("/api/v1/query", statement)
      |> response(200)

      [public_model_id_one, public_model_id_two] = public_model_ids

      assert_receive {:"$gen_call", {_, :send}, _}
      assert_receive {:"$gen_call", {_, :send}, _}
    end
  end

  describe "query geojson" do
    setup do
      geojson_model =
        DiscoveryApi.Test.Helper.sample_model(%{
          private: false,
          systemName: "geojson__geojson"
        })

      statement = "SELECT * FROM #{geojson_model.systemName}"

      stub(PrestigeMock, :stream!, fn _, _ ->
        Stream.map(
          [
            %{"feature" => "{\"geometry\": {\"coordinates\": [1, 0]}}"},
            %{"feature" => "{\"geometry\": {\"coordinates\": [[0, 1]]}}"}
          ],
          &{:ok, &1}
        )
      end)

      stub(@presto_service, :is_select_statement?, fn _ -> true end)

      stub(@presto_service, :get_affected_tables, fn _, _ ->
        {:ok, [Map.get(geojson_model, :systemName)]}
      end)

      stub(@model_access_utils, :has_access?, fn _, _ -> true end)

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
