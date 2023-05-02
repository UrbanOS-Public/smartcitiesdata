defmodule E2ETest do
  use ExUnit.Case
  use Divo
  use Placebo

  @moduletag :e2e
  @moduletag capture_log: false
  @endpoint DiscoveryStreamsWeb.Endpoint

  alias SmartCity.TestDataGenerator, as: TDG
  import Phoenix.ChannelTest
  import SmartCity.TestHelper
  @brokers Application.get_env(:e2e, :elsa_brokers)
  @overrides %{
    technical: %{
      orgName: "end_to",
      dataName: "end",
      systemName: "end_to__end",
      schema: [
        %{name: "one", type: "boolean", ingestion_field_selector: "one"},
        %{name: "two", type: "string", ingestion_field_selector: "two"},
        %{name: "three", type: "integer", ingestion_field_selector: "three"},
        %{name: "parsed", type: "string", ingestion_field_selector: "parsed"}
      ],
      sourceType: "ingest",
      sourceUrl: "http://example.com",
      cadence: "once"
    }
  }

  @streaming_overrides %{
    technical: %{
      dataName: "strimmin",
      orgName: "usa",
      cadence: "*/10 * * * * *",
      sourceType: "stream",
      systemName: "usa__strimmin"
    }
  }

  setup_all do
    Mix.Tasks.Ecto.Create.run([])
    Mix.Tasks.Ecto.Migrate.run([])

    bypass = Bypass.open()
    shapefile = File.read!("test/support/shapefile.zip")

    Bypass.stub(bypass, "POST", "/path/to/the/auth.json", fn conn ->
      Plug.Conn.resp(conn, 200, %{token: "3uthsveiruybaov78yr784bhruef"} |> Jason.encode!())
    end)

    Bypass.stub(bypass, "GET", "/path/to/the/data.csv", fn conn ->
      Plug.Conn.resp(conn, 200, "true,foobar,10")
    end)

    Bypass.stub(bypass, "GET", "/path/to/the/geo_data.shapefile", fn conn ->
      Plug.Conn.resp(conn, 200, shapefile)
    end)

    dataset_struct =
      @overrides
      |> TDG.create_dataset()

    {_, dataset_struct} = pop_in(dataset_struct, [:id])

    {:ok, %{status_code: 201, body: dataset_body}} =
      HTTPoison.put("http://localhost:4000/api/v1/dataset", Jason.encode!(dataset_struct), [
        {"Content-Type", "application/json"}
      ])

    dataset = Jason.decode!([dataset_body])

    streaming_dataset_struct = SmartCity.Helpers.deep_merge(dataset_struct, @streaming_overrides)

    {:ok, %{status_code: 201, body: streaming_dataset_body}} =
      HTTPoison.put(
        "http://localhost:4000/api/v1/dataset",
        Jason.encode!(streaming_dataset_struct),
        [
          {"Content-Type", "application/json"}
        ]
      )

    streaming_dataset = Jason.decode!(streaming_dataset_body)

    eventually(
      fn ->
        {:ok, resp} = HTTPoison.get("http://localhost:4000/api/v1/datasets")
        assert length(Jason.decode!(resp.body)) == 2
      end,
      500,
      20
    )

    ingest_regex_transformation =
      TDG.create_transformation(%{
        name: "Ingest Transformation",
        type: "regex_extract",
        sequence: 1,
        parameters: %{
          :sourceField => "two",
          :targetField => "parsed",
          :regex => "^f(\\w{2})bar"
        }
      })

    streaming_regex_transformation =
      TDG.create_transformation(%{
        name: "Streaming Transformation",
        type: "regex_extract",
        sequence: 1,
        parameters: %{
          :sourceField => "two",
          :targetField => "parsed",
          :regex => "^f(\\w{2})bar"
        }
      })

    ingestion_struct =
      TDG.create_ingestion(%{
        id: nil,
        targetDataset: dataset["id"],
        cadence: "once",
        schema: [
          %{name: "one", type: "boolean", ingestion_field_selector: "oparsedne"},
          %{name: "two", type: "string", ingestion_field_selector: "oparsedne"},
          %{name: "three", type: "integer", ingestion_field_selector: "oparsedne"}
        ],
        sourceFormat: "text/csv",
        topLevelSelector: nil,
        extractSteps: [
          %{
            type: "http",
            context: %{
              url: "http://localhost:#{bypass.port()}/path/to/the/data.csv",
              action: "GET",
              queryParams: %{},
              headers: %{},
              protocol: nil,
              body: ""
            },
            assigns: %{}
          }
        ],
        transformations: [ingest_regex_transformation]
      })

    {:ok, %{status_code: 201, body: ingestion_body}} =
      HTTPoison.put("http://localhost:4000/api/v1/ingestion", Jason.encode!(ingestion_struct), [
        {"Content-Type", "application/json"}
      ])

    ingestion = Jason.decode!([ingestion_body])

    streaming_ingestion_struct =
      TDG.create_ingestion(%{
        targetDataset: streaming_dataset["id"],
        cadence: "*/10 * * * * *",
        schema: [
          %{name: "one", type: "boolean", ingestion_field_selector: "oparsedne"},
          %{name: "two", type: "string", ingestion_field_selector: "oparsedne"},
          %{name: "three", type: "integer", ingestion_field_selector: "oparsedne"}
        ],
        sourceFormat: "text/csv",
        topLevelSelector: nil,
        extractSteps: [
          %{
            type: "http",
            context: %{
              url: "http://localhost:#{bypass.port()}/path/to/the/data.csv",
              action: "GET",
              queryParams: %{},
              headers: %{},
              protocol: nil,
              body: ""
            },
            assigns: %{}
          }
        ],
        transformations: [streaming_regex_transformation]
      })

    {:ok, %{status_code: 201, body: streaming_ingestion_body}} =
      HTTPoison.put(
        "http://localhost:4000/api/v1/ingestion",
        Jason.encode!(%{streaming_ingestion_struct | id: nil}),
        [
          {"Content-Type", "application/json"}
        ]
      )

    streaming_ingestion = Jason.decode!(streaming_ingestion_body)

    eventually(
      fn ->
        resp = HTTPoison.get!("http://localhost:4000/api/v1/ingestions")
        assert length(Jason.decode!(resp.body)) == 2
      end,
      500,
      20
    )

    [
      dataset: dataset,
      ingestion: ingestion,
      streaming_dataset: streaming_dataset,
      streaming_ingestion: streaming_ingestion,
      bypass: bypass
    ]
  end

  describe "creating an organization" do
    test "via RESTful POST" do
      org =
        TDG.create_organization(%{orgName: "end_to", id: "451d5608-b4dc-406c-a7ce-8df24768a237"})

      resp =
        HTTPoison.post!("http://localhost:4000/api/v1/organization", Jason.encode!(org), [
          {"Content-Type", "application/json"}
        ])

      assert resp.status_code == 201
    end

    test "persists the organization for downstream use" do
      eventually(fn ->
        with resp <- HTTPoison.get!("http://localhost:4000/api/v1/organizations"),
             [org] <- Jason.decode!(resp.body) do
          assert org["id"] == "451d5608-b4dc-406c-a7ce-8df24768a237"
          assert org["orgName"] == "end_to"
        end
      end)
    end
  end

  describe "creating a dataset" do
    test "creates a PrestoDB table" do
      expected = [
        %{"Column" => "one", "Comment" => "", "Extra" => "", "Type" => "boolean"},
        %{"Column" => "two", "Comment" => "", "Extra" => "", "Type" => "varchar"},
        %{"Column" => "three", "Comment" => "", "Extra" => "", "Type" => "integer"},
        %{"Column" => "parsed", "Comment" => "", "Extra" => "", "Type" => "varchar"},
        %{
          "Column" => "_extraction_start_time",
          "Comment" => "",
          "Extra" => "",
          "Type" => "bigint"
        },
        %{
          "Column" => "_ingestion_id",
          "Comment" => "",
          "Extra" => "partition key",
          "Type" => "varchar"
        }
      ]

      eventually(
        fn ->
          table = query("describe hive.default.end_to__end", true)
          assert table == expected
        end,
        500,
        20
      )
    end

    test "stores a definition that can be retrieved", %{dataset: expected} do
      resp = HTTPoison.get!("http://localhost:4000/api/v1/datasets")
      assert expected in Jason.decode!(resp.body)
    end
  end

  describe "creating an ingestion" do
    test "stores a definition that can be retrieved", %{ingestion: expected} do
      eventually(
        fn ->
          resp = HTTPoison.get!("http://localhost:4000/api/v1/ingestions")
          assert expected in Jason.decode!(resp.body)
        end,
        500,
        20
      )
    end
  end

  # This series of tests should be extended as more apps are added to the umbrella.
  describe "ingested data" do
    test "is written by reaper", %{ingestion: ingestion} do
      topic = "#{Application.get_env(:reaper, :output_topic_prefix)}-#{ingestion["id"]}"

      eventually(fn ->
        {:ok, _, [message]} = Elsa.fetch(@brokers, topic)
        {:ok, data} = SmartCity.Data.new(message.value)

        assert %{"one" => "true", "two" => "foobar", "three" => "10"} ==
                 data.payload
      end)
    end

    test "is transformed by alchemist", %{dataset: dataset} do
      topic = "#{Application.get_env(:alchemist, :output_topic_prefix)}-#{dataset["id"]}"

      eventually(fn ->
        {:ok, _, [message]} = Elsa.fetch(@brokers, topic)
        {:ok, data} = SmartCity.Data.new(message.value)

        assert %{"one" => "true", "two" => "foobar", "three" => "10", "parsed" => "oo"} ==
                 data.payload
      end)
    end

    test "is standardized by valkyrie", %{dataset: dataset} do
      topic = "#{Application.get_env(:valkyrie, :output_topic_prefix)}-#{dataset["id"]}"

      eventually(fn ->
        {:ok, _, [message]} = Elsa.fetch(@brokers, topic)
        {:ok, data} = SmartCity.Data.new(message.value)
        IO.inspect(data, label: "data")
        assert %{"one" => true, "two" => "foobar", "three" => 10, "parsed" => "oo"} ==
                 data.payload
      end)
    end

    @tag timeout: :infinity, capture_log: true
    test "persists in PrestoDB", %{dataset: ds, ingestion: ingestion} do
      topic = "#{Application.get_env(:forklift, :input_topic_prefix)}-#{ds["id"]}"
      table = ds["technical"]["systemName"]

      eventually(fn ->
        assert Elsa.topic?(@brokers, topic)
      end)

      eventually(
        fn ->
          assert [%{"Table" => table}] == query("show tables like '#{table}'", true)

          assert [
                   %{
                     "one" => true,
                     "two" => "foobar",
                     "three" => 10,
                     "parsed" => "oo",
                     "_ingestion_id" => ingestion["id"],
                     "os_partition" => get_current_yyyy_mm(),
                     "_extraction_start_time" => get_current_yyyy_mm_dd()
                   }
                 ] ==
                   query(
                     "select one, two, three, parsed, _ingestion_id, os_partition, date_format(from_unixtime(_extraction_start_time), '%Y_%m_%d') as _extraction_start_time from #{
                       table
                     }",
                     true
                   )
        end,
        10_000
      )
    end

    test "forklift sends event to update last ingested time", %{dataset: _ds} do
      eventually(fn ->
        messages =
          Elsa.Fetch.search_keys(@brokers, "event-stream", "data:write:complete")
          |> Enum.to_list()

        assert 0 < length(messages)
      end)
    end
  end

  describe "streaming data" do
    test "is written by reaper", %{streaming_ingestion: ingestion} do
      topic = "#{Application.get_env(:reaper, :output_topic_prefix)}-#{ingestion["id"]}"

      eventually(fn ->
        {:ok, _, [message | _]} = Elsa.fetch(@brokers, topic)
        {:ok, data} = SmartCity.Data.new(message.value)

        assert %{"one" => "true", "two" => "foobar", "three" => "10"} ==
                 data.payload
      end)
    end

    test "is standardized by valkyrie", %{streaming_dataset: ds} do
      topic = "#{Application.get_env(:valkyrie, :output_topic_prefix)}-#{ds["id"]}"

      eventually(fn ->
        {:ok, _, [message | _]} = Elsa.fetch(@brokers, topic)
        {:ok, data} = SmartCity.Data.new(message.value)

        assert %{"one" => true, "two" => "foobar", "three" => 10, "parsed" => "oo"} ==
                 data.payload
      end)
    end

    @tag timeout: :infinity, capture_log: true
    test "persists in PrestoDB", %{streaming_dataset: ds, streaming_ingestion: ingestion} do
      topic = "#{Application.get_env(:forklift, :input_topic_prefix)}-#{ds["id"]}"
      table = ds["technical"]["systemName"]

      eventually(fn ->
        assert Elsa.topic?(@brokers, topic)
      end)

      eventually(
        fn ->
          assert [%{"Table" => table}] == query("show tables like '#{table}'", true)

          query_result =
            query(
              "select one, two, three, parsed, _ingestion_id, os_partition, date_format(from_unixtime(_extraction_start_time), '%Y_%m_%d') as _extraction_start_time from #{
                table
              }",
              true
            )

          table_contents =
            case query_result do
              {:error, _} ->
                []

              rows ->
                rows
            end

          assert %{
                   "one" => true,
                   "two" => "foobar",
                   "three" => 10,
                   "parsed" => "oo",
                   "_ingestion_id" => ingestion["id"],
                   "os_partition" => get_current_yyyy_mm(),
                   "_extraction_start_time" => get_current_yyyy_mm_dd()
                 } in table_contents
        end,
        5_000
      )
    end

    test "is available through socket connection", %{streaming_dataset: ds} do
      {:ok, _, _} =
        socket(DiscoveryStreamsWeb.UserSocket, "kenny", %{})
        |> subscribe_and_join(
          DiscoveryStreamsWeb.StreamingChannel,
          "streaming:#{ds["technical"]["systemName"]}",
          %{}
        )

      assert_push(
        "update",
        %{"one" => true, "three" => 10, "two" => "foobar", "parsed" => "oo"},
        30_000
      )
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
  end

  describe "extract steps" do
    test "from andi are executable by reaper", %{bypass: bypass, dataset: ds} do
      smrt_ingestion =
        TDG.create_ingestion(%{
          topLevelSelector: nil,
          targetDataset: ds["id"],
          extractSteps: [
            %{
              type: "date",
              context: %{
                destination: "blah",
                format: "{YYYY}"
              },
              assigns: %{}
            },
            %{
              type: "auth",
              context: %{
                destination: "dest",
                body: "",
                url: "http://localhost:#{bypass.port()}/path/to/the/auth.json",
                path: ["token"],
                cacheTtl: 15_000
              }
            },
            %{
              type: "http",
              context: %{
                url: "http://localhost:#{bypass.port()}/path/to/the/data.csv",
                body: "",
                action: "GET",
                headers: %{},
                queryParams: %{}
              },
              assigns: %{}
            }
          ]
        })

      {:ok, andi_ingestion} = Andi.InputSchemas.Ingestions.update(smrt_ingestion)

      ingestion_changeset =
        Andi.InputSchemas.InputConverter.andi_ingestion_to_full_ui_changeset_for_publish(
          andi_ingestion
        )

      ingestion_for_publish = ingestion_changeset |> Ecto.Changeset.apply_changes()

      converted_smrt_ingestion =
        Andi.InputSchemas.InputConverter.andi_ingestion_to_smrt_ingestion(ingestion_for_publish)

      converted_extract_steps = get_in(converted_smrt_ingestion, [:extractSteps])

      assert %{output_file: _} =
               Reaper.DataExtract.ExtractStep.execute_extract_steps(
                 converted_smrt_ingestion,
                 converted_extract_steps
               )
    end
  end

  def query(statment, toggle \\ false)

  def query(statement, false) do
    prestige_session()
    |> Prestige.execute(statement)
    |> case do
      {:ok, result} -> result
      {:error, error} -> {:error, error}
    end
  end

  def query(statement, true) do
    prestige_session()
    |> Prestige.execute(statement)
    |> case do
      {:ok, result} -> Prestige.Result.as_maps(result)
      {:error, error} -> {:error, error}
    end
  end

  defp get_current_yyyy_mm() do
    month = DateTime.utc_now().month |> Integer.to_string() |> String.pad_leading(2, "0")
    year = DateTime.utc_now().year |> Integer.to_string()
    "#{year}_#{month}"
  end

  defp get_current_yyyy_mm_dd() do
    day = DateTime.utc_now().day |> Integer.to_string() |> String.pad_leading(2, "0")
    month = DateTime.utc_now().month |> Integer.to_string() |> String.pad_leading(2, "0")
    year = DateTime.utc_now().year |> Integer.to_string()
    "#{year}_#{month}_#{day}"
  end

  defp prestige_session(),
    do: Application.get_env(:prestige, :session_opts) |> Prestige.new_session()
end
