defmodule Reaper.SftpExtractorTest do
  use ExUnit.Case
  use Divo
  use Placebo
  alias SmartCity.Dataset
  alias SmartCity.TestDataGenerator, as: TDG

  @host to_charlist(System.get_env("HOST"))

  @sftp %{host: @host, port: 2222, user: 'sftp_user', password: 'sftp_password'}

  setup do
    {:ok, conn} = SftpEx.connect(host: @sftp.host, port: @sftp.port, user: @sftp.user, password: @sftp.password)
    json_data = Jason.encode!([%{datum: "Bobber", sanctum: "Alice"}])
    SftpEx.upload(conn, "./upload/file.json", json_data)

    csv_data = "Alice,Bobbero\nCharlesque,Deltor\n"
    SftpEx.upload(conn, "./upload/file.csv", csv_data)

    :ok
  end

  test "reaps a json file from sftp" do
    dataset_id = "23456-7891"

    allow Reaper.CredentialRetriever.retrieve(any()),
      return: {:ok, %{username: "sftp_user", password: "sftp_password"}}

    dataset =
      TDG.create_dataset(%{
        id: dataset_id,
        technical: %{
          cadence: 1_000,
          sourceUrl: "sftp://#{@host}:#{@sftp.port}/upload/file.json",
          queryParams: %{},
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

    allow Reaper.CredentialRetriever.retrieve(any()),
      return: {:ok, %{username: "sftp_user", password: "sftp_password"}}

    dataset =
      TDG.create_dataset(%{
        id: dataset_id,
        technical: %{
          cadence: 1_000,
          sourceUrl: "sftp://#{@host}:#{@sftp.port}/upload/file.csv",
          queryParams: %{},
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
