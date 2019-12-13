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

    test "is profiled by flair", %{dataset: ds} do
      table = Application.get_env(:flair, :table_name_timing)

      expected = ["SmartCityOS", "forklift", "valkyrie", "reaper"]

      eventually(fn ->
        actual = query("select distinct dataset_id, app from #{table}")

        Enum.each(expected, fn app -> assert [ds.id, app] in actual end)
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
      resp = HTTPoison.put!("http://localhost:4000/api/v1/dataset", Jason.encode!(ds), [
        {"Content-Type", "application/json"}
          ])

      assert resp.status_code == 201
    end

      @expected "geometry\":{\"coordinates\":[[[489257.623999998,141086.54630000144],[489122.64400000125,140988.30629999936],[489095.22399999946,140739.3161999993],[489056.8439999968,140586.14620000124],[488969.7339999974,140433.58619999886],[488902.72389999777,140127.2360999994],[488749.84390000254,139992.97610000148],[488664.56390000135,139840.4160999991],[488654.7638999969,139676.89600000158],[488470.0838999972,139543.89600000158],[488453.2937999964,139529.5460000001],[488436.47389999777,139513.3660000004],[488420.28390000015,139498.39600000158],[488407.07379999757,139479.0859999992],[488399.27380000055,139454.77600000054],[488398.683799997,139424.21599999815],[488398.11389999837,139394.87590000033],[488391.49390000105,139368.71590000018],[488371.00379999727,139320.80600000173],[488271.78379999846,139090.38589999825],[488247.60379999876,139041.3258999996],[488244.89389999956,139026.17590000108],[488242.80380000174,139014.51590000093],[488244.49379999936,138975.34589999914],[488244.02380000055,138950.8958999999],[488233.6238999963,138918.69590000063],[488215.77380000055,138881.13589999825],[488199.35379999876,138853.935899999],[488185.84380000085,138807.08590000123]"
    @tag timeout: :infinity
    test "persists geojson in PrestoDB", %{geo_dataset: ds} do

      table = ds.technical.systemName

      eventually(
        fn ->
          # assert [[table] | _] = query("show tables like '#{table}'")
          assert [[table | _]] = query("show tables like '#{table}'")
          # [[actual]] = query("select * from #{table}")
          query("select * from #{table}") |> IO.inspect(label: "SELECT FROM TABLE")
          # assert String.starts_with?(expected) == actual
          assert @expected <> _rest = "GEOJSON!" #actual
        end,
        30_000
      )
    end
  end

  def query(statement, toggle \\ false) do
    statement
    |> Prestige.execute(rows_as_maps: toggle)
    |> Prestige.prefetch()
  end
end
