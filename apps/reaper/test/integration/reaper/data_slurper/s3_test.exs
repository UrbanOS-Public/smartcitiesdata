defmodule Reaper.S3ExtractorTest do
  use ExUnit.Case
  use Divo
  alias SmartCity.TestDataGenerator, as: TDG
  import SmartCity.TestHelper
  import SmartCity.Event, only: [file_ingest_end: 0]

  @bucket Application.get_env(:reaper, :hosted_file_bucket)
  @org "my-org"
  @instance Reaper.Application.instance()
  @id "geojson-dataset"
  @endpoints Application.get_env(:reaper, :elsa_brokers)

  describe "ingestion from s3" do
    setup do
      shapefile_dataset = TDG.create_dataset(id: @id, technical: %{sourceFormat: "zip"})

      Brook.Test.with_event(
        @instance,
        fn ->
          Brook.ViewState.merge(:file_ingestions, shapefile_dataset.id, shapefile_dataset)
        end
      )

      {:ok, file} =
        SmartCity.HostedFile.new(%{
          dataset_id: @id,
          bucket: @bucket,
          key: "#{@org}/my-data.geojson",
          mime_type: "application/geo+json"
        })

      Brook.Event.send(@instance, file_ingest_end(), :odo, file)
    end

    test "previously hosted file is converted from file:ingest:end event" do
      eventually(fn ->
        assert Brook.get!(@instance, :extractions, @id) != nil

        {:ok, _, messages} = Elsa.fetch(@endpoints, "raw-#{@id}", partition: 0)
        assert Enum.all?(messages, fn %Elsa.Message{value: value} -> String.contains?(value, "geojson-dataset") end)
      end)
    end
  end
end
