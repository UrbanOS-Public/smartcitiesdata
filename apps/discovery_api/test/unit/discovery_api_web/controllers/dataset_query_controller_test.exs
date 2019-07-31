defmodule DiscoveryApiWeb.DatasetQueryControllerTest do
  import ExUnit.CaptureLog
  use DiscoveryApiWeb.ConnCase
  use Placebo
  import Checkov
  alias DiscoveryApi.Data.{Model, SystemNameCache}
  alias DiscoveryApiWeb.Services.{AuthService, PrestoService}

  @dataset_id "test"
  @system_name "coda__test_dataset"
  @org_name "org1"
  @data_name "data1"

  describe "fetching csv data" do
    setup do
      model =
        Helper.sample_model(%{
          id: @dataset_id,
          systemName: @system_name,
          name: @data_name,
          private: false,
          lastUpdatedDate: nil,
          queries: 7,
          downloads: 9
        })

      allow(SystemNameCache.get(@org_name, @data_name), return: @dataset_id)
      allow(Model.get(@dataset_id), return: model)

      allow(Prestige.execute("describe #{@system_name}"),
        return: []
      )

      allow(Prestige.execute("SELECT id, one FROM #{@system_name}"),
        return: [[1, 2], [4, 5]]
      )

      allow(Prestige.execute(any()),
        return: [[1, 2, 3], [4, 5, 6]]
      )

      allow(Prestige.prefetch(any()),
        return: [["id", "bigint", "", ""], ["one", "bigint", "", ""], ["two", "bigint", "", ""]]
      )

      allow(Redix.command!(any(), any()), return: :does_not_matter)
      :ok
    end

    data_test "returns csv", %{conn: conn} do
      actual = conn |> put_req_header("accept", "text/csv") |> get(url) |> response(200)
      assert "id,one,two\n1,2,3\n4,5,6\n" == actual

      where(
        url: [
          "/api/v1/dataset/test/query",
          "/api/v1/organization/org1/dataset/data1/query"
        ]
      )
    end

    data_test "selects from the table specified in the dataset definition", %{conn: conn} do
      conn |> put_req_header("accept", "text/csv") |> get(url) |> response(200)

      assert_called Prestige.execute("describe #{@system_name}"), once()
      assert_called Prestige.execute("SELECT * FROM #{@system_name}"), once()

      where(
        url: [
          "/api/v1/dataset/test/query",
          "/api/v1/organization/org1/dataset/data1/query"
        ]
      )
    end

    data_test "selects using the where clause provided", %{conn: conn} do
      conn |> put_req_header("accept", "text/csv") |> get(url, where: "one=1") |> response(200)

      assert_called Prestige.execute("SELECT * FROM #{@system_name} WHERE one=1"),
                    once()

      where(
        url: [
          "/api/v1/dataset/test/query",
          "/api/v1/organization/org1/dataset/data1/query"
        ]
      )
    end

    data_test "selects using the order by clause provided", %{conn: conn} do
      conn |> put_req_header("accept", "text/csv") |> get(url, orderBy: "one") |> response(200)

      assert_called Prestige.execute("SELECT * FROM #{@system_name} ORDER BY one"),
                    once()

      where(
        url: [
          "/api/v1/dataset/test/query",
          "/api/v1/organization/org1/dataset/data1/query"
        ]
      )
    end

    data_test "selects using the limit clause provided", %{conn: conn} do
      conn |> put_req_header("accept", "text/csv") |> get(url, limit: "200") |> response(200)

      assert_called Prestige.execute("SELECT * FROM #{@system_name} LIMIT 200"),
                    once()

      where(
        url: [
          "/api/v1/dataset/test/query",
          "/api/v1/organization/org1/dataset/data1/query"
        ]
      )
    end

    data_test "selects using the group by clause provided", %{conn: conn} do
      conn |> put_req_header("accept", "text/csv") |> get(url, groupBy: "one") |> response(200)

      assert_called Prestige.execute("SELECT * FROM #{@system_name} GROUP BY one"),
                    once()

      where(
        url: [
          "/api/v1/dataset/test/query",
          "/api/v1/organization/org1/dataset/data1/query"
        ]
      )
    end

    data_test "selects using multiple clauses provided", %{conn: conn} do
      conn
      |> put_req_header("accept", "text/csv")
      |> get(url, where: "one=1", orderBy: "one", limit: "200", groupBy: "one")
      |> response(200)

      assert_called Prestige.execute("SELECT * FROM #{@system_name} WHERE one=1 GROUP BY one ORDER BY one LIMIT 200"),
                    once()

      where(
        url: [
          "/api/v1/dataset/test/query",
          "/api/v1/organization/org1/dataset/data1/query"
        ]
      )
    end

    data_test "selects using columns provided returns only those columns of data", %{conn: conn} do
      actual =
        conn
        |> put_req_header("accept", "text/csv")
        |> get(url, columns: "id, one")
        |> response(200)

      assert "id,one\n1,2\n4,5\n" == actual

      where(
        url: [
          "/api/v1/dataset/test/query",
          "/api/v1/organization/org1/dataset/data1/query"
        ]
      )
    end

    data_test "increments dataset queries count when dataset query is requested", %{conn: conn} do
      conn
      |> put_req_header("accept", "text/csv")
      |> get(url, columns: "id, one")
      |> response(200)

      assert_called(Redix.command!(:redix, ["INCR", "smart_registry:queries:count:test"]))

      where(
        url: [
          "/api/v1/dataset/test/query",
          "/api/v1/organization/org1/dataset/data1/query"
        ]
      )
    end
  end

  describe "fetching json" do
    setup do
      model =
        Helper.sample_model(%{
          id: @dataset_id,
          systemName: @system_name,
          name: @data_name,
          private: false,
          lastUpdatedDate: nil,
          queries: 7,
          downloads: 9
        })

      allow(SystemNameCache.get(@org_name, @data_name), return: @dataset_id)
      allow(Model.get(@dataset_id), return: model)

      allow(Prestige.execute(any()),
        return: []
      )

      allow(
        Prestige.execute("SELECT * FROM #{@system_name}",
          rows_as_maps: true
        ),
        return: [%{id: 1, name: "Joe"}, %{id: 2, name: "Robby"}]
      )

      allow(Redix.command!(any(), any()), return: :does_not_matter)
      :ok
    end

    data_test "returns json", %{conn: conn} do
      actual =
        conn
        |> put_req_header("accept", "application/json")
        |> get(url)
        |> response(200)

      assert Jason.decode!(actual) == [
               %{"id" => 1, "name" => "Joe"},
               %{"id" => 2, "name" => "Robby"}
             ]

      assert_called Prestige.execute("SELECT * FROM #{@system_name}", rows_as_maps: true), once()

      where(
        url: [
          "/api/v1/dataset/test/query",
          "/api/v1/organization/org1/dataset/data1/query"
        ]
      )
    end

    data_test "increments dataset queries count when dataset query is requested", %{conn: conn} do
      conn
      |> put_req_header("accept", "application/json")
      |> get(url)
      |> response(200)

      assert_called(Redix.command!(:redix, ["INCR", "smart_registry:queries:count:test"]))

      where(
        url: [
          "/api/v1/dataset/test/query",
          "/api/v1/organization/org1/dataset/data1/query"
        ]
      )
    end
  end

  describe "error cases" do
    test "table does not exist returns Not Found", %{conn: conn} do
      allow(Model.get("no_exist"),
        return: %Model{:id => "test", :systemName => "coda__no_exist", private: false}
      )

      allow(Prestige.execute(any()), return: [])
      allow(Prestige.prefetch(any()), return: [])

      query_string = "SELECT id, one, two FROM coda__no_exist"

      assert capture_log(fn ->
               conn
               |> put_req_header("accept", "text/csv")
               |> get("/api/v1/dataset/no_exist/query", columns: "id,one,two")
               |> response(404)
             end) =~ "Table coda__no_exist not found"

      assert_called Prestige.execute(query_string), times(0)
    end
  end

  describe "malice cases" do
    setup do
      allow(Model.get("bobber"),
        return: %Model{:id => "test", :systemName => "coda__test_dataset", private: false}
      )

      allow(Prestige.execute(any()), return: [])
      allow(Prestige.execute(any()), return: [])

      allow(Prestige.prefetch(any()),
        return: [["id", "bigint", "", ""], ["one", "bigint", "", ""], ["two", "bigint", "", ""]]
      )

      :ok
    end

    test "json queries cannot contain semicolons", %{conn: conn} do
      assert capture_log(fn ->
               conn
               |> put_req_header("accept", "application/json")
               |> get("/api/v1/dataset/bobber/query", columns: "id,one; select * from system; two")
               |> response(400)
             end) =~
               "Query contained illegal character(s): [SELECT id, one; select * from system; two FROM coda__test_dataset]"

      assert_called(
        Prestige.execute("SELECT id, one; select * from system; two FROM coda__test_dataset"),
        times(0)
      )
    end

    test "csv queries cannot contain semicolons", %{conn: conn} do
      assert capture_log(fn ->
               conn
               |> put_req_header("accept", "text/csv")
               |> get("/api/v1/dataset/bobber/query", columns: "id,one; select * from system; two")
               |> response(400)
             end) =~
               "Query contained illegal character(s): [SELECT id, one; select * from system; two FROM coda__test_dataset]"

      assert_called(
        Prestige.execute("SELECT id, one; select * from system; two FROM coda__test_dataset"),
        times(0)
      )
    end

    test "queries cannot contain block comments", %{conn: conn} do
      query_string = "SELECT * FROM coda__test_dataset ORDER BY /* This is a comment */"

      assert capture_log(fn ->
               conn
               |> put_req_header("accept", "text/csv")
               |> get("/api/v1/dataset/bobber/query", orderBy: "/* This is a comment */")
               |> response(400)
             end) =~ "Query contained illegal character(s): [#{query_string}]"

      assert_called Prestige.execute(query_string), times(0)
    end

    test "queries cannot contain single-line comments", %{conn: conn} do
      query_string = "SELECT * FROM coda__test_dataset ORDER BY -- This is a comment"

      assert capture_log(fn ->
               conn
               |> put_req_header("accept", "text/csv")
               |> get("/api/v1/dataset/bobber/query", orderBy: "-- This is a comment")
               |> response(400)
             end) =~ "Query contained illegal character(s): [#{query_string}]"

      assert_called Prestige.execute(query_string), times(0)
    end
  end

  @moduletag capture_log: true
  describe "query multiple datasets" do
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

      datasets = [
        public_one_dataset,
        public_two_dataset,
        private_one_dataset,
        private_two_dataset
      ]

      username = "jessie"

      json_from_execute = [
        %{"a" => 2, "b" => 2},
        %{"a" => 3, "b" => 3},
        %{"a" => 1, "b" => 1}
      ]

      csv_from_execute = "a,b\n2,2\n3,3\n1,1\n"

      allow(Model.get_all(), return: datasets)
      allow(AuthService.get_user(any()), return: username)
      allow(Prestige.execute(any(), any()), return: json_from_execute)

      {
        :ok,
        %{
          public_tables: [public_one_dataset, public_two_dataset] |> Enum.map(&Map.get(&1, :systemName)),
          private_tables: [private_one_dataset, private_two_dataset] |> Enum.map(&Map.get(&1, :systemName)),
          json_response: json_from_execute,
          csv_response: csv_from_execute
        }
      }
    end

    test "can select from some public datasets as json", %{conn: conn, public_tables: public_tables, json_response: expected_response} do
      statement = """
        WITH public_one AS (select a from public__one), public_two AS (select b from public__two)
        SELECT * FROM public_one JOIN public_two ON public_one.a = public_two.b
      """

      request_body = %{statement: statement}

      allow(PrestoService.supported?(statement), return: true)
      allow(PrestoService.get_affected_tables(statement), return: {public_tables, []})
      allow(AuthService.has_access?(any(), any()), return: true)

      response_body =
        conn
        |> put_req_header("accept", "application/json")
        |> post("/api/v1/query", request_body)
        |> response(200)
        |> Jason.decode!()

      assert expected_response == response_body
    end

    test "can select from some public datasets as csv", %{conn: conn, public_tables: public_tables, csv_response: expected_response} do
      statement = """
        WITH public_one AS (select a from public__one), public_two AS (select b from public__two)
        SELECT * FROM public_one JOIN public_two ON public_one.a = public_two.b
      """

      request_body = %{statement: statement}

      allow(PrestoService.supported?(statement), return: true)
      allow(PrestoService.get_affected_tables(statement), return: {public_tables, []})
      allow(AuthService.has_access?(any(), any()), return: true)

      response_body =
        conn
        |> put_req_header("accept", "text/csv")
        |> post("/api/v1/query", request_body)
        |> response(200)

      assert expected_response == response_body
    end

    test "can select from some authorized private datasets", %{conn: conn, private_tables: private_tables} do
      statement = """
        WITH private_one AS (select a from private__one), private_two AS (select b from private__two)
        SELECT * FROM private_one JOIN private_two ON private_one.a = private_two.b
      """

      request_body = %{statement: statement}

      allow(PrestoService.supported?(statement), return: true)
      allow(PrestoService.get_affected_tables(statement), return: {private_tables, []})
      allow(AuthService.has_access?(any(), any()), return: true)

      assert conn
             |> put_req_header("accept", "application/json")
             |> post("/api/v1/query", request_body)
             |> response(200)
    end

    test "can't select from some unauthorized private datasets", %{conn: conn, private_tables: private_tables} do
      statement = """
        WITH private_one AS (select a from private__one), private_two AS (select b from private__two)
        SELECT * FROM private_one JOIN private_two ON private_one.a = private_two.b
      """

      request_body = %{statement: statement}

      allow(PrestoService.supported?(statement), return: true)
      allow(PrestoService.get_affected_tables(statement), return: {private_tables, []})
      allow(AuthService.has_access?(any(), any()), seq: [false, true])

      assert conn
             |> put_req_header("accept", "application/json")
             |> post("/api/v1/query", request_body)
             |> response(400)
    end

    test "can't perform query if it includes writes of any sort", %{conn: conn, public_tables: public_tables} do
      statement = """
        INSERT INTO public__one SELECT * FROM public__two
      """

      request_body = %{statement: statement}

      allow(PrestoService.supported?(statement), return: true)
      allow(PrestoService.get_affected_tables(statement), return: {public_tables, public_tables})
      allow(AuthService.has_access?(any(), any()), return: true)

      assert conn
             |> put_req_header("accept", "application/json")
             |> post("/api/v1/query", request_body)
             |> response(400)
    end

    test "can't perform query if it doesn't include any valid reads", %{conn: conn} do
      statement = """
        SHOW TABLES
      """

      request_body = %{statement: statement}

      allow(PrestoService.supported?(statement), return: true)
      allow(PrestoService.get_affected_tables(statement), return: {[], []})
      allow(AuthService.has_access?(any(), any()), return: true)

      assert conn
             |> put_req_header("accept", "application/json")
             |> post("/api/v1/query", request_body)
             |> response(400)
    end

    test "can't perform query if it not a supported/allowed statement type", %{conn: conn, public_tables: public_tables} do
      statement = """
        EXPLAIN ANALYZE select * from public__one
      """

      request_body = %{statement: statement}

      allow(PrestoService.supported?(statement), return: false)
      allow(PrestoService.get_affected_tables(statement), return: {public_tables, []})
      allow(AuthService.has_access?(any(), any()), return: true)

      assert conn
             |> put_req_header("accept", "application/json")
             |> post("/api/v1/query", request_body)
             |> response(400)
    end

    test "does not accept requests with no statement in the body", %{conn: conn} do
      request_body = %{}

      assert conn
             |> put_req_header("accept", "application/json")
             |> post("/api/v1/query", request_body)
             |> response(400)
    end
  end

  describe "query restricted dataset" do
    setup do
      allow(Redix.command!(any(), any()), return: :does_not_matter)

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
            orgName: @org_name,
            dn: "cn=this_is_a_group,ou=Group"
          }
        })

      allow(SystemNameCache.get(@org_name, @data_name), return: @dataset_id)
      allow(Model.get(@dataset_id), return: model)

      allow(Prestige.execute(any()),
        return: []
      )

      allow(
        Prestige.execute("SELECT * FROM #{@system_name}",
          rows_as_maps: true
        ),
        return: [%{id: 1, name: "Joe"}, %{id: 2, name: "Robby"}]
      )

      :ok
    end

    test "does not query a restricted dataset if the given user is not a member of the dataset's group", %{conn: conn} do
      username = "bigbadbob"
      ldap_user = Helper.ldap_user()
      ldap_group = Helper.ldap_group(%{"member" => ["uid=FirstUser,ou=People"]})

      allow PaddleWrapper.authenticate(any(), any()), return: :ok
      allow PaddleWrapper.get(filter: [uid: username]), return: {:ok, [ldap_user]}
      allow PaddleWrapper.get(base: [ou: "Group"], filter: [cn: "this_is_a_group"]), return: {:ok, [ldap_group]}

      {:ok, token, _} = DiscoveryApi.Auth.Guardian.encode_and_sign(username, %{}, token_type: "refresh")

      conn
      |> put_req_cookie(Helper.default_guardian_token_key(), token)
      |> put_req_header("accept", "application/json")
      |> get("/api/v1/dataset/test/query")
      |> json_response(404)
    end

    test "queries a restricted dataset if the given user has access to it, via cookie", %{conn: conn} do
      username = "bigbadbob"
      ldap_user = Helper.ldap_user()
      ldap_group = Helper.ldap_group(%{"member" => ["uid=#{username},ou=People"]})

      allow PaddleWrapper.authenticate(any(), any()), return: :ok
      allow PaddleWrapper.get(filter: [uid: username]), return: {:ok, [ldap_user]}
      allow PaddleWrapper.get(base: [ou: "Group"], filter: [cn: "this_is_a_group"]), return: {:ok, [ldap_group]}

      {:ok, token, _} = DiscoveryApi.Auth.Guardian.encode_and_sign(username, %{}, token_type: "refresh")

      conn
      |> put_req_cookie(Helper.default_guardian_token_key(), token)
      |> put_req_header("accept", "application/json")
      |> get("/api/v1/dataset/test/query")
      |> json_response(200)
    end

    test "queries a restricted dataset if the given user has access to it, via token", %{conn: conn} do
      username = "bigbadbob"
      ldap_user = Helper.ldap_user()
      ldap_group = Helper.ldap_group(%{"member" => ["uid=#{username},ou=People"]})

      allow PaddleWrapper.authenticate(any(), any()), return: :ok
      allow PaddleWrapper.get(filter: [uid: username]), return: {:ok, [ldap_user]}
      allow PaddleWrapper.get(base: [ou: "Group"], filter: [cn: "this_is_a_group"]), return: {:ok, [ldap_group]}

      {:ok, token, _} = DiscoveryApi.Auth.Guardian.encode_and_sign(username, %{}, token_type: "access")

      conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> put_req_header("accept", "application/json")
      |> get("/api/v1/dataset/test/query")
      |> json_response(200)
    end
  end
end
