defmodule Reaper.HostedFileProcessorTest do
  use ExUnit.Case
  use Placebo
  import ExUnit.CaptureLog

  alias Reaper.HostedFileProcessor

  @dataset_id "12345"

  @hosted_file "Some content"

  @download_dir System.get_env("TMPDIR") || "/tmp/reaper/"
  use TempEnv, reaper: [download_dir: @download_dir]

  setup do
    bypass = Bypass.open()

    Bypass.expect(bypass, "GET", "/api/hosted", fn conn ->
      Plug.Conn.resp(conn, 200, @hosted_file)
    end)

    expect(
      ExAws.request(any()),
      return: {:ok, :done},
      meck_options: [:passthrough]
    )

    config =
      FixtureHelper.new_reaper_config(%{
        dataset_id: @dataset_id,
        sourceType: "host",
        sourceFormat: "txt",
        sourceUrl: "http://localhost:#{bypass.port}/api/hosted",
        cadence: 100
      })

    [byass: bypass, config: config]
  end

  describe "process/1 happy path" do
    setup do
      :ok
    end

    test "downloads file and uploads to s3", %{config: config} do
      HostedFileProcessor.process(config)
    end
  end
end
