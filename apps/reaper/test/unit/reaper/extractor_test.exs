defmodule Reaper.ExtractorTest do
  use ExUnit.Case
  use Placebo
  alias Reaper.Extractor

  @dataset_id "ds1"

  describe "extract" do
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

    test "downloads csvs to file on local filesystem", %{bypass: bypass} do
      Bypass.stub(bypass, "HEAD", "/1.2/data.csv", fn conn ->
        Plug.Conn.resp(conn, 200, ~s|one,two,three\n1,2,3\n|)
      end)

      Bypass.stub(bypass, "GET", "/1.2/data.csv", fn conn ->
        Plug.Conn.resp(conn, 200, ~s|one,two,three\n1,2,3\n|)
      end)

      {:file, filename} = Extractor.extract("http://localhost:#{bypass.port}/1.2/data.csv", @dataset_id, "batch")

      assert ~s|one,two,three\n1,2,3\n| == File.read!(filename)
    end

    test "downloads csvs to file in download direction when", %{bypass: bypass} do
      Application.put_env(:reaper, :download_dir, "/tmp/")
      on_exit(fn -> Application.delete_env(:reaper, :download_dir) end)

      Bypass.stub(bypass, "HEAD", "/1.2/data.csv", fn conn ->
        Plug.Conn.resp(conn, 200, ~s|one,two,three\n1,2,3\n|)
      end)

      Bypass.stub(bypass, "GET", "/1.2/data.csv", fn conn ->
        Plug.Conn.resp(conn, 200, ~s|one,two,three\n1,2,3\n|)
      end)

      {:file, filename} = Extractor.extract("http://localhost:#{bypass.port}/1.2/data.csv", @dataset_id, "batch")

      assert "/tmp/#{@dataset_id}" == filename
      assert ~s|one,two,three\n1,2,3\n| == File.read!(filename)
    end

    test "follows 302 redirects and downloads csv file to local filesystem", %{bypass: bypass} do
      Bypass.expect(bypass, "HEAD", "/some/csv-file.csv", fn conn ->
        Phoenix.Controller.redirect(conn, external: "http://localhost:#{bypass.port}/some/other/csv-file.csv")
      end)

      Bypass.expect(bypass, "HEAD", "/some/other/csv-file.csv", fn conn ->
        conn
        |> Plug.Conn.resp(200, "")
      end)

      Bypass.expect(bypass, "GET", "/some/other/csv-file.csv", fn conn ->
        Plug.Conn.resp(conn, 200, ~s|one,two,three\n4,5,6\n|)
      end)

      {:file, filename} = Extractor.extract("http://localhost:#{bypass.port}/some/csv-file.csv", @dataset_id, "batch")

      assert ~s|one,two,three\n4,5,6\n| == File.read!(filename)
    end

    test "follows 301 redirects and downloads csv file to local filesystem", %{bypass: bypass} do
      Bypass.expect(bypass, "HEAD", "/some/csv-file.csv", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("location", "http://localhost:#{bypass.port}/some/other/csv-file.csv")
        |> Plug.Conn.resp(301, "")
      end)

      Bypass.expect(bypass, "HEAD", "/some/other/csv-file.csv", fn conn ->
        conn
        |> Plug.Conn.resp(200, "")
      end)

      Bypass.expect(bypass, "GET", "/some/other/csv-file.csv", fn conn ->
        Plug.Conn.resp(conn, 200, ~s|one,two,three\n4,5,6\n|)
      end)

      {:file, filename} = Extractor.extract("http://localhost:#{bypass.port}/some/csv-file.csv", @dataset_id, "batch")

      assert ~s|one,two,three\n4,5,6\n| == File.read!(filename)
    end

    test "When the extractor encounters a redirect it follows it to the source", %{
      bypass: bypass
    } do
      Bypass.stub(bypass, "GET", "/1.1/statuses/update.json", fn conn ->
        conn
        |> Phoenix.Controller.redirect(external: "http://localhost:#{bypass.port}/1.1/statuses/update2.json")
      end)

      Bypass.stub(bypass, "GET", "/1.1/statuses/update2.json", fn conn ->
        Plug.Conn.resp(
          conn,
          200,
          ~s<one,two\n1,2\n>
        )
      end)

      actual = Extractor.extract("http://localhost:#{bypass.port}/1.1/statuses/update.json", @dataset_id, "batch")

      assert actual == ~s<one,two\n1,2\n>
    end

    test "sets timeout when download the file" do
      allow Downstream.get!(any(), any(), any()), return: :ok

      Extractor.extract("http://some.url", @dataset_id, "batch")

      assert_called Downstream.get!("http://some.url", any(), timeout: 600_000)
    end
  end

  describe "failure to extract" do
    test "RuntimeError are bubbled up instead of masked as a match error" do
      assert_raise RuntimeError, fn ->
        Extractor.extract("http://localhost:100/1.1/statuses/update.json", @dataset_id, "json")
      end
    end
  end
end
