defmodule Odo.InitTest do
  import SmartCity.TestHelper
  use ExUnit.Case
  use Placebo
  alias Odo.FileProcessor

  test "loads all queued files and passes them for conversion" do
    allow(Brook.get_all_values!(:file_conversions),
      return: [%{dataset_id: 1, key: "shapefile1"}, %{dataset_id: 2, key: "shapefile2"}]
    )

    allow(FileProcessor.process(any()), return: :ok)

    {:ok, pid} = Odo.Init.start_link([])

    eventually(fn ->
      assert_called(Brook.get_all_values!(:file_conversions))
      assert_called(FileProcessor.process(%{dataset_id: 1, key: "shapefile1"}))
      assert_called(FileProcessor.process(%{dataset_id: 2, key: "shapefile2"}))
      assert num_calls(FileProcessor.process(any())) == 2
      assert false == Process.alive?(pid)
    end)
  end
end
