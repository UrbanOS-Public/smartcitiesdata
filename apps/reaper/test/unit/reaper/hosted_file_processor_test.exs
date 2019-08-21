defmodule Reaper.HostedFileProcessorTest do
  use ExUnit.Case
  use Placebo

  alias Reaper.HostedFileProcessor
  alias Reaper.Persistence
  alias SmartCity.Event.FileUpload

  @dataset_id "12345"
  @bucket Application.get_env(:reaper, :hosted_file_bucket)

  @download_dir System.get_env("TMPDIR") || "/tmp/reaper/"
  use TempEnv, reaper: [download_dir: @download_dir]

  setup do
    expect ExAws.request(any()), return: {:ok, :done}, meck_options: [:passthrough]
    expect Persistence.record_last_fetched_timestamp("12345", any()), return: :ok

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
    test "downloads file and uploads to s3", %{config: config} do
      expect Reaper.DataSlurper.slurp(config.sourceUrl, config.dataset_id, any(), any()), meck_options: [:passthrough]
      expect ExAws.S3.upload(any(), any(), "#{config.orgName}/#{config.dataName}.txt"), meck_options: [:passthrough]
      expect Brook.Event.send(any(), any(), any()), return: :ok

      HostedFileProcessor.process(config)

      expected_file_upload = %FileUpload{
        dataset_id: config.dataset_id,
        mime_type: "text/plain",
        bucket: @bucket,
        key: "#{config.orgName}/#{config.dataName}.#{config.sourceFormat}"
      }

      assert_called Brook.Event.send("file:upload", :reaper, expected_file_upload)
    end
  end
end
