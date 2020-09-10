defmodule Reaper.DataExtract.ExtractStepTest do
  use ExUnit.Case

  alias SmartCity.TestDataGenerator, as: TDG
  alias Reaper.DataExtract.ExtractStep
  alias Reaper.Cache.AuthCache

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

      steps =
        [%{
          type: "auth",
          context: %{
            # action: "POST",  # TODO: do we need this
            path: ["sub", "path"],
            destination: "token",
            url: "http://localhost:#{bypass.port}",
            encodeMethod: "json",
            body: %{Key: "AuthToken"},
            headers: %{},
            cacheTtl: nil
          },
          assigns: %{}
        }]

      assigns = ExtractStep.execute_extract_steps(dataset, steps)

      assert assigns == %{token: "auth_token"}
    end

    test "fails with a reasonable error message", %{bypass: bypass, dataset: dataset} do
      Cachex.start(AuthCache.cache_name())
      Cachex.clear(AuthCache.cache_name())

      Bypass.stub(bypass, "POST", "/", fn conn ->
           Plug.Conn.resp(conn, 403, "No dice")
      end)

      steps =
        [%{
          type: "auth",
          context: %{
            # action: "POST",  # TODO: do we need this
            path: ["sub", "path"],
            destination: "token",
            url: "http://localhost:#{bypass.port}",
            encodeMethod: "json",
            body: %{Key: "AuthToken"},
            headers: %{},
            cacheTtl: nil
          },
          assigns: %{}
        }]


      assert_raise RuntimeError, "Unable to process auth step for dataset 12345-6789.", fn ->
        ExtractStep.execute_extract_steps(dataset, steps)
      end
    end
    test "Can use assigns block for body", %{bypass: bypass, dataset: dataset} do
      Cachex.start(AuthCache.cache_name())
      Cachex.clear(AuthCache.cache_name())

      Bypass.stub(bypass, "POST", "/", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed = Jason.decode!(body)
        case parsed do
          %{"Key" => "super secret"} -> Plug.Conn.resp(conn, 200, %{sub: %{path: "auth_token"}} |> Jason.encode!)
          _ -> Plug.Conn.resp(conn, 403, "No dice")
        end
      end)

      steps =
        [%{
          type: "auth",
          context: %{
            # action: "POST",  # TODO: do we need this
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
        }]

      assigns = ExtractStep.execute_extract_steps(dataset, steps)

      assert assigns == %{key: "super secret", token: "auth_token"}
    end
    test "Can use assigns block for headers", %{bypass: bypass, dataset: dataset} do
      Cachex.start(AuthCache.cache_name())
      Cachex.clear(AuthCache.cache_name())

      Bypass.stub(bypass, "POST", "/headers", fn conn ->
        if(Enum.any?(conn.req_headers, fn header -> header == {"header", "super secret"} end)) do
          Plug.Conn.resp(conn, 200,  %{sub: %{path: "auth_token"}} |> Jason.encode!)
        else
          Plug.Conn.resp(conn, 401, "Unauthorized")
        end
      end)

      steps =
        [%{
          type: "auth",
          context: %{
            # action: "POST",  # TODO: do we need this
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
        }]

      assigns = ExtractStep.execute_extract_steps(dataset, steps)

      assert assigns == %{header: "super secret", token: "auth_token"}
    end
    test "Can use assigns block for url", %{bypass: bypass, dataset: dataset} do
      Cachex.start(AuthCache.cache_name())
      Cachex.clear(AuthCache.cache_name())

      Bypass.stub(bypass, "POST", "/fancyurl", fn conn ->
          Plug.Conn.resp(conn, 200,  %{sub: %{path: "auth_token"}} |> Jason.encode!)
      end)

      steps =
        [%{
          type: "auth",
          context: %{
            # action: "POST",  # TODO: do we need this
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
        }]

      assigns = ExtractStep.execute_extract_steps(dataset, steps)

      assert assigns == %{path: "fancyurl", token: "auth_token"}
    end
  end
end
