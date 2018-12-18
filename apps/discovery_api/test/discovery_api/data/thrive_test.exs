defmodule DiscoverApi.Data.ThriveTest do
  use ExUnit.Case
  use Placebo
  alias DiscoverApi.Data.Thrive

  setup do
    Application.put_env(:discovery_api, :thrive_address, :address)
    Application.put_env(:discovery_api, :thrive_port, :port)
    Application.put_env(:discovery_api, :thrive_username, :username)
    Application.put_env(:discovery_api, :thrive_password, :password)
  end

  describe "Thrive.connect" do
    test "with username and password, it opens session and returns a session id" do
      username = "nothive"
      password = "whonko"

      custom_open_session_request = %{
        username: username,
        password: password,
        configuration: :dict.new()
      }

      expect(HiveClient.start_link(:address, :port), return: {:ok, :client_pid})

      expect(HiveClient."OpenSession"(:client_pid, custom_open_session_request),
        return: mock_open_session_response()
      )

      assert {:ok, get_common_state()} == Thrive.connect(username, password)
    end

    test "without username and password, it opens session and returns a session id" do
      expect(HiveClient.start_link(:address, :port), return: {:ok, :client_pid})

      expect(HiveClient."OpenSession"(:client_pid, mock_open_session_request()),
        return: mock_open_session_response()
      )

      assert {:ok, get_common_state()} == Thrive.connect()
    end

    test "when start_link fails, returns error and reason" do
      allow(
        HiveClient.start_link(:address, :port),
        exec: fn _, _ -> raise RuntimeError, message: "raisins" end
      )

      assert {:error, %RuntimeError{message: "raisins"}} == Thrive.connect()
    end

    test "when open_session fails, returns error and reason" do
      allow(HiveClient.start_link(:address, :port), return: {:ok, :client_pid})

      allow(HiveClient."OpenSession"(:client_pid, mock_open_session_request()),
        exec: fn _, _ -> raise RuntimeError, message: "craisins" end
      )

      assert {:error, %RuntimeError{message: "craisins"}} == Thrive.connect()
    end
  end

  describe "Thrive.disconnect" do
    test "with a state, disconnects the client session in that state" do
      expect(HiveClient."CloseSession"(:client_pid, %{sessionHandle: :session_handle}),
        return: expected_disconnect_response()
      )

      assert {:ok, %{statusCode: 0}} == Thrive.disconnect(get_common_state())
    end
  end

  describe "execute statement" do
    test "execute statement returns an operation handle" do
      expect(
        HiveClient."ExecuteStatement"(:client_pid, %{
          sessionHandle: :session_handle,
          statement: :query,
          confOverlay: :dict.new()
        }),
        return: get_common_execute_response()
      )

      assert {:ok, :operation_handle} == Thrive.execute_statement(get_common_state(), :query)
    end

    test "when statement execution fails, an error message is returned" do
      expect(
        HiveClient."ExecuteStatement"(:client_pid, %{
          sessionHandle: :session_handle,
          statement: :query,
          confOverlay: :dict.new()
        }),
        return: %{
          status: %Models.TStatus{
            statusCode: 3,
            infoMessages: [],
            sqlState: "SQLSTATE",
            errorCode: 9,
            errorMessage: "bad stuff happened"
          },
          operationHandle: nil
        }
      )

      assert {:error, "Error processing Hive query: SQLSTATE | 9"} ==
               Thrive.execute_statement(get_common_state(), :query)
    end
  end

  describe "Thrive.fetch_results" do
    test "fetches all values from the query results" do
      expect(
        HiveClient."FetchResults"(:client_pid, %{operationHandle: :operation_handle, maxRows: 2_147_483_647}),
        return: %{status: %Models.TStatus{statusCode: 0}, results: get_common_fetch_response(), hasMoreRows: false}
      )

      assert {get_common_expected_data(), false} == Thrive.fetch_results(get_common_state(), :operation_handle)
    end

    test "returns error code and reason if the fetch fails" do
      expect(
        HiveClient."FetchResults"(:client_pid, %{operationHandle: :operation_handle, maxRows: 2_147_483_647}),
        return: %{hasMoreRows: false, status: %{statusCode: 3}}
      )

      assert {["Connection Interrupted"], false} == Thrive.fetch_results(get_common_state(), :operation_handle)
    end
  end

  describe "Thrive.parse_results" do
    test "parse thrift results to a sane format" do
      results = get_common_fetch_response()

      expected_data = get_common_expected_data()

      assert expected_data == Thrive.parse_results(results)
    end
  end

  describe "Thrive.stream_results" do
    test "connects, streams and disconnects" do
      expect(
        HiveClient.start_link(:address, :port),
        return: {:ok, :client_pid}
      )

      expect(
        HiveClient."OpenSession"(:client_pid, mock_open_session_request()),
        return: mock_open_session_response()
      )

      expect(
        HiveClient."ExecuteStatement"(:client_pid, %{
          sessionHandle: :session_handle,
          statement: :query,
          confOverlay: :dict.new()
        }),
        return: get_common_execute_response()
      )

      expect(
        HiveClient."FetchResults"(:client_pid, %{operationHandle: :operation_handle, maxRows: 1_000}),
        return: %{status: %Models.TStatus{statusCode: 0}, results: get_common_fetch_response(), hasMoreRows: false}
      )

      expect(
        HiveClient."CloseSession"(:client_pid, %{sessionHandle: :session_handle}),
        return: expected_disconnect_response()
      )

      {:ok, actual} = Thrive.stream_results(:query, 1_000)
      assert(actual |> Enum.to_list() == get_common_expected_data())
    end

    test "when a post-connection error state occurs it disconnects session" do
      allow(
        HiveClient.start_link(:address, :port),
        return: {:ok, :client_pid}
      )

      allow(
        HiveClient."OpenSession"(:client_pid, mock_open_session_request()),
        return: mock_open_session_response()
      )

      allow(
        HiveClient."ExecuteStatement"(:client_pid, %{
          sessionHandle: :session_handle,
          statement: :query,
          confOverlay: :dict.new()
        }),
        return: %{
          status: %Models.TStatus{
            statusCode: 3,
            infoMessages: [],
            sqlState: "SQUIRRELSTATE",
            errorCode: 10,
            errorMessage: "bad stuff happened"
          },
          operationHandle: nil
        }
      )

      expect(
        HiveClient."CloseSession"(:client_pid, %{sessionHandle: :session_handle}),
        return: expected_disconnect_response()
      )

      assert {:error, "Error processing Hive query: SQUIRRELSTATE | 10"} == Thrive.stream_results(:query, 1_000)
    end
  end

  defp get_common_state() do
    %Thrive.State{
      client: :client_pid,
      session_handle: :session_handle
    }
  end

  defp get_common_execute_response() do
    %{
      status: %Models.TStatus{statusCode: 0},
      operationHandle: :operation_handle
    }
  end

  defp get_common_expected_data() do
    [
      {1, "a"},
      {2, "b"},
      {3, "c"}
    ]
  end

  defp get_common_fetch_response() do
    %{
      startRowOffset: 0,
      rows: [],
      columns: [
        %Models.TColumn{
          byteVal: %{
            values: [
              1,
              2,
              3
            ]
          }
        },
        %Models.TColumn{
          stringVal: %{
            values: [
              "a",
              "b",
              "c"
            ]
          }
        }
      ]
    }
  end

  def mock_open_session_request() do
    %{
      username: :username,
      password: :password,
      configuration: :dict.new()
    }
  end

  def mock_open_session_response() do
    %{
      sessionHandle: :session_handle
    }
  end

  def expected_disconnect_response do
    %{
      status: %{
        statusCode: 0
      }
    }
  end
end
