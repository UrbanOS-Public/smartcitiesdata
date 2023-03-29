defmodule Reaper.DataExtract.ExtractStepTest do
  use ExUnit.Case

  alias SmartCity.TestDataGenerator, as: TDG
  alias Reaper.DataExtract.ExtractStep
  alias Reaper.Cache.AuthCache
  use Placebo

  @ingestion_id "12345-6789"

  @csv """
  one,two,three
  four,five,six
  """

  @csvquery """
  this,is,another
  csv,with,columns
  """

  @csvheaders """
  hello,it's,me
  your,csv,friend
  """

  @csvbody """
  this,csv,is only
  attainable,with a,post body
  """

  setup do
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
        allow_duplicates: false
      })

    [bypass: bypass, ingestion: ingestion, sourceUrl: sourceUrl]
  end

  describe "execute_extract_steps/2 auth" do
    setup do
      Cachex.start(AuthCache.cache_name())
      Cachex.clear(AuthCache.cache_name())

      :ok
    end

    test "Calls the auth retriever and adds response token to assigns", %{bypass: bypass, ingestion: ingestion} do
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
            body: "{\"Key\": \"AuthToken\"}",
            headers: %{},
            cacheTtl: nil
          },
          assigns: %{}
        }
      ]

      assigns = ExtractStep.execute_extract_steps(ingestion, steps)

      assert assigns == %{token: "auth_token"}
    end

    test "Handles compressed auth bodies", %{bypass: bypass, ingestion: ingestion} do
      Bypass.stub(bypass, "POST", "/", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed = Jason.decode!(body)

        case parsed do
          %{"Key" => "AuthToken"} ->
            conn
            |> Plug.Conn.put_resp_header("Content-Encoding", "gzip")
            |> Plug.Conn.resp(200, :zlib.gzip(Jason.encode!(%{token: "thetokenstring"})))

          _ ->
            Plug.Conn.resp(conn, 403, "No dice")
        end
      end)

      steps = [
        %{
          type: "auth",
          context: %{
            path: ["token"],
            destination: "token",
            url: "http://localhost:#{bypass.port}",
            encodeMethod: "json",
            body: "{\"Key\": \"AuthToken\"}",
            headers: %{},
            cacheTtl: nil
          },
          assigns: %{}
        }
      ]

      assigns = ExtractStep.execute_extract_steps(ingestion, steps)

      assert assigns == %{token: "thetokenstring"}
    end

    test "Handles invalid compressed auth bodies", %{bypass: bypass, ingestion: ingestion} do
      Bypass.stub(bypass, "POST", "/", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed = Jason.decode!(body)

        case parsed do
          %{"Key" => "AuthToken"} ->
            conn
            |> Plug.Conn.put_resp_header("Content-Encoding", "gzip")
            |> Plug.Conn.resp(200, "This is not gzipped")

          _ ->
            Plug.Conn.resp(conn, 403, "No dice")
        end
      end)

      steps = [
        %{
          type: "auth",
          context: %{
            path: ["token"],
            destination: "token",
            url: "http://localhost:#{bypass.port}",
            encodeMethod: "json",
            body: "{\"Key\": \"AuthToken\"}",
            headers: %{},
            cacheTtl: nil
          },
          assigns: %{}
        }
      ]

      assert_raise RuntimeError, "Unable to process auth step for ingestion 12345-6789.", fn ->
        ExtractStep.execute_extract_steps(ingestion, steps)
      end
    end

    test "Can use assigns block for body", %{bypass: bypass, ingestion: ingestion} do
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
            body: "{\"Key\": \"{{key}}\"}",
            headers: %{},
            cacheTtl: nil
          },
          assigns: %{
            key: "super secret"
          }
        }
      ]

      assigns = ExtractStep.execute_extract_steps(ingestion, steps)

      assert assigns == %{key: "super secret", token: "auth_token"}
    end

    test "Can use empty string for body", %{bypass: bypass, ingestion: ingestion} do
      Bypass.stub(bypass, "POST", "/", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)

        case body do
          "" -> Plug.Conn.resp(conn, 200, %{sub: %{path: "auth_token2"}} |> Jason.encode!())
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
            body: "",
            headers: %{},
            cacheTtl: nil
          },
          assigns: %{
            key: "super secret two"
          }
        }
      ]

      assigns = ExtractStep.execute_extract_steps(ingestion, steps)

      assert assigns == %{key: "super secret two", token: "auth_token2"}
    end

    test "Can use empty map for body", %{bypass: bypass, ingestion: ingestion} do
      Bypass.stub(bypass, "POST", "/", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)

        case body do
          "" -> Plug.Conn.resp(conn, 200, %{sub: %{path: "auth_token2"}} |> Jason.encode!())
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
            body: %{},
            headers: %{},
            cacheTtl: nil
          },
          assigns: %{
            key: "super secret two"
          }
        }
      ]

      assigns = ExtractStep.execute_extract_steps(ingestion, steps)

      assert assigns == %{key: "super secret two", token: "auth_token2"}
    end

    test "Can use assigns block for headers", %{bypass: bypass, ingestion: ingestion} do
      Bypass.stub(bypass, "POST", "/headers", fn conn ->
        if Enum.any?(conn.req_headers, fn header -> header == {"header", "super secret"} end) do
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
            body: "",
            headers: %{Header: "{{header}}"},
            cacheTtl: nil
          },
          assigns: %{
            header: "super secret"
          }
        }
      ]

      assigns = ExtractStep.execute_extract_steps(ingestion, steps)

      assert assigns == %{header: "super secret", token: "auth_token"}
    end

    test "Can use assigns block for url", %{bypass: bypass, ingestion: ingestion} do
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
            body: "",
            headers: %{},
            cacheTtl: nil
          },
          assigns: %{
            path: "fancyurl"
          }
        }
      ]

      assigns = ExtractStep.execute_extract_steps(ingestion, steps)

      assert assigns == %{path: "fancyurl", token: "auth_token"}
    end

    test "fails with a reasonable error message", %{bypass: bypass, ingestion: ingestion} do
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
            body: "{\"Key\": \"AuthToken\"}",
            headers: %{},
            cacheTtl: nil
          },
          assigns: %{}
        }
      ]

      assert_raise RuntimeError, "Unable to process auth step for ingestion 12345-6789.", fn ->
        ExtractStep.execute_extract_steps(ingestion, steps)
      end
    end
  end

  describe "execute_extract_steps/2 date" do
    test "puts current date with format into assigns block", %{ingestion: ingestion} do
      allow Timex.now(), return: DateTime.from_naive!(~N[2020-08-31 13:26:08.003], "Etc/UTC")

      steps = [
        %{
          type: "date",
          context: %{
            destination: "currentDate",
            deltaTimeUnit: nil,
            deltaTimeValue: nil,
            format: "{YYYY}-{0M}"
          },
          assigns: %{}
        }
      ]

      assert ExtractStep.execute_extract_steps(ingestion, steps) ==
               %{
                 currentDate: "2020-08"
               }
    end

    test "puts current date can do time delta", %{ingestion: ingestion} do
      allow Timex.now(), return: DateTime.from_naive!(~N[2020-08-31 13:30:00.000], "Etc/UTC")

      steps = [
        %{
          type: "date",
          context: %{
            destination: "currentDate",
            deltaTimeUnit: "years",
            deltaTimeValue: -33,
            format: "{YYYY}-{0M}"
          },
          assigns: %{}
        }
      ]

      assert ExtractStep.execute_extract_steps(ingestion, steps) ==
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
            format: "{YYYY}-{0M}-{0D} {h12}:{m}"
          },
          assigns: %{}
        }
      ]

      assert ExtractStep.execute_extract_steps(ingestion, steps) ==
               %{
                 currentDate: "2020-08-31 2:03"
               }
    end
  end

  describe "execute_extract_steps/2 secret" do
    test "puts a secret into assigns block", %{ingestion: ingestion} do
      allow Timex.now(), return: DateTime.from_naive!(~N[2020-08-31 13:26:08.003], "Etc/UTC")

      allow Reaper.SecretRetriever.retrieve_ingestion_credentials("the_key"),
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

      assert ExtractStep.execute_extract_steps(ingestion, steps) ==
               %{
                 token: "mah_secret"
               }
    end
  end

  describe "execute_extract_steps/2 http" do
    test "simple http get", %{bypass: bypass, ingestion: ingestion, sourceUrl: sourceUrl} do
      Bypass.stub(bypass, "GET", "/api/csv", fn conn ->
        Plug.Conn.resp(conn, 200, @csv)
      end)

      steps = [
        %{
          type: "http",
          context: %{
            action: "GET",
            protocol: nil,
            body: "",
            url: "#{sourceUrl}",
            queryParams: %{},
            headers: %{}
          },
          assigns: %{}
        }
      ]

      expected_assigns = ExtractStep.execute_extract_steps(ingestion, steps)

      assert expected_assigns == %{output_file: {:file, "12345-6789"}}
      assert File.read!("12345-6789") == "one,two,three\nfour,five,six\n"
    end

    test "can use assigns block for query params", %{bypass: bypass, ingestion: ingestion, sourceUrl: sourceUrl} do
      Bypass.stub(bypass, "GET", "/api/csv/query", fn conn ->
        token =
          conn
          |> Plug.Conn.fetch_query_params()
          |> Map.get(:query_params)
          |> Map.get("token")

        if token == "secret tunnel" do
          Plug.Conn.resp(conn, 200, @csvquery)
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
            body: "",
            url: "#{sourceUrl}/query",
            queryParams: %{
              token: "{{token}}"
            },
            headers: %{}
          },
          assigns: %{token: "secret tunnel"}
        }
      ]

      expected_assigns = ExtractStep.execute_extract_steps(ingestion, steps)

      assert expected_assigns == %{output_file: {:file, "12345-6789"}, token: "secret tunnel"}
      assert File.read!("12345-6789") == "this,is,another\ncsv,with,columns\n"
    end

    test "can use assigns block for headers", %{bypass: bypass, ingestion: ingestion, sourceUrl: sourceUrl} do
      Bypass.stub(bypass, "GET", "/api/csv/headers", fn conn ->
        if Enum.any?(conn.req_headers, fn header -> header == {"bearer", "bear token"} end) do
          Plug.Conn.resp(conn, 200, @csvheaders)
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
            body: "",
            url: "#{sourceUrl}/headers",
            queryParams: %{},
            headers: %{Bearer: "{{token}}"}
          },
          assigns: %{token: "bear token"}
        }
      ]

      expected_assigns = ExtractStep.execute_extract_steps(ingestion, steps)

      assert expected_assigns == %{output_file: {:file, "12345-6789"}, token: "bear token"}
      assert File.read!("12345-6789") == "hello,it's,me\nyour,csv,friend\n"
    end

    test "can use assigns block for url", %{bypass: bypass, ingestion: ingestion, sourceUrl: sourceUrl} do
      Bypass.stub(bypass, "GET", "/api/csv/fancyurl", fn conn ->
        Plug.Conn.resp(conn, 200, @csv)
      end)

      steps = [
        %{
          type: "http",
          context: %{
            action: "GET",
            protocol: nil,
            body: "",
            url: "#{sourceUrl}/{{path}}",
            queryParams: %{},
            headers: %{}
          },
          assigns: %{path: "fancyurl"}
        }
      ]

      assigns = ExtractStep.execute_extract_steps(ingestion, steps)

      assert assigns == %{output_file: {:file, "12345-6789"}, path: "fancyurl"}
      assert File.read!("12345-6789") == "one,two,three\nfour,five,six\n"
    end

    test "can post with an encoded post body", %{bypass: bypass, ingestion: ingestion, sourceUrl: sourceUrl} do
      Bypass.stub(bypass, "POST", "/api/csv/post", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed = Jason.decode!(body)

        case parsed do
          %{"soap_request" => %{"date" => "2018-01-01"}} -> Plug.Conn.resp(conn, 200, @csvbody)
          _ -> Plug.Conn.resp(conn, 403, "No dice")
        end
      end)

      steps = [
        %{
          type: "http",
          context: %{
            action: "POST",
            protocol: nil,
            body: "{
              \"soap_request\": {
                \"date\": \"{{date}}\"
              }
            }",
            url: "#{sourceUrl}/post",
            queryParams: %{},
            headers: %{}
          },
          assigns: %{date: "2018-01-01"}
        }
      ]

      expected_assigns = ExtractStep.execute_extract_steps(ingestion, steps)

      assert expected_assigns == %{date: "2018-01-01", output_file: {:file, "12345-6789"}}
      assert File.read!("12345-6789") == "this,csv,is only\nattainable,with a,post body\n"
    end

    test "sends through protocols", %{bypass: bypass, ingestion: ingestion, sourceUrl: sourceUrl} do
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
            body: "",
            url: "#{sourceUrl}",
            queryParams: %{},
            headers: %{}
          },
          assigns: %{}
        }
      ]

      expected_assigns = ExtractStep.execute_extract_steps(ingestion, steps)

      assert expected_assigns == %{output_file: {:file, "12345-6789"}}
      assert_called Mint.HTTP.connect(:http, "localhost", any(), transport_opts: [timeout: 30_000], protocols: [:http1])
    end
  end

  describe "execute_extract_steps/2 s3" do
    test "successfully constructs the S3 request", %{ingestion: ingestion} do
      allow Reaper.DataSlurper.S3.slurp(
              "s3://some-bucket/subdir/blaster.exe",
              ingestion.id,
              %{"x-scos-amzn-s3-region": "us-east-2"},
              any(),
              any(),
              any()
            ),
            return: {:file, "somefile2"}

      steps = [
        %{
          type: "s3",
          context: %{
            url: "s3://some-bucket/subdir/blaster.exe",
            queryParams: %{},
            headers: %{
              "x-scos-amzn-s3-region": "us-east-2"
            }
          },
          assigns: %{}
        }
      ]

      expected_assigns = ExtractStep.execute_extract_steps(ingestion, steps)

      assert expected_assigns == %{output_file: {:file, "somefile2"}}
    end
  end

  describe "execute_extract_steps/2 sftp" do
    test "successfully constructs the sftp request", %{ingestion: ingestion} do
      allow Reaper.DataSlurper.Sftp.slurp(
              "sftp://host:port/wow/such/path",
              ingestion.id,
              any(),
              any(),
              any(),
              any()
            ),
            return: {:file, "somefile2"}

      steps = [
        %{
          type: "sftp",
          context: %{
            url: "sftp://{{host}}:{{port}}{{path}}"
          },
          assigns: %{
            path: "/wow/such/path",
            host: "host",
            port: "port"
          }
        }
      ]

      expected_assigns = ExtractStep.execute_extract_steps(ingestion, steps)

      assert expected_assigns == %{
               host: "host",
               output_file: {:file, "somefile2"},
               path: "/wow/such/path",
               port: "port"
             }
    end
  end

  describe "extract steps error paths" do
    test "Set variable then single extract step for http get", %{ingestion: ingestion, sourceUrl: sourceUrl} do
      steps = [
        %{
          type: "date",
          context: %{
            destination: "currentDate",
            deltaTimeUnit: nil,
            deltaTimeValue: nil,
            format: "{WILLFAIL}-{0M}"
          },
          assigns: %{}
        },
        %{
          type: "http",
          context: %{
            url: "#{sourceUrl}/{{currentDate}}",
            queryParams: %{},
            headers: %{}
          },
          assigns: %{}
        }
      ]

      assert_raise RuntimeError, "Unable to process date step for ingestion 12345-6789.", fn ->
        ExtractStep.execute_extract_steps(ingestion, steps)
      end
    end
  end
end
