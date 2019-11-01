defmodule Reaper.DataSlurper.S3Test do
  use ExUnit.Case
  use Placebo

  describe "DataSlurper.S3.slurp/2" do
    setup do
      downloads = Application.get_env(:reaper, :download_dir)
      %{sourceUrl: "s3://bucket/subdir/file.ext", dataset_id: "12345-6789", download_dir: downloads}
    end

    test "successfully constructs the S3 api request", map do
      allow ExAws.S3.download_file(any(), any(), any()), return: :ok
      allow ExAws.request(any()), return: {:ok, any()}

      filename = "#{map.download_dir}#{map.dataset_id}"

      assert {:file, filename} == Reaper.DataSlurper.S3.slurp(map.sourceUrl, map.dataset_id)
      assert_called ExAws.S3.download_file("bucket", "subdir/file.ext", filename)
    end

    test "raises in the event of a download issue" do
      allow ExAws.request(any()), return: {:error, "download failed"}

      assert_raise RuntimeError, "Error downloading file for not_gonna/work: download failed", fn ->
        Reaper.DataSlurper.S3.slurp("s3://not_gonna/work", "12345-6789")
      end
    end
  end
end
