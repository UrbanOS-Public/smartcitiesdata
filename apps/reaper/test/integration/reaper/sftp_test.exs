defmodule SftpTest do
  use ExUnit.Case
  use Divo
  use Placebo
  alias SmartCity.Dataset
  alias SmartCity.TestDataGenerator, as: TDG

  @sftp %{host: 'localhost', port: 2222, user: 'sftp_user', password: 'sftp_password'}

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

    allow Reaper.CredentialRetriever.retrieve(any()),
      return: {:ok, %{username: "sftp_user", password: "sftp_password"}}

    dataset =
      TDG.create_dataset(%{
        id: dataset_id,
        technical: %{
          cadence: 1_000,
          sourceUrl: "sftp://localhost:#{@sftp.port}/upload/file.json",
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
          sourceUrl: "sftp://localhost:#{@sftp.port}/upload/file.csv",
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

  test "handles failure to retrieve any dataset credentials" do
    dataset_id = "34567-8934"
    source_url = "sftp://localhost:#{@sftp.port}/upload/file.csv"
    allow Reaper.CredentialRetriever.retrieve(any()), return: {:error, :retrieve_credential_failed}

    dataset =
      TDG.create_dataset(%{
        id: dataset_id,
        technical: %{
          cadence: 1_000,
          sourceUrl: source_url,
          queryParams: %{},
          sourceFormat: "csv",
          schema: [
            %{name: "datum"},
            %{name: "sanctum"}
          ]
        }
      })

    Dataset.write(dataset)

    assert Reaper.SftpExtractor.extract(dataset_id, source_url) == {:error, :retrieve_credential_failed}
  end

  test "handles incorrectly configured dataset credentials" do
    dataset_id = "45678-9456"
    source_url = "sftp://localhost:#{@sftp.port}/upload/file.csv"
    allow Reaper.CredentialRetriever.retrieve(any()), return: {:ok, %{api_key: "q4587435o43759o47597"}}

    dataset =
      TDG.create_dataset(%{
        id: dataset_id,
        technical: %{
          cadence: 1_000,
          sourceUrl: source_url,
          queryParams: %{},
          sourceFormat: "csv",
          schema: [
            %{name: "datum"},
            %{name: "sanctum"}
          ]
        }
      })

    Dataset.write(dataset)

    assert Reaper.SftpExtractor.extract(dataset_id, source_url) ==
             {:error, "Dataset credentials are not of the correct type"}
  end
end
