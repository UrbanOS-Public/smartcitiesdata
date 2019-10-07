defmodule E2ETest do
  use ExUnit.Case
  use Divo
  use Placebo

  @moduletag :e2e

  alias SmartCity.TestDataGenerator, as: TDG
  import SmartCity.TestHelper
  import SmartCity.Event, only: [data_ingest_start: 0]

  @brokers Application.get_env(:e2e, :elsa_brokers)
  @overrides %{
    technical: %{
      orgName: "end_to",
      dataName: "end",
      systemName: "end_to__end",
      schema: [%{name: "one", type: "boolean"}, %{name: "two", type: "string"}],
      sourceType: "ingest"
    }
  }

  setup_all do
    user = Application.get_env(:andi, :ldap_user)
    pass = Application.get_env(:andi, :ldap_pass)
    Paddle.authenticate(user, pass)
    Paddle.add([ou: "integration"], objectClass: ["top", "organizationalunit"], ou: "integration")

    dataset = TDG.create_dataset(@overrides)

    [dataset: dataset]
  end

  describe "creating an organization" do
    test "via RESTful POST" do
      org = TDG.create_organization(%{orgName: "end_to", id: "org-id"})

      resp =
        HTTPoison.post!("http://localhost:4000/api/v1/organization", Jason.encode!(org), [
          {"Content-Type", "application/json"}
        ])

      assert resp.status_code == 201
    end

    test "persists the organization for downstream use" do
      base = Application.get_env(:paddle, Paddle)[:base]

      eventually(fn ->
        with resp <- HTTPoison.get!("http://localhost:4000/api/v1/organizations"),
             [org] <- Jason.decode!(resp.body) do
          assert org["dn"] == "cn=end_to,ou=integration,#{base}"
          assert org["id"] == "org-id"
          assert org["orgName"] == "end_to"
        end
      end)
    end
  end

  describe "creating a dataset" do
    test "via RESTful PUT", %{dataset: ds} do
      resp =
        HTTPoison.put!("http://localhost:4000/api/v1/dataset", Jason.encode!(ds), [
          {"Content-Type", "application/json"}
        ])

      assert resp.status_code == 201
    end

    test "creates a PrestoDB table" do
      expected = [
        %{"Column" => "one", "Comment" => "", "Extra" => "", "Type" => "boolean"},
        %{"Column" => "two", "Comment" => "", "Extra" => "", "Type" => "varchar"}
      ]

      eventually(fn ->
        table =
          try do
            query("describe hive.default.end_to__end", true)
          rescue
            _ -> []
          end

        assert table == expected
      end)
    end

    test "stores a definition that can be retrieved", %{dataset: expected} do
      resp = HTTPoison.get!("http://localhost:4000/api/v1/datasets")
      assert resp.body == Jason.encode!([expected])
    end
  end

  # This series of tests should be extended as more apps are added to the umbrella.
  describe "ingested data" do
    test "persists in PrestoDB", %{dataset: ds} do
      topic = "#{Application.get_env(:forklift, :input_topic_prefix)}-#{ds.id}"
      table = ds.technical.systemName
      data = TDG.create_data(dataset_id: ds.id, payload: %{"one" => true, "two" => "foobar"})

      Brook.Event.send(:forklift, data_ingest_start(), :author, ds)

      eventually(fn ->
        assert Elsa.topic?(@brokers, topic)
      end)

      Elsa.produce(@brokers, topic, Jason.encode!(data))

      eventually(
        fn ->
          assert [[true, "foobar"]] = query("select * from #{table}")
        end,
        10_000
      )
    end

    # This really should test flair itself, but we're not quite ready to hook it up.
    test "streams to flair for profiling" do
      topic = Application.get_env(:forklift, :output_topic)

      eventually(fn ->
        assert {:ok, _, [message]} = Elsa.fetch(@brokers, topic)
        assert Jason.decode!(message.value)["payload"] == %{"one" => true, "two" => "foobar"}
      end)
    end
  end

  def query(statement, toggle \\ false) do
    statement
    |> Prestige.execute(rows_as_maps: toggle)
    |> Prestige.prefetch()
  end
end
