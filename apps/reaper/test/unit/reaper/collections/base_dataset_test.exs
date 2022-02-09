defmodule Reaper.Collections.BaseDatasetTest do
  use ExUnit.Case
  use Placebo
  use Properties, otp_app: :reaper

  require Logger

  @instance_name Reaper.instance_name()

  alias Reaper.Collections.Extractions
  alias SmartCity.TestDataGenerator, as: TDG

  getter(:brook, generic: true)

  setup do
    {:ok, brook} = Brook.start_link(brook() |> Keyword.put(:instance, @instance_name))

    Brook.Test.register(@instance_name)

    on_exit(fn ->
      kill(brook)
    end)

    :ok
  end

  describe "is_enabled?/1" do
    test "a dataset that is not in the view state is not enabled" do
      assert false == Extractions.is_enabled?("not-there?")
    end

    test "a dataset that has no definition in the view state is not enabled" do
      id = "almost-there"

      Brook.Test.with_event(@instance_name, fn ->
        Extractions.update_started_timestamp(id)
      end)

      assert false == Extractions.is_enabled?(id)
    end

    test "a dataset that has no definition in the view state, but has its enabled flag explicitly set, reflects it" do
      id = "explicitly-there"

      Brook.Test.with_event(@instance_name, fn ->
        Brook.ViewState.merge(:extractions, id, %{"enabled" => true})
      end)

      assert true == Extractions.is_enabled?(id)
    end

    @tag :skip
    test "a dataset that has a definition in the view state (via update), but has no enabled flag explicitly set IS enabled" do
      dataset = TDG.create_dataset(%{})

      Brook.Test.with_event(@instance_name, fn ->
        Extractions.update_dataset(dataset)
      end)

      assert true == Extractions.is_enabled?(dataset.id)
    end

    test "an ingestion that has a definition in the view state (via update), but has no enabled flag explicitly set IS enabled" do
      ingestion = TDG.create_ingestion(%{})

      Brook.Test.with_event(@instance_name, fn ->
        Extractions.update_ingestion(ingestion)
      end)

      assert true == Extractions.is_enabled?(ingestion.id)
    end

    @tag :skip
    test "a dataset that has a definition in the view state (via update), but has its enabled flag explicitly set, reflects that" do
      dataset = TDG.create_dataset(%{})

      Brook.Test.with_event(@instance_name, fn ->
        Extractions.update_dataset(dataset)
        Extractions.disable_dataset(dataset.id)
      end)

      assert false == Extractions.is_enabled?(dataset.id)
    end

    test "a ingestion that has a definition in the view state (via update), but has its enabled flag explicitly set, reflects that" do
      ingestion = TDG.create_ingestion(%{})

      Brook.Test.with_event(@instance_name, fn ->
        Extractions.update_ingestion(ingestion)
        Extractions.disable_ingestion(ingestion.id)
      end)

      assert false == Extractions.is_enabled?(ingestion.id)
    end
  end

  defp kill(pid) do
    ref = Process.monitor(pid)
    Process.exit(pid, :normal)
    assert_receive {:DOWN, ^ref, _, _, _}
  end
end
