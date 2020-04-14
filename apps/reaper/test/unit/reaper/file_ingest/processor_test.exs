defmodule Reaper.FileIngest.ProcessorTest do
  use ExUnit.Case
  use Placebo

  alias Reaper.FileIngest.Processor
  alias SmartCity.HostedFile

  alias SmartCity.TestDataGenerator, as: TDG
  import SmartCity.Event, only: [file_ingest_end: 0]
  import Mox

  @dataset_id "12345"
  @bucket Application.get_env(:reaper, :hosted_file_bucket)
  @instance Reaper.Application.instance()

  @download_dir System.get_env("TMPDIR") || "/tmp/reaper/"
  @source_url "http://localhost/api/hosted"
  use TempEnv, reaper: [download_dir: @download_dir]

  setup do
    expect(ExAws.request(any()), return: {:ok, :done}, meck_options: [:passthrough])

    Providers.Echo
    |> expect(:provide, 1, fn _, %{value: value} -> value end)

    :ok
  end

  describe "process/1 happy path" do
    test "downloads file and uploads to s3" do
      dataset =
        TDG.create_dataset(
          id: @dataset_id,
          technical: %{
            sourceType: "host",
            sourceFormat: "txt",
            sourceUrl: @source_url,
            cadence: 100
          }
        )

      expect(Reaper.DataSlurper.slurp(@source_url, dataset.id, any(), any()),
        meck_options: [:passthrough],
        return: {:file, "filename"}
      )

      expect(
        ExAws.S3.upload(
          any(),
          any(),
          "#{dataset.technical.orgName}/#{dataset.technical.dataName}.txt"
        ),
        meck_options: [:passthrough]
      )

      expect(Brook.Event.send(any(), any(), any(), any()), return: :ok)

      Processor.process(dataset)

      expected_file_upload = %HostedFile{
        dataset_id: dataset.id,
        mime_type: "text/plain",
        bucket: @bucket,
        key: "#{dataset.technical.orgName}/#{dataset.technical.dataName}.txt"
      }

      assert_called(Brook.Event.send(@instance, file_ingest_end(), :reaper, expected_file_upload))
    end

    test "downloads file with a provisioned url and uploads to s3" do
      dataset =
        TDG.create_dataset(
          id: @dataset_id,
          technical: %{
            sourceType: "host",
            sourceFormat: "txt",
            sourceUrl: %{
              provider: "Echo",
              opts: %{value: @source_url},
              version: "1"
            },
            cadence: 100
          }
        )

      expect(Reaper.DataSlurper.slurp(@source_url, dataset.id, any(), any()),
        meck_options: [:passthrough],
        return: {:file, "filename"}
      )

      expect(
        ExAws.S3.upload(
          any(),
          any(),
          "#{dataset.technical.orgName}/#{dataset.technical.dataName}.txt"
        ),
        meck_options: [:passthrough]
      )

      expect(Brook.Event.send(any(), any(), any(), any()), return: :ok)

      Processor.process(dataset)

      expected_file_upload = %HostedFile{
        dataset_id: dataset.id,
        mime_type: "text/plain",
        bucket: @bucket,
        key: "#{dataset.technical.orgName}/#{dataset.technical.dataName}.txt"
      }

      assert_called(Brook.Event.send(@instance, file_ingest_end(), :reaper, expected_file_upload))
    end
  end
end
