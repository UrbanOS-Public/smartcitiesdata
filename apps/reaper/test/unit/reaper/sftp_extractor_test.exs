defmodule Reaper.SftpExtractorTest do
  use ExUnit.Case
  use Placebo

  describe "SftpExtractor.extract/2" do
    setup do
      %{source_url: "sftp://localhost:222/does/not/matter.csv", dataset_id: "12345-6789"}
    end

    test "handles failure to retrieve any dataset credentials", map do
      allow Reaper.CredentialRetriever.retrieve(any()), return: {:error, :retrieve_credential_failed}
      allow SftpEx.connect(any())

      Reaper.SftpExtractor.extract(map.source_url, map.dataset_id)
      refute_called SftpEx.connect(any())
    end

    test "handles incorrectly configured dataset credentials", map do
      allow Reaper.CredentialRetriever.retrieve(any()), return: {:ok, %{api_key: "q4587435o43759o47597"}}

      assert Reaper.SftpExtractor.extract(map.source_url, map.dataset_id) ==
               {:error, "Dataset credentials are not of the correct type"}
    end
  end
end
