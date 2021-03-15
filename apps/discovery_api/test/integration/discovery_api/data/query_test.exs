defmodule DiscoveryApi.Data.QueryTest do
  import ExUnit.CaptureLog
  use ExUnit.Case
  use DiscoveryApi.DataCase
  use DiscoveryApiWeb.Test.AuthConnCase.IntegrationCase

  alias SmartCity.TestDataGenerator, as: TDG
  alias DiscoveryApi.Test.Helper
  alias DiscoveryApi.Data.Model

  import SmartCity.Event, only: [dataset_update: 0]
  import SmartCity.TestHelper, only: [eventually: 1]
  import Plug.Conn

  @instance_name DiscoveryApi.instance_name()

  setup_all do
    Redix.command!(:redix, ["FLUSHALL"])

    prestige_session =
      DiscoveryApi.prestige_opts()
      |> Keyword.merge(receive_timeout: 10_000)
      |> Prestige.new_session()

    organization = Helper.create_persisted_organization(%{})

    public_dataset =
      TDG.create_dataset(%{
        technical: %{
          private: false,
          orgId: organization.id,
          orgName: organization.orgName
        }
      })

    private_dataset =
      TDG.create_dataset(%{
        technical: %{
          private: true,
          orgId: organization.id,
          orgName: organization.orgName
        }
      })

    geojson_dataset =
      TDG.create_dataset(%{
        technical: %{
          private: false,
          orgId: organization.id,
          orgName: organization.orgName
        }
      })

    Brook.Event.send(@instance_name, dataset_update(), __MODULE__, public_dataset)
    Brook.Event.send(@instance_name, dataset_update(), __MODULE__, private_dataset)
    Brook.Event.send(@instance_name, dataset_update(), __MODULE__, geojson_dataset)

    eventually(fn ->
      assert nil != Model.get(public_dataset.id)
      assert nil != Model.get(private_dataset.id)
      assert nil != Model.get(geojson_dataset.id)
    end)

    public_table = public_dataset.technical.systemName
    private_table = private_dataset.technical.systemName
    geojson_table = geojson_dataset.technical.systemName

    capture_log(fn ->
      Prestige.query(
        prestige_session,
        ~s|create table if not exists "#{public_table}" (id integer, name varchar)|
      )
    end)

    capture_log(fn ->
      Prestige.query(
        prestige_session,
        ~s|create table if not exists "#{private_table}" (id integer, name varchar)|
      )
    end)

    capture_log(fn ->
      Prestige.query(
        prestige_session,
        ~s|insert into "#{public_table}" values (1,'Fred'),(2,'Gred'),(3,'Hred')|
      )
    end)

    capture_log(fn ->
      Prestige.query(
        prestige_session,
        ~s|insert into "#{private_table}" values (3,'Brad'),(4,'Jrad'),(5,'Thad')|
      )
    end)

    capture_log(fn ->
      Prestige.query(
        prestige_session,
        ~s|create table if not exists "#{geojson_table}" (feature varchar)|
      )
    end)

    capture_log(fn ->
      Prestige.query(
        prestige_session,
        ~s|insert into "#{geojson_table}" (feature) values
        ('{"geometry":{"coordinates":[[-1.0,1.0],[0.0,0.0]],"type":"LineString"},"properties":{"Foo":"Bar"},"type":"Feature"}'),
        ('{"geometry":{"coordinates":[[-2.0,0.0],[3.0,0.0]],"type":"LineString"},"properties":{"Foo":"Baz"},"type":"Feature"}')|
      )
    end)

    {:ok,
     %{
       organization: organization,
       private_table: private_table,
       public_table: public_table,
       public_dataset: public_dataset,
       private_dataset: private_dataset,
       geojson_dataset: geojson_dataset,
       geojson_table: geojson_table,
       prestige_session: prestige_session
     }}
  end

  @moduletag capture_log: true
  describe "api/v1/dataset/<id>/query" do
    test "Queries limited data from presto", %{public_dataset: public_dataset, anonymous_conn: conn} do
      actual =
        get(conn, "/api/v1/dataset/#{public_dataset.id}/query?limit=2&orderBy=name")
        |> response(200)

      assert actual == "id,name\n1,Fred\n2,Gred\n"
    end

    test "Queries limited data from presto when using orgName and dataName in url", %{public_dataset: public_dataset, anonymous_conn: conn} do
      actual =
        get(
          conn,
          "/api/v1/organization/#{public_dataset.technical.orgName}/dataset/#{public_dataset.technical.dataName}/query?limit=2&orderBy=name"
        )
        |> response(200)

      assert actual == "id,name\n1,Fred\n2,Gred\n"
    end

    test "Queries data from presto with multiple clauses", %{public_dataset: public_dataset, anonymous_conn: conn} do
      actual =
        get(conn, "/api/v1/dataset/#{public_dataset.id}/query?limit=2&columns=name&orderBy=name")
        |> response(200)

      assert actual == "name\nFred\nGred\n"
    end

    test "Queries data from presto with an aggregator", %{public_dataset: public_dataset, anonymous_conn: conn} do
      actual =
        get(conn, "/api/v1/dataset/#{public_dataset.id}/query?columns=count(id),%20name&groupBy=name&orderBy=name")
        |> response(200)

      assert actual == "_col0,name\n1,Fred\n1,Gred\n1,Hred\n"
    end

    test "queries data from presto with non-default format", %{public_dataset: public_dataset, anonymous_conn: conn} do
      actual =
        put_req_header(conn, "accept", "application/json")
        |> get("/api/v1/dataset/#{public_dataset.id}/query?columns=count(id),%20name&groupBy=name&orderBy=name")
        |> json_response(200)

      expected = [
        %{"_col0" => 1, "name" => "Fred"},
        %{"_col0" => 1, "name" => "Gred"},
        %{"_col0" => 1, "name" => "Hred"}
      ]

      assert actual == expected
    end

    test "Queries can't include sub-queries of private tables", %{
      public_dataset: public_dataset,
      private_table: private_table,
      anonymous_conn: conn
    } do
      actual =
        get(
          conn,
          "/api/v1/dataset/#{public_dataset.id}/query?limit=2&columns=(SELECT%20name%20FROM%20#{private_table}%20LIMIT%201)%20AS%20hacked"
        )
        |> response(400)
        |> Jason.decode!()

      assert actual == %{"message" => "Bad Request"}
    end
  end

  describe "api/v1/query as a user with no access" do
    test "unauthorized user can't query private and public datasets in one statement", %{
      public_table: public_table,
      private_table: private_table,
      anonymous_conn: conn
    } do
      request_body = """
        WITH public_one AS (select id from #{public_table}), private_one AS (select id from #{private_table})
        SELECT * FROM public_one JOIN private_one ON public_one.id = private_one.id
      """

      plain_text_post(conn, "/api/v1/query", request_body)
      |> response(400)
    end

    test "another user can query public datasets in one statement", %{
      public_table: public_table,
      anonymous_conn: conn
    } do
      request_body = """
        SELECT * FROM #{public_table} AS one JOIN #{public_table} AS two ON one.id = two.id
      """

      assert body =
               Plug.Conn.put_req_header(conn, "accept", "application/json")
               |> plain_text_post("/api/v1/query", request_body)
               |> json_response(200)

      assert body == [
               %{"id" => 1, "name" => "Fred"},
               %{"id" => 2, "name" => "Gred"},
               %{"id" => 3, "name" => "Hred"}
             ]
    end
  end

  describe "api/v1/query" do
    setup context do
      user = Helper.create_persisted_user(context.authorized_subject)
      Helper.associate_user_with_organization(user.id, context.organization.id)

      context
    end

    test "authorized user can query private and public datasets in one statement", %{
      public_table: public_table,
      private_table: private_table,
      authorized_conn: authorized_conn
    } do
      request_body = """
        WITH public_one AS (select id from #{public_table}), private_one AS (select id from #{private_table})
        SELECT * FROM public_one JOIN private_one ON public_one.id = private_one.id
      """

      assert [%{"id" => 3}] ==
               put_req_header(authorized_conn, "accept", "application/json")
               |> plain_text_post("/api/v1/query", request_body)
               |> json_response(200)
    end

    test "anonymous user can't query private datasets as a subquery with public datasets in one statement", %{
      public_table: public_table,
      private_table: private_table,
      anonymous_conn: conn
    } do
      request_body = """
        SELECT (SELECT id FROM #{private_table} LIMIT 1) FROM #{public_table}
      """

      assert %{"message" => "Bad Request"} ==
               plain_text_post(conn, "/api/v1/query", request_body)
               |> response(400)
               |> Jason.decode!()
    end

    test "anonymous user can't query private and public datasets in one statement", %{
      public_table: public_table,
      private_table: private_table,
      anonymous_conn: conn
    } do
      request_body = """
        WITH public_one AS (select id from #{public_table}), private_one AS (select id from #{private_table})
        SELECT * FROM public_one JOIN private_one ON public_one.id = private_one.id
      """

      assert plain_text_post(conn, "/api/v1/query", request_body)
             |> response(400)
    end

    test "anonymous user can query public datasets in one statement", %{public_table: public_table, anonymous_conn: conn} do
      request_body = """
        SELECT * FROM #{public_table} AS one JOIN #{public_table} AS two ON one.id = two.id
      """

      assert body =
               put_req_header(conn, "accept", "application/json")
               |> plain_text_post("/api/v1/query", request_body)
               |> json_response(200)

      assert body == [
               %{"id" => 1, "name" => "Fred"},
               %{"id" => 2, "name" => "Gred"},
               %{"id" => 3, "name" => "Hred"}
             ]
    end

    test "any user gets a reasonable response when submitting statements with bad syntax", %{
      public_table: public_table,
      anonymous_conn: conn
    } do
      request_body = """
        SELECT * FORM #{public_table}
      """

      assert %{
               "message" =>
                 "Syntax Error: mismatched input 'FORM'. Expecting: ',', 'EXCEPT', 'FROM', 'GROUP', 'HAVING', 'INTERSECT', 'LIMIT', 'ORDER', 'UNION', 'WHERE', <EOF>"
             } ==
               plain_text_post(conn, "/api/v1/query", request_body)
               |> response(400)
               |> Jason.decode!()
    end

    test "any user gets a reasonable response when submitting statements with a missing column", %{
      public_table: public_table,
      anonymous_conn: conn
    } do
      request_body = """
        SELECT missing_column FROM #{public_table}
      """

      assert %{"message" => "Syntax Error: Column 'missing_column' cannot be resolved"} ==
               plain_text_post(conn, "/api/v1/query", request_body)
               |> response(400)
               |> Jason.decode!()
    end

    test "any user gets a reasonable response when submitting statements with runtime errors", %{
      public_table: public_table,
      anonymous_conn: conn
    } do
      request_body = """
        SELECT cast(name as double) FROM #{public_table}
      """

      assert %{"message" => "Query Error: Cannot cast 'Fred' to DOUBLE"} ==
               plain_text_post(conn, "/api/v1/query", request_body)
               |> response(400)
               |> Jason.decode!()
    end

    test "any user gets an opaque response when submitting statements for a table that does not exist", %{
      public_table: public_table,
      anonymous_conn: conn
    } do
      request_body = """
        SELECT * FROM non_existant_dataset
      """

      assert %{"message" => "Bad Request"} ==
               plain_text_post(conn, "/api/v1/query", request_body)
               |> response(400)
               |> Jason.decode!()
    end

    test "any user can't use multiple line magic comments (on more than one line)", %{
      public_table: public_table,
      anonymous_conn: conn
    } do
      request_body = """
        /*
        set session distributed_join = 'true'
        */
        SELECT * FROM #{public_table}
      """

      assert %{"message" => "Bad Request"} ==
               plain_text_post(conn, "/api/v1/query", request_body)
               |> response(400)
               |> Jason.decode!()
    end

    test "any user can't use multiple line magic comments", %{
      public_table: public_table,
      anonymous_conn: conn
    } do
      request_body = """
        /* set session distributed_join = 'true' */
        SELECT * FROM #{public_table}
      """

      assert %{"message" => "Bad Request"} ==
               plain_text_post(conn, "/api/v1/query", request_body)
               |> response(400)
               |> Jason.decode!()
    end

    test "any user can't use single line magic comments", %{
      public_table: public_table,
      anonymous_conn: conn
    } do
      request_body = """
        -- set session distributed_join = 'true'
        SELECT * FROM #{public_table}
      """

      assert %{"message" => "Bad Request"} ==
               plain_text_post(conn, "/api/v1/query", request_body)
               |> response(400)
               |> Jason.decode!()
    end

    test "any user can't explain a statement", %{
      private_table: private_table,
      anonymous_conn: conn
    } do
      request_body = """
        EXPLAIN ANALYZE SELECT * FROM #{private_table}
      """

      assert %{"message" => "Bad Request"} ==
               plain_text_post(conn, "/api/v1/query", request_body)
               |> response(400)
               |> Jason.decode!()
    end

    test "any user can't describe table", %{
      private_table: private_table,
      anonymous_conn: conn
    } do
      request_body = """
        DESCRIBE #{private_table}
      """

      assert %{"message" => "Bad Request"} ==
               plain_text_post(conn, "/api/v1/query", request_body)
               |> response(400)
               |> Jason.decode!()
    end

    test "any user can't desc table", %{
      private_table: private_table,
      anonymous_conn: conn
    } do
      request_body = """
        DESC #{private_table}
      """

      assert %{"message" => "Bad Request"} ==
               plain_text_post(conn, "/api/v1/query", request_body)
               |> response(400)
               |> Jason.decode!()
    end

    test "any user can't delete from a table", %{
      private_table: private_table,
      anonymous_conn: conn,
      prestige_session: prestige_session
    } do
      request_body = """
        DELETE FROM #{private_table}
      """

      assert %{"message" => "Bad Request"} ==
               plain_text_post(conn, "/api/v1/query", request_body)
               |> response(400)
               |> Jason.decode!()

      assert 3 ==
               prestige_session
               |> Prestige.query!(~s|select * from #{private_table}|)
               |> (fn result -> result.rows end).()
               |> Enum.count()
    end

    test "any user can't drop a table", %{
      private_table: private_table,
      anonymous_conn: conn,
      prestige_session: prestige_session
    } do
      request_body = """
        DROP TABLE #{private_table}
      """

      assert %{"message" => "Bad Request"} ==
               plain_text_post(conn, "/api/v1/query", request_body)
               |> response(400)
               |> Jason.decode!()

      assert 3 ==
               prestige_session
               |> Prestige.query!(~s|select * from #{private_table}|)
               |> (fn result -> result.rows end).()
               |> Enum.count()
    end

    test "any user can't create a table", %{
      private_table: private_table,
      anonymous_conn: conn,
      prestige_session: prestige_session
    } do
      request_body = """
        CREATE TABLE my_own_table (id integer, name varchar) AS SELECT * FROM #{private_table}
      """

      assert %{"message" => "Bad Request"} ==
               plain_text_post(conn, "/api/v1/query", request_body)
               |> response(400)
               |> Jason.decode!()

      assert_raise Prestige.Error, fn ->
        Prestige.query!(prestige_session, ~s|select * from my_own_table|)
      end
    end

    test "any user can't perform multiple queries separated by newlines", %{
      public_table: public_table,
      private_table: private_table,
      anonymous_conn: conn,
      prestige_session: prestige_session
    } do
      request_body = """
        SELECT * FROM #{public_table}

        DROP TABLE #{private_table}
      """

      assert %{
               "message" =>
                 "Syntax Error: mismatched input 'DROP'. Expecting: ',', '.', 'AS', 'CROSS', 'EXCEPT', 'FULL', 'GROUP', 'HAVING', 'INNER', 'INTERSECT', 'JOIN', 'LEFT', 'LIMIT', 'NATURAL', 'ORDER', 'RIGHT', 'TABLESAMPLE', 'UNION', 'WHERE', <EOF>, <identifier>"
             } ==
               plain_text_post(conn, "/api/v1/query", request_body)
               |> response(400)
               |> Jason.decode!()

      assert 3 ==
               prestige_session
               |> Prestige.query!(~s|select * from #{private_table}|)
               |> (fn result -> result.rows end).()
               |> Enum.count()
    end

    test "any user can't perform multiple queries separated by carriage return", %{
      public_table: public_table,
      private_table: private_table,
      anonymous_conn: conn
    } do
      request_body = "SELECT * FROM #{public_table}\rSELECT * FROM #{private_table}"

      assert %{
               "message" =>
                 "Syntax Error: mismatched input 'SELECT'. Expecting: ',', '.', 'AS', 'CROSS', 'EXCEPT', 'FULL', 'GROUP', 'HAVING', 'INNER', 'INTERSECT', 'JOIN', 'LEFT', 'LIMIT', 'NATURAL', 'ORDER', 'RIGHT', 'TABLESAMPLE', 'UNION', 'WHERE', <EOF>, <identifier>"
             } ==
               plain_text_post(conn, "/api/v1/query", request_body)
               |> response(400)
               |> Jason.decode!()
    end

    test "any user can't perform multiple queries separated by a semicolon", %{
      public_table: public_table,
      private_table: private_table,
      anonymous_conn: conn,
      prestige_session: prestige_session
    } do
      request_body = """
        SELECT * FROM #{public_table}; DROP TABLE #{private_table}
      """

      assert %{
               "message" =>
                 "Syntax Error: mismatched input ';'. Expecting: ',', '.', 'AS', 'CROSS', 'EXCEPT', 'FULL', 'GROUP', 'HAVING', 'INNER', 'INTERSECT', 'JOIN', 'LEFT', 'LIMIT', 'NATURAL', 'ORDER', 'RIGHT', 'TABLESAMPLE', 'UNION', 'WHERE', <EOF>, <identifier>"
             } ==
               plain_text_post(conn, "/api/v1/query", request_body)
               |> response(400)
               |> Jason.decode!()

      assert 3 ==
               prestige_session
               |> Prestige.query!(~s|select * from #{private_table}|)
               |> (fn result -> result.rows end).()
               |> Enum.count()
    end

    test "any user can't insert data", %{
      public_table: public_table,
      private_table: private_table,
      anonymous_conn: conn,
      prestige_session: prestige_session
    } do
      request_body = """
        INSERT INTO #{private_table} SELECT * FROM #{public_table}
      """

      assert %{"message" => "Bad Request"} ==
               plain_text_post(conn, "/api/v1/query", request_body)
               |> response(400)
               |> Jason.decode!()

      assert 3 ==
               prestige_session
               |> Prestige.query!(~s|select * from #{private_table}|)
               |> (fn result -> result.rows end).()
               |> Enum.count()
    end

    test "any user can't query for path columns", %{
      public_table: public_table,
      private_table: private_table,
      anonymous_conn: conn,
      prestige_session: prestige_session
    } do
      request_body = """
        select "$path" from #{public_table}
      """

      assert %{"message" => "Bad Request"} ==
               plain_text_post(conn, "/api/v1/query", request_body)
               |> response(400)
               |> Jason.decode!()
    end
  end

  @moduletag capture_log: true
  describe "api/v1/dataset/<id>/download" do
    test "downloads all of a dataset's data from presto", %{public_dataset: public_dataset, anonymous_conn: conn} do
      actual =
        get(conn, "/api/v1/dataset/#{public_dataset.id}/download")
        |> response(200)

      assert actual == "id,name\n1,Fred\n2,Gred\n3,Hred\n"
    end
  end

  describe "geojson queries" do
    setup do
      %{
        expected_body: %{
          "bbox" => [-2.0, 0.0, 3.0, 1.0],
          "type" => "FeatureCollection",
          "features" => [
            %{
              "geometry" => %{"coordinates" => [[-1.0, 1.0], [0.0, 0.0]], "type" => "LineString"},
              "properties" => %{"Foo" => "Bar"},
              "type" => "Feature"
            },
            %{
              "geometry" => %{"coordinates" => [[-2.0, 0.0], [3.0, 0.0]], "type" => "LineString"},
              "properties" => %{"Foo" => "Baz"},
              "type" => "Feature"
            }
          ]
        }
      }
    end

    test "can query a geojson dataset", %{
      geojson_dataset: geojson_dataset,
      expected_body: expected_body,
      anonymous_conn: conn
    } do
      actual =
        get(conn, "/api/v1/dataset/#{geojson_dataset.id}/query?_format=geojson&orderBy=feature")
        |> json_response(200)

      assert geojson_dataset.technical.systemName == Map.get(actual, "name")
      sorted_expected_features = expected_body |> Map.get("features") |> Enum.sort()
      sorted_actual_features = Map.get(actual, "features") |> Enum.sort()
      assert sorted_expected_features == sorted_actual_features
    end

    test "can query geojson with SQL", %{
      geojson_table: geojson_table,
      expected_body: expected_body,
      anonymous_conn: conn
    } do
      actual =
        plain_text_post(conn, "/api/v1/query?_format=geojson", "select * from #{geojson_table} order by feature")
        |> json_response(200)

      sorted_expected_features = expected_body |> Map.get("features") |> Enum.sort()
      sorted_actual_features = Map.get(actual, "features") |> Enum.sort()
      assert sorted_expected_features == sorted_actual_features
    end
  end

  defp plain_text_post(conn, path, body) do
    put_req_header(conn, "content-type", "text/plain")
    |> post(path, body)
  end
end
