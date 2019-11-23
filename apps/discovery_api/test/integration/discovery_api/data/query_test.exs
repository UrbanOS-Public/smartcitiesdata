defmodule DiscoveryApi.Data.QueryTest do
  import ExUnit.CaptureLog
  use ExUnit.Case
  use Divo
  use DiscoveryApi.DataCase
  alias SmartCity.Registry.Dataset
  alias DiscoveryApi.TestDataGenerator, as: TDG
  alias DiscoveryApi.Test.Helper

  @public_dataset_id "123-456-789"
  @private_dataset_id "111-222-333"
  @organization_name "org1"
  @username_with_public_access "jessie"
  @username_with_private_access "aloha"
  @public_dataset_name "public_data"
  @private_dataset_name "private_data"

  @prestige_session_opts DiscoveryApi.prestige_session_opts()

  setup_all do
    Helper.wait_for_brook_to_be_ready()
    Redix.command!(:redix, ["FLUSHALL"])

    prestige_session =
      @prestige_session_opts
      |> Keyword.merge(receive_timeout: 10_000)
      |> Prestige.new_session()

    membership = %{
      @organization_name => [
        @username_with_private_access
      ],
      "some_other_organization" => [
        @username_with_public_access
      ]
    }

    %{
      @organization_name => organization
    } = Helper.setup_ldap(membership)

    public_dataset =
      TDG.create_dataset(%{
        id: @public_dataset_id,
        technical: %{
          private: false,
          orgId: organization.id,
          orgName: organization.orgName,
          dataName: @public_dataset_name,
          systemName: "#{organization.orgName}__#{@public_dataset_name}"
        }
      })

    private_dataset =
      TDG.create_dataset(%{
        id: @private_dataset_id,
        technical: %{
          private: true,
          orgId: organization.id,
          orgName: organization.orgName,
          dataName: @private_dataset_name,
          systemName: "#{organization.orgName}__#{@private_dataset_name}"
        }
      })

    geojson_dataset =
      TDG.create_dataset(%{
        id: "geojson_id",
        technical: %{
          private: false,
          orgId: organization.id,
          orgName: organization.orgName,
          dataName: "some_geojson",
          systemName: "#{organization.orgName}__some_geojson"
        }
      })

    Dataset.write(public_dataset)
    Dataset.write(private_dataset)
    Dataset.write(geojson_dataset)

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

    public_token = Helper.get_token_from_login(@username_with_public_access)
    private_token = Helper.get_token_from_login(@username_with_private_access)

    {:ok,
     %{
       organization: organization,
       public_token: public_token,
       private_token: private_token,
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
    test "Queries limited data from presto", %{public_dataset: public_dataset} do
      actual = get("http://localhost:4000/api/v1/dataset/#{public_dataset.id}/query?limit=2&orderBy=name")

      assert actual.body == "id,name\n1,Fred\n2,Gred\n"
    end

    test "Queries limited data from presto when using orgName and dataName in url", %{public_dataset: public_dataset} do
      actual =
        get(
          "http://localhost:4000/api/v1/organization/#{public_dataset.technical.orgName}/dataset/#{public_dataset.technical.dataName}/query?limit=2&orderBy=name"
        )

      assert actual.body == "id,name\n1,Fred\n2,Gred\n"
    end

    test "Queries data from presto with multiple clauses", %{public_dataset: public_dataset} do
      actual = get("http://localhost:4000/api/v1/dataset/#{public_dataset.id}/query?limit=2&columns=name&orderBy=name")

      assert actual.body == "name\nFred\nGred\n"
    end

    test "Queries data from presto with an aggregator", %{public_dataset: public_dataset} do
      actual = get("http://localhost:4000/api/v1/dataset/#{public_dataset.id}/query?columns=count(id),%20name&groupBy=name&orderBy=name")

      assert actual.body == "_col0,name\n1,Fred\n1,Gred\n1,Hred\n"
    end

    test "queries data from presto with non-default format", %{public_dataset: public_dataset} do
      actual =
        get(
          "http://localhost:4000/api/v1/dataset/#{public_dataset.id}/query?columns=count(id),%20name&groupBy=name&orderBy=name",
          %{"Accept" => "application/json"}
        )

      expected =
        [
          %{"_col0" => 1, "name" => "Fred"},
          %{"_col0" => 1, "name" => "Gred"},
          %{"_col0" => 1, "name" => "Hred"}
        ]
        |> Jason.encode!()

      assert actual.body == expected
    end

    test "Queries can't include sub-queries of private tables", %{
      public_dataset: public_dataset,
      private_table: private_table
    } do
      actual =
        get(
          "http://localhost:4000/api/v1/dataset/#{public_dataset.id}/query?limit=2&columns=(SELECT%20name%20FROM%20#{private_table}%20LIMIT%201)%20AS%20hacked"
        )

      assert actual.body == "{\"message\":\"Bad Request\"}"
      assert actual.status_code == 400
    end
  end

  describe "api/v1/query" do
    test "authorized user can query private and public datasets in one statement", %{
      public_table: public_table,
      private_table: private_table,
      private_token: private_token
    } do
      request_body = """
        WITH public_one AS (select id from #{public_table}), private_one AS (select id from #{private_table})
        SELECT * FROM public_one JOIN private_one ON public_one.id = private_one.id
      """

      actual = post("http://localhost:4000/api/v1/query", request_body, private_token)

      assert actual.body == "[{\"id\":3}]"
    end

    test "unauthorized user can't query private and public datasets in one statement", %{
      public_table: public_table,
      private_table: private_table,
      public_token: public_token
    } do
      request_body = """
        WITH public_one AS (select id from #{public_table}), private_one AS (select id from #{private_table})
        SELECT * FROM public_one JOIN private_one ON public_one.id = private_one.id
      """

      actual = post("http://localhost:4000/api/v1/query", request_body, public_token)

      assert actual.status_code == 400
    end

    test "anonymous user can't query private datasets as a subquery with public datasets in one statement", %{
      public_table: public_table,
      private_table: private_table
    } do
      request_body = """
        SELECT (SELECT id FROM #{private_table} LIMIT 1) FROM #{public_table}
      """

      actual = post("http://localhost:4000/api/v1/query", request_body)

      assert actual.status_code == 400
      assert actual.body == "{\"message\":\"Bad Request\"}"
    end

    test "anonymous user can't query private and public datasets in one statement", %{
      public_table: public_table,
      private_table: private_table
    } do
      request_body = """
        WITH public_one AS (select id from #{public_table}), private_one AS (select id from #{private_table})
        SELECT * FROM public_one JOIN private_one ON public_one.id = private_one.id
      """

      actual = post("http://localhost:4000/api/v1/query", request_body)

      assert actual.status_code == 400
    end

    test "another user can query public datasets in one statement", %{
      public_table: public_table,
      public_token: public_token
    } do
      request_body = """
        SELECT * FROM #{public_table} AS one JOIN #{public_table} AS two ON one.id = two.id
      """

      actual = post("http://localhost:4000/api/v1/query", request_body, public_token)

      assert actual.body == "[{\"id\":1,\"name\":\"Fred\"},{\"id\":2,\"name\":\"Gred\"},{\"id\":3,\"name\":\"Hred\"}]"
    end

    test "anonymous user can query public datasets in one statement", %{public_table: public_table} do
      request_body = """
        SELECT * FROM #{public_table} AS one JOIN #{public_table} AS two ON one.id = two.id
      """

      actual = post("http://localhost:4000/api/v1/query", request_body)

      assert actual.body == "[{\"id\":1,\"name\":\"Fred\"},{\"id\":2,\"name\":\"Gred\"},{\"id\":3,\"name\":\"Hred\"}]"
    end

    test "any user gets a reasonable response when submitting statements with bad syntax", %{
      private_table: private_table,
      private_token: private_token
    } do
      request_body = """
        SALECT * FORM #{private_table}
      """

      actual = post("http://localhost:4000/api/v1/query", request_body, private_token)

      assert actual.status_code == 400
      assert actual.body == "{\"message\":\"Bad Request\"}"
    end

    test "any user can't use multiple line magic comments (on more than one line)", %{
      private_table: private_table,
      private_token: private_token
    } do
      request_body = """
        /*
        set session distributed_join = 'true'
        */
        SELECT * FROM #{private_table}
      """

      actual = post("http://localhost:4000/api/v1/query", request_body, private_token)

      assert actual.status_code == 400
      assert actual.body == "{\"message\":\"Bad Request\"}"
    end

    test "any user can't use multiple line magic comments", %{
      private_table: private_table,
      private_token: private_token
    } do
      request_body = """
        /* set session distributed_join = 'true' */
        SELECT * FROM #{private_table}
      """

      actual = post("http://localhost:4000/api/v1/query", request_body, private_token)

      assert actual.status_code == 400
      assert actual.body == "{\"message\":\"Bad Request\"}"
    end

    test "any user can't use single line magic comments", %{
      private_table: private_table,
      private_token: private_token
    } do
      request_body = """
        -- set session distributed_join = 'true'
        SELECT * FROM #{private_table}
      """

      actual = post("http://localhost:4000/api/v1/query", request_body, private_token)

      assert actual.status_code == 400
      assert actual.body == "{\"message\":\"Bad Request\"}"
    end

    test "any user can't explain a statement", %{
      private_table: private_table,
      private_token: private_token
    } do
      request_body = """
        EXPLAIN ANALYZE SELECT * FROM #{private_table}
      """

      actual = post("http://localhost:4000/api/v1/query", request_body, private_token)

      assert actual.status_code == 400
      assert actual.body == "{\"message\":\"Bad Request\"}"
    end

    test "any user can't describe table", %{
      private_table: private_table,
      private_token: private_token
    } do
      request_body = """
        DESCRIBE #{private_table}
      """

      actual = post("http://localhost:4000/api/v1/query", request_body, private_token)

      assert actual.status_code == 400
      assert actual.body == "{\"message\":\"Bad Request\"}"
    end

    test "any user can't desc table", %{
      private_table: private_table,
      private_token: private_token
    } do
      request_body = """
        DESC #{private_table}
      """

      actual = post("http://localhost:4000/api/v1/query", request_body, private_token)

      assert actual.status_code == 400
      assert actual.body == "{\"message\":\"Bad Request\"}"
    end

    test "any user can't delete from a table", %{
      private_table: private_table,
      private_token: private_token,
      prestige_session: prestige_session
    } do
      request_body = """
        DELETE FROM #{private_table}
      """

      actual = post("http://localhost:4000/api/v1/query", request_body, private_token)

      assert actual.status_code == 400

      assert 3 ==
               prestige_session
               |> Prestige.query!(~s|select * from #{private_table}|)
               |> (fn result -> result.rows end).()
               |> Enum.count()
    end

    test "any user can't drop a table", %{
      private_table: private_table,
      private_token: private_token,
      prestige_session: prestige_session
    } do
      request_body = """
        DROP TABLE #{private_table}
      """

      actual = post("http://localhost:4000/api/v1/query", request_body, private_token)

      assert actual.status_code == 400
      assert actual.body == "{\"message\":\"Bad Request\"}"

      assert 3 ==
               prestige_session
               |> Prestige.query!(~s|select * from #{private_table}|)
               |> (fn result -> result.rows end).()
               |> Enum.count()
    end

    test "any user can't create a table", %{
      private_table: private_table,
      private_token: private_token,
      prestige_session: prestige_session
    } do
      request_body = """
        CREATE TABLE my_own_table (id integer, name varchar) AS SELECT * FROM #{private_table}
      """

      actual = post("http://localhost:4000/api/v1/query", request_body, private_token)

      assert actual.status_code == 400
      assert actual.body == "{\"message\":\"Bad Request\"}"

      assert_raise Prestige.Error, fn ->
        Prestige.query!(prestige_session, ~s|select * from my_own_table|)
      end
    end

    test "any user can't perform multiple queries separated by newlines", %{
      public_table: public_table,
      private_table: private_table,
      private_token: private_token,
      prestige_session: prestige_session
    } do
      request_body = """
        SELECT * FROM #{public_table}

        DROP TABLE #{private_table}
      """

      actual = post("http://localhost:4000/api/v1/query", request_body, private_token)

      assert actual.status_code == 400
      assert actual.body == "{\"message\":\"Bad Request\"}"

      assert 3 ==
               prestige_session
               |> Prestige.query!(~s|select * from #{private_table}|)
               |> (fn result -> result.rows end).()
               |> Enum.count()
    end

    test "any user can't perform multiple queries separated by carriage return", %{
      public_table: public_table,
      private_table: private_table,
      private_token: private_token
    } do
      request_body = "SELECT * FROM #{public_table}\rSELECT * FROM #{private_table}"

      actual = post("http://localhost:4000/api/v1/query", request_body, private_token)

      assert actual.status_code == 400
      assert actual.body == "{\"message\":\"Bad Request\"}"
    end

    test "any user can't perform multiple queries separated by a semicolon", %{
      public_table: public_table,
      private_table: private_table,
      private_token: private_token,
      prestige_session: prestige_session
    } do
      request_body = """
        SELECT * FROM #{public_table}; DROP TABLE #{private_table}
      """

      actual = post("http://localhost:4000/api/v1/query", request_body, private_token)

      assert actual.status_code == 400
      assert actual.body == "{\"message\":\"Bad Request\"}"

      assert 3 ==
               prestige_session
               |> Prestige.query!(~s|select * from #{private_table}|)
               |> (fn result -> result.rows end).()
               |> Enum.count()
    end

    test "any user can't insert data", %{
      public_table: public_table,
      private_table: private_table,
      private_token: private_token,
      prestige_session: prestige_session
    } do
      request_body = """
        INSERT INTO #{private_table} SELECT * FROM #{public_table}
      """

      actual = post("http://localhost:4000/api/v1/query", request_body, private_token)

      assert actual.status_code == 400
      assert actual.body == "{\"message\":\"Bad Request\"}"

      assert 3 ==
               prestige_session
               |> Prestige.query!(~s|select * from #{private_table}|)
               |> (fn result -> result.rows end).()
               |> Enum.count()
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
      expected_body: expected_body
    } do
      actual = get("http://localhost:4000/api/v1/dataset/#{geojson_dataset.id}/query?_format=geojson&orderBy=feature")

      assert geojson_dataset.technical.systemName == Jason.decode!(actual.body) |> Map.get("name")
      sorted_expected_features = expected_body |> Map.get("features") |> Enum.sort()
      sorted_actual_features = Jason.decode!(actual.body) |> Map.get("features") |> Enum.sort()
      assert sorted_expected_features == sorted_actual_features
    end

    test "can query geojson with SQL", %{
      geojson_table: geojson_table,
      expected_body: expected_body
    } do
      actual = post("http://localhost:4000/api/v1/query?_format=geojson", "select * from #{geojson_table} order by feature")

      sorted_expected_features = expected_body |> Map.get("features") |> Enum.sort()
      sorted_actual_features = Jason.decode!(actual.body) |> Map.get("features") |> Enum.sort()
      assert sorted_expected_features == sorted_actual_features
    end
  end

  defp get(url, headers \\ %{}) do
    HTTPoison.get!(url, headers)
    |> Map.from_struct()
  end

  defp post(url, body) do
    headers = %{
      "Accept" => "application/json",
      "Content-Type" => "text/plain"
    }

    post(url, body, headers)
  end

  defp post(url, body, token) when is_binary(token) do
    headers = %{
      "Accept" => "application/json",
      "Authorization" => "Bearer #{token}",
      "Content-Type" => "text/plain"
    }

    post(url, body, headers)
  end

  defp post(url, body, %{} = headers) do
    response = HTTPoison.post!(url, body, headers)
    Map.from_struct(response)
  end
end
