defmodule E2ETest do
  use ExUnit.Case
  use Divo
  use Placebo

  alias SmartCity.TestDataGenerator, as: TDG
  import SmartCity.TestHelper
  import SmartCity.Event, only: [data_ingest_start: 0]

  @brokers Application.get_env(:e2e, :elsa_brokers)
  @overrides %{
    technical: %{
      orgName: "orgWithId",
      dataName: "e2e",
      systemName: "orgWithId__e2e",
      schema: [%{name: "on", type: "boolean"}],
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
      org = TDG.create_organization(%{orgName: "orgWithId", id: "org-id"})

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
          assert org["dn"] == "cn=orgWithId,ou=integration,#{base}"
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
      expected = [%{"Column" => "on", "Comment" => "", "Extra" => "", "Type" => "boolean"}]

      eventually(fn ->
        table =
          try do
            "describe hive.default.orgWithId__e2e"
            |> Prestige.execute(rows_as_maps: true)
            |> Prestige.prefetch()
          rescue
            _ -> []
          end

        assert table == expected
      end)
    end
  end

  describe "ingesting data" do
    test "persists data in PrestoDB", %{dataset: ds} do
      topic = "#{Application.get_env(:forklift, :input_topic_prefix)}-#{ds.id}"
      table = ds.technical.systemName
      data = TDG.create_data(dataset_id: ds.id, payload: %{"on" => true})

      Brook.Event.send(:forklift, data_ingest_start(), :author, ds)

      eventually(fn ->
        assert Elsa.topic?(@brokers, topic)
      end)

      Elsa.produce(@brokers, topic, Jason.encode!(data))

      eventually(
        fn ->
          assert [[true]] = "select * from #{table}" |> Prestige.execute() |> Prestige.prefetch()
        end,
        10_000
      )
    end
  end
end
