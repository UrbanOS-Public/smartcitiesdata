defmodule DiscoveryApi.Data.QueryTest do
  import ExUnit.CaptureLog
  use ExUnit.Case
  use Divo
  alias SmartCity.Dataset
  alias SmartCity.TestDataGenerator, as: TDG
  alias DiscoveryApi.Test.Helper

  @public_dataset_id "123-456-789"
  @private_dataset_id "111-222-333"
  @organization_name "org1"
  @username_with_public_access "jessie"
  @username_with_private_access "aloha"
  @public_dataset_name "public_data"
  @private_dataset_name "private_data"

  setup_all do
    Redix.command!(:redix, ["FLUSHALL"])

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

    Dataset.write(public_dataset)
    Dataset.write(private_dataset)

    public_table = public_dataset.technical.systemName
    private_table = private_dataset.technical.systemName

    capture_log(fn ->
      ~s|create table if not exists "#{public_table}" (id integer, name varchar)|
      |> Prestige.execute()
      |> Prestige.prefetch()
    end)

    capture_log(fn ->
      ~s|create table if not exists "#{private_table}" (id integer, name varchar)|
      |> Prestige.execute()
      |> Prestige.prefetch()
    end)

    capture_log(fn ->
      ~s|insert into "#{public_table}" values (1,'Fred'),(2,'Gred'),(3,'Hred')|
      |> Prestige.execute()
      |> Prestige.prefetch()
    end)

    capture_log(fn ->
      ~s|insert into "#{private_table}" values (3,'Brad'),(4,'Jrad'),(5,'Thad')|
      |> Prestige.execute()
      |> Prestige.prefetch()
    end)

    public_token = Helper.get_token_from_login(@username_with_public_access)
    private_token = Helper.get_token_from_login(@username_with_private_access)

    {:ok,
     %{
       public_token: public_token,
       private_token: private_token,
       private_table: private_table,
       public_table: public_table
     }}
  end

  @moduletag capture_log: true
  test "Queries limited data from presto" do
    actual =
      "http://localhost:4000/api/v1/dataset/#{@public_dataset_id}/query?limit=2&orderBy=name"
      |> HTTPoison.get!()
      |> Map.from_struct()
      |> Map.get(:body)

    assert "id,name\n1,Fred\n2,Gred\n" == actual
  end

  @moduletag capture_log: true
  test "Queries limited data from presto when using orgName and dataName in url" do
    actual =
      "http://localhost:4000/api/v1/organization/#{@organization_name}/dataset/#{@public_dataset_name}/query?limit=2&orderBy=name"
      |> HTTPoison.get!()
      |> Map.from_struct()
      |> Map.get(:body)

    assert "id,name\n1,Fred\n2,Gred\n" == actual
  end

  @moduletag capture_log: true
  test "Queries data from presto with multiple clauses" do
    actual =
      "http://localhost:4000/api/v1/dataset/#{@public_dataset_id}/query?limit=2&columns=name&orderBy=name"
      |> HTTPoison.get!()
      |> Map.from_struct()
      |> Map.get(:body)

    assert "name\nFred\nGred\n" == actual
  end

  @moduletag capture_log: true
  test "Queries data from presto with an aggregator" do
    actual =
      "http://localhost:4000/api/v1/dataset/#{@public_dataset_id}/query?columns=count(id),%20name&groupBy=name&orderBy=name"
      |> HTTPoison.get!()
      |> Map.from_struct()
      |> Map.get(:body)

    assert "count(id),name\n1,Fred\n1,Gred\n1,Hred\n" == actual
  end

  @moduletag capture_log: true
  test "queries data from presto with non-default format" do
    actual =
      "http://localhost:4000/api/v1/dataset/#{@public_dataset_id}/query?columns=count(id),%20name&groupBy=name&orderBy=name"
      |> HTTPoison.get!([{"Accept", "application/json"}])
      |> Map.from_struct()
      |> Map.get(:body)

    expected =
      [
        %{"_col0" => 1, "name" => "Fred"},
        %{"_col0" => 1, "name" => "Gred"},
        %{"_col0" => 1, "name" => "Hred"}
      ]
      |> Jason.encode!()

    assert expected == actual
  end

  test "authorized user can query private and public datasets in one statement", %{
    public_table: public_table,
    private_table: private_table,
    private_token: private_token
  } do
    request_body = %{
      statement: """
        WITH public_one AS (select id from #{public_table}), private_one AS (select id from #{private_table})
        SELECT * FROM public_one JOIN private_one ON public_one.id = private_one.id
      """
    }

    actual = post("http://localhost:4000/api/v1/query", request_body, private_token)

    assert actual.body == "[{\"id\":3}]"
  end

  test "unauthorized user can't query private and public datasets in one statement", %{
    public_table: public_table,
    private_table: private_table,
    public_token: public_token
  } do
    request_body = %{
      statement: """
        WITH public_one AS (select id from #{public_table}), private_one AS (select id from #{private_table})
        SELECT * FROM public_one JOIN private_one ON public_one.id = private_one.id
      """
    }

    actual = post("http://localhost:4000/api/v1/query", request_body, public_token)

    assert actual.status_code == 400
  end

  test "anonymous user can't query private and public datasets in one statement", %{
    public_table: public_table,
    private_table: private_table
  } do
    request_body = %{
      statement: """
        WITH public_one AS (select id from #{public_table}), private_one AS (select id from #{private_table})
        SELECT * FROM public_one JOIN private_one ON public_one.id = private_one.id
      """
    }

    actual = post("http://localhost:4000/api/v1/query", request_body)

    assert actual.status_code == 400
  end

  test "another user can query public datasets in one statement", %{
    public_table: public_table,
    public_token: public_token
  } do
    request_body = %{
      statement: """
        SELECT * FROM #{public_table} AS one JOIN #{public_table} AS two ON one.id = two.id
      """
    }

    actual = post("http://localhost:4000/api/v1/query", request_body, public_token)

    assert actual.body == "[{\"id\":1,\"name\":\"Fred\"},{\"id\":2,\"name\":\"Gred\"},{\"id\":3,\"name\":\"Hred\"}]"
  end

  test "anonymous user can query public datasets in one statement", %{public_table: public_table} do
    request_body = %{
      statement: """
        SELECT * FROM #{public_table} AS one JOIN #{public_table} AS two ON one.id = two.id
      """
    }

    actual = post("http://localhost:4000/api/v1/query", request_body)

    assert actual.body == "[{\"id\":1,\"name\":\"Fred\"},{\"id\":2,\"name\":\"Gred\"},{\"id\":3,\"name\":\"Hred\"}]"
  end

  # TOODO - timebox looking into magic comments more fully as they "could" be placed in the middle of a query
  # test "any user can't put single line comments in the middle of a statement", %{
  #   private_table: private_table,
  #   public_table: public_table,
  #   private_token: private_token
  # } do
  #   request_body = %{
  #     statement: """
  #     WITH public_one AS (select id from #{public_table}), private_one AS (select id from #{private_table})
  #     -- set session join_distribution_type = 'PARTITIONED'
  #     SELECT * FROM public_one JOIN private_one ON public_one.id = private_one.id
  #     """
  #   }

  #   actual = post("http://localhost:4000/api/v1/query", request_body, private_token)

  #   assert actual.body == "{\"message\":\"Bad Request\"}"
  #   assert actual.status_code == 400
  # end

  test "any user gets a reasonable response when submitting statements with bad syntax", %{
    private_table: private_table,
    private_token: private_token
  } do
    request_body = %{
      statement: """
        SALECT * FORM #{private_table}
      """
    }

    actual = post("http://localhost:4000/api/v1/query", request_body, private_token)

    assert actual.status_code == 400
    assert actual.body == "{\"message\":\"Bad Request\"}"
  end

  test "any user can't use multiple line magic comments (on more than one line)", %{
    private_table: private_table,
    private_token: private_token
  } do
    request_body = %{
      statement: """
        /*
        set session distributed_join = 'true'
        */
        SELECT * FROM #{private_table}
      """
    }

    actual = post("http://localhost:4000/api/v1/query", request_body, private_token)

    assert actual.status_code == 400
    assert actual.body == "{\"message\":\"Bad Request\"}"
  end

  test "any user can't use multiple line magic comments", %{
    private_table: private_table,
    private_token: private_token
  } do
    request_body = %{
      statement: """
        /* set session distributed_join = 'true' */
        SELECT * FROM #{private_table}
      """
    }

    actual = post("http://localhost:4000/api/v1/query", request_body, private_token)

    assert actual.status_code == 400
    assert actual.body == "{\"message\":\"Bad Request\"}"
  end

  test "any user can't use single line magic comments", %{
    private_table: private_table,
    private_token: private_token
  } do
    request_body = %{
      statement: """
        -- set session distributed_join = 'true'
        SELECT * FROM #{private_table}
      """
    }

    actual = post("http://localhost:4000/api/v1/query", request_body, private_token)

    assert actual.status_code == 400
    assert actual.body == "{\"message\":\"Bad Request\"}"
  end

  test "any user can't explain a statement", %{
    private_table: private_table,
    private_token: private_token
  } do
    request_body = %{
      statement: """
        EXPLAIN ANALYZE SELECT * FROM #{private_table}
      """
    }

    actual = post("http://localhost:4000/api/v1/query", request_body, private_token)

    assert actual.status_code == 400
    assert actual.body == "{\"message\":\"Bad Request\"}"
  end

  test "any user can't describe table", %{
    private_table: private_table,
    private_token: private_token
  } do
    request_body = %{
      statement: """
        DESCRIBE #{private_table}
      """
    }

    actual = post("http://localhost:4000/api/v1/query", request_body, private_token)

    assert actual.status_code == 400
    assert actual.body == "{\"message\":\"Bad Request\"}"
  end

  test "any user can't desc table", %{
    private_table: private_table,
    private_token: private_token
  } do
    request_body = %{
      statement: """
        DESC #{private_table}
      """
    }

    actual = post("http://localhost:4000/api/v1/query", request_body, private_token)

    assert actual.status_code == 400
    assert actual.body == "{\"message\":\"Bad Request\"}"
  end

  test "any user can't delete from a table", %{
    private_table: private_table,
    private_token: private_token
  } do
    request_body = %{
      statement: """
        DELETE FROM #{private_table}
      """
    }

    actual = post("http://localhost:4000/api/v1/query", request_body, private_token)

    assert actual.status_code == 400

    assert 3 ==
             ~s|select * from #{private_table}|
             |> Prestige.execute()
             |> Prestige.prefetch()
             |> Enum.count()
  end

  test "any user can't drop a table", %{
    private_table: private_table,
    private_token: private_token
  } do
    request_body = %{
      statement: """
        DROP TABLE #{private_table}
      """
    }

    actual = post("http://localhost:4000/api/v1/query", request_body, private_token)

    assert actual.status_code == 400
    assert actual.body == "{\"message\":\"Bad Request\"}"

    assert 3 ==
             ~s|select * from #{private_table}|
             |> Prestige.execute()
             |> Prestige.prefetch()
             |> Enum.count()
  end

  test "any user can't create a table", %{
    private_table: private_table,
    private_token: private_token
  } do
    request_body = %{
      statement: """
        CREATE TABLE my_own_table (id integer, name varchar) AS SELECT * FROM #{private_table}
      """
    }

    actual = post("http://localhost:4000/api/v1/query", request_body, private_token)

    assert actual.status_code == 400
    assert actual.body == "{\"message\":\"Bad Request\"}"

    assert_raise Prestige.Error, fn ->
      ~s|select * from my_own_table|
      |> Prestige.execute()
      |> Prestige.prefetch()
    end
  end

  test "any user can't perform multiple queries separated by newlines", %{
    public_table: public_table,
    private_table: private_table,
    private_token: private_token
  } do
    request_body = %{
      statement: """
        SELECT * FROM #{public_table}

        DROP TABLE #{private_table}
      """
    }

    actual = post("http://localhost:4000/api/v1/query", request_body, private_token)

    assert actual.status_code == 400
    assert actual.body == "{\"message\":\"Bad Request\"}"

    assert 3 ==
             ~s|select * from #{private_table}|
             |> Prestige.execute()
             |> Prestige.prefetch()
             |> Enum.count()
  end

  test "any user can't perform multiple queries separated by carriage return", %{
    public_table: public_table,
    private_table: private_table,
    private_token: private_token
  } do
    request_body = %{
      statement: "SELECT * FROM #{public_table}\rSELECT * FROM #{private_table}"
    }

    actual = post("http://localhost:4000/api/v1/query", request_body, private_token)

    assert actual.status_code == 400
    assert actual.body == "{\"message\":\"Bad Request\"}"
  end

  test "any user can't perform multiple queries separated by a semicolon", %{
    public_table: public_table,
    private_table: private_table,
    private_token: private_token
  } do
    request_body = %{
      statement: """
        SELECT * FROM #{public_table}; DROP TABLE #{private_table}
      """
    }

    actual = post("http://localhost:4000/api/v1/query", request_body, private_token)

    assert actual.status_code == 400
    assert actual.body == "{\"message\":\"Bad Request\"}"

    assert 3 ==
             ~s|select * from #{private_table}|
             |> Prestige.execute()
             |> Prestige.prefetch()
             |> Enum.count()
  end

  test "any user can't insert data", %{
    public_table: public_table,
    private_table: private_table,
    private_token: private_token
  } do
    request_body = %{
      statement: """
        INSERT INTO #{private_table} SELECT * FROM #{public_table}
      """
    }

    actual = post("http://localhost:4000/api/v1/query", request_body, private_token)

    assert actual.status_code == 400
    assert actual.body == "{\"message\":\"Bad Request\"}"

    assert 3 ==
             ~s|select * from #{private_table}|
             |> Prestige.execute()
             |> Prestige.prefetch()
             |> Enum.count()
  end

  defp post(url, body) do
    headers = %{
      "Accept" => "application/json",
      "Content-Type" => "application/json"
    }

    post(url, body, headers)
  end

  defp post(url, body, token) when is_binary(token) do
    headers = %{
      "Accept" => "application/json",
      "Authorization" => "Bearer #{token}",
      "Content-Type" => "application/json"
    }

    post(url, body, headers)
  end

  defp post(url, body, %{} = headers) do
    response = HTTPoison.post!(url, Jason.encode!(body), headers)
    Map.from_struct(response)
  end
end
