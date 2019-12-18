defmodule Odo.InitTest do
  import SmartCity.TestHelper
  use ExUnit.Case
  use Placebo
  alias Odo.FileProcessor
  alias SmartCity.HostedFile

  test "loads all queued files and passes them for conversion" do
    file_1 = %HostedFile{
      bucket: "bucket1",
      key: "key1.shapefile",
      mime_type: "application/zip",
      dataset_id: "dataset1"
    }

    file_2 = %HostedFile{
      bucket: "bucket2",
      key: "key2.shp",
      mime_type: "application/zip",
      dataset_id: "dataset2"
    }

    allow(Brook.get_all_values!(Odo.event_stream_instance(), :file_conversions),
      return: [file_1, file_2]
    )

    allow(FileProcessor.process(any()), return: :ok)

    {:ok, pid} = Odo.Init.start_link([])

    eventually(fn ->
      assert_called(Brook.get_all_values!(Odo.event_stream_instance(), :file_conversions))
      assert_called(FileProcessor.process(any()), times(2))
      assert false == Process.alive?(pid)
    end)
  end
end
