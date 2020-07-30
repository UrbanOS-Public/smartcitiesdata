defmodule Kafka.Topic.DestinationDeadLettersTest do
  use ExUnit.Case
  use Placebo

  require Temp.Env
  import Mox
  import AssertAsync

  Temp.Env.modify([
    %{
      app: :definition_kafka,
      key: Kafka.Topic.Destination,
      set: [dlq: DlqMock]
    }
  ])

  setup :set_mox_global

  setup do
    test = self()

    handler = fn event, measurements, metadata, config ->
      send(test, {:telemetry_event, event, measurements, metadata, config})
    end

    :telemetry.attach(__MODULE__, [:destination, :kafka, :write], handler, %{})
    on_exit(fn -> :telemetry.detach(__MODULE__) end)

    allow Elsa.topic?(any(), any()), return: true
    allow Elsa.Supervisor.start_link(any()), return: {:ok, :pid}
    # allow Elsa.Producer.ready?(any()), return: true
    allow Elsa.produce(any(), any(), any(), any()), return: :ok

    Process.flag(:trap_exit, true)

    :ok
  end

  describe "write/2" do
    ### TOODOO: This test only works in elsa 0.12.  Do not want to upgrade to 0.12 as step one of this refactor.
    # test "writes errors to DLQ" do
    #   expect(DlqMock, :write, fn %{app_name: "some-app"} -> :ok end)

    #   context =
    #     Destination.Context.new!(
    #       app_name: "some-app",
    #       dictionary: Dictionary.from_list([]),
    #       dataset_id: "foo",
    #       subset_id: "bar"
    #     )

    #   topic = Kafka.Topic.new!(endpoints: [foo: 123], name: "write-errors")
    #   {:ok, pid} = Destination.start_link(topic, context)

    #   assert :ok = Destination.write(topic, pid, [%{one: 1}, ~r/no/, %{two: 2}])
    #   assert_receive {:telemetry_event, [:destination, :kafka, :write], %{count: 2}, _, _}, 5_000

    #   assert_async debug: true do
    #     try do
    #       Mox.verify!()
    #       true
    #     rescue
    #       _ -> false
    #     end
    #   end
    # end
  end

  # defp verified?() do
  #   case Mox.Server.verify(self(), :all, :test) do
  #     [] -> true
  #     _ -> false
  #   end
  # end
end
