defmodule Reaper.DataExtract.ProcessorTest do
  use ExUnit.Case
  use Placebo
  import ExUnit.CaptureLog
  import Mox

  import SmartCity.Data, only: [end_of_data: 0]

  import SmartCity.Event,
    only: [
      event_log_published: 0
    ]

  alias Reaper.{Cache, Persistence}
  alias Reaper.DataExtract.Processor
  alias Reaper.Cache.MsgCountCache
  alias SmartCity.TestDataGenerator, as: TDG

  @ingestion_id "12345-6789"

  @csv """
  one,two,three
  four,five,six
  """

  @download_dir System.get_env("TMPDIR") || "/tmp/"
  use TempEnv, reaper: [download_dir: @download_dir]

  setup do
    {:ok, horde_registry} = Horde.Registry.start_link(keys: :unique, name: Reaper.Cache.Registry)
    {:ok, horde_sup} = Horde.DynamicSupervisor.start_link(strategy: :one_for_one, name: Reaper.Horde.Supervisor)

    on_exit(fn ->
      kill(horde_sup)
      kill(horde_registry)
    end)

    bypass = Bypass.open()

    sourceUrl = "http://localhost:#{bypass.port}/api/csv"

    ingestion =
      TDG.create_ingestion(%{
        id: @ingestion_id,
        sourceFormat: "csv",
        cadence: 100,
        schema: [
          %{name: "a", type: "string"},
          %{name: "b", type: "string"},
          %{name: "c", type: "string"}
        ],
        extractSteps: [
          %{
            assigns: %{},
            context: %{
              action: "GET",
              body: "",
              headers: [],
              protocol: nil,
              queryParams: [],
              url: sourceUrl
            },
            sequence: 13033,
            type: "http"
          }
        ],
        allow_duplicates: false
      })

    unix_time = 1_672_552_800

    allow DateTime.to_unix(any()), return: unix_time
    allow Elsa.create_topic(any(), any()), return: :ok
    allow Elsa.Supervisor.start_link(any()), return: {:ok, :pid}
    allow Elsa.topic?(any(), any()), return: true
    allow Elsa.Producer.ready?(any()), return: :does_not_matter
    allow Brook.Event.send(any(), any(), any(), any()), return: :ok

    Cachex.start(MsgCountCache.cache_name())
    Cachex.clear(MsgCountCache.cache_name())

    extract_time = DateTime.utc_now()
    cache_name = ingestion.id <> "_" <> to_string(DateTime.to_unix(extract_time))
    Horde.DynamicSupervisor.start_child(Reaper.Horde.Supervisor, {Reaper.Cache, name: cache_name})

    [bypass: bypass, ingestion: ingestion, sourceUrl: sourceUrl, extract_time: extract_time]
  end

  describe "process/2 happy path" do
    setup %{bypass: bypass} do
      allow Elsa.produce(any(), any(), any(), any()), return: :ok
      allow Persistence.remove_last_processed_index(@ingestion_id), return: :ok

      Bypass.expect(bypass, "GET", "/api/csv", fn conn ->
        Plug.Conn.resp(conn, 200, @csv)
      end)

      :ok
    end

    test "parses csv into data messages and sends to kafka", %{ingestion: ingestion, extract_time: extract_time} do
      allow Persistence.get_last_processed_index(@ingestion_id), return: -1
      allow Persistence.record_last_processed_index(@ingestion_id, any()), return: "OK"

      Processor.process(ingestion, extract_time)

      messages = capture(1, Elsa.produce(any(), any(), any(), any()), 3)

      expected = [
        %{"a" => "one", "b" => "two", "c" => "three"},
        %{"a" => "four", "b" => "five", "c" => "six"},
        end_of_data()
      ]

      assert expected == get_payloads(messages)

      assert_called Persistence.record_last_processed_index(any(), any()), once()
      assert_called Persistence.remove_last_processed_index(@ingestion_id), once()
    end

    test "returns the count of messages processed from MsgCountCache", %{ingestion: ingestion} do
      allow Persistence.get_last_processed_index(@ingestion_id), return: -1
      allow Persistence.record_last_processed_index(@ingestion_id, any()), return: "OK"

      message_count = Processor.process(ingestion, DateTime.utc_now())

      expected = [
        %{"a" => "one", "b" => "two", "c" => "three"},
        %{"a" => "four", "b" => "five", "c" => "six"}
      ]

      assert message_count == length(expected)
    end

    test "eliminates duplicates before sending to kafka", %{ingestion: ingestion} do
      allow Persistence.get_last_processed_index(@ingestion_id), return: -1
      allow Persistence.record_last_processed_index(@ingestion_id, any()), return: "OK"

      extract_time = DateTime.utc_now()
      cache_name = ingestion.id <> "_" <> to_string(DateTime.to_unix(extract_time))
      Horde.DynamicSupervisor.start_child(Reaper.Horde.Supervisor, {Reaper.Cache, name: cache_name})
      Cache.cache(cache_name, %{"a" => "one", "b" => "two", "c" => "three"})

      Processor.process(ingestion, extract_time)

      messages = capture(1, Elsa.produce(any(), any(), any(), any()), 3)
      assert [%{"a" => "four", "b" => "five", "c" => "six"}, end_of_data()] == get_payloads(messages)
      assert_called Elsa.produce(any(), any(), any(), any()), once()

      assert_called Persistence.record_last_processed_index(any(), any()), once()
      assert_called Persistence.remove_last_processed_index(@ingestion_id), once()
    end
  end

  test "provisions and uses a source url", %{bypass: bypass, sourceUrl: sourceUrl} do
    allow Persistence.get_last_processed_index(@ingestion_id), return: -1
    allow Persistence.record_last_processed_index(@ingestion_id, any()), return: "OK"
    allow Elsa.produce(any(), any(), any(), any()), return: :ok
    allow Persistence.remove_last_processed_index(@ingestion_id), return: :ok

    Providers.Echo
    |> expect(:provide, 1, fn _, %{value: value} -> value end)

    Bypass.expect(bypass, "GET", "/api/prov_csv", fn conn ->
      Plug.Conn.resp(conn, 200, @csv)
    end)

    ingestion =
      TDG.create_ingestion(%{
        id: @ingestion_id,
        sourceFormat: "csv",
        cadence: 100,
        schema: [
          %{name: "a", type: "string"},
          %{name: "b", type: "string"},
          %{name: "c", type: "string"}
        ],
        allow_duplicates: false,
        extractSteps: [
          %{
            assigns: %{},
            context: %{
              action: "GET",
              body: "",
              headers: [],
              protocol: nil,
              queryParams: [],
              url: "http://localhost:#{bypass.port}/api/prov_csv"
            },
            type: "http"
          }
        ]
      })

    Processor.process(ingestion, DateTime.utc_now())
  end

  describe "process/2 happy path with extract steps" do
    setup %{bypass: bypass} do
      allow Elsa.produce(any(), any(), any(), any()), return: :ok
      allow Persistence.remove_last_processed_index(@ingestion_id), return: :ok
      allow Timex.now(), return: DateTime.from_naive!(~N[2020-08-31 13:26:08.003], "Etc/UTC")

      Bypass.stub(bypass, "GET", "/api/csv", fn conn ->
        Plug.Conn.resp(conn, 200, @csv)
      end)

      Bypass.stub(bypass, "GET", "/api/csv/2020-08", fn conn ->
        Plug.Conn.resp(conn, 200, @csv)
      end)

      :ok
    end

    test "Single extract step for http get", %{ingestion: ingestion, sourceUrl: sourceUrl} do
      allow Persistence.get_last_processed_index(@ingestion_id), return: -1
      allow Persistence.record_last_processed_index(@ingestion_id, any()), return: "OK"

      extract_step = %{
        type: "http",
        context: %{
          action: "GET",
          protocol: nil,
          body: "",
          url: sourceUrl,
          queryParams: %{},
          headers: %{}
        },
        assigns: %{}
      }

      put_in(ingestion, [:extractSteps], [extract_step])
      |> Processor.process(DateTime.utc_now())

      messages = capture(1, Elsa.produce(any(), any(), any(), any()), 3)

      expected = [
        %{"a" => "one", "b" => "two", "c" => "three"},
        %{"a" => "four", "b" => "five", "c" => "six"},
        end_of_data()
      ]

      assert expected == get_payloads(messages)

      assert_called Persistence.record_last_processed_index(any(), any()), once()
      assert_called Persistence.remove_last_processed_index(@ingestion_id), once()
    end

    test "Set two variables then single extract step for http get", %{ingestion: ingestion, sourceUrl: sourceUrl} do
      allow Persistence.get_last_processed_index(@ingestion_id), return: -1
      allow Persistence.record_last_processed_index(@ingestion_id, any()), return: "OK"

      extract_steps = [
        %{
          type: "date",
          context: %{
            destination: "currentMonth",
            deltaTimeUnit: nil,
            deltaTimeValue: nil,
            format: "{0M}"
          },
          assigns: %{}
        },
        %{
          type: "date",
          context: %{
            destination: "currentYear",
            deltaTimeUnit: nil,
            deltaTimeValue: nil,
            format: "{YYYY}"
          },
          assigns: %{}
        },
        %{
          type: "http",
          context: %{
            action: "GET",
            protocol: nil,
            body: "",
            url: "#{sourceUrl}/{{currentYear}}-{{currentMonth}}",
            queryParams: %{},
            headers: %{}
          },
          assigns: %{}
        }
      ]

      put_in(ingestion, [:extractSteps], extract_steps)
      |> Processor.process(DateTime.utc_now())

      messages = capture(1, Elsa.produce(any(), any(), any(), any()), 3)

      expected = [
        %{"a" => "one", "b" => "two", "c" => "three"},
        %{"a" => "four", "b" => "five", "c" => "six"},
        end_of_data()
      ]

      assert expected == get_payloads(messages)

      assert_called Persistence.record_last_processed_index(any(), any()), once()
      assert_called Persistence.remove_last_processed_index(@ingestion_id), once()
    end
  end

  describe "process/2" do
    setup %{bypass: bypass} do
      Bypass.expect(bypass, "GET", "/api/csv", fn conn ->
        Plug.Conn.resp(conn, 200, @csv)
      end)

      :ok
    end

    @tag capture_log: true
    test "process/2 should remove file for ingestion regardless of error being raised", %{ingestion: ingestion} do
      allow Persistence.get_last_processed_index(any()), return: -1

      allow Reaper.Cache.mark_duplicates(any(), any()),
        exec: fn _, _ -> raise "some error" end,
        meck_options: [:passthrough]

      assert_raise RuntimeError, fn ->
        Processor.process(ingestion, DateTime.utc_now())
      end

      assert false == File.exists?(@download_dir <> ingestion.id)
    end

    test "process/2 should catch log all exceptions and reraise", %{ingestion: ingestion} do
      allow Persistence.get_last_processed_index(any()), return: -1

      allow Elsa.produce(any(), any(), any(), any()), exec: fn _, _, _, _ -> raise "some error" end

      log =
        capture_log(fn ->
          assert_raise RuntimeError, fn ->
            Processor.process(ingestion, DateTime.utc_now())
          end
        end)

      assert log =~ inspect(ingestion)
      assert log =~ "some error"
    end

    test "process/2 should execute providers prior to processing", %{bypass: bypass, sourceUrl: sourceUrl} do
      allow Elsa.produce(any(), any(), any(), any()), return: :ok
      allow Persistence.remove_last_processed_index(@ingestion_id), return: :ok
      allow Persistence.get_last_processed_index(@ingestion_id), return: -1
      allow Persistence.record_last_processed_index(@ingestion_id, any()), return: "OK"

      Providers.Echo
      |> expect(:provide, 2, fn _, %{value: value} -> value end)

      provisioned_ingestion =
        TDG.create_ingestion(%{
          id: @ingestion_id,
          sourceFormat: "csv",
          cadence: 100,
          schema: [
            %{name: "a", type: "string"},
            %{name: "b", type: "string"},
            %{name: "c", type: "string"},
            %{
              name: "p",
              type: "string",
              default: %{
                provider: "Echo",
                opts: %{value: "six of six"},
                version: "1"
              }
            }
          ],
          extractSteps: [
            %{
              assigns: %{},
              context: %{
                action: "GET",
                body: "",
                headers: [],
                protocol: nil,
                queryParams: [],
                url: "http://localhost:#{bypass.port}/api/csv"
              },
              sequence: 13033,
              type: "http"
            }
          ],
          allow_duplicates: false
        })

      Processor.process(provisioned_ingestion, DateTime.utc_now())

      messages = capture(1, Elsa.produce(any(), any(), any(), any()), 3)

      expected = [
        %{"a" => "one", "b" => "two", "c" => "three", "p" => "six of six"},
        %{"a" => "four", "b" => "five", "c" => "six", "p" => "six of six"},
        end_of_data()
      ]

      assert expected == get_payloads(messages)
    end

    test "process/2 should send an EventLog for each dataset before the processor processes the ingestion",
         %{bypass: bypass, sourceUrl: sourceUrl, extract_time: extract_time} do
      first_dataset_id = Faker.UUID.v4()
      second_dataset_id = Faker.UUID.v4()

      allow Elsa.produce(any(), any(), any(), any()), return: :ok
      allow Persistence.remove_last_processed_index(@ingestion_id), return: :ok
      allow Persistence.get_last_processed_index(@ingestion_id), return: -1
      allow Persistence.record_last_processed_index(@ingestion_id, any()), return: "OK"
      allow DateTime.to_string(any()), return: "2023-08-03 16:31:47.899763Z"

      provisioned_ingestion =
        TDG.create_ingestion(%{
          id: @ingestion_id,
          sourceFormat: "csv",
          targetDatasets: [first_dataset_id, second_dataset_id],
          cadence: 100,
          schema: [
            %{name: "a", type: "string"}
          ],
          extractSteps: [
            %{
              assigns: %{},
              context: %{
                action: "GET",
                body: "",
                headers: [],
                protocol: nil,
                queryParams: [],
                url: "http://localhost:#{bypass.port}/api/csv"
              },
              sequence: 13033,
              type: "http"
            }
          ],
          allow_duplicates: false
        })

      Processor.process(provisioned_ingestion, extract_time)

      first_expected_event_log = %SmartCity.EventLog{
        title: "Ingestion Started",
        timestamp: DateTime.utc_now() |> DateTime.to_string(),
        source: "Reaper",
        description: "Ingestion has started",
        ingestion_id: @ingestion_id,
        dataset_id: first_dataset_id
      }

      second_expected_event_log = %SmartCity.EventLog{
        title: "Ingestion Started",
        timestamp: DateTime.utc_now() |> DateTime.to_string(),
        source: "Reaper",
        description: "Ingestion has started",
        ingestion_id: @ingestion_id,
        dataset_id: second_dataset_id
      }

      first_event_log = capture(1, Brook.Event.send(any(), event_log_published(), :reaper, any()), 4)
      second_event_log = capture(2, Brook.Event.send(any(), event_log_published(), :reaper, any()), 4)

      assert first_event_log == first_expected_event_log
      assert second_event_log == second_expected_event_log
    end

    test "process/2 should send an EventLog for each dataset once data has successfully been written to the data pipeline",
         %{bypass: bypass, sourceUrl: sourceUrl} do
      first_dataset_id = Faker.UUID.v4()
      second_dataset_id = Faker.UUID.v4()

      allow Elsa.produce(any(), any(), any(), any()), return: :ok
      allow Persistence.remove_last_processed_index(@ingestion_id), return: :ok
      allow Persistence.get_last_processed_index(@ingestion_id), return: -1
      allow Persistence.record_last_processed_index(@ingestion_id, any()), return: "OK"
      allow DateTime.to_string(any()), return: "2023-08-03 16:31:47.899763Z"

      provisioned_ingestion =
        TDG.create_ingestion(%{
          id: @ingestion_id,
          sourceFormat: "csv",
          targetDatasets: [first_dataset_id, second_dataset_id],
          cadence: 100,
          schema: [
            %{name: "a", type: "string"}
          ],
          extractSteps: [
            %{
              assigns: %{},
              context: %{
                action: "GET",
                body: "",
                headers: [],
                protocol: nil,
                queryParams: [],
                url: "http://localhost:#{bypass.port}/api/csv"
              },
              sequence: 13033,
              type: "http"
            }
          ],
          allow_duplicates: false
        })

      Processor.process(provisioned_ingestion, DateTime.utc_now())

      first_expected_event_log = %SmartCity.EventLog{
        title: "Data Retrieved",
        timestamp: DateTime.utc_now() |> DateTime.to_string(),
        source: "Reaper",
        description: "Successfully downloaded data and placed on data pipeline to begin processing.",
        dataset_id: first_dataset_id,
        ingestion_id: @ingestion_id
      }

      second_expected_event_log = %SmartCity.EventLog{
        title: "Data Retrieved",
        timestamp: DateTime.utc_now() |> DateTime.to_string(),
        source: "Reaper",
        description: "Successfully downloaded data and placed on data pipeline to begin processing.",
        dataset_id: second_dataset_id,
        ingestion_id: @ingestion_id
      }

      first_event_log = capture(3, Brook.Event.send(any(), event_log_published(), :reaper, any()), 4)
      second_event_log = capture(4, Brook.Event.send(any(), event_log_published(), :reaper, any()), 4)

      assert first_event_log == first_expected_event_log
      assert second_event_log == second_expected_event_log
    end

    test "process/2 should not send an EventLog if stages do not complete", %{bypass: bypass, sourceUrl: sourceUrl} do
      first_dataset_id = Faker.UUID.v4()
      second_dataset_id = Faker.UUID.v4()

      allow Elsa.produce(any(), any(), any(), any()), exec: fn _, _, _, _ -> raise "Fake Error" end
      allow Persistence.remove_last_processed_index(@ingestion_id), return: :ok
      allow Persistence.get_last_processed_index(@ingestion_id), return: -1
      allow Persistence.record_last_processed_index(@ingestion_id, any()), return: "OK"
      allow DateTime.to_string(any()), return: "2023-08-03 16:31:47.899763Z"

      provisioned_ingestion =
        TDG.create_ingestion(%{
          id: @ingestion_id,
          sourceFormat: "csv",
          targetDatasets: [first_dataset_id, second_dataset_id],
          cadence: 100,
          schema: [
            %{name: "a", type: "string"}
          ],
          extractSteps: [
            %{
              assigns: %{},
              context: %{
                action: "GET",
                body: "",
                headers: [],
                protocol: nil,
                queryParams: [],
                url: "http://localhost:#{bypass.port}/api/csv"
              },
              sequence: 13033,
              type: "http"
            }
          ],
          allow_duplicates: false
        })

      assert_raise RuntimeError, ~r/.+Fake Error.+/, fn ->
        Processor.process(provisioned_ingestion, DateTime.utc_now())
      end

      assert_raise RuntimeError, "Unable to find capture: :not_found", fn ->
        capture(3, Brook.Event.send(any(), event_log_published(), :reaper, any()), 4)
      end

      assert_raise RuntimeError, "Unable to find capture: :not_found", fn ->
        capture(4, Brook.Event.send(any(), event_log_published(), :reaper, any()), 4)
      end
    end
  end

  defp get_payloads(list) do
    list
    |> Enum.map(&SmartCity.Data.new/1)
    |> Enum.map(fn {:ok, data} -> data.payload end)
  end

  defp kill(pid) do
    ref = Process.monitor(pid)
    Process.exit(pid, :normal)
    assert_receive {:DOWN, ^ref, _, _, _}
  end
end
