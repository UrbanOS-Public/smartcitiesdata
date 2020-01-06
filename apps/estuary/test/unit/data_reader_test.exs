defmodule Estuary.DataReaderTest do
  use ExUnit.Case

  import Mox

  alias Estuary.DataReader

  setup :set_mox_global
  setup :verify_on_exit!

  test "should read the event" do
    expect(MockReader, :init, fn _ -> :ok end)
    expected_value = :ok

    actual_value = DataReader.init()

    assert expected_value == actual_value
  end
end
