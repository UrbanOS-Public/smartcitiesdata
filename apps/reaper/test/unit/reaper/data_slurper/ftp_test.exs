defmodule Reaper.DataSlurper.FtpTest do
  use ExUnit.Case
  import Mox

  setup :verify_on_exit!

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
      expect(FtpMock, :open, fn _host -> {:ok, "pid"} end)
      expect(FtpMock, :user, fn "pid", _username, _password -> {:error, :euser} end)

      message = "Unable to establish FTP connection: Invalid username or password"

      assert_raise RuntimeError,
                   ~s|Failed calling '#{map.source_url}': "#{message}"|,
                   fn ->
                     Reaper.DataSlurper.Ftp.slurp(map.source_url, map.ingestion_id)
                   end
    end

    test "handles closed session", map do
      expect(FtpMock, :open, fn _host -> {:error, :eclosed} end)

      message = "Unable to establish FTP connection: The session is closed"

      assert_raise RuntimeError,
                   ~s|Failed calling '#{map.source_url}': "#{message}"|,
                   fn ->
                     Reaper.DataSlurper.Ftp.slurp(map.source_url, map.ingestion_id)
                   end
    end

    test "handles bad connection", map do
      expect(FtpMock, :open, fn _host -> {:ok, "pid"} end)
      expect(FtpMock, :user, fn "pid", _username, _password -> {:error, :econn} end)

      message = "Unable to establish FTP connection: Connection to the remote server is prematurely closed"

      assert_raise RuntimeError,
                   ~s|Failed calling '#{map.source_url}': "#{message}"|,
                   fn ->
                     Reaper.DataSlurper.Ftp.slurp(map.source_url, map.ingestion_id)
                   end
    end

    test "handles bad host", map do
      expect(FtpMock, :open, fn _host -> {:error, :ehost} end)

      message =
        "Unable to establish FTP connection: Host is not found, FTP server is not found, or connection is rejected by FTP server"

      assert_raise RuntimeError,
                   ~s|Failed calling '#{map.source_url}': "#{message}"|,
                   fn ->
                     Reaper.DataSlurper.Ftp.slurp(map.source_url, map.ingestion_id)
                   end
    end

    test "handles bad file path", map do
      expect(FtpMock, :open, fn _host -> {:ok, "pid"} end)
      expect(FtpMock, :user, fn "pid", _username, _password -> :ok end)
      expect(FtpMock, :recv, fn "pid", _path, _filename -> {:error, :epath} end)

      message = "No such file or directory, or directory already exists, or permission denied"

      assert_raise RuntimeError,
                   ~s|Failed calling '#{map.source_url}': "#{message}"|,
                   fn ->
                     Reaper.DataSlurper.Ftp.slurp(map.source_url, map.ingestion_id)
                   end
    end

    test "handles successful file retrieval", map do
      expect(FtpMock, :open, fn _host -> {:ok, "pid"} end)
      expect(FtpMock, :user, fn "pid", _username, _password -> :ok end)
      expect(FtpMock, :recv, fn "pid", _path, filename -> 
        if filename == map.ingestion_id, do: :ok, else: {:error, :epath}
      end)

      assert {:file, map.ingestion_id} == Reaper.DataSlurper.Ftp.slurp(map.source_url, map.ingestion_id)
    end
  end
end
