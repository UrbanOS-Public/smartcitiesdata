defmodule ThriftTest do
  use ExUnit.Case
  alias Models
  alias DiscoverApi.Data.Thrive

  describe "thrift_client" do
      Application.put_env(:discovery_api, :thrive_address, "10.197.76.99")
      Application.put_env(:discovery_api, :thrive_port, 10_000)
      Application.put_env(:discovery_api, :thrive_username, "hive")
      Application.put_env(:discovery_api, :thrive_password, "whonko")

      test "should work" do
        # profile do
          # {:ok, state} = Thrive.connect()

          # {:ok, operation_handle} =
          #   Thrive.execute_statement(
          #     state,
          #     "select * from berp.big_file limit 200"
          #     # "select * from stuff2"
          #   )
          #   |> IO.inspect()
          # IO.inspect(operation_handle)

          # file = File.stream!("a.txt")

          # Thrive.stream_results(state, operation_handle, 20)
          # |> Stream.map(&Tuple.to_list(&1))
          # |> Stream.map(&Enum.join(&1, ","))
          # |> Stream.map(fn x -> x <> "\n" end)
          # |> Stream.into(File.stream!("a.txt"))
          # |> Stream.run()

          # Thrive.disconnect(state)
        # end
      end
  end

  # test "should work raw" do
  #   profile do
  #     {:ok, tfactory} = :thrift_socket_transport.new_transport_factory('10.197.76.99', 10_000, [])
  #     {:ok, pfactory} = :thrift_binary_protocol.new_protocol_factory(tfactory, [])
  #     {:ok, protocol} = pfactory.()
  #     {:ok, client} = :thrift_client.new(protocol, :t_c_l_i_service_thrift)

  #     {client, {:ok, {:TOpenSessionResp, _status, _, session, _}}} =
  #       :thrift_client.call(client, :OpenSession, [{:TOpenSessionReq, 7, 'hive', 'notset', :dict.new()}])

  #     {client, {:ok, {:TExecuteStatementResp, _status, operation_handle}}} =
  #       :thrift_client.call(client, :ExecuteStatement, [
  #         {:TExecuteStatementReq, session, 'select * from test.big_file limit 200000', :dict.new(), false}
  #       ])

  #     IO.inspect(_status)

  #     Stream.map(1..10, fn x ->
  #     {client, {:ok, results}} =
  #       :thrift_client.call(client, :FetchResults, [
  #         {:TFetchResultsReq, operation_handle, 0, 20000, 0}
  #       ])
  #     end)
  #     |> Stream.run()

  #     {client, {:ok, {:TCloseSessionResp, _status}}} =
  #       :thrift_client.call(client, :CloseSession, [{:TCloseSessionReq, session}])
  #   end
  # end
  # end
end
