defmodule Reaper.FullTest do
  use ExUnit.Case
  use Divo
  use Tesla
  use Placebo
  use Properties, otp_app: :reaper

  import Checkov

  require Logger
  alias SmartCity.TestDataGenerator, as: TDG
  import SmartCity.TestHelper

  import SmartCity.Data, only: [end_of_data: 0]

  import SmartCity.Event,
    only: [
      data_ingest_start: 0,
      data_extract_start: 0,
      data_extract_end: 0,
      ingestion_update: 0,
      ingestion_delete: 0,
      error_ingestion_update: 0
    ]

  alias Reaper.Collections.Extractions

  getter(:elsa_brokers, generic: true)
  getter(:output_topic_prefix, generic: true)
  getter(:hosted_file_bucket, generic: true)

  @instance_name Reaper.instance_name()
  @redix Reaper.Application.redis_client()

  @pre_existing_ingestion_id "00000-0000"
  @pre_existing_target_dataset "1701-1701"
  @pre_existing_target_dataset2 "1501-1501"
  @partial_load_dataset_id "11111-1113"
  @partial_load_dataset_id2 "222333-4445"
  @partial_load_ingestion_id "11111-1112"
  @extraction_start_time "2022-05-19T19:31:16.994987Z"

  @json_file_name "vehicle_locations.json"
  @nested_data_file_name "nested_data.json"
  @gtfs_file_name "gtfs-realtime.pb"
  @csv_file_name "random_stuff.csv"
  @xml_file_name "xml_sample.xml"
  @json_file_name_subpath "json_subpath.json"

  @host to_charlist(System.get_env("HOST"))
  @sftp %{host: @host, port: 2222, user: 'sftp_user', password: 'sftp_password'}

  setup_all do
    Temp.track!()
    Application.put_env(:reaper, :download_dir, Temp.mkdir!())

    # NOTE: using Bypass in setup all b/c we have no expectations.
    # If we add any, we'll need to move this, per https://github.com/pspdfkit-labs/bypass#example
    bypass = Bypass.open()

    bypass
    |> TestUtils.bypass_file(@gtfs_file_name)
    |> TestUtils.bypass_file(@json_file_name)
    |> TestUtils.bypass_file(@nested_data_file_name)
    |> TestUtils.bypass_file(@csv_file_name)
    |> TestUtils.bypass_file(@xml_file_name)
    |> TestUtils.bypass_file(@json_file_name_subpath)

    eventually(fn ->
      {type, result} = get("http://localhost:#{bypass.port}/#{@csv_file_name}")
      type == :ok and result.status == 200
    end)

    {:ok, bypass: bypass}
  end

  setup do
    Redix.command(@redix, ["FLUSHALL"])
    :ok
  end

  describe "pre-existing ingestion" do
    setup %{bypass: bypass} do
      allow DateTime.utc_now(), return: ~U[2022-05-19 19:31:16.994987Z]

      pre_existing_ingestion =
        TDG.create_ingestion(%{
          id: @pre_existing_ingestion_id,
          targetDatasets: [@pre_existing_target_dataset, @pre_existing_target_dataset2],
          cadence: "once",
          sourceFormat: "json",
          schema: [
            %{name: "latitude"},
            %{name: "vehicle_id"},
            %{name: "update_time"},
            %{name: "longitude"}
          ],
          topLevelSelector: nil,
          extractSteps: [
            %{
              assigns: %{},
              context: %{
                action: "GET",
                body: "",
                headers: [],
                protocol: nil,
                queryParams: [],
                url: "http://localhost:#{bypass.port}/#{@json_file_name}"
              },
              type: "http"
            }
          ]
        })

      Brook.Event.send(@instance_name, ingestion_update(), :reaper, pre_existing_ingestion)
      :ok
    end

    test "configures and ingests a json-source that was added before reaper started" do
      expected =
        TestUtils.create_data(%{
          dataset_ids: [@pre_existing_target_dataset, @pre_existing_target_dataset2],
          extraction_start_time: @extraction_start_time,
          ingestion_id: @pre_existing_ingestion_id,
          payload: %{
            "latitude" => 39.9613,
            "vehicle_id" => 41_015,
            "update_time" => "2019-02-14T18:53:23.498889+00:00",
            "longitude" => -83.0074
          }
        })

      topic = "#{output_topic_prefix()}-#{@pre_existing_ingestion_id}"

      eventually(fn ->
        results = TestUtils.get_data_messages_from_kafka(topic, elsa_brokers())
        last_one = List.last(results)

        assert expected == last_one
      end)
    end
  end

  describe "partial-existing ingestion" do
    setup %{bypass: bypass} do
      {:ok, pid} = Agent.start_link(fn -> %{has_raised: false, invocations: 0} end)

      allow Elsa.produce(any(), any(), any()),
        meck_options: [:passthrough],
        exec: fn topic, messages, options ->
          case Agent.get(pid, fn s -> {s.has_raised, s.invocations} end) do
            {false, count} when count >= 2 ->
              Agent.update(pid, fn _ -> %{has_raised: true, invocations: count + 1} end)
              raise "Bring this thing down!"

            {_, count} ->
              Agent.update(pid, fn s -> %{s | invocations: count + 1} end)
              :meck.passthrough([topic, messages, options])
          end
        end

      Bypass.stub(bypass, "GET", "/partial.csv", fn conn ->
        data =
          1..10_000
          |> Enum.map(fn _ -> random_string(10) end)
          |> Enum.join("\n")

        Plug.Conn.send_resp(conn, 200, data)
      end)

      pre_existing_ingestion =
        TDG.create_ingestion(%{
          id: @partial_load_ingestion_id,
          targetDatasets: [@partial_load_dataset_id, @partial_load_dataset_id2],
          cadence: "once",
          sourceFormat: "csv",
          schema: [%{name: "name", type: "string"}],
          topLevelSelector: nil,
          extractSteps: [
            %{
              assigns: %{},
              context: %{
                action: "GET",
                body: "",
                headers: [],
                protocol: nil,
                queryParams: [],
                url: "http://localhost:#{bypass.port}/partial.csv"
              },
              type: "http"
            }
          ]
        })

      Brook.Event.send(@instance_name, ingestion_update(), :reaper, pre_existing_ingestion)
      :ok
    end

    @tag capture_log: true
    test "configures and ingests a csv datasource that was partially loaded before reaper restarted", %{bypass: _bypass} do
      topic = "#{output_topic_prefix()}-#{@partial_load_ingestion_id}"

      eventually(
        fn ->
          result = :brod.resolve_offset(brod_endpoints(), topic, 0)
          assert {:ok, 10_000} == result
        end,
        2_000,
        50
      )
    end
  end

  describe "No pre-existing ingestions" do
    test "configures and ingests a gtfs source", %{bypass: bypass} do
      ingestion_id = "12345-6789"
      dataset_id = "0123-4567"
      dataset_id2 = "985348-47723"
      topic = "#{output_topic_prefix()}-#{ingestion_id}"

      gtfs_ingestion =
        TDG.create_ingestion(%{
          id: ingestion_id,
          targetDatasets: [dataset_id, dataset_id2],
          cadence: "once",
          sourceFormat: "gtfs",
          topLevelSelector: nil,
          schema: [],
          extractSteps: [
            %{
              assigns: %{},
              context: %{
                action: "GET",
                body: "",
                headers: [],
                protocol: nil,
                queryParams: [],
                url: "http://localhost:#{bypass.port}/#{@gtfs_file_name}"
              },
              type: "http"
            }
          ]
        })

      Brook.Event.send(@instance_name, ingestion_update(), :reaper, gtfs_ingestion)

      eventually(fn ->
        results = TestUtils.get_data_messages_from_kafka(topic, elsa_brokers())

        assert [%{payload: %{"id" => "1004"}} | _] = results
      end)
    end

    test "configures and ingests a json source", %{bypass: bypass} do
      ingestion_id = "23456-7891"
      topic = "#{output_topic_prefix()}-#{ingestion_id}"

      json_ingestion =
        TDG.create_ingestion(%{
          id: ingestion_id,
          topLevelSelector: nil,
          sourceFormat: "json",
          schema: [],
          extractSteps: [
            %{
              assigns: %{},
              context: %{
                action: "GET",
                body: "",
                headers: [],
                protocol: nil,
                queryParams: [],
                url: "http://localhost:#{bypass.port}/#{@json_file_name}"
              },
              type: "http"
            }
          ],
          cadence: "once"
        })

      Brook.Event.send(@instance_name, ingestion_update(), :reaper, json_ingestion)

      eventually(fn ->
        results = TestUtils.get_data_messages_from_kafka(topic, elsa_brokers())

        assert [%{payload: %{"vehicle_id" => 51_127}} | _] = results
      end)
    end

    test "configures and ingests a json source using topLevelSelector", %{bypass: bypass} do
      ingestion_id = "topLevelSelectorId"
      topic = "#{output_topic_prefix()}-#{ingestion_id}"

      json_ingestion =
        TDG.create_ingestion(%{
          id: ingestion_id,
          schema: [],
          sourceFormat: "json",
          extractSteps: [
            %{
              assigns: %{},
              context: %{
                action: "GET",
                body: "",
                headers: [],
                protocol: nil,
                queryParams: [],
                url: "http://localhost:#{bypass.port}/#{@json_file_name_subpath}"
              },
              type: "http"
            }
          ],
          cadence: "once",
          topLevelSelector: "$.sub.path"
        })

      Brook.Event.send(@instance_name, ingestion_update(), :reaper, json_ingestion)

      eventually(fn ->
        results = TestUtils.get_data_messages_from_kafka(topic, elsa_brokers())

        assert [%{payload: %{"name" => "Fred"}} | [%{payload: %{"name" => "Bob"}} | _]] = results
      end)
    end

    test "configures and ingests a csv source", %{bypass: bypass} do
      ingestion_id = "34567-8912"
      topic = "#{output_topic_prefix()}-#{ingestion_id}"

      csv_ingestion =
        TDG.create_ingestion(%{
          id: ingestion_id,
          extractSteps: [
            %{
              assigns: %{},
              context: %{
                action: "GET",
                body: "",
                headers: [],
                protocol: nil,
                queryParams: [],
                url: "http://localhost:#{bypass.port}/#{@csv_file_name}"
              },
              type: "http"
            }
          ],
          cadence: "once",
          sourceFormat: "csv",
          topLevelSelector: nil,
          schema: [%{name: "id"}, %{name: "name"}, %{name: "pet"}]
        })

      Brook.Event.send(@instance_name, ingestion_update(), :reaper, csv_ingestion)

      eventually(fn ->
        results = TestUtils.get_data_messages_from_kafka(topic, elsa_brokers())

        assert [%{payload: %{"name" => "Austin"}} | _] = results
        assert false == File.exists?(ingestion_id)
      end)
    end
  end

  describe "One time Ingest" do
    @tag timeout: 120_000
    test "cadence of once is only processed once", %{bypass: bypass} do
      ingestion_id = "only-once"
      topic = "#{output_topic_prefix()}-#{ingestion_id}"

      csv_ingestion =
        TDG.create_ingestion(%{
          id: ingestion_id,
          cadence: "once",
          extractSteps: [
            %{
              assigns: %{},
              context: %{
                action: "GET",
                body: "",
                headers: [],
                protocol: nil,
                queryParams: [],
                url: "http://localhost:#{bypass.port}/#{@csv_file_name}"
              },
              type: "http"
            }
          ],
          sourceFormat: "csv",
          schema: [%{name: "id"}, %{name: "name"}, %{name: "pet"}],
          topLevelSelector: nil
        })

      Brook.Event.send(@instance_name, ingestion_update(), :reaper, csv_ingestion)

      eventually(
        fn ->
          results = TestUtils.get_data_messages_from_kafka(topic, elsa_brokers())

          assert [%{payload: %{"name" => "Austin"}} | _] = results
        end,
        1_000,
        60
      )
    end

    @tag timeout: 120_000
    test "cadence of once is only processed once, extract steps", %{bypass: bypass} do
      Bypass.stub(bypass, "GET", "/2017-01", fn conn ->
        Plug.Conn.resp(
          conn,
          200,
          File.read!("test/support/#{@csv_file_name}")
        )
      end)

      allow Timex.now(), return: DateTime.from_naive!(~N[2018-01-01 13:26:08.003], "Etc/UTC")

      ingestion_id = "only-once-extract-steps"
      topic = "#{output_topic_prefix()}-#{ingestion_id}"

      csv_ingestion =
        TDG.create_ingestion(%{
          id: ingestion_id,
          cadence: "once",
          extractSteps: [
            %{
              type: "date",
              context: %{
                destination: "currentDate",
                deltaTimeUnit: "years",
                deltaTimeValue: -1,
                format: "{YYYY}-{0M}"
              },
              assigns: %{}
            },
            %{
              type: "http",
              context: %{
                url: "http://localhost:#{bypass.port}/{{currentDate}}",
                action: "GET",
                body: "",
                protocol: nil,
                queryParams: %{},
                headers: %{}
              },
              assigns: %{}
            }
          ],
          sourceFormat: "csv",
          schema: [%{name: "id"}, %{name: "name"}, %{name: "pet"}],
          topLevelSelector: nil
        })

      Brook.Event.send(@instance_name, ingestion_update(), :reaper, csv_ingestion)

      eventually(
        fn ->
          results = TestUtils.get_data_messages_from_kafka(topic, elsa_brokers())

          assert [%{payload: %{"name" => "Austin"}} | _] = results
        end,
        1_000,
        60
      )
    end

    @tag timeout: 120_000
    test "cadence of once is only processed once, extract steps s3", %{bypass: bypass} do
      ingestion_id = "only-once-extract-steps-s3"
      topic = "#{output_topic_prefix()}-#{ingestion_id}"

      "./test/support/random_stuff.csv"
      |> ExAws.S3.Upload.stream_file()
      |> ExAws.S3.upload(hosted_file_bucket(), "fake_data")
      |> ExAws.request!()

      csv_ingestion =
        TDG.create_ingestion(%{
          id: ingestion_id,
          cadence: "once",
          extractSteps: [
            %{
              type: "s3",
              context: %{
                url: "s3://#{hosted_file_bucket()}/fake_data",
                headers: %{}
              },
              assigns: %{}
            }
          ],
          sourceFormat: "csv",
          schema: [%{name: "col1"}, %{name: "col2"}, %{name: "col3"}],
          topLevelSelector: nil
        })

      Brook.Event.send(@instance_name, ingestion_update(), :reaper, csv_ingestion)

      eventually(
        fn ->
          results = TestUtils.get_data_messages_from_kafka(topic, elsa_brokers())

          assert [%{payload: %{"col1" => "1", "col2" => "Austin", "col3" => "Spot"}} | _] = results
        end,
        1_000,
        60
      )
    end

    @tag timeout: 120_000
    test "cadence of once is only processed once, extract steps sftp", %{bypass: bypass} do
      ingestion_id = "only-once-extract-steps-sftp"
      topic = "#{output_topic_prefix()}-#{ingestion_id}"

      {:ok, connection} =
        SftpEx.connect(
          host: @sftp.host,
          port: @sftp.port,
          user: @sftp.user,
          password: @sftp.password
        )

      File.stream!("./test/support/random_stuff.csv")
      |> Stream.into(SftpEx.stream!(connection, "/upload/random_stuff.csv"))
      |> Stream.run()

      csv_ingestion =
        TDG.create_ingestion(%{
          id: ingestion_id,
          cadence: "once",
          extractSteps: [
            %{
              type: "sftp",
              context: %{
                url: "sftp://#{@sftp.user}:#{@sftp.password}@{{host}}:{{port}}{{path}}"
              },
              assigns: %{
                path: "/upload/random_stuff.csv",
                host: "#{@host}",
                port: "#{@sftp.port}"
              }
            }
          ],
          sourceFormat: "csv",
          schema: [%{name: "col1"}, %{name: "col2"}, %{name: "col3"}],
          topLevelSelector: nil
        })

      Brook.Event.send(@instance_name, ingestion_update(), :reaper, csv_ingestion)

      eventually(
        fn ->
          results = TestUtils.get_data_messages_from_kafka(topic, elsa_brokers())
          assert [%{payload: %{"col1" => "1", "col2" => "Austin", "col3" => "Spot"}} | _] = results
        end,
        1_000,
        60
      )
    end
  end

  describe "Schema Stage" do
    test "fills nested nils", %{bypass: bypass} do
      ingestion_id = "alzenband"
      topic = "#{output_topic_prefix()}-#{ingestion_id}"

      json_ingestion =
        TDG.create_ingestion(%{
          id: ingestion_id,
          cadence: "once",
          sourceFormat: "json",
          topLevelSelector: nil,
          extractSteps: [
            %{
              assigns: %{},
              context: %{
                action: "GET",
                body: "",
                headers: [],
                protocol: nil,
                queryParams: [],
                url: "http://localhost:#{bypass.port}/#{@nested_data_file_name}"
              },
              type: "http"
            }
          ],
          schema: [
            %{name: "id", type: "string"},
            %{
              name: "grandParent",
              type: "map",
              subSchema: [
                %{
                  name: "parentMap",
                  type: "map",
                  subSchema: [%{name: "fieldA", type: "string"}, %{name: "fieldB", type: "string"}]
                }
              ]
            }
          ]
        })

      Brook.Event.send(@instance_name, ingestion_update(), :reaper, json_ingestion)

      eventually(fn ->
        results = TestUtils.get_data_messages_from_kafka(topic, elsa_brokers())

        assert 4 == length(results)

        assert Enum.at(results, 0).payload == %{
                 "id" => nil,
                 "grandParent" => %{"parentMap" => %{"fieldA" => nil, "fieldB" => nil}}
               }

        assert Enum.at(results, 1).payload == %{
                 "id" => "2",
                 "grandParent" => %{"parentMap" => %{"fieldA" => "Bob", "fieldB" => "Purple"}}
               }

        assert Enum.at(results, 2).payload == %{
                 "id" => "3",
                 "grandParent" => %{"parentMap" => %{"fieldA" => "Joe", "fieldB" => nil}}
               }

        assert Enum.at(results, 3).payload == %{
                 "id" => "3",
                 end_of_data()
               }
      end)
    end
  end

  describe "xml ingestion" do
    setup %{bypass: bypass} do
      allow DateTime.utc_now(), return: ~U[2022-05-19 19:31:16.994987Z]

      pre_existing_ingestion =
        TDG.create_ingestion(%{
          id: @pre_existing_ingestion_id,
          targetDatasets: [@pre_existing_target_dataset, @pre_existing_target_dataset2],
          cadence: "once",
          sourceFormat: "xml",
          schema: [
            %{name: "first_name", selector: "//person/firstName/text()"}
          ],
          topLevelSelector: "top/middle/rows/person",
          extractSteps: [
            %{
              assigns: %{},
              context: %{
                action: "GET",
                body: "",
                headers: [],
                protocol: nil,
                queryParams: [],
                url: "http://localhost:#{bypass.port}/#{@xml_file_name}"
              },
              type: "http"
            }
          ]
        })

      Brook.Event.send(@instance_name, ingestion_update(), :reaper, pre_existing_ingestion)
      :ok
    end

    test "is processed successfully" do
      expected =
        TestUtils.create_data(%{
          dataset_ids: [@pre_existing_target_dataset, @pre_existing_target_dataset2],
          extraction_start_time: @extraction_start_time,
          ingestion_id: @pre_existing_ingestion_id,
          payload: %{
            "first_name" => "John"
          }
        })

      topic = "#{output_topic_prefix()}-#{@pre_existing_ingestion_id}"

      eventually(fn ->
        results = TestUtils.get_data_messages_from_kafka(topic, elsa_brokers())
        last_one = List.last(results)

        assert expected == last_one
      end)
    end
  end

  test "ingestion:update updates ingestion definition in view state", %{bypass: bypass} do
    ingestion =
      TDG.create_ingestion(%{
        technical: %{
          cadence: "once",
          sourceFormat: "csv",
          schema: [%{name: "id"}, %{name: "name"}, %{name: "pet"}],
          extractSteps: [
            %{
              assigns: %{},
              context: %{
                action: "GET",
                body: "",
                headers: [],
                protocol: nil,
                queryParams: [],
                url: "http://localhost:#{bypass.port}/#{@csv_file_name}"
              },
              type: "http"
            }
          ],
          topLevelSelector: nil
        }
      })

    Brook.Event.send(@instance_name, ingestion_update(), :reaper, ingestion)

    eventually(fn ->
      assert Reaper.Collections.Extractions.get_ingestion!(ingestion.id) == ingestion
    end)
  end

  data_test "extracts and ingests update started_timestamp in view state", %{bypass: bypass} do
    ingestion =
      TDG.create_ingestion(%{
        cadence: "once",
        sourceFormat: "csv",
        schema: [%{name: "id"}, %{name: "name"}, %{name: "pet"}],
        extractSteps: [
          %{
            assigns: %{},
            context: %{
              action: "GET",
              body: "",
              headers: [],
              protocol: nil,
              queryParams: [],
              url: "http://localhost:#{bypass.port}/#{@csv_file_name}"
            },
            type: "http"
          }
        ],
        topLevelSelector: nil
      })

    Brook.Event.send(@instance_name, ingestion_update(), :reaper, ingestion)

    eventually(fn ->
      assert view_state_module.is_enabled?(ingestion.id) == true
    end)

    Brook.Event.send(@instance_name, start_event_type, :reaper, ingestion)

    eventually(fn ->
      assert nil != view_state_module.get_started_timestamp!(ingestion.id)
    end)

    now = DateTime.utc_now()
    Brook.Event.send(@instance_name, start_event_type, :reaper, ingestion)

    eventually(fn ->
      assert DateTime.compare(view_state_module.get_started_timestamp!(ingestion.id), now) == :gt
    end)

    where([
      [:start_event_type, :source_type, :view_state_module],
      [data_extract_start(), "ingest", Reaper.Collections.Extractions]
    ])
  end

  defp fetch_event_messages_of_type(type) do
    Elsa.Fetch.search_keys([localhost: 9092], "event-stream", type)
    |> Enum.to_list()
    |> Enum.map(fn %Elsa.Message{value: value} ->
      {:ok, data} = Jason.decode!(value)["data"] |> Brook.Deserializer.deserialize()
      data
    end)
  end

  test "should delete the ingestion and the view state when delete event is called" do
    ingestion_id = Faker.UUID.v4()
    output_topic = "#{output_topic_prefix()}-#{ingestion_id}"

    ingestion =
      TDG.create_ingestion(%{
        id: ingestion_id,
        allow_duplicates: false,
        cadence: "*/5 * * * * * *",
        targetDatasets: ["ds1"]
      })

    Brook.Event.send(@instance_name, ingestion_update(), :author, ingestion)

    eventually(
      fn ->
        assert String.to_atom(ingestion_id) == find_quantum_job(ingestion_id)
        assert nil != Reaper.Horde.Registry.lookup(ingestion_id)
        assert nil != Reaper.Cache.Registry.lookup(ingestion_id)
        assert ingestion == Extractions.get_ingestion!(ingestion.id)
        assert true == Elsa.Topic.exists?(elsa_brokers(), output_topic)
      end,
      2_000,
      10
    )

    Brook.Event.send(@instance_name, ingestion_delete(), :author, ingestion)

    eventually(
      fn ->
        assert nil == find_quantum_job(ingestion_id)
        assert nil == Reaper.Horde.Registry.lookup(ingestion_id)
        assert nil == Reaper.Cache.Registry.lookup(ingestion_id)
        assert nil == Extractions.get_ingestion!(ingestion.id)
        assert false == Elsa.Topic.exists?(elsa_brokers(), output_topic)
      end,
      2_000,
      10
    )
  end

  defp random_string(length) do
    :crypto.strong_rand_bytes(length)
    |> Base.url_encode64()
    |> binary_part(0, length)
  end

  defp find_quantum_job(ingestion_id) do
    ingestion_id
    |> String.to_atom()
    |> Reaper.Scheduler.find_job()
    |> quantum_job_name()
  end

  defp quantum_job_name(job) do
    case job do
      nil -> nil
      job -> job.name
    end
  end

  defp brod_endpoints() do
    elsa_brokers()
    |> Enum.map(fn {host, port} -> {to_charlist(host), port} end)
  end
end
