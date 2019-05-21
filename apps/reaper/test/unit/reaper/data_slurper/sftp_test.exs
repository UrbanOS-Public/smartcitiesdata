defmodule Reaper.DataSlurper.SftpTest do
  use ExUnit.Case
  use Placebo

  describe "DataSlurper.Sftp.slurp/2" do
    setup do
      %{source_url: "sftp://localhost:222/does/not/matter.csv", dataset_id: "12345-6789"}
    end

    test "handles failure to retrieve any dataset credentials", map do
      allow Reaper.CredentialRetriever.retrieve(any()), return: {:error, :retrieve_credential_failed}
      allow SftpEx.connect(any())

      assert_raise RuntimeError,
                   ~s|Failed calling '#{map.source_url}': :retrieve_credential_failed|,
                   fn ->
                     Reaper.DataSlurper.Sftp.slurp(map.source_url, map.dataset_id)
                   end
    end

    test "handles incorrectly configured dataset credentials", map do
      allow Reaper.CredentialRetriever.retrieve(any()), return: {:ok, %{api_key: "q4587435o43759o47597"}}

      message = "Dataset credentials are not of the correct type"

      assert_raise RuntimeError,
                   ~s|Failed calling '#{map.source_url}': "#{message}"|,
                   fn ->
                     Reaper.DataSlurper.Sftp.slurp(map.source_url, map.dataset_id)
                   end
    end
  end
end
