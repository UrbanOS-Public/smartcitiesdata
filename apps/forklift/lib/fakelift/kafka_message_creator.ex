defmodule FakeLift.KafkaMessageCreator do
  def create_messages() do
    [
      %{
        key: "thisisakey",
        value: """
        {
          "dataset_id": "bob"
          "data": [
            {
              "id": 1,
              "one": 234234,
              "two": 345363
            }
          ]
        }
        """,
        topic: "topicname",
        partition: 4
      }
    ]
  end
end
