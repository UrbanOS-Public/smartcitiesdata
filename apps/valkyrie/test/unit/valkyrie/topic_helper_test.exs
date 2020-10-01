defmodule Valkyrie.TopicHelperTest do
  use ExUnit.Case
  use Placebo

  alias Valkyrie.TopicHelper
  @input_topic_prefix Application.get_env(:valkyrie, :input_topic_prefix, "raw-")
  @output_topic_prefix Application.get_env(:valkyrie, :output_topic_prefix, "transformed-")

describe "input_topic_name/1" do
    test "should return given dataset_id prefixed with the input topic prefix" do
      dataset_id = Faker.UUID.v4()
      assert "#{@input_topic_prefix}#{dataset_id}" == TopicHelper.input_topic_name(dataset_id)
    end
  end

  describe "output_topic_name/1" do
    test "should return given dataset_id prefixed with the output topic prefix" do
      dataset_id = Faker.UUID.v4()
      assert "#{@output_topic_prefix}#{dataset_id}" == TopicHelper.output_topic_name(dataset_id)
    end
  end

  describe "delete_topics/1" do
    test "should delete input and output topic when the dataset id is provided" do
      dataset_id = Faker.UUID.v4()
      allow(Elsa.delete_topic(any(), any()), return: :ok)

      TopicHelper.delete_topics(dataset_id)

      assert_called(Elsa.delete_topic(TopicHelper.get_endpoints(), "#{@input_topic_prefix}#{dataset_id}"))
      assert_called(Elsa.delete_topic(TopicHelper.get_endpoints(), "#{@output_topic_prefix}#{dataset_id}"))
    end
  end
end
