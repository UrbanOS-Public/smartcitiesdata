defmodule Reaper.DataSlurper.FtpTest do
  use ExUnit.Case
  use Placebo

  describe "DataSlurper.Ftp.slurp/2" do
    setup do
      %{source_url: "ftp://validUser:validPassword@localhost:222/does/not/matter.csv", ingestion_id: "12345-6789"}
    end

    test "handles incorrectly configured ingestion credentials", map do
      ftp_url = "ftp://badUserbadPassword@localhost:222/does/not/matter.csv"

      message = "Ingestion credentials are not in username:password format"

      assert_raise RuntimeError,
                   ~s|Failed calling '#{ftp_url}': "#{message}"|,
                   fn ->
                     Reaper.DataSlurper.Ftp.slurp(ftp_url, map.ingestion_id)
                   end
    end

    test "handles invalid ingestion credentials", map do
      allow :ftp.open(any()),
        return: {:ok, "pid"}

      allow :ftp.user(any(), any(), any()),
        return: {:error, :euser}

      message = "Unable to establish FTP connection: Invalid username or password"

      assert_raise RuntimeError,
                   ~s|Failed calling '#{map.source_url}': "#{message}"|,
                   fn ->
                     Reaper.DataSlurper.Ftp.slurp(map.source_url, map.ingestion_id)
                   end
    end

    test "handles closed session", map do
      allow :ftp.open(any()),
        return: {:error, :eclosed}

      message = "Unable to establish FTP connection: The session is closed"

      assert_raise RuntimeError,
                   ~s|Failed calling '#{map.source_url}': "#{message}"|,
                   fn ->
                     Reaper.DataSlurper.Ftp.slurp(map.source_url, map.ingestion_id)
                   end
    end

    test "handles bad connection", map do
      allow :ftp.open(any()),
        return: {:ok, "pid"}

      allow :ftp.user(any(), any(), any()),
        return: {:error, :econn}

      message = "Unable to establish FTP connection: Connection to the remote server is prematurely closed"

      assert_raise RuntimeError,
                   ~s|Failed calling '#{map.source_url}': "#{message}"|,
                   fn ->
                     Reaper.DataSlurper.Ftp.slurp(map.source_url, map.ingestion_id)
                   end
    end

    test "handles bad host", map do
      allow :ftp.open(any()),
        return: {:error, :ehost}

      message =
        "Unable to establish FTP connection: Host is not found, FTP server is not found, or connection is rejected by FTP server"

      assert_raise RuntimeError,
                   ~s|Failed calling '#{map.source_url}': "#{message}"|,
                   fn ->
                     Reaper.DataSlurper.Ftp.slurp(map.source_url, map.ingestion_id)
                   end
    end

    test "handles bad file path", map do
      allow :ftp.open(any()),
        return: {:ok, "pid"}

      allow :ftp.user(any(), any(), any()),
        return: :ok

      allow :ftp.recv(any(), any(), any()),
        return: {:error, :epath}

      message = "No such file or directory, or directory already exists, or permission denied"

      assert_raise RuntimeError,
                   ~s|Failed calling '#{map.source_url}': "#{message}"|,
                   fn ->
                     Reaper.DataSlurper.Ftp.slurp(map.source_url, map.ingestion_id)
                   end
    end

    test "handles successful file retrieval", map do
      allow :ftp.open(any()),
        return: {:ok, "pid"}

      allow :ftp.user(any(), any(), any()),
        return: :ok

      allow :ftp.recv(any(), any(), map.ingestion_id),
        return: :ok

      message = "No such file or directory, or directory already exists, or permission denied"

      assert {:file, map.ingestion_id} == Reaper.DataSlurper.Ftp.slurp(map.source_url, map.ingestion_id)
    end
  end
end
