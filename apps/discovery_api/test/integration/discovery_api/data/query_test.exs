defmodule DiscoveryApi.Data.QueryTest do
  import ExUnit.CaptureLog
  use ExUnit.Case
  use Divo
  alias SmartCity.Dataset

  @dataset_id "123-456-789"

  setup_all do
    Redix.command!(:redix, ["FLUSHALL"])
    system_name = "foo__bar_baz"

    dataset = %Dataset{
      id: @dataset_id,
      business: %{
        dataTitle: "my title",
        description: "description",
        modifiedDate: "2017-11-28T16:53:15.000Z",
        orgTitle: "Organization 1",
        contactName: "Bob Jones",
        contactEmail: "bjones@example.com",
        license: "http://openlicense.org",
        keywords: ["key", "words"]
      },
      technical: %{dataName: "", orgName: "", systemName: system_name, stream: "", sourceUrl: "", sourceFormat: ""}
    }

    Dataset.write(dataset)

    capture_log(fn ->
      ~s|create table if not exists "#{system_name}" (id integer, name varchar)|
      |> Prestige.execute()
      |> Prestige.prefetch()
    end)

    capture_log(fn ->
      ~s|insert into "#{system_name}" values (1,'Fred'),(2,'Gred'),(3,'Hred')|
      |> Prestige.execute()
      |> Prestige.prefetch()
    end)

    :ok

    on_exit(fn ->
      Redix.command!(:redix, ["FLUSHALL"])
    end)
  end

  @moduletag capture_log: true
  test "Queries limited data from presto" do
    actual =
      "http://localhost:4000/api/v1/dataset/#{@dataset_id}/query?limit=2&orderBy=name"
      |> HTTPoison.get!()
      |> Map.from_struct()
      |> Map.get(:body)

    assert "id,name\n1,Fred\n2,Gred\n" == actual
  end

  @moduletag capture_log: true
  test "Queries data from presto with multiple clauses" do
    actual =
      "http://localhost:4000/api/v1/dataset/#{@dataset_id}/query?limit=2&columns=name&orderBy=name"
      |> HTTPoison.get!()
      |> Map.from_struct()
      |> Map.get(:body)

    assert "name\nFred\nGred\n" == actual
  end

  @moduletag capture_log: true
  test "Queries data from presto with an aggregator" do
    actual =
      "http://localhost:4000/api/v1/dataset/#{@dataset_id}/query?columns=count(id),%20name&groupBy=name&orderBy=name"
      |> HTTPoison.get!()
      |> Map.from_struct()
      |> Map.get(:body)

    assert "count(id),name\n1,Fred\n1,Gred\n1,Hred\n" == actual
  end

  @moduletag capture_log: true
  test "queries data from presto with non-default format" do
    actual =
      "http://localhost:4000/api/v1/dataset/#{@dataset_id}/query?columns=count(id),%20name&groupBy=name&orderBy=name"
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
end
