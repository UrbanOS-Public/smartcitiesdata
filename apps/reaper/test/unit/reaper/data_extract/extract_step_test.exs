defmodule Reaper.DataExtract.ExtractStepTest do
  use ExUnit.Case

  alias SmartCity.TestDataGenerator, as: TDG
  alias Reaper.DataExtract.ExtractStep
  alias Reaper.Cache.AuthCache
  use Placebo

  @dataset_id "12345-6789"

  @csv """
  one,two,three
  four,five,six
  """

  setup do
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

    [bypass: bypass, dataset: dataset]
  end

  describe "execute_extract_steps/2 auth" do
    setup do
      Cachex.start(AuthCache.cache_name())
      Cachex.clear(AuthCache.cache_name())

      :ok
    end

    test "Calls the auth retriever and adds response token to assigns", %{bypass: bypass, dataset: dataset} do
      Bypass.stub(bypass, "POST", "/", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed = Jason.decode!(body)

        case parsed do
          %{"Key" => "AuthToken"} -> Plug.Conn.resp(conn, 200, %{sub: %{path: "auth_token"}} |> Jason.encode!())
          _ -> Plug.Conn.resp(conn, 403, "No dice")
        end
      end)

      steps = [
        %{
          type: "auth",
          context: %{
            path: ["sub", "path"],
            destination: "token",
            url: "http://localhost:#{bypass.port}",
            encodeMethod: "json",
            body: %{Key: "AuthToken"},
            headers: %{},
            cacheTtl: nil
          },
          assigns: %{}
        }
      ]

      assigns = ExtractStep.execute_extract_steps(dataset, steps)

      assert assigns == %{token: "auth_token"}
    end

    test "Can use assigns block for body", %{bypass: bypass, dataset: dataset} do
      Bypass.stub(bypass, "POST", "/", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed = Jason.decode!(body)

        case parsed do
          %{"Key" => "super secret"} -> Plug.Conn.resp(conn, 200, %{sub: %{path: "auth_token"}} |> Jason.encode!())
          _ -> Plug.Conn.resp(conn, 403, "No dice")
        end
      end)

      steps = [
        %{
          type: "auth",
          context: %{
            path: ["sub", "path"],
            destination: "token",
            url: "http://localhost:#{bypass.port}",
            encodeMethod: "json",
            body: %{Key: "{{key}}"},
            headers: %{},
            cacheTtl: nil
          },
          assigns: %{
            key: "super secret"
          }
        }
      ]

      assigns = ExtractStep.execute_extract_steps(dataset, steps)

      assert assigns == %{key: "super secret", token: "auth_token"}
    end

    test "Can use assigns block for headers", %{bypass: bypass, dataset: dataset} do
      Bypass.stub(bypass, "POST", "/headers", fn conn ->
        if(Enum.any?(conn.req_headers, fn header -> header == {"header", "super secret"} end)) do
          Plug.Conn.resp(conn, 200, %{sub: %{path: "auth_token"}} |> Jason.encode!())
        else
          Plug.Conn.resp(conn, 401, "Unauthorized")
        end
      end)

      steps = [
        %{
          type: "auth",
          context: %{
            path: ["sub", "path"],
            destination: "token",
            url: "http://localhost:#{bypass.port}/headers",
            encodeMethod: "json",
            body: %{},
            headers: %{Header: "{{header}}"},
            cacheTtl: nil
          },
          assigns: %{
            header: "super secret"
          }
        }
      ]

      assigns = ExtractStep.execute_extract_steps(dataset, steps)

      assert assigns == %{header: "super secret", token: "auth_token"}
    end

    test "Can use assigns block for url", %{bypass: bypass, dataset: dataset} do
      Bypass.stub(bypass, "POST", "/fancyurl", fn conn ->
        Plug.Conn.resp(conn, 200, %{sub: %{path: "auth_token"}} |> Jason.encode!())
      end)

      steps = [
        %{
          type: "auth",
          context: %{
            path: ["sub", "path"],
            destination: "token",
            url: "http://localhost:#{bypass.port}/{{path}}",
            encodeMethod: "json",
            body: %{},
            headers: %{},
            cacheTtl: nil
          },
          assigns: %{
            path: "fancyurl"
          }
        }
      ]

      assigns = ExtractStep.execute_extract_steps(dataset, steps)

      assert assigns == %{path: "fancyurl", token: "auth_token"}
    end

    test "fails with a reasonable error message", %{bypass: bypass, dataset: dataset} do
      Bypass.stub(bypass, "POST", "/", fn conn ->
        Plug.Conn.resp(conn, 403, "No dice")
      end)

      steps = [
        %{
          type: "auth",
          context: %{
            path: ["sub", "path"],
            destination: "token",
            url: "http://localhost:#{bypass.port}",
            encodeMethod: "json",
            body: %{Key: "AuthToken"},
            headers: %{},
            cacheTtl: nil
          },
          assigns: %{}
        }
      ]

      assert_raise RuntimeError, "Unable to process auth step for dataset 12345-6789.", fn ->
        ExtractStep.execute_extract_steps(dataset, steps)
      end
    end
  end

  describe "execute_extract_steps/2 date" do
    test "puts current date with format into assigns block", %{dataset: dataset} do
      allow Timex.now(), return: DateTime.from_naive!(~N[2020-08-31 13:26:08.003], "Etc/UTC")

      steps = [
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
        }
      ]

      assert ExtractStep.execute_extract_steps(dataset, steps) ==
               %{
                 currentDate: "2020-08"
               }
    end

    test "puts current date can do time delta", %{dataset: dataset} do
      allow Timex.now(), return: DateTime.from_naive!(~N[2020-08-31 13:30:00.000], "Etc/UTC")

      steps = [
        %{
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
      ]

      assert ExtractStep.execute_extract_steps(dataset, steps) ==
               %{
                 currentDate: "1987-08"
               }

      steps = [
        %{
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
      ]

      assert ExtractStep.execute_extract_steps(dataset, steps) ==
               %{
                 currentDate: "2020-08-31 2:03"
               }
    end
  end

  describe "execute_extract_steps/2 secret" do
    test "puts a secret into assigns block", %{dataset: dataset} do
      allow Timex.now(), return: DateTime.from_naive!(~N[2020-08-31 13:26:08.003], "Etc/UTC")

      allow Reaper.SecretRetriever.retrieve_dataset_credentials("the_key"),
        return:
          {:ok,
           %{
             "client_id" => "mah_client",
             "client_secret" => "mah_secret"
           }}

      steps = [
        %{
          type: "secret",
          context: %{
            destination: "token",
            key: "the_key",
            sub_key: "client_secret"
          },
          assigns: %{}
        }
      ]

      assert ExtractStep.execute_extract_steps(dataset, steps) ==
               %{
                 token: "mah_secret"
               }
    end
  end

  describe "execute_extract_steps/2 http" do
    test "simple http get", %{bypass: bypass, dataset: dataset} do
      Bypass.stub(bypass, "GET", "/api/csv", fn conn ->
        Plug.Conn.resp(conn, 200, @csv)
      end)

      steps = [
        %{
          type: "http",
          context: %{
            action: "GET",
            protocol: nil,
            body: %{},
            url: dataset.technical.sourceUrl,
            queryParams: %{},
            headers: %{}
          },
          assigns: %{}
        }
      ]

      expected = ExtractStep.execute_extract_steps(dataset, steps) |> Enum.to_list()

      assert expected == [
               {%{"a" => "one", "b" => "two", "c" => "three"}, 0},
               {%{"a" => "four", "b" => "five", "c" => "six"}, 1}
             ]
    end

    test "can use assigns block for query params", %{bypass: bypass, dataset: dataset} do
      Bypass.stub(bypass, "GET", "/api/csv/query", fn conn ->
        token =
          conn
          |> Plug.Conn.fetch_query_params()
          |> Map.get(:query_params)
          |> Map.get("token")

        if token == "secret tunnel" do
          Plug.Conn.resp(conn, 200, @csv)
        else
          Plug.Conn.resp(conn, 401, "Unauthorized")
        end
      end)

      steps = [
        %{
          type: "http",
          context: %{
            action: "GET",
            protocol: nil,
            body: %{},
            url: "#{dataset.technical.sourceUrl}/query",
            queryParams: %{
              token: "{{token}}"
            },
            headers: %{}
          },
          assigns: %{token: "secret tunnel"}
        }
      ]

      expected =
        ExtractStep.execute_extract_steps(dataset, steps)
        |> Enum.to_list()

      assert expected == [
               {%{"a" => "one", "b" => "two", "c" => "three"}, 0},
               {%{"a" => "four", "b" => "five", "c" => "six"}, 1}
             ]
    end

    test "can use assigns block for headers", %{bypass: bypass, dataset: dataset} do
      Bypass.stub(bypass, "GET", "/api/csv/headers", fn conn ->
        if(Enum.any?(conn.req_headers, fn header -> header == {"bearer", "bear token"} end)) do
          Plug.Conn.resp(conn, 200, @csv)
        else
          Plug.Conn.resp(conn, 401, "Unauthorized")
        end
      end)

      steps = [
        %{
          type: "http",
          context: %{
            action: "GET",
            protocol: nil,
            body: %{},
            url: "#{dataset.technical.sourceUrl}/headers",
            queryParams: %{},
            headers: %{Bearer: "{{token}}"}
          },
          assigns: %{token: "bear token"}
        }
      ]

      expected =
        ExtractStep.execute_extract_steps(dataset, steps)
        |> Enum.to_list()

      assert expected == [
               {%{"a" => "one", "b" => "two", "c" => "three"}, 0},
               {%{"a" => "four", "b" => "five", "c" => "six"}, 1}
             ]
    end

    test "can use assigns block for url", %{bypass: bypass, dataset: dataset} do
      Bypass.stub(bypass, "GET", "/api/csv/fancyurl", fn conn ->
        Plug.Conn.resp(conn, 200, @csv)
      end)

      steps = [
        %{
          type: "http",
          context: %{
            action: "GET",
            protocol: nil,
            body: %{},
            url: "#{dataset.technical.sourceUrl}/{{path}}",
            queryParams: %{},
            headers: %{}
          },
          assigns: %{path: "fancyurl"}
        }
      ]

      expected =
        ExtractStep.execute_extract_steps(dataset, steps)
        |> Enum.to_list()

      assert expected == [
               {%{"a" => "one", "b" => "two", "c" => "three"}, 0},
               {%{"a" => "four", "b" => "five", "c" => "six"}, 1}
             ]
    end

    test "can post with an encoded post body", %{bypass: bypass, dataset: dataset} do
      Bypass.stub(bypass, "POST", "/api/csv/post", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed = Jason.decode!(body)

        case parsed do
          %{"soap_request" => %{"date" => "2018-01-01"}} -> Plug.Conn.resp(conn, 200, @csv)
          _ -> Plug.Conn.resp(conn, 403, "No dice")
        end
      end)

      steps = [
        %{
          type: "http",
          context: %{
            action: "POST",
            protocol: nil,
            body: %{
              soap_request: %{
                date: "{{date}}"
              }
            },
            url: "#{dataset.technical.sourceUrl}/post",
            queryParams: %{},
            headers: %{}
          },
          assigns: %{date: "2018-01-01"}
        }
      ]

      expected =
        ExtractStep.execute_extract_steps(dataset, steps)
        |> Enum.to_list()

      assert expected == [
               {%{"a" => "one", "b" => "two", "c" => "three"}, 0},
               {%{"a" => "four", "b" => "five", "c" => "six"}, 1}
             ]
    end

    test "sends through protocols", %{bypass: bypass, dataset: dataset} do
      Bypass.stub(bypass, "GET", "/api/csv", fn conn ->
        Plug.Conn.resp(conn, 200, @csv)
      end)

      allow Mint.HTTP.connect(:spy, :spy, :spy, :spy), return: :spy, meck_options: [:passthrough]

      steps = [
        %{
          type: "http",
          context: %{
            action: "GET",
            protocol: ["http1"],
            body: %{},
            url: "#{dataset.technical.sourceUrl}",
            queryParams: %{},
            headers: %{}
          },
          assigns: %{}
        }
      ]

      expected =
        ExtractStep.execute_extract_steps(dataset, steps)
        |> Enum.to_list()

      assert expected == [
               {%{"a" => "one", "b" => "two", "c" => "three"}, 0},
               {%{"a" => "four", "b" => "five", "c" => "six"}, 1}
             ]

      assert_called Mint.HTTP.connect(:http, "localhost", any(), transport_opts: [timeout: 30_000], protocols: [:http1])
    end
  end

  describe "extract steps error paths" do
    test "Set variable then single extract step for http get", %{dataset: dataset} do
      steps = [
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

      assert_raise RuntimeError, "Unable to process date step for dataset 12345-6789.", fn ->
        ExtractStep.execute_extract_steps(dataset, steps)
      end
    end
  end
end
