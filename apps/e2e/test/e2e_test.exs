defmodule E2ETest do
  use ExUnit.Case
  use Divo
  use Placebo
  use Phoenix.ChannelTest

  @moduletag :e2e
  @moduletag capture_log: false
  @endpoint DiscoveryStreamsWeb.Endpoint

  alias SmartCity.TestDataGenerator, as: TDG
  import SmartCity.TestHelper

  @brokers Application.get_env(:e2e, :elsa_brokers)
  @overrides %{
    technical: %{
      orgName: "end_to",
      dataName: "end",
      systemName: "end_to__end",
      schema: [
        %{name: "one", type: "boolean"},
        %{name: "two", type: "string"},
        %{name: "three", type: "integer"}
      ],
      sourceType: "ingest",
      sourceFormat: "text/csv",
      cadence: "once"
    }
  }

  @streaming_overrides %{
    id: "strimmin",
    technical: %{
      dataName: "strimmin",
      orgName: "usa",
      cadence: "*/1 * * * * * *",
      sourceType: "stream",
      systemName: "usa__strimmin"
    }
  }

  @geo_overrides %{
    id: "geo_data",
    technical: %{
      orgName: "end_to",
      dataName: "land",
      systemName: "end_to__land",
      schema: [%{name: "feature", type: "json"}],
      sourceType: "ingest",
      sourceFormat: "zip",
      cadence: "once"
    }
  }

  setup_all do
    Temp.track!()
    Application.put_env(:odo, :working_dir, Temp.mkdir!())
    bypass = Bypass.open()
    user = Application.get_env(:andi, :ldap_user)
    pass = Application.get_env(:andi, :ldap_pass)
    shapefile = File.read!("test/support/shapefile.zip")
    Paddle.authenticate(user, pass)
    Paddle.add([ou: "integration"], objectClass: ["top", "organizationalunit"], ou: "integration")

    Bypass.stub(bypass, "GET", "/path/to/the/data.csv", fn conn ->
      Plug.Conn.resp(conn, 200, "true,foobar,10")
    end)

    Bypass.stub(bypass, "GET", "/path/to/the/geo_data.shapefile", fn conn ->
      Plug.Conn.resp(conn, 200, shapefile)
    end)

    dataset =
      @overrides
      |> put_in(
        [:technical, :sourceUrl],
        "http://localhost:#{bypass.port()}/path/to/the/data.csv"
      )
      |> TDG.create_dataset()

    streaming_dataset = SmartCity.Helpers.deep_merge(dataset, @streaming_overrides)

    geo_dataset =
      @geo_overrides
      |> put_in(
        [:technical, :sourceUrl],
        "http://localhost:#{bypass.port()}/path/to/the/geo_data.shapefile"
      )
      |> TDG.create_dataset()

    [dataset: dataset, streaming_dataset: streaming_dataset, geo_dataset: geo_dataset]
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
        %{"Column" => "two", "Comment" => "", "Extra" => "", "Type" => "varchar"},
        %{"Column" => "three", "Comment" => "", "Extra" => "", "Type" => "integer"}
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
    test "is written by reaper", %{dataset: ds} do
      topic = "#{Application.get_env(:reaper, :output_topic_prefix)}-#{ds.id}"

      eventually(fn ->
        {:ok, _, [message]} = Elsa.fetch(@brokers, topic)
        {:ok, data} = SmartCity.Data.new(message.value)

        assert %{"one" => "true", "two" => "foobar", "three" => "10"} == data.payload
      end)
    end

    test "is standardized by valkyrie", %{dataset: ds} do
      topic = "#{Application.get_env(:valkyrie, :output_topic_prefix)}-#{ds.id}"

      eventually(fn ->
        {:ok, _, [message]} = Elsa.fetch(@brokers, topic)
        {:ok, data} = SmartCity.Data.new(message.value)

        assert %{"one" => true, "two" => "foobar", "three" => 10} == data.payload
      end)
    end

    @tag timeout: :infinity
    test "persists in PrestoDB", %{dataset: ds} do
      topic = "#{Application.get_env(:forklift, :input_topic_prefix)}-#{ds.id}"
      table = ds.technical.systemName

      eventually(fn ->
        assert Elsa.topic?(@brokers, topic)
      end)

      eventually(
        fn ->
          assert [[table] | _] = query("show tables like '#{table}'")

          assert [[true, "foobar", 10]] = query("select * from #{table}")
        end,
        10_000
      )
    end

    test "forklift sends event to update last ingested time", %{dataset: _ds} do
      eventually(fn ->
        messages =
          Elsa.Fetch.search_keys(@brokers, "event-stream", "data:write:complete")
          |> Enum.to_list()

        assert 1 == length(messages)
      end)
    end

    test "is profiled by flair", %{dataset: ds} do
      table = Application.get_env(:flair, :table_name_timing)

      expected = ["SmartCityOS", "forklift", "valkyrie", "reaper"]

      eventually(fn ->
        actual = query("select distinct dataset_id, app from #{table}")

        Enum.each(expected, fn app -> assert [ds.id, app] in actual end)
      end)
    end

    test "events have been stored in estuary" do
      table = Application.get_env(:estuary, :table_name)

      eventually(fn ->
        [[actual]] = query("SELECT count(1) FROM #{table}")

        assert actual > 0
      end)
    end
  end

  describe "streaming data" do
    test "creating a dataset via RESTful PUT", %{streaming_dataset: ds} do
      resp =
        HTTPoison.put!("http://localhost:4000/api/v1/dataset", Jason.encode!(ds), [
          {"Content-Type", "application/json"}
        ])

      assert resp.status_code == 201
    end

    test "is written by reaper", %{streaming_dataset: ds} do
      topic = "#{Application.get_env(:reaper, :output_topic_prefix)}-#{ds.id}"

      eventually(fn ->
        {:ok, _, [message | _]} = Elsa.fetch(@brokers, topic)
        {:ok, data} = SmartCity.Data.new(message.value)

        assert %{"one" => "true", "two" => "foobar", "three" => "10"} == data.payload
      end)
    end

    test "is standardized by valkyrie", %{streaming_dataset: ds} do
      topic = "#{Application.get_env(:valkyrie, :output_topic_prefix)}-#{ds.id}"

      eventually(fn ->
        {:ok, _, [message | _]} = Elsa.fetch(@brokers, topic)
        {:ok, data} = SmartCity.Data.new(message.value)

        assert %{"one" => true, "two" => "foobar", "three" => 10} == data.payload
      end)
    end

    @tag timeout: :infinity
    test "persists in PrestoDB", %{streaming_dataset: ds} do
      topic = "#{Application.get_env(:forklift, :input_topic_prefix)}-#{ds.id}"
      table = ds.technical.systemName

      eventually(fn ->
        assert Elsa.topic?(@brokers, topic)
      end)

      eventually(
        fn ->
          assert [[table] | _] = query("show tables like '#{table}'")

          assert [[true, "foobar", 10] | _] = query("select * from #{table}")
        end,
        5_000
      )
    end

    test "is available through socket connection", %{streaming_dataset: ds} do
      eventually(fn ->
        assert "#{Application.get_env(:discovery_streams, :topic_prefix)}#{ds.id}" in DiscoveryStreams.TopicSubscriber.list_subscribed_topics()
      end)

      {:ok, _, _} =
        socket(DiscoveryStreamsWeb.UserSocket, "kenny", %{})
        |> subscribe_and_join(
          DiscoveryStreamsWeb.StreamingChannel,
          "streaming:#{ds.technical.systemName}",
          %{}
        )

      assert_push("update", %{"one" => true, "three" => 10, "two" => "foobar"}, 30_000)
    end

    test "forklift sends event to update last ingested time for streaming datasets", %{
      streaming_dataset: _ds
    } do
      eventually(fn ->
        messages =
          Elsa.Fetch.search_keys(@brokers, "event-stream", "data:write:complete")
          |> Enum.to_list()

        assert length(messages) > 0
      end)
    end

    test "is profiled by flair", %{streaming_dataset: ds} do
      table = Application.get_env(:flair, :table_name_timing)

      expected = ["SmartCityOS", "forklift", "valkyrie", "reaper"]

      eventually(fn ->
        actual = query("select distinct dataset_id, app from #{table}")

        Enum.each(expected, fn app -> assert [ds.id, app] in actual end)
      end)
    end
  end

  describe "geospatial data" do
    test "creating a dataset via RESTful PUT", %{geo_dataset: ds} do
      resp =
        HTTPoison.put!("http://localhost:4000/api/v1/dataset", Jason.encode!(ds), [
          {"Content-Type", "application/json"}
        ])

      assert resp.status_code == 201
    end

    @tag timeout: :infinity
    test "persists geojson in PrestoDB", %{geo_dataset: ds} do
      table = ds.technical.systemName

      eventually(
        fn ->
          assert [[table | _]] = query("show tables like '#{table}'")
          assert [[actual | _] | _] = query("select * from #{table}")

          result = Jason.decode!(actual)

          assert Map.keys(result) == ["bbox", "geometry", "properties", "type"]

          [coordinates] = result["geometry"]["coordinates"]

          assert 253 == Enum.count(coordinates)
        end,
        10_000
      )
    end
  end

  def query(statement, toggle \\ false) do
    statement
    |> Prestige.execute(rows_as_maps: toggle)
    |> Prestige.prefetch()
  end
end
