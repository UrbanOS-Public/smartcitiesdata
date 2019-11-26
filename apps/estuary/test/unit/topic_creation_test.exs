defmodule TopicCreationTest do
  use ExUnit.Case
  use Placebo

  test "Does somethign cool when elsa cant connect to kafka" do
    allow(Elsa.create_topic(any(), any()), return: :error)

    assert TopicHelper.create_topic("topic") == :error
  end
end
