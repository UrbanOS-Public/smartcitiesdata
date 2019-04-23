defmodule SftpTest do
  use ExUnit.Case
  use Divo
  alias SmartCity.Dataset
  alias SmartCity.TestDataGenerator, as: TDG

  @sftp Application.get_env(:sftp, :connection)

  setup _context do
    {:ok, conn} = SftpEx.connect(host: @sftp.host, port: @sftp.port, user: @sftp.user, password: @sftp.password)
    SftpEx.upload(conn, "./upload/file.json", Jason.encode!(%{datum: "Bobber", sanctum: "Alice"}))
    :ok
  end

  test "reaps a file from sftp" do
    dataset_id = "23456-7891"

    json_dataset =
      TDG.create_dataset(%{
        id: dataset_id,
        technical: %{
          cadence: 1_000,
          sourceUrl: "sftp://localhost:#{@sftp.port}/upload/file.json",
          sourceFormat: "json"
        }
      })

    Dataset.write(json_dataset)

    Patiently.wait_for!(
      fn ->
        result =
          dataset_id
          |> TestUtils.fetch_relevant_messages()
          |> List.first()

        case result do
          nil -> false
          message -> message["datum"] == "Bobber"
        end
      end,
      dwell: 1000,
      max_tries: 20
    )
  end
end
