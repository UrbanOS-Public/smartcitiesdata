defmodule Reaper.Http.DownloaderTest do
  use ExUnit.Case
  use Placebo

  alias Plug.Conn
  alias Reaper.Http.Downloader

  setup do
    [bypass: Bypass.open()]
  end

  test "downloads the file correctly", %{bypass: bypass} do
    on_exit(fn -> File.rm("test.output") end)

    Bypass.stub(bypass, "GET", "/file/to/download", fn conn ->
      conn = Conn.send_chunked(conn, 200)

      Enum.reduce_while(~w|each chunk as a word|, conn, fn chunk, acc ->
        case Conn.chunk(acc, chunk) do
          {:ok, conn} -> {:cont, conn}
          {:error, :closed} -> {:halt, conn}
        end
      end)
    end)

    {:ok, response} = Downloader.download("http://localhost:#{bypass.port}/file/to/download", to: "test.output")

    assert "eachchunkasaword" == File.read!("test.output")
    assert response.status == 200
    assert response.destination == "test.output"
    assert response.done == true
    assert response.url == "http://localhost:#{bypass.port}/file/to/download"
  end

  test "raises an error when unable to connect", %{bypass: bypass} do
    on_exit(fn -> File.rm("fake.file") end)
    Bypass.down(bypass)

    {:error, reason} = Downloader.download("http://localhost:#{bypass.port}/file/to/download.csv", to: "fake.file")

    assert reason == Mint.TransportError.exception(reason: :econnrefused)
  end

  test "raises an error when request returns a non 200 status code", %{bypass: bypass} do
    on_exit(fn -> File.rm("test.output") end)

    Bypass.expect(bypass, fn conn ->
      Conn.send_resp(conn, 404, "Not Found")
    end)

    {:error, reason} = Downloader.download("http://localhost:#{bypass.port}/file/to/download", to: "test.output")

    assert reason == Downloader.InvalidStatusError.exception(message: "Invalid status code: 404", status: 404)
  end

  test "raises an error when request is made" do
    allow Mint.HTTP.connect(any(), any(), any(), any()), return: {:ok, :connection}
    allow Mint.HTTP.request(:connection, any(), any(), any()), return: {:error, :connection, "some error"}
    allow Mint.HTTP.close(any()), return: :ok

    {:error, reason} = Downloader.download("http://some.url", to: "test.output")

    assert reason == "some error"
    assert_called Mint.HTTP.close(:connection), once()
  end

  test "raises an error when processing a stream message" do
    on_exit(fn -> File.rm("test.output") end)
    allow Mint.HTTP.connect(any(), any(), any(), any()), return: {:ok, :connection}
    allow Mint.HTTP.request(:connection, any(), any(), any()), return: {:ok, :connection, :ref}
    allow Mint.HTTP.stream(:connection, any()), return: {:error, :connection, "some error", []}
    allow Mint.HTTP.close(any()), return: :ok

    send(self(), :message1)
    {:error, reason} = Downloader.download("http://some.url", to: "test.output")

    assert reason == "some error"
  end

  test "handles 301 redirects", %{bypass: bypass} do
    on_exit(fn -> File.rm("test.output") end)

    Bypass.stub(bypass, "GET", "/some/file.csv", fn conn ->
      conn
      |> Conn.put_resp_header("location", "http://localhost:#{bypass.port}/some/other/file.csv")
      |> Conn.send_resp(301, "")
    end)

    Bypass.stub(bypass, "GET", "/some/other/file.csv", fn conn ->
      Conn.send_resp(conn, 200, "howdy")
    end)

    Downloader.download("http://localhost:#{bypass.port}/some/file.csv", to: "test.output")

    assert "howdy" == File.read!("test.output")
  end

  test "handles 302 redirects", %{bypass: bypass} do
    on_exit(fn -> File.rm("test.output") end)

    Bypass.stub(bypass, "GET", "/some/file.csv", fn conn ->
      conn
      |> Conn.put_resp_header("location", "http://localhost:#{bypass.port}/some/other/file.csv")
      |> Conn.send_resp(302, "")
    end)

    Bypass.stub(bypass, "GET", "/some/other/file.csv", fn conn ->
      Conn.send_resp(conn, 200, "howdy")
    end)

    Downloader.download("http://localhost:#{bypass.port}/some/file.csv", to: "test.output")

    assert "howdy" == File.read!("test.output")
  end

  test "passes connect timeout to tcp library" do
    allow Mint.HTTP.connect(any(), any(), any(), any()), return: {:error, :not_found}

    Downloader.download("http://localhost/some/file.csv", to: "test.output", connect_timeout: 60_000)

    assert_called Mint.HTTP.connect(:http, "localhost", 80, transport_opts: [timeout: 60_000]), once()
  end

  test "only waits idle_timeout to receive message from process queue" do
    allow Mint.HTTP.connect(any(), any(), any(), any()), return: {:ok, :connection}
    allow Mint.HTTP.request(:connection, any(), any(), any()), return: {:ok, :connection, :ref}
    allow Mint.HTTP.close(any()), return: :ok

    result = Downloader.download("http://localhost/some.file", to: "test.output", idle_timeout: 50)

    error =
      Downloader.IdleTimeoutError.exception(
        timeout: 50,
        message: "Idle timeout was reached while attempting to download http://localhost/some.file"
      )

    assert {:error, error} == result
  end

  test "evaluate paramaters in headers" do
    allow Mint.HTTP.connect(any(), any(), any(), any()), return: {:ok, :connection}
    allow Mint.HTTP.request(:connection, any(), any(), any()), return: {:ok}
    allow Mint.HTTP.close(any()), return: :ok

    headers = %{
      "testKey" => "<%= Date.to_iso8601(~D[1970-01-02], :basic) %>",
      "testB" => "valB"
    }

    evaluated_headers = %{"testKey" => "19700102", "testB" => "valB"}

    {:ok} = Downloader.download("http://some.url", headers, to: "test.output")

    assert_called Mint.HTTP.request(:connection, any(), any(), evaluated_headers), once()
  end
end
