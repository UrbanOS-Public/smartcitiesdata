defmodule Andi.RepostingEventsTest do
  use ExUnit.Case
  use Divo
  use Tesla

  alias SmartCity.TestDataGenerator, as: TDG

  import Andi, only: [instance_name: 0]
  import SmartCity.TestHelper, only: [eventually: 3]

  plug Tesla.Middleware.BaseUrl, "http://localhost:4000"
  @kafka_broker Application.get_env(:andi, :kafka_broker)
  @ou Application.get_env(:andi, :ldap_env_ou)

  setup_all do
    user = Application.get_env(:andi, :ldap_user)
    pass = Application.get_env(:andi, :ldap_pass)
    Paddle.authenticate(user, pass)

    Paddle.add([ou: @ou], objectClass: ["top", "organizationalunit"], ou: @ou)
    wait_for_brook_to_be_ready()
    :ok
  end

  test "reposting organization:update events" do
    create_org()
    create_org()

    wait_for_organization_update_event_count(2)
    wait_for_andi_to_process_events(2)

    post("/api/v1/repost_org_updates", "", headers: [])

    wait_for_organization_update_event_count(4)
  end

  defp wait_for_brook_to_be_ready() do
    Process.sleep(5000)
  end

  defp create_org() do
    org =
      TDG.create_organization(%{})
      |> Map.from_struct()

    org_json = Jason.encode!(org)

    {:ok, _response} = post("/api/v1/organization", org_json, headers: [{"content-type", "application/json"}])
    org
  end

  defp wait_for_andi_to_process_events(count) do
    eventually(
      fn ->
        brook_count =
          Brook.get_all_values(instance_name(), :org)
          |> elem(1)
          |> length()

        assert brook_count == count
      end,
      1000,
      10
    )
  end

  defp wait_for_organization_update_event_count(count) do
    eventually(
      fn ->
        organization_update_count =
          Elsa.Fetch.fetch(@kafka_broker, "event-stream")
          |> elem(2)
          |> Enum.filter(fn message -> message.key == "organization:update" end)
          |> length()

        assert organization_update_count == count
      end,
      100,
      10
    )
  end
end
