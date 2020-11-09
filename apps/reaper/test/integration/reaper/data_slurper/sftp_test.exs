defmodule Reaper.SftpExtractorTest do
  use ExUnit.Case
  use Divo
  use Placebo
  use Properties, otp_app: :reaper

  alias SmartCity.TestDataGenerator, as: TDG
  import SmartCity.TestHelper
  import SmartCity.Event, only: [dataset_update: 0]

  @host to_charlist(System.get_env("HOST"))
  @instance_name Reaper.instance_name()
  @sftp %{host: @host, port: 2222, user: 'sftp_user', password: 'sftp_password'}

  getter(:elsa_brokers, generic: true)
  getter(:output_topic_prefix, generic: true)

  setup do
    {:ok, conn} =
      SftpEx.connect(
        host: @sftp.host,
        port: @sftp.port,
        user: @sftp.user,
        password: @sftp.password
      )

    json_data = Jason.encode!([%{datum: "Bobber", sanctum: "Alice"}])
    SftpEx.upload(conn, "./upload/file.json", json_data)

    csv_data = "Alice,Bobbero\nCharlesque,Deltor\n"
    SftpEx.upload(conn, "./upload/file.csv", csv_data)

    :ok
  end

  test "reaps a json file from sftp" do
    dataset_id = "23456-7891"
    topic = "#{output_topic_prefix()}-#{dataset_id}"
    Elsa.create_topic(elsa_brokers(), topic)

    allow(Reaper.SecretRetriever.retrieve_dataset_credentials(any()),
      return: {:ok, %{"username" => "sftp_user", "password" => "sftp_password"}}
    )

    dataset =
      TDG.create_dataset(%{
        id: dataset_id,
        technical: %{
          cadence: "once",
          sourceUrl: "sftp://#{@host}:#{@sftp.port}/upload/file.json",
          sourceQueryParams: %{},
          sourceFormat: "json",
          schema: [
            %{name: "datum"},
            %{name: "sanctum"}
          ]
        }
      })

    Brook.Event.send(@instance_name, dataset_update(), :reaper, dataset)

    payload = %{
      "datum" => "Bobber",
      "sanctum" => "Alice"
    }

    eventually(fn ->
      result = TestUtils.get_data_messages_from_kafka(topic, elsa_brokers())

      assert [%{payload: ^payload} | _] = result
    end)
  end

  test "reaps a csv file from sftp" do
    dataset_id = "34567-8912"
    topic = "#{output_topic_prefix()}-#{dataset_id}"
    Elsa.create_topic(elsa_brokers(), topic)

    allow(Reaper.SecretRetriever.retrieve_dataset_credentials(any()),
      return: {:ok, %{"username" => "sftp_user", "password" => "sftp_password"}}
    )

    dataset =
      TDG.create_dataset(%{
        id: dataset_id,
        technical: %{
          cadence: "once",
          sourceUrl: "sftp://#{@host}:#{@sftp.port}/upload/file.csv",
          sourceQueryParams: %{},
          sourceFormat: "csv",
          schema: [
            %{name: "datum"},
            %{name: "sanctum"}
          ]
        }
      })

    Brook.Event.send(@instance_name, dataset_update(), :reaper, dataset)
    payload = %{"sanctum" => "Bobbero", "datum" => "Alice"}

    eventually(fn ->
      result = TestUtils.get_data_messages_from_kafka(topic, elsa_brokers())
      assert [%{payload: ^payload} | _] = result
    end)
  end
end
