defmodule Odo.InitTest do
  import SmartCity.TestHelper
  use ExUnit.Case
  use Placebo
  alias Odo.FileProcessor

  test "loads all queued files and passes them for conversion" do
    conversion_map_1 = %Odo.ConversionMap{
      bucket: "bucket1",
      original_key: "key1",
      converted_key: "converted_key1",
      download_path: "download_path1",
      converted_path: "converted_path1",
      conversion: &Geomancer.geo_json/1,
      dataset_id: "dataset1"
    }

    conversion_map_2 = %Odo.ConversionMap{
      bucket: "bucket2",
      original_key: "key2",
      converted_key: "converted_key2",
      download_path: "download_path2",
      converted_path: "converted_path2",
      conversion: &Geomancer.geo_json/1,
      dataset_id: "dataset2"
    }

    allow(Brook.get_all_values!(:file_conversions),
      return: [conversion_map_1, conversion_map_2]
    )

    allow(FileProcessor.process(any()), return: :ok)

    {:ok, pid} = Odo.Init.start_link([])

    eventually(fn ->
      assert_called(Brook.get_all_values!(:file_conversions))
      assert_called(FileProcessor.process(conversion_map_1))
      assert_called(FileProcessor.process(conversion_map_2))
      assert num_calls(FileProcessor.process(any())) == 2
      assert false == Process.alive?(pid)
    end)
  end
end
