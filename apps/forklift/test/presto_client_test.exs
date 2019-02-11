defmodule PrestoClientTest do
  use ExUnit.Case
  use Placebo

  alias Forklift.PrestoClient
  alias Prestige

  test "upload_data sends a valid statement to prestige" do
    allow(Prestige.execute(any(), catalog: "hive", schema: "default"), return: :ok )

    expected_statement = ~s/insert into placeholder_id (id,name) values (123,'bob'),(234,'cob'),(345,'dob')/

    messages = [
      ~s({
        \"id\":\"123\",
        \"name\":\"bob\"
      }),
      ~s({
        \"id\":\"234\",
        \"name\":\"cob\"
      }),
      ~s({
        \"id\":\"345\",
        \"name\":\"dob\"
      }),
    ]

    PrestoClient.upload_data("placeholder_id", messages)

    assert_called Prestige.execute(expected_statement, catalog: "hive", schema: "default"), once()
  end

end
