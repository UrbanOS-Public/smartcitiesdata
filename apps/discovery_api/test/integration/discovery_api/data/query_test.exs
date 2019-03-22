defmodule DiscoveryApi.Data.QueryTest do
  use ExUnit.Case
  use DiscoveryApiWeb.ConnCase

  use Divo
  alias DiscoveryApi.Test.Helper
  alias DiscoveryApi.Data.Dataset

  setup_all do
    dataset = Mockaffe.create_message(:registry, :basic)

    system_name =
      dataset
      |> Map.get(:technical)
      |> Map.get(:systemName)

    dataset |> Mockaffe.send_to_kafka("dataset-registry")

    "create table #{system_name} (id integer, name varchar)"
    |> Prestige.execute()
    |> Prestige.prefetch()

    ~s|insert into "#{system_name}" ("id","name") values (1,'Fred'),(2,'Gred'),(3,'Hred')|
    |> Prestige.execute()
    |> Prestige.prefetch()

    :ok
  end

  test "Queries limited data from presto" do
    actual =
      conn
      |> put_req_header("accept", "text/csv")
      |> get("/api/v1/dataset/basic/query", limit: "2", orderBy: "name")
      |> response(200)

    assert "id,name\n1,Fred\n2,Gred\n" == actual
  end

  test "Queries data from presto with multiple clauses" do
    actual =
      conn
      |> put_req_header("accept", "text/csv")
      |> get("/api/v1/dataset/basic/query", limit: "2", columns: "name", orderBy: "name")
      |> response(200)

    assert "name\nFred\nGred\n" == actual
  end

  test "Queries data from presto with an aggregator" do
    actual =
      conn
      |> put_req_header("accept", "text/csv")
      |> get("/api/v1/dataset/basic/query", columns: "count(id), name", groupBy: "name", orderBy: "name")
      |> response(200)

    assert "count(id),name\n1,Fred\n1,Gred\n1,Hred\n" == actual
  end
end
