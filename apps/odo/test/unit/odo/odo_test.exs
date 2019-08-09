defmodule Odo.Unit.OdoTest do
  use ExUnit.Case
  import SmartCity.Event, only: [file_upload: 0]
  alias SmartCity.Event.FileUpload

  test "raises an error on unsupported file type" do
    {:ok, bad_event} =
      FileUpload.new(%{
        dataset_id: 111,
        mime_type: "application/zip",
        bucket: "hosted-files",
        key: "my-org/my-dataset.foo"
      })

    assert_raise RuntimeError, "Unable to convert file; unsupported type", fn ->
      Odo.FileProcessor.process(bad_event)
    end
  end
end
