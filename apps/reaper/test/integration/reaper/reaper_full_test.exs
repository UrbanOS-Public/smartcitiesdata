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

  import SmartCity.Event,
    only: [
      dataset_update: 0,
      dataset_disable: 0,
      dataset_delete: 0,
      data_extract_start: 0,
      file_ingest_start: 0,
      data_extract_end: 0,
      file_ingest_end: 0
    ]

  alias Reaper.Collections.Extractions

  getter(:elsa_brokers, generic: true)
  getter(:output_topic_prefix, generic: true)
  getter(:hosted_file_bucket, generic: true)

  @instance_name Reaper.instance_name()
  @redix Reaper.Application.redis_client()

  @pre_existing_dataset_id "00000-0000"
  @partial_load_dataset_id "11111-1112"

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

  describe "pre-existing dataset" do
    setup %{bypass: bypass} do
      pre_existing_dataset =
        TDG.create_dataset(%{
          id: @pre_existing_dataset_id,
          technical: %{
            cadence: "once",
            sourceUrl: "http://localhost:#{bypass.port}/#{@json_file_name}",
            sourceFormat: "json",
            schema: [
              %{name: "latitude"},
              %{name: "vehicle_id"},
              %{name: "update_time"},
              %{name: "longitude"}
            ]
          }
        })

      Brook.Event.send(@instance_name, dataset_update(), :reaper, pre_existing_dataset)
      :ok
    end

    test "configures and ingests a json-source that was added before reaper started" do
      expected =
        TestUtils.create_data(%{
          dataset_id: @pre_existing_dataset_id,
          payload: %{
            "latitude" => 39.9613,
            "vehicle_id" => 41_015,
            "update_time" => "2019-02-14T18:53:23.498889+00:00",
            "longitude" => -83.0074
          }
        })

      topic = "#{output_topic_prefix()}-#{@pre_existing_dataset_id}"

      eventually(fn ->
        results = TestUtils.get_data_messages_from_kafka(topic, elsa_brokers())
        last_one = List.last(results)

        assert expected == last_one
      end)
    end
  end

  describe "partial-existing dataset" do
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

      pre_existing_dataset =
        TDG.create_dataset(%{
          id: @partial_load_dataset_id,
          technical: %{
            cadence: "once",
            sourceUrl: "http://localhost:#{bypass.port}/partial.csv",
            sourceFormat: "csv",
            sourceType: "ingest",
            schema: [%{name: "name", type: "string"}]
          }
        })

      Brook.Event.send(@instance_name, dataset_update(), :reaper, pre_existing_dataset)
      :ok
    end

    @tag capture_log: true
    test "configures and ingests a csv datasource that was partially loaded before reaper restarted", %{bypass: _bypass} do
      topic = "#{output_topic_prefix()}-#{@partial_load_dataset_id}"

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

  describe "No pre-existing datasets" do
    test "configures and ingests a gtfs source", %{bypass: bypass} do
      dataset_id = "12345-6789"
      topic = "#{output_topic_prefix()}-#{dataset_id}"

      gtfs_dataset =
        TDG.create_dataset(%{
          id: dataset_id,
          technical: %{
            cadence: "once",
            sourceUrl: "http://localhost:#{bypass.port}/#{@gtfs_file_name}",
            sourceFormat: "gtfs"
          }
        })

      Brook.Event.send(@instance_name, dataset_update(), :reaper, gtfs_dataset)

      eventually(fn ->
        results = TestUtils.get_data_messages_from_kafka(topic, elsa_brokers())

        assert [%{payload: %{"id" => "1004"}} | _] = results
      end)
    end

    test "configures and ingests a json source", %{bypass: bypass} do
      dataset_id = "23456-7891"
      topic = "#{output_topic_prefix()}-#{dataset_id}"

      json_dataset =
        TDG.create_dataset(%{
          id: dataset_id,
          technical: %{
            cadence: "once",
            sourceUrl: "http://localhost:#{bypass.port}/#{@json_file_name}",
            sourceFormat: "json"
          }
        })

      Brook.Event.send(@instance_name, dataset_update(), :reaper, json_dataset)

      eventually(fn ->
        results = TestUtils.get_data_messages_from_kafka(topic, elsa_brokers())

        assert [%{payload: %{"vehicle_id" => 51_127}} | _] = results
      end)
    end

    test "configures and ingests a json source using topLevelSelector", %{bypass: bypass} do
      dataset_id = "topLevelSelectorId"
      topic = "#{output_topic_prefix()}-#{dataset_id}"

      json_dataset =
        TDG.create_dataset(%{
          id: dataset_id,
          technical: %{
            cadence: "once",
            sourceUrl: "http://localhost:#{bypass.port}/#{@json_file_name_subpath}",
            sourceFormat: "json",
            topLevelSelector: "$.sub.path"
          }
        })

      Brook.Event.send(@instance_name, dataset_update(), :reaper, json_dataset)

      eventually(fn ->
        results = TestUtils.get_data_messages_from_kafka(topic, elsa_brokers())

        assert [%{payload: %{"name" => "Fred"}} | [%{payload: %{"name" => "Bob"}} | _]] = results
      end)
    end

    test "configures and ingests a csv source", %{bypass: bypass} do
      dataset_id = "34567-8912"
      topic = "#{output_topic_prefix()}-#{dataset_id}"

      csv_dataset =
        TDG.create_dataset(%{
          id: dataset_id,
          technical: %{
            cadence: "once",
            sourceUrl: "http://localhost:#{bypass.port}/#{@csv_file_name}",
            sourceFormat: "csv",
            sourceType: "ingest",
            schema: [%{name: "id"}, %{name: "name"}, %{name: "pet"}]
          }
        })

      Brook.Event.send(@instance_name, dataset_update(), :reaper, csv_dataset)

      eventually(fn ->
        results = TestUtils.get_data_messages_from_kafka(topic, elsa_brokers())

        assert [%{payload: %{"name" => "Austin"}} | _] = results
        assert false == File.exists?(dataset_id)
      end)
    end

    test "configures and ingests a hosted dataset", %{bypass: bypass} do
      dataset_id = "1-22-333-4444"

      hosted_dataset =
        TDG.create_dataset(%{
          id: dataset_id,
          technical: %{
            cadence: "once",
            extractSteps: [
              %{
                type: "http",
                context: %{
                  url: "http://localhost:#{bypass.port}/#{@csv_file_name}",
                  queryParams: %{},
                  headers: %{},
                  protocol: nil,
                  action: "GET"
                },
                assigns: %{}
              }
            ],
            sourceFormat: "csv",
            sourceType: "host"
          }
        })
      orgName = String.split(hosted_dataset.technical.systemName, "__") |> Enum.at(0)

      Brook.Event.send(@instance_name, dataset_update(), :reaper, hosted_dataset)

      eventually(fn ->
        expected = File.read!("test/support/#{@csv_file_name}")

        case ExAws.S3.get_object(
               hosted_file_bucket(),
               "#{orgName}/#{hosted_dataset.technical.dataName}.csv"
             )
             |> ExAws.request() do
          {:ok, resp} ->
            assert Map.get(resp, :body) == expected

          _other ->
            Logger.info("File not uploaded yet")
            flunk("File should have been uploaded")
        end
      end)

      {:ok, _, messages} = Elsa.fetch(elsa_brokers(), "event-stream", partition: 0)
      assert Enum.any?(messages, fn %Elsa.Message{key: key} -> key == "file:ingest:end" end)
    end
  end

  describe "One time Ingest" do
    @tag timeout: 120_000
    test "cadence of once is only processed once", %{bypass: bypass} do
      dataset_id = "only-once"
      topic = "#{output_topic_prefix()}-#{dataset_id}"

      csv_dataset =
        TDG.create_dataset(%{
          id: dataset_id,
          technical: %{
            cadence: "once",
            sourceUrl: "http://localhost:#{bypass.port}/#{@csv_file_name}",
            sourceFormat: "csv",
            sourceType: "ingest",
            schema: [%{name: "id"}, %{name: "name"}, %{name: "pet"}]
          }
        })

      Brook.Event.send(@instance_name, dataset_update(), :reaper, csv_dataset)

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

      dataset_id = "only-once-extract-steps"
      topic = "#{output_topic_prefix()}-#{dataset_id}"

      csv_dataset =
        TDG.create_dataset(%{
          id: dataset_id,
          technical: %{
            cadence: "once",
            sourceUrl: "",
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
                  body: %{},
                  protocol: nil,
                  queryParams: %{},
                  headers: %{}
                },
                assigns: %{}
              }
            ],
            sourceFormat: "csv",
            sourceType: "ingest",
            schema: [%{name: "id"}, %{name: "name"}, %{name: "pet"}]
          }
        })

      Brook.Event.send(@instance_name, dataset_update(), :reaper, csv_dataset)

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
      dataset_id = "only-once-extract-steps-s3"
      topic = "#{output_topic_prefix()}-#{dataset_id}"

      "./test/support/random_stuff.csv"
      |> ExAws.S3.Upload.stream_file()
      |> ExAws.S3.upload(hosted_file_bucket(), "fake_data")
      |> ExAws.request!()

      csv_dataset =
        TDG.create_dataset(%{
          id: dataset_id,
          technical: %{
            cadence: "once",
            sourceUrl: "",
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
            sourceType: "ingest",
            schema: [%{name: "col1"}, %{name: "col2"}, %{name: "col3"}]
          }
        })

      Brook.Event.send(@instance_name, dataset_update(), :reaper, csv_dataset)

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
      dataset_id = "only-once-extract-steps-sftp"
      topic = "#{output_topic_prefix()}-#{dataset_id}"

      allow(Reaper.SecretRetriever.retrieve_dataset_credentials(any()),
        return: {:ok, %{"username" => @sftp.user, "password" => @sftp.password}}
      )

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

      csv_dataset =
        TDG.create_dataset(%{
          id: dataset_id,
          technical: %{
            cadence: "once",
            sourceUrl: "",
            extractSteps: [
              %{
                type: "sftp",
                context: %{
                  url: "sftp://{{host}}:{{port}}{{path}}"
                },
                assigns: %{
                  path: "/upload/random_stuff.csv",
                  host: "#{@host}",
                  port: "#{@sftp.port}"
                }
              }
            ],
            sourceFormat: "csv",
            sourceType: "ingest",
            schema: [%{name: "col1"}, %{name: "col2"}, %{name: "col3"}]
          }
        })

      Brook.Event.send(@instance_name, dataset_update(), :reaper, csv_dataset)

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
      dataset_id = "alzenband"
      topic = "#{output_topic_prefix()}-#{dataset_id}"

      json_dataset =
        TDG.create_dataset(%{
          id: dataset_id,
          technical: %{
            cadence: "once",
            sourceUrl: "http://localhost:#{bypass.port}/#{@nested_data_file_name}",
            sourceFormat: "json",
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
          }
        })

      Brook.Event.send(@instance_name, dataset_update(), :reaper, json_dataset)

      eventually(fn ->
        results = TestUtils.get_data_messages_from_kafka(topic, elsa_brokers())

        assert 3 == length(results)

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
      end)
    end
  end

  describe "xml dataset" do
    setup %{bypass: bypass} do
      pre_existing_dataset =
        TDG.create_dataset(%{
          id: @pre_existing_dataset_id,
          technical: %{
            cadence: "once",
            sourceUrl: "http://localhost:#{bypass.port}/#{@xml_file_name}",
            sourceFormat: "xml",
            schema: [
              %{name: "first_name", selector: "//person/firstName/text()"}
            ],
            topLevelSelector: "top/middle/rows/person"
          }
        })

      Brook.Event.send(@instance_name, dataset_update(), :reaper, pre_existing_dataset)
      :ok
    end

    test "is processed successfully" do
      expected =
        TestUtils.create_data(%{
          dataset_id: @pre_existing_dataset_id,
          payload: %{
            "first_name" => "John"
          }
        })

      topic = "#{output_topic_prefix()}-#{@pre_existing_dataset_id}"

      eventually(fn ->
        results = TestUtils.get_data_messages_from_kafka(topic, elsa_brokers())
        last_one = List.last(results)

        assert expected == last_one
      end)
    end
  end

  describe "#{dataset_disable()} then a #{dataset_update()}" do
    setup %{bypass: bypass} do
      dataset =
        TDG.create_dataset(%{
          technical: %{
            cadence: "*/5 * * * * * *",
            sourceUrl: "http://localhost:#{bypass.port}/#{@csv_file_name}",
            sourceFormat: "csv",
            sourceType: "stream",
            schema: [%{name: "id"}, %{name: "name"}, %{name: "pet"}]
          }
        })

      Brook.Event.send(@instance_name, dataset_update(), :reaper, dataset)

      eventually(fn ->
        assert %{state: :active} = Reaper.Scheduler.find_job(String.to_atom(dataset.id))
        assert Reaper.Collections.Extractions.is_enabled?(dataset.id) == true
      end)

      Brook.Event.send(@instance_name, dataset_disable(), :reaper, dataset)

      eventually(fn ->
        assert %{state: :inactive} = Reaper.Scheduler.find_job(String.to_atom(dataset.id))
        assert Reaper.Collections.Extractions.is_enabled?(dataset.id) == false
      end)

      [dataset: dataset]
    end

    test "sending an update for the disabled dataset does NOT re-enable it", %{dataset: dataset} do
      Brook.Event.send(@instance_name, dataset_update(), :reaper, dataset)

      Process.sleep(5_000)

      eventually(fn ->
        assert %{state: :inactive} = Reaper.Scheduler.find_job(String.to_atom(dataset.id))
        assert Reaper.Collections.Extractions.is_enabled?(dataset.id) == false
      end)
    end
  end

  test "dataset:update updates dataset definition in view state", %{bypass: bypass} do
    dataset =
      TDG.create_dataset(%{
        technical: %{
          cadence: "once",
          sourceUrl: "http://localhost:#{bypass.port}/#{@csv_file_name}",
          sourceFormat: "csv",
          sourceType: "ingest",
          schema: [%{name: "id"}, %{name: "name"}, %{name: "pet"}]
        }
      })

    Brook.Event.send(@instance_name, dataset_update(), :reaper, dataset)

    eventually(fn ->
      assert Reaper.Collections.Extractions.get_dataset!(dataset.id) == dataset
    end)
  end

  data_test "extracts and ingests update started_timestamp in view state", %{bypass: bypass} do
    dataset =
      TDG.create_dataset(%{
        technical: %{
          cadence: "once",
          sourceUrl: "http://localhost:#{bypass.port}/#{@csv_file_name}",
          sourceFormat: "csv",
          sourceType: source_type,
          schema: [%{name: "id"}, %{name: "name"}, %{name: "pet"}]
        }
      })

    Brook.Event.send(@instance_name, dataset_update(), :reaper, dataset)

    eventually(fn ->
      assert view_state_module.is_enabled?(dataset.id) == true
    end)

    Brook.Event.send(@instance_name, start_event_type, :reaper, dataset)

    eventually(fn ->
      assert nil != view_state_module.get_started_timestamp!(dataset.id)
    end)

    now = DateTime.utc_now()
    Brook.Event.send(@instance_name, start_event_type, :reaper, dataset)

    eventually(fn ->
      assert DateTime.compare(view_state_module.get_started_timestamp!(dataset.id), now) == :gt
    end)

    where([
      [:start_event_type, :source_type, :view_state_module],
      [data_extract_start(), "ingest", Reaper.Collections.Extractions],
      [file_ingest_start(), "host", Reaper.Collections.FileIngestions]
    ])
  end

  data_test "dataset:disable followed by a ingest or extract start", %{bypass: bypass} do
    dataset =
      TDG.create_dataset(%{
        technical: %{
          cadence: "once",
          sourceUrl: "http://localhost:#{bypass.port}/#{@csv_file_name}",
          sourceFormat: "csv",
          sourceType: source_type,
          schema: [%{name: "id"}, %{name: "name"}, %{name: "pet"}]
        }
      })

    Brook.Event.send(@instance_name, dataset_update(), :reaper, dataset)

    eventually(fn ->
      assert view_state_module.is_enabled?(dataset.id) == true
    end)

    Brook.Event.send(@instance_name, dataset_disable(), :reaper, dataset)

    eventually(fn ->
      assert view_state_module.is_enabled?(dataset.id) == false
    end)

    marked_dataset = TDG.create_dataset(Map.merge(dataset, %{business: %{dataTitle: "this-should-not-extract"}}))
    Brook.Event.send(@instance_name, start_event_type, :reaper, marked_dataset)

    Process.sleep(5_000)

    eventually(fn ->
      assert view_state_module.is_enabled?(dataset.id) == false
      assert not (marked_dataset in fetch_event_messages_of_type(end_event_type))
    end)

    where([
      [:start_event_type, :end_event_type, :source_type, :view_state_module],
      [data_extract_start(), data_extract_end(), "ingest", Reaper.Collections.Extractions],
      [file_ingest_start(), file_ingest_end(), "host", Reaper.Collections.FileIngestions]
    ])
  end

  data_test "dataset:disable followed by a ingest or extract end or file ingest end", %{bypass: bypass} do
    dataset =
      TDG.create_dataset(%{
        technical: %{
          cadence: "once",
          sourceUrl: "http://localhost:#{bypass.port}/#{@csv_file_name}",
          sourceFormat: "csv",
          sourceType: source_type,
          schema: [%{name: "id"}, %{name: "name"}, %{name: "pet"}]
        }
      })

    Brook.Event.send(@instance_name, dataset_update(), :reaper, dataset)

    eventually(fn ->
      assert view_state_module.is_enabled?(dataset.id) == true
    end)

    Brook.Event.send(@instance_name, dataset_delete(), :reaper, dataset)

    eventually(fn ->
      assert view_state_module.is_enabled?(dataset.id) == false
    end)

    Brook.Event.send(@instance_name, end_event_type, :reaper, dataset)

    Process.sleep(5_000)

    eventually(fn ->
      assert view_state_module.is_enabled?(dataset.id) == false
    end)

    where([
      [:end_event_type, :source_type, :view_state_module],
      [data_extract_end(), "ingest", Reaper.Collections.Extractions],
      [file_ingest_end(), "host", Reaper.Collections.FileIngestions]
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

  test "should delete the dataset and the view state when delete event is called" do
    dataset_id = Faker.UUID.v4()
    output_topic = "#{output_topic_prefix()}-#{dataset_id}"

    dataset =
      TDG.create_dataset(
        id: dataset_id,
        technical: %{allow_duplicates: false, cadence: "*/5 * * * * * *"}
      )

    Brook.Event.send(@instance_name, dataset_update(), :author, dataset)

    eventually(
      fn ->
        assert String.to_atom(dataset_id) == find_quantum_job(dataset_id)
        assert nil != Reaper.Horde.Registry.lookup(dataset_id)
        assert nil != Reaper.Cache.Registry.lookup(dataset_id)
        assert dataset == Extractions.get_dataset!(dataset.id)
        assert true == Elsa.Topic.exists?(elsa_brokers(), output_topic)
      end,
      2_000,
      10
    )

    Brook.Event.send(@instance_name, dataset_delete(), :author, dataset)

    eventually(
      fn ->
        assert nil == find_quantum_job(dataset_id)
        assert nil == Reaper.Horde.Registry.lookup(dataset_id)
        assert nil == Reaper.Cache.Registry.lookup(dataset_id)
        assert nil == Extractions.get_dataset!(dataset.id)
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

  defp find_quantum_job(dataset_id) do
    dataset_id
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
