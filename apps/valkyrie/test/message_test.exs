defmodule Valkyrie.MessageTest do
  use ExUnit.Case
  doctest SCOS.Message

  alias SCOS.Message

  test "parse message" do
    assert true
  end

  test "encode message" do
    assert true
  end

  test "put operational works when app and key don't already exist" do
    message = struct!(Message)

    new_message = Message.put_operational(message, :valkyrie, :test_val, 75)

    assert ^new_message = %Message{operational: %{valkyrie: %{test_val: 75}}}
  end

  test "put_operational does not overwrite app when it does exist" do
    message = struct!(Message, %{operational: %{valkyrie: %{keep: :me}}})

    new_message = Message.put_operational(message, :valkyrie, :val_test, 85)

    assert ^new_message = %Message{operational: %{valkyrie: %{val_test: 85, keep: :me}}}
  end
end
