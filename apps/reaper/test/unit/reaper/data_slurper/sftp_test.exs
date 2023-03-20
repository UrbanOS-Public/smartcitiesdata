defmodule Reaper.DataSlurper.SftpTest do
  use ExUnit.Case
  use Placebo

  describe "DataSlurper.Sftp.slurp/2" do
    setup do
      %{source_url: "sftp://localhost:222/does/not/matter.csv", ingestion_id: "12345-6789"}
    end

    test "handles incorrectly configured ingestion credentials", map do
      ftp_url = "sftp://badUserbadPassword@localhost:222/does/not/matter.csv"

      message = "Ingestion credentials are not in username:password format"

      assert_raise RuntimeError,
                   ~s|Failed calling '#{ftp_url}': "#{message}"|,
                   fn ->
                     Reaper.DataSlurper.Sftp.slurp(ftp_url, map.ingestion_id)
                   end
    end
  end
end
