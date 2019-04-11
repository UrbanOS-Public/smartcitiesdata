defmodule DiscoveryApiWeb.DatasetQueryControllerTest do
  import ExUnit.CaptureLog
  use DiscoveryApiWeb.ConnCase
  use Placebo
  import Checkov
  alias DiscoveryApi.Data.{Dataset, SystemNameCache}
  alias Plug.Conn
  alias SmartCity.TestDataGenerator, as: TDG

  describe "fetching csv data" do
    setup do
      org = TDG.create_organization(id: "org_id", orgName: "org1")
      dataset = TDG.create_dataset(id: "test", technical: %{orgId: org.id, dataName: "data1"})
      allow SmartCity.Organization.get(any()), return: {:ok, org}
      SystemNameCache.put(dataset)

      allow(DiscoveryApi.Data.Dataset.get("test"), return: %Dataset{:id => "test", :systemName => "coda__test_dataset"})

      allow(Prestige.execute("describe coda__test_dataset"),
        return: []
      )

      allow(Prestige.execute("SELECT id, one FROM coda__test_dataset"),
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

      assert_called Prestige.execute("describe coda__test_dataset"), once()
      assert_called Prestige.execute("SELECT * FROM coda__test_dataset"), once()

      where(
        url: [
          "/api/v1/dataset/test/query",
          "/api/v1/organization/org1/dataset/data1/query"
        ]
      )
    end

    data_test "selects using the where clause provided", %{conn: conn} do
      conn |> put_req_header("accept", "text/csv") |> get(url, where: "one=1") |> response(200)

      assert_called Prestige.execute("SELECT * FROM coda__test_dataset WHERE one=1"),
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

      assert_called Prestige.execute("SELECT * FROM coda__test_dataset ORDER BY one"),
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

      assert_called Prestige.execute("SELECT * FROM coda__test_dataset LIMIT 200"),
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

      assert_called Prestige.execute("SELECT * FROM coda__test_dataset GROUP BY one"),
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

      assert_called Prestige.execute(
                      "SELECT * FROM coda__test_dataset WHERE one=1 GROUP BY one ORDER BY one LIMIT 200"
                    ),
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
      org = TDG.create_organization(id: "org_id", orgName: "org1")
      dataset = TDG.create_dataset(id: "test", technical: %{orgId: org.id, dataName: "data1"})
      allow SmartCity.Organization.get(any()), return: {:ok, org}
      SystemNameCache.put(dataset)

      allow(Prestige.execute(any()),
        return: []
      )

      allow(DiscoveryApi.Data.Dataset.get("test"), return: %Dataset{:id => "test", :systemName => "coda__test_dataset"})

      allow(
        Prestige.execute("SELECT * FROM coda__test_dataset",
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

      assert_called Prestige.execute("SELECT * FROM coda__test_dataset", rows_as_maps: true), once()

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
      allow(DiscoveryApi.Data.Dataset.get("no_exist"), return: %Dataset{:id => "test", :systemName => "coda__no_exist"})
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
      allow(DiscoveryApi.Data.Dataset.get("bobber"),
        return: %Dataset{:id => "test", :systemName => "coda__test_dataset"}
      )

      allow(Prestige.execute(any()), return: [])
      allow(Prestige.execute(any()), return: [])

      allow(Prestige.prefetch(any()),
        return: [["id", "bigint", "", ""], ["one", "bigint", "", ""], ["two", "bigint", "", ""]]
      )

      :ok
    end

    test "queries cannot contain semicolons", %{conn: conn} do
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

  describe "query restricted dataset" do
    setup do
      allow(Redix.command!(any(), any()), return: :does_not_matter)
      organization = TDG.create_organization(%{dn: "cn=this_is_a_group,ou=Group"})

      dataset =
        Helper.sample_dataset(%{
          id: "test",
          private: true,
          organizationDetails: organization,
          systemName: "coda__test_dataset"
        })

      allow DiscoveryApi.Data.Dataset.get(dataset.id), return: dataset

      allow SmartCity.Organization.get(dataset.organizationDetails.id), return: organization

      allow(Prestige.execute(any()),
        return: []
      )

      allow(
        Prestige.execute("SELECT * FROM coda__test_dataset",
          rows_as_maps: true
        ),
        return: [%{id: 1, name: "Joe"}, %{id: 2, name: "Robby"}]
      )

      :ok
    end

    test "does not query a restricted dataset if the given user does not have access to it", %{conn: conn} do
      ldap_user = Helper.ldap_user()

      ldap_group = Helper.ldap_group(%{"member" => ["uid=FirstUser,ou=People"]})

      allow Paddle.authenticate(any(), any()), return: :ok
      allow Paddle.config(:account_subdn), return: "ou=People"
      allow Paddle.get(filter: [uid: "bigbadbob"]), return: {:ok, [ldap_user]}
      allow Paddle.get(base: [ou: "Group"], filter: [cn: "this_is_a_group"]), return: {:ok, [ldap_group]}

      {:ok, token, _} = DiscoveryApi.Auth.Guardian.encode_and_sign("bigbadbob")

      conn
      |> Conn.put_req_header("authorization", "Bearer " <> token)
      |> put_req_header("accept", "application/json")
      |> get("/api/v1/dataset/test/query")
      |> json_response(404)
    end

    test "queries a restricted dataset if the given user has access to it", %{conn: conn} do
      ldap_user = Helper.ldap_user()

      ldap_group = Helper.ldap_group(%{"member" => ["uid=bigbadbob,ou=People"]})

      allow Paddle.authenticate(any(), any()), return: :ok
      allow Paddle.config(:account_subdn), return: "ou=People"
      allow Paddle.get(filter: [uid: "bigbadbob"]), return: {:ok, [ldap_user]}
      allow Paddle.get(base: [ou: "Group"], filter: [cn: "this_is_a_group"]), return: {:ok, [ldap_group]}

      {:ok, token, _} = DiscoveryApi.Auth.Guardian.encode_and_sign("bigbadbob")

      conn
      |> Conn.put_req_header("authorization", "Bearer " <> token)
      |> put_req_header("accept", "application/json")
      |> get("/api/v1/dataset/test/query")
      |> json_response(200)
    end
  end
end
