defmodule Valkyrie.InitTest do
  use ExUnit.Case
  use Placebo

  alias SmartCity.TestDataGenerator, as: TDG

  setup do
    allow(Brook.get_all(any(), :datasets),
      return:
      {:ok,
       %{
         "2f3e26b3-89a9-4837-a780-5364587ecbc1" => TDG.create_dataset(%{technical: %{schema: [%{"type" => "string", "name" => "first"}]}}),
         "884bd4be-4d0b-47d2-ac88-069e04f3a0fc" => TDG.create_dataset(%{technical: %{schema: [%{"type" => "string", "name" => "first"}]}})
       }}
    )

    :ok
  end

  test "Creates streams with proper parameters" do
    expect Valkyrie.Stream.Supervisor.start_child("2f3e26b3-89a9-4837-a780-5364587ecbc1"),
      return: :does_not_matter

    expect Valkyrie.Stream.Supervisor.start_child("884bd4be-4d0b-47d2-ac88-069e04f3a0fc"),
      return: :does_not_matter

    Valkyrie.Init.on_start(:does_not_matter)
  end
end
