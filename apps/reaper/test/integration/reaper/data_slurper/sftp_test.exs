defmodule Reaper.SftpExtractorTest do
  use ExUnit.Case
  use Divo
  use Placebo
  use Properties, otp_app: :reaper

  alias SmartCity.TestDataGenerator, as: TDG
  import SmartCity.TestHelper
  import SmartCity.Event, only: [ingestion_update: 0]

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
    ingestion_id = "23456-7891"
    topic = "#{output_topic_prefix()}-#{ingestion_id}"
    Elsa.create_topic(elsa_brokers(), topic)

    ingestion =
      TDG.create_ingestion(%{
        id: ingestion_id,
        cadence: "once",
        sourceQueryParams: %{},
        sourceFormat: "json",
        schema: [
          %{name: "datum"},
          %{name: "sanctum"}
        ],
        extractSteps: [
          %{
            assigns: %{},
            context: %{
              action: "GET",
              body: %{},
              headers: [],
              protocol: nil,
              queryParams: [],
              url: "sftp://#{@sftp.user}:#{@sftp.password}@#{@host}:#{@sftp.port}/upload/file.json"
            },
            type: "sftp"
          }
        ],
        topLevelSelector: nil
      })

    Brook.Event.send(@instance_name, ingestion_update(), :reaper, ingestion)

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
    ingestion_id = "34567-8912"
    topic = "#{output_topic_prefix()}-#{ingestion_id}"
    Elsa.create_topic(elsa_brokers(), topic)

    ingestion =
      TDG.create_ingestion(%{
        id: ingestion_id,
        cadence: "once",
        sourceQueryParams: %{},
        sourceFormat: "csv",
        schema: [
          %{name: "datum"},
          %{name: "sanctum"}
        ],
        extractSteps: [
          %{
            assigns: %{},
            context: %{
              action: "GET",
              body: %{},
              headers: [],
              protocol: nil,
              queryParams: [],
              url: "sftp://#{@sftp.user}:#{@sftp.password}@#{@host}:#{@sftp.port}/upload/file.csv"
            },
            type: "sftp"
          }
        ],
        topLevelSelector: nil
      })

    Brook.Event.send(@instance_name, ingestion_update(), :reaper, ingestion)
    payload = %{"sanctum" => "Bobbero", "datum" => "Alice"}

    eventually(fn ->
      result = TestUtils.get_data_messages_from_kafka(topic, elsa_brokers())
      assert [%{payload: ^payload} | _] = result
    end)
  end
end
