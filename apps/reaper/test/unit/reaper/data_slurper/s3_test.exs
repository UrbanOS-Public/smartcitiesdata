defmodule Reaper.DataSlurper.S3Test do
  use ExUnit.Case
  use Placebo

  @download_dir System.get_env("TMPDIR") || "/tmp/reaper/"
  use TempEnv, reaper: [download_dir: @download_dir]

  describe "DataSlurper.S3.slurp/2" do
    test "successfully constructs the S3 api request" do
      allow ExAws.S3.download_file(any(), any(), any()), return: :ok
      allow ExAws.request(any()), return: {:ok, any()}

      source_url = "s3://bucket/subdir/file.ext"
      ingestion_id = "12345-6789"
      filename = "#{@download_dir}#{ingestion_id}"

      assert {:file, filename} == Reaper.DataSlurper.S3.slurp(source_url, ingestion_id)
      assert_called ExAws.S3.download_file("bucket", "subdir/file.ext", filename)
    end

    test "sets ExAws region conditionally if x-scos-amzn-s3-region is set in sourceHeaders" do
      allow ExAws.S3.download_file(any(), any(), any()), return: :ok
      allow ExAws.request(any(), any()), return: {:ok, any()}

      source_url = "s3://bucket/subdir/file.ext"
      ingestion_id = "12345-6789"
      filename = "#{@download_dir}#{ingestion_id}"

      assert {:file, filename} ==
               Reaper.DataSlurper.S3.slurp(source_url, ingestion_id, %{"x-scos-amzn-s3-region": "us-east-1"})

      assert_called ExAws.request(any(), region: "us-east-1")
      refute_called ExAws.request(any(), [])
    end

    test "raises in the event of a download issue" do
      allow ExAws.request(any()), return: {:error, "download failed"}

      assert_raise RuntimeError, "Error downloading file for not_gonna/work: download failed", fn ->
        Reaper.DataSlurper.S3.slurp("s3://not_gonna/work", "12345-6789")
      end
    end
  end
end
