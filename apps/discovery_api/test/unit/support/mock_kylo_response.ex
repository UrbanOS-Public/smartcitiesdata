defmodule DiscoveryApi.Test.MockKyloResponse do
  def feedmgr_response() do
    ~s({"data": [
      { "id": "14fca5cd-2ddd-46dd-9380-01e9c35c674f"
      },
      { "id": "57eac648-729c-44f5-89f2-d446ce2a4d68"
      }
    ]})
  end

  def feedmgr_id_response_with_keywords() do
    ~s(
      { "id": "57eac648-729c-44f5-89f2-d446ce2a4d68",
      "feedName": "input invoice",
      "systemFeedName": "input_invoice",
      "description": "Quo aspernatur rerum voluptas natus ratione suscipit. Occaecati temporibus quibusdam fugit. Minus consequuntur adipisci. Velit molestias minus ratione expedita. Unde voluptatum distinctio officia voluptatem. Dolorem quibusdam quia et rem harum odio magni inventore.",
      "updateDate": "a while back",
      "userProperties": [
        {
          "systemName": "publisher.name",
          "value": "Slime Jime"
        }
      ],
      "keywords": [
        {
          "name": "bar"
        },
        {
          "name": "foo"
        }
        ]
      }
    )
  end

  def feedmgr_id_response_without_keywords() do
    ~s(
      { "id": "14fca5cd-2ddd-46dd-9380-01e9c35c674f",
      "feedName": "Swiss Franc Cotton",
      "systemFeedName": "Swiss_Franc_Cotton",
      "description": "Neque soluta architecto consequatur earum ipsam molestiae tempore at dolorem. Similique consectetur cum.",
      "updateDate": "recently"
      }
    )
  end
end
