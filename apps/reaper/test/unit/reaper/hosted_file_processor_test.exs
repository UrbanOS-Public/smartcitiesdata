defmodule Reaper.HostedFileProcessorTest do
  use ExUnit.Case
  use Placebo

  alias Reaper.HostedFileProcessor
  alias Reaper.Persistence

  @dataset_id "12345"

  @download_dir System.get_env("TMPDIR") || "/tmp/reaper/"
  use TempEnv, reaper: [download_dir: @download_dir]

  setup do
    expect(
      ExAws.request(any()),
      return: {:ok, :done},
      meck_options: [:passthrough]
    )

    expect(Persistence.record_last_fetched_timestamp("12345", any()),
      return: :ok
    )

    config =
      FixtureHelper.new_reaper_config(%{
        dataset_id: @dataset_id,
        sourceType: "host",
        sourceFormat: "txt",
        sourceUrl: "http://localhost/api/hosted",
        cadence: 100
      })

    [config: config]
  end

  describe "process/1 happy path" do
    setup do
      :ok
    end

    test "downloads file and uploads to s3", %{config: config} do
      expect(Reaper.DataSlurper.slurp(config.sourceUrl, config.dataset_id, any(), any()), meck_options: [:passthrough])
      expect(ExAws.S3.upload(any(), any(), "#{config.orgName}/#{config.dataName}.txt"), meck_options: [:passthrough])
      expect(ExAws.request(any()))

      HostedFileProcessor.process(config)
    end
  end
end
