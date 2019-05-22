defmodule Reaper.DataSlurper.HttpTest do
  use ExUnit.Case
  use Placebo
  alias Reaper.DataSlurper

  @dataset_id "12345-23729"

  describe "slurp" do
    setup do
      bypass = Bypass.open()
      filename = @dataset_id

      on_exit(fn ->
        if File.exists?(filename) do
          File.rm(filename)
        end
      end)

      {:ok, bypass: bypass}
    end

    test "downlaods http urls file on local filesystem", %{bypass: bypass} do
      setup_get(bypass, "/1.2/data.csv", ~s|one,two,three\n1,2,3\n|)

      {:file, filename} = DataSlurper.Http.slurp("http://localhost:#{bypass.port}/1.2/data.csv", @dataset_id)

      assert ~s|one,two,three\n1,2,3\n| == File.read!(filename)
    end

    test "downloads http urls to file in download directory when", %{bypass: bypass} do
      Application.put_env(:reaper, :download_dir, "/tmp/")
      on_exit(fn -> Application.delete_env(:reaper, :download_dir) end)

      setup_get(bypass, "/1.2/data.csv", ~s|one,two,three\n1,2,3\n|)

      {:file, filename} = DataSlurper.Http.slurp("http://localhost:#{bypass.port}/1.2/data.csv", @dataset_id)

      assert "/tmp/#{@dataset_id}" == filename
      assert ~s|one,two,three\n1,2,3\n| == File.read!(filename)
    end

    test "follows 302 redirects and downloads file to local filesystem", %{bypass: bypass} do
      setup_redirect(bypass, "/some/csv-file.csv", "/some/other/csv-file.csv")
      setup_get(bypass, "/some/other/csv-file.csv", ~s|one,two,three\n4,5,6\n|)

      {:file, filename} = DataSlurper.Http.slurp("http://localhost:#{bypass.port}/some/csv-file.csv", @dataset_id)

      assert ~s|one,two,three\n4,5,6\n| == File.read!(filename)
    end

    test "follows 301 redirects and downloads file to local filesystem", %{bypass: bypass} do
      setup_redirect(bypass, "/some/csv-file.csv", "/some/other/csv-file.csv", status_code: 301)
      setup_get(bypass, "/some/other/csv-file.csv", ~s|one,two,three\n4,5,6\n|)

      {:file, filename} = DataSlurper.Http.slurp("http://localhost:#{bypass.port}/some/csv-file.csv", @dataset_id)

      assert ~s|one,two,three\n4,5,6\n| == File.read!(filename)
    end

    test "sets timeout when downloading the file", %{bypass: bypass} do
      Application.put_env(:reaper, :http_download_timeout, 1)
      on_exit(fn -> Application.delete_env(:reaper, :http_download_timeout) end)

      allow Reaper.Http.Downloader.download(any(), any()),
        exec: fn _, _ ->
          Process.sleep(1_000)
        end

      url = "http://localhost:#{bypass.port}/some/johnson.csv"

      expected_message = "Timed out downloading dataset #{@dataset_id} at #{url} in 1 ms"

      assert_raise DataSlurper.Http.HttpDownloadTimeoutError, expected_message, fn ->
        DataSlurper.Http.slurp(url, @dataset_id)
      end
    end
  end

  defp setup_redirect(bypass, path, redirect_path, opts \\ []) do
    status_code = Keyword.get(opts, :status_code, 302)
    url = "http://localhost:#{bypass.port}#{redirect_path}"

    Bypass.stub(bypass, "GET", path, fn conn ->
      case status_code do
        302 ->
          Phoenix.Controller.redirect(conn, external: url)

        301 ->
          conn
          |> Plug.Conn.put_resp_header("location", url)
          |> Plug.Conn.resp(301, "")
      end
    end)
  end

  defp setup_get(bypass, path, data) do
    Bypass.stub(bypass, "GET", path, fn conn ->
      Plug.Conn.resp(conn, 200, data)
    end)
  end
end
