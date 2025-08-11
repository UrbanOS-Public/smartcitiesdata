defmodule Reaper.DataSlurper.S3Test do
  use ExUnit.Case
  import Mox

  @download_dir System.get_env("TMPDIR") || "/tmp/reaper/"
  use TempEnv, reaper: [download_dir: @download_dir]

  setup :verify_on_exit!

  describe "DataSlurper.S3.slurp/2" do
    test "successfully constructs the S3 api request" do
      source_url = "s3://bucket/subdir/file.ext"
      ingestion_id = "12345-6789"
      filename = "#{@download_dir}#{ingestion_id}"

      expect(ExAwsS3Mock, :download_file, fn "bucket", "subdir/file.ext", ^filename -> :download_struct end)
      expect(ExAwsMock, :request, fn :download_struct -> {:ok, :response} end)

      assert {:file, filename} == Reaper.DataSlurper.S3.slurp(source_url, ingestion_id)
    end

    test "sets ExAws region conditionally if x-scos-amzn-s3-region is set in sourceHeaders" do
      source_url = "s3://bucket/subdir/file.ext"
      ingestion_id = "12345-6789"
      filename = "#{@download_dir}#{ingestion_id}"

      expect(ExAwsS3Mock, :download_file, fn "bucket", "subdir/file.ext", ^filename -> :download_struct end)
      expect(ExAwsMock, :request, fn :download_struct, [region: "us-east-1"] -> {:ok, :response} end)

      assert {:file, filename} ==
               Reaper.DataSlurper.S3.slurp(source_url, ingestion_id, %{"x-scos-amzn-s3-region": "us-east-1"})
    end

    test "raises in the event of a download issue" do
      expect(ExAwsS3Mock, :download_file, fn "not_gonna", "work", _ -> :download_struct end)
      expect(ExAwsMock, :request, fn :download_struct -> {:error, "download failed"} end)

      assert_raise RuntimeError, "Error downloading file for not_gonna/work: download failed", fn ->
        Reaper.DataSlurper.S3.slurp("s3://not_gonna/work", "12345-6789")
      end
    end
  end
end
