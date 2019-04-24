defmodule SftpTest do
  use ExUnit.Case
  use Divo
  alias SmartCity.Dataset
  alias SmartCity.TestDataGenerator, as: TDG

  @sftp %{host: 'localhost', port: 2222, user: 'username', password: 'password'}

  setup _context do
    {:ok, conn} = SftpEx.connect(host: @sftp.host, port: @sftp.port, user: @sftp.user, password: @sftp.password)
    json_data = Jason.encode!([%{datum: "Bobber", sanctum: "Alice"}])
    SftpEx.upload(conn, "./upload/file.json", json_data)

    csv_data = "Alice,Bobbero\nCharlesque,Deltor\n"

    SftpEx.upload(conn, "./upload/file.csv", csv_data)

    :ok
  end

  test "reaps a json file from sftp" do
    dataset_id = "23456-7891"

    dataset =
      TDG.create_dataset(%{
        id: dataset_id,
        technical: %{
          cadence: 1_000,
          sourceUrl: "sftp://localhost:#{@sftp.port}/upload/file.json",
          sourceFormat: "json"
        }
      })

    Dataset.write(dataset)

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

  test "reaps a csv file from sftp" do
    dataset_id = "23456-7892"

    dataset =
      TDG.create_dataset(%{
        id: dataset_id,
        technical: %{
          cadence: 1_000,
          sourceUrl: "sftp://localhost:#{@sftp.port}/upload/file.csv",
          sourceFormat: "csv",
          schema: [
            %{name: "datum"},
            %{name: "sanctum"}
          ]
        }
      })

    Dataset.write(dataset)

    Patiently.wait_for!(
      fn ->
        result =
          dataset_id
          |> TestUtils.fetch_relevant_messages()
          |> List.first()

        case result do
          nil -> false
          message -> message["datum"] == "Alice"
        end
      end,
      dwell: 1000,
      max_tries: 20
    )
  end
end
