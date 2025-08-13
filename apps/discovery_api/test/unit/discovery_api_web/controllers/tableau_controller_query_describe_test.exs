defmodule DiscoveryApiWeb.TableauControllerQueryDescribeTest do
  use DiscoveryApiWeb.ConnCase
  import Mox
  alias DiscoveryApi.Data.Model
  alias DiscoveryApiWeb.Utilities.ModelAccessUtils
  alias DiscoveryApi.Services.PrestoService

  setup :verify_on_exit!

  @model Application.compile_env(:discovery_api, :model)
  @presto_service Application.compile_env(:discovery_api, :presto_service)
  @model_access_utils Application.compile_env(:discovery_api, :model_access_utils)
  @prestige Application.compile_env(:discovery_api, :prestige)
  @prestige_result Application.compile_env(:discovery_api, :prestige_result)

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
    stub(@prestige, :new_session, fn _ -> :connection end)

    {
      :ok,
      %{
        public_tables: [public_one_dataset, public_two_dataset] |> Enum.map(&Map.get(&1, :systemName)),
        private_tables: [private_one_dataset, private_two_dataset] |> Enum.map(&Map.get(&1, :systemName))
      }
    }
  end

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

    test "can describe queries for some public datasets", %{
      conn: conn,
      public_tables: public_tables
    } do
      statement = """
        WITH public_one AS (select a from public__one), public_two AS (select b from public__two)
        SELECT * FROM public_one JOIN public_two ON public_one.a = public_two.b
      """

      allowed_response = [
        %{
          "Column Name" => "a",
          "Type" => "integer"
        },
        %{
          "Column Name" => "b",
          "Type" => "integer"
        }
      ]

      expected_response =
        [
          %{
            id: "a",
            description: "a",
            dataType: "integer"
          },
          %{
            id: "b",
            description: "b",
            dataType: "integer"
          }
        ]
        |> Jason.encode!()

      stub(@prestige, :prepare!, fn _, _, _ -> :result end)
      stub(@prestige, :execute!, fn _, _ -> :result end)
      stub(@prestige_result, :as_maps, fn _ -> allowed_response end)
      stub(@presto_service, :is_select_statement?, fn _ -> true end)
      stub(@presto_service, :get_affected_tables, fn _, _ -> {:ok, public_tables} end)
      stub(@model_access_utils, :has_access?, fn _, _ -> true end)

      response_body =
        conn
        |> put_req_header("accept", "application/json")
        |> put_req_header("content-type", "text/plain")
        |> post("/api/v1/tableau/query_describe", statement)
        |> response(200)

      assert expected_response == response_body
    end

    test "can describe queries for some authorized private datasets", %{
      conn: conn,
      private_tables: private_tables
    } do
      statement = """
      WITH private_one AS (select a from private__one), private_two AS (select b from private__two)
      SELECT * FROM private_one JOIN private_two ON private_one.a = private_two.b
      """

      allowed_response = [
        %{
          "Column Name" => "a",
          "Type" => "integer"
        },
        %{
          "Column Name" => "b",
          "Type" => "integer"
        }
      ]

      expected_response =
        [
          %{
            id: "a",
            description: "a",
            dataType: "integer"
          },
          %{
            id: "b",
            description: "b",
            dataType: "integer"
          }
        ]
        |> Jason.encode!()

      stub(@prestige, :prepare!, fn _, _, _ -> :result end)
      stub(@prestige, :execute!, fn _, _ -> :result end)
      stub(@prestige_result, :as_maps, fn _ -> allowed_response end)
      stub(@presto_service, :is_select_statement?, fn _ -> true end)
      stub(@presto_service, :get_affected_tables, fn _, _ -> {:ok, private_tables} end)
      stub(@model_access_utils, :has_access?, fn _, _ -> true end)

      response_body =
        conn
        |> put_req_header("accept", "application/json")
        |> put_req_header("content-type", "text/plain")
        |> post("/api/v1/tableau/query_describe", statement)
        |> response(200)

      assert expected_response == response_body
    end

    test "can't perform or describe query if there is an error getting affected tables", %{conn: conn} do
      statement = """
        INSERT INTO public__one SELECT * FROM public__two
      """

      stub(@presto_service, :is_select_statement?, fn _ -> true end)
      stub(@presto_service, :get_affected_tables, fn _, _ -> {:error, :does_not_matter} end)
      stub(@model_access_utils, :has_access?, fn _, _ -> true end)

      assert conn
             |> put_req_header("accept", "application/json")
             |> put_req_header("content-type", "text/plain")
             |> post("/api/v1/query", statement)
             |> response(400)

      assert conn
             |> put_req_header("accept", "application/json")
             |> put_req_header("content-type", "text/plain")
             |> post("/api/v1/tableau/query_describe", statement)
             |> response(400)
    end

    test "unable to query or describe datasets which are not in redis", %{conn: conn} do
      statement = """
      SELECT * FROM not_in_redis
      """

      stub(@presto_service, :is_select_statement?, fn _ -> true end)
      stub(@presto_service, :get_affected_tables, fn _, _ -> {:ok, ["not_in_redis"]} end)
      stub(@model_access_utils, :has_access?, fn _, _ -> true end)

      _response_body =
        conn
        |> put_req_header("accept", "text/csv")
        |> put_req_header("content-type", "text/plain")
        |> post("/api/v1/query", statement)
        |> response(400)

      assert conn
             |> put_req_header("accept", "application/json")
             |> put_req_header("content-type", "text/plain")
             |> post("/api/v1/tableau/query_describe", statement)
             |> response(400)
    end

    test "can't perform or describe query if it not a supported/allowed statement type", %{
      conn: conn
    } do
      statement = """
        EXPLAIN ANALYZE select * from public__one
      """

      stub(@presto_service, :is_select_statement?, fn _ -> false end)

      assert conn
             |> put_req_header("accept", "application/json")
             |> put_req_header("content-type", "text/plain")
             |> post("/api/v1/tableau/query_describe", statement)
             |> response(400)
    end

    test "does not accept requests with no statement in the body", %{conn: conn} do
      statement = ""

      assert conn
             |> put_req_header("accept", "application/json")
             |> put_req_header("content-type", "text/plain")
             |> post("/api/v1/tableau/query_describe", statement)
             |> response(400)
    end
  end
end
