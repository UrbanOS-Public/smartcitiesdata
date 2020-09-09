defmodule Reaper.DataExtract.ProcessorTest do
  use ExUnit.Case
  use Placebo
  import ExUnit.CaptureLog
  import Mox

  alias Reaper.{Cache, Persistence}
  alias Reaper.DataExtract.Processor
  alias Reaper.Cache.AuthCache
  alias SmartCity.TestDataGenerator, as: TDG

  @dataset_id "12345-6789"

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

    dataset =
      TDG.create_dataset(
        id: @dataset_id,
        technical: %{
          sourceType: "ingest",
          sourceFormat: "csv",
          sourceUrl: "http://localhost:#{bypass.port}/api/csv",
          cadence: 100,
          schema: [
            %{name: "a", type: "string"},
            %{name: "b", type: "string"},
            %{name: "c", type: "string"}
          ],
          allow_duplicates: false
        }
      )

    allow Elsa.create_topic(any(), any()), return: :ok
    allow Elsa.Supervisor.start_link(any()), return: {:ok, :pid}
    allow Elsa.topic?(any(), any()), return: true
    allow Elsa.Producer.ready?(any()), return: :does_not_matter

    [bypass: bypass, dataset: dataset]
  end

  describe "process/2 happy path" do
    setup %{bypass: bypass} do
      allow Elsa.produce(any(), any(), any(), any()), return: :ok
      allow Persistence.remove_last_processed_index(@dataset_id), return: :ok

      Bypass.expect(bypass, "GET", "/api/csv", fn conn ->
        Plug.Conn.resp(conn, 200, @csv)
      end)

      :ok
    end

    test "parses turns csv into data messages and sends to kafka", %{dataset: dataset} do
      allow Persistence.get_last_processed_index(@dataset_id), return: -1
      allow Persistence.record_last_processed_index(@dataset_id, any()), return: "OK"

      Processor.process(dataset)

      messages = capture(1, Elsa.produce(any(), any(), any(), any()), 3)

      expected = [
        %{"a" => "one", "b" => "two", "c" => "three"},
        %{"a" => "four", "b" => "five", "c" => "six"}
      ]

      assert expected == get_payloads(messages)

      assert_called Persistence.record_last_processed_index(any(), any()), once()
      assert_called Persistence.remove_last_processed_index(@dataset_id), once()
    end

    test "eliminates duplicates before sending to kafka", %{dataset: dataset} do
      allow Persistence.get_last_processed_index(@dataset_id), return: -1
      allow Persistence.record_last_processed_index(@dataset_id, any()), return: "OK"
      Horde.DynamicSupervisor.start_child(Reaper.Horde.Supervisor, {Reaper.Cache, name: dataset.id})
      Cache.cache(dataset.id, %{"a" => "one", "b" => "two", "c" => "three"})

      Processor.process(dataset)

      messages = capture(1, Elsa.produce(any(), any(), any(), any()), 3)
      assert [%{"a" => "four", "b" => "five", "c" => "six"}] == get_payloads(messages)
      assert_called Elsa.produce(any(), any(), any(), any()), once()

      assert_called Persistence.record_last_processed_index(any(), any()), once()
      assert_called Persistence.remove_last_processed_index(@dataset_id), once()
    end
  end

  test "provisions and uses a source url", %{bypass: bypass} do
    allow Persistence.get_last_processed_index(@dataset_id), return: -1
    allow Persistence.record_last_processed_index(@dataset_id, any()), return: "OK"
    allow Elsa.produce(any(), any(), any(), any()), return: :ok
    allow Persistence.remove_last_processed_index(@dataset_id), return: :ok

    Providers.Echo
    |> expect(:provide, 1, fn _, %{value: value} -> value end)

    Bypass.expect(bypass, "GET", "/api/prov_csv", fn conn ->
      Plug.Conn.resp(conn, 200, @csv)
    end)

    dataset =
      TDG.create_dataset(
        id: @dataset_id,
        technical: %{
          sourceType: "ingest",
          sourceFormat: "csv",
          sourceUrl: %{
            provider: "Echo",
            opts: %{value: "http://localhost:#{bypass.port}/api/prov_csv"},
            version: "1"
          },
          cadence: 100,
          schema: [
            %{name: "a", type: "string"},
            %{name: "b", type: "string"},
            %{name: "c", type: "string"}
          ],
          allow_duplicates: false
        }
      )

    Processor.process(dataset)
  end

  describe "process/2 happy path with extract steps" do
    setup %{bypass: bypass} do
      allow Elsa.produce(any(), any(), any(), any()), return: :ok
      allow Persistence.remove_last_processed_index(@dataset_id), return: :ok
      allow Timex.now(), return: DateTime.from_naive!(~N[2020-08-31 13:26:08.003], "Etc/UTC")

      # TODO: Change to @csv 1,2,3
      Bypass.stub(bypass, "GET", "/api/csv", fn conn ->
        Plug.Conn.resp(conn, 200, @csv)
      end)

      Bypass.stub(bypass, "GET", "/api/csv/2020-08", fn conn ->
        Plug.Conn.resp(conn, 200, @csv)
      end)

      Bypass.stub(bypass, "GET", "/api/csv/2020", fn conn ->
        token =
          conn
          |> Plug.Conn.fetch_query_params()
          |> Map.get(:query_params)
          |> Map.get("token")

        if(token == "mah_secret") do
          Plug.Conn.resp(conn, 200, @csv)
        else
          Plug.Conn.resp(conn, 401, "Unauthorized")
        end
      end)

      Bypass.stub(bypass, "GET", "/api/csv/headers", fn conn ->
        IO.inspect(conn.req_headers, label: "mah headers")

        if(Enum.any?(conn.req_headers, fn header -> header == {"bearer", "mah_secret"} end)) do
          Plug.Conn.resp(conn, 200, @csv)
        else
          Plug.Conn.resp(conn, 401, "Unauthorized")
        end
      end)

      :ok
    end

    test "Single extract step for http get", %{dataset: dataset} do
      allow Persistence.get_last_processed_index(@dataset_id), return: -1
      allow Persistence.record_last_processed_index(@dataset_id, any()), return: "OK"

      extract_step = %{
        type: "http",
        context: %{
          url: dataset.technical.sourceUrl,
          queryParams: %{},
          headers: %{}
        },
        assigns: %{}
      }

      put_in(dataset, [:technical, :extractSteps], [extract_step])
      |> Processor.process()

      messages = capture(1, Elsa.produce(any(), any(), any(), any()), 3)

      expected = [
        %{"a" => "one", "b" => "two", "c" => "three"},
        %{"a" => "four", "b" => "five", "c" => "six"}
      ]

      assert expected == get_payloads(messages)

      assert_called Persistence.record_last_processed_index(any(), any()), once()
      assert_called Persistence.remove_last_processed_index(@dataset_id), once()
    end

    test "Set variable then single extract step for http get", %{dataset: dataset} do
      allow Persistence.get_last_processed_index(@dataset_id), return: -1
      allow Persistence.record_last_processed_index(@dataset_id, any()), return: "OK"

      extract_steps = [
        %{
          type: "date",
          context: %{
            destination: "currentDate",
            deltaTimeUnit: nil,
            deltaTimeValue: nil,
            timeZone: nil,
            format: "{YYYY}-{0M}"
          },
          assigns: %{}
        },
        %{
          type: "http",
          context: %{
            url: "#{dataset.technical.sourceUrl}/{{currentDate}}",
            queryParams: %{},
            headers: %{}
          },
          assigns: %{}
        }
      ]

      put_in(dataset, [:technical, :extractSteps], extract_steps)
      |> Processor.process()

      messages = capture(1, Elsa.produce(any(), any(), any(), any()), 3)

      expected = [
        %{"a" => "one", "b" => "two", "c" => "three"},
        %{"a" => "four", "b" => "five", "c" => "six"}
      ]

      assert expected == get_payloads(messages)

      assert_called Persistence.record_last_processed_index(any(), any()), once()
      assert_called Persistence.remove_last_processed_index(@dataset_id), once()
    end

    test "Set two variables then single extract step for http get", %{dataset: dataset} do
      allow Persistence.get_last_processed_index(@dataset_id), return: -1
      allow Persistence.record_last_processed_index(@dataset_id, any()), return: "OK"

      extract_steps = [
        %{
          type: "date",
          context: %{
            destination: "currentMonth",
            deltaTimeUnit: nil,
            deltaTimeValue: nil,
            timeZone: nil,
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
            timeZone: nil,
            format: "{YYYY}"
          },
          assigns: %{}
        },
        %{
          type: "http",
          context: %{
            url: "#{dataset.technical.sourceUrl}/{{currentYear}}-{{currentMonth}}",
            queryParams: %{},
            headers: %{}
          },
          assigns: %{}
        }
      ]

      put_in(dataset, [:technical, :extractSteps], extract_steps)
      |> Processor.process()

      messages = capture(1, Elsa.produce(any(), any(), any(), any()), 3)

      expected = [
        %{"a" => "one", "b" => "two", "c" => "three"},
        %{"a" => "four", "b" => "five", "c" => "six"}
      ]

      assert expected == get_payloads(messages)

      assert_called Persistence.record_last_processed_index(any(), any()), once()
      assert_called Persistence.remove_last_processed_index(@dataset_id), once()
    end

    test "Lookup secret and date single extract step for http get", %{dataset: dataset} do
      allow Persistence.get_last_processed_index(@dataset_id), return: -1
      allow Persistence.record_last_processed_index(@dataset_id, any()), return: "OK"

      allow Reaper.SecretRetriever.retrieve_dataset_credentials("the_key"),
        return:
          {:ok,
           %{
             "client_id" => "mah_client",
             "client_secret" => "mah_secret"
           }}

      extract_steps = [
        %{
          type: "date",
          context: %{
            destination: "currentYear",
            deltaTimeUnit: nil,
            deltaTimeValue: nil,
            timeZone: nil,
            format: "{YYYY}"
          },
          assigns: %{}
        },
        %{
          type: "secret",
          context: %{
            destination: "token",
            key: "the_key",
            sub_key: "client_secret"
          },
          assigns: %{}
        },
        %{
          type: "http",
          context: %{
            url: "#{dataset.technical.sourceUrl}/{{currentYear}}",
            queryParams: %{
              token: "{{token}}"
            },
            headers: %{}
          },
          assigns: %{}
        }
      ]

      put_in(dataset, [:technical, :extractSteps], extract_steps)
      |> Processor.process()

      messages = capture(1, Elsa.produce(any(), any(), any(), any()), 3)

      expected = [
        %{"a" => "one", "b" => "two", "c" => "three"},
        %{"a" => "four", "b" => "five", "c" => "six"}
      ]

      assert expected == get_payloads(messages)

      assert_called Persistence.record_last_processed_index(any(), any()), once()
      assert_called Persistence.remove_last_processed_index(@dataset_id), once()
    end

    test "Will put a secret into a header", %{dataset: dataset} do
      allow Persistence.get_last_processed_index(@dataset_id), return: -1
      allow Persistence.record_last_processed_index(@dataset_id, any()), return: "OK"

      allow Reaper.SecretRetriever.retrieve_dataset_credentials("the_key"),
        return:
          {:ok,
           %{
             "client_id" => "mah_client",
             "client_secret" => "mah_secret"
           }}

      extract_steps = [
        %{
          type: "secret",
          context: %{
            destination: "token",
            key: "the_key",
            sub_key: "client_secret"
          },
          assigns: %{}
        },
        %{
          type: "http",
          context: %{
            url: "#{dataset.technical.sourceUrl}/headers",
            queryParams: %{},
            headers: %{
              Bearer: "{{token}}"
            }
          },
          assigns: %{}
        }
      ]

      put_in(dataset, [:technical, :extractSteps], extract_steps)
      |> Processor.process()

      messages = capture(1, Elsa.produce(any(), any(), any(), any()), 3)

      expected = [
        %{"a" => "one", "b" => "two", "c" => "three"},
        %{"a" => "four", "b" => "five", "c" => "six"}
      ]

      assert expected == get_payloads(messages)

      assert_called Persistence.record_last_processed_index(any(), any()), once()
      assert_called Persistence.remove_last_processed_index(@dataset_id), once()
    end

    test "extract steps uses auth retrieval", %{dataset: dataset} do
      steps = [
        %{
          type: "auth",
          context: %{
            path: ["sub", "path"],
            destination: "token",
            url: "authorize.example",
            encodeMethod: "json",
            body: %{Key: "AuthToken"},
            queryParams: %{},
            headers: %{}
          },
          assigns: %{}
        },
        %{
          type: "http",
          context: %{
            url: "#{dataset.technical.sourceUrl}/auth",
            queryParams: %{},
            headers: %{
              Bearer: "{{token}}"
            }
          },
          assigns: %{}
        }
      ]
    end
  end

  describe "process_extract_step for auth" do
    test "Calls the auth retriever and adds response token to assigns", %{bypass: bypass, dataset: dataset} do
      Cachex.start(AuthCache.cache_name())
      Cachex.clear(AuthCache.cache_name())

      Bypass.stub(bypass, "POST", "/", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed = Jason.decode!(body)
        case parsed do
          %{"Key" => "AuthToken"} -> Plug.Conn.resp(conn, 200, %{sub: %{path: "auth_token"}} |> Jason.encode!)
          _ -> Plug.Conn.resp(conn, 403, "No dice")
        end
      end)

      step =
        %{
          type: "auth",
          context: %{
            # action: "POST",  # TODO: do we need this
            path: ["sub", "path"],
            destination: "token",
            url: "http://localhost:#{bypass.port}",
            encodeMethod: "json",
            body: %{Key: "AuthToken"},
            queryParams: %{},
            headers: %{}
          },
          assigns: %{}
        }

      assigns = Processor.process_extract_step(dataset, step)

      assert assigns == %{token: "auth_token"}
    end
    test "fails with a reasonable error message", %{bypass: bypass, dataset: dataset} do
      Cachex.start(AuthCache.cache_name())
      Cachex.clear(AuthCache.cache_name())

      Bypass.stub(bypass, "POST", "/", fn conn ->
           Plug.Conn.resp(conn, 403, "No dice")
      end)

      step =
        %{
          type: "auth",
          context: %{
            # action: "POST",  # TODO: do we need this
            path: ["sub", "path"],
            destination: "token",
            url: "http://localhost:#{bypass.port}",
            encodeMethod: "json",
            body: %{Key: "AuthToken"},
            queryParams: %{},
            headers: %{}
          },
          assigns: %{}
        }

      assert_raise RuntimeError, "Unable to parse auth request for dataset: #{dataset.id}. Unable to retrieve auth credentials for dataset 12345-6789 with status 403", fn ->
        Processor.process_extract_step(dataset, step)
      end
    end
  end

  describe "extract steps error paths" do
    test "Set variable then single extract step for http get", %{dataset: dataset} do
      allow Persistence.get_last_processed_index(@dataset_id), return: -1
      allow Persistence.record_last_processed_index(@dataset_id, any()), return: "OK"

      extract_steps = [
        %{
          type: "date",
          context: %{
            destination: "currentDate",
            deltaTimeUnit: nil,
            deltaTimeValue: nil,
            timeZone: nil,
            format: "{WILLFAIL}-{0M}"
          },
          assigns: %{}
        },
        %{
          type: "http",
          context: %{
            url: "#{dataset.technical.sourceUrl}/{{currentDate}}",
            queryParams: %{},
            headers: %{}
          },
          assigns: %{}
        }
      ]

      assert_raise Timex.Format.FormatError, fn ->
        put_in(dataset, [:technical, :extractSteps], extract_steps)
        |> Processor.process()
      end
    end
  end

  describe "date step" do
    test "puts current date with format into assigns block", %{dataset: dataset} do
      allow Timex.now(), return: DateTime.from_naive!(~N[2020-08-31 13:26:08.003], "Etc/UTC")

      step = %{
        type: "date",
        context: %{
          destination: "currentDate",
          deltaTimeUnit: nil,
          deltaTimeValue: nil,
          timeZone: nil,
          format: "{YYYY}-{0M}"
        },
        assigns: %{}
      }

      assert Processor.process_extract_step(dataset, step) ==
               %{
                 currentDate: "2020-08"
               }
    end

    test "puts current date can do time delta", %{dataset: dataset} do
      allow Timex.now(), return: DateTime.from_naive!(~N[2020-08-31 13:30:00.000], "Etc/UTC")

      step = %{
        type: "date",
        context: %{
          destination: "currentDate",
          deltaTimeUnit: "years",
          deltaTimeValue: -33,
          timeZone: nil,
          format: "{YYYY}-{0M}"
        },
        assigns: %{}
      }

      assert Processor.process_extract_step(dataset, step) ==
               %{
                 currentDate: "1987-08"
               }

      step = %{
        type: "date",
        context: %{
          destination: "currentDate",
          deltaTimeUnit: "minutes",
          deltaTimeValue: 33,
          timeZone: nil,
          format: "{YYYY}-{0M}-{0D} {h12}:{m}"
        },
        assigns: %{}
      }

      assert Processor.process_extract_step(dataset, step) ==
               %{
                 currentDate: "2020-08-31 2:03"
               }
    end
  end

  describe "secret step" do
    test "puts a secret into assigns block", %{dataset: dataset} do
      allow Timex.now(), return: DateTime.from_naive!(~N[2020-08-31 13:26:08.003], "Etc/UTC")

      allow Reaper.SecretRetriever.retrieve_dataset_credentials("the_key"),
        return:
          {:ok,
           %{
             "client_id" => "mah_client",
             "client_secret" => "mah_secret"
           }}

      step = %{
        type: "secret",
        context: %{
          destination: "token",
          key: "the_key",
          sub_key: "client_secret"
        },
        assigns: %{}
      }

      assert Processor.process_extract_step(dataset, step) ==
               %{
                 token: "mah_secret"
               }
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
    test "process/2 should remove file for dataset regardless of error being raised", %{dataset: dataset} do
      allow Persistence.get_last_processed_index(any()), return: -1

      allow Reaper.Cache.mark_duplicates(any(), any()),
        exec: fn _, _ -> raise "some error" end,
        meck_options: [:passthrough]

      assert_raise RuntimeError, fn ->
        Processor.process(dataset)
      end

      assert false == File.exists?(@download_dir <> dataset.id)
    end

    test "process/2 should catch log all exceptions and reraise", %{dataset: dataset} do
      allow Persistence.get_last_processed_index(any()), return: -1

      allow Elsa.produce(any(), any(), any(), any()), exec: fn _, _, _, _ -> raise "some error" end

      log =
        capture_log(fn ->
          assert_raise RuntimeError, fn ->
            Processor.process(dataset)
          end
        end)

      assert log =~ inspect(dataset)
      assert log =~ "some error"
    end

    test "process/2 should execute providers prior to processing", %{bypass: bypass} do
      dataset_id = "prov-dataset-1234"
      allow Elsa.produce(any(), any(), any(), any()), return: :ok
      allow Persistence.remove_last_processed_index(dataset_id), return: :ok
      allow Persistence.get_last_processed_index(dataset_id), return: -1
      allow Persistence.record_last_processed_index(dataset_id, any()), return: "OK"

      Providers.Echo
      |> expect(:provide, 2, fn _, %{value: value} -> value end)

      provisioned_dataset =
        TDG.create_dataset(
          id: "prov-dataset-1234",
          technical: %{
            sourceType: "ingest",
            sourceFormat: "csv",
            sourceUrl: %{
              provider: "Echo",
              opts: %{value: "http://localhost:#{bypass.port}/api/csv"},
              version: "1"
            },
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
            allow_duplicates: false
          }
        )

      Processor.process(provisioned_dataset)

      messages = capture(1, Elsa.produce(any(), any(), any(), any()), 3)

      expected = [
        %{"a" => "one", "b" => "two", "c" => "three", "p" => "six of six"},
        %{"a" => "four", "b" => "five", "c" => "six", "p" => "six of six"}
      ]

      assert expected == get_payloads(messages)
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
