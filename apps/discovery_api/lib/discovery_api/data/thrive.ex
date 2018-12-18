defmodule Models do
  use Riffed.Struct,
    t_c_l_i_service_types: [
      :TOpenSessionReq,
      :TOpenSessionResp,
      :TCloseSessionReq,
      :TCloseSessionResp,
      :TExecuteStatementReq,
      :TExecuteStatementResp,
      :TOperationHandle,
      :TFetchResultsReq,
      :TFetchResultsResp,
      :THandleIdentifier,
      :TSessionHandle,
      :THandleIdentifier,
      :TColumn,
      :TStringColumn,
      :TByteColumn,
      :TRowSet,
      :TI16Column,
      :TI32Column,
      :TDoubleColumn,
      :TStatus
    ]
end

defmodule HiveClient do
  use Riffed.Client,
    structs: Models,
    client_opts: [
      framed: false,
      retries: 10
    ],
    service: :t_c_l_i_service_thrift,
    import: [
      :OpenSession,
      :ExecuteStatement,
      :FetchResults,
      :CloseSession,
      :GetSchemas
    ]
end

defmodule DiscoverApi.Data.Thrive do
  alias DiscoverApi.Data.Thrive.State

  @max_int 2_147_483_647

  def connect(username, password) do
    try do
      {:ok, client} =
        HiveClient.start_link(
          Application.get_env(:discovery_api, :thrive_address),
          Application.get_env(:discovery_api, :thrive_port)
        )

      %{
        sessionHandle: session_handle
      } =
        HiveClient."OpenSession"(client, %Models.TOpenSessionReq{
          username: username,
          password: password,
          configuration: :dict.new()
        })

      {:ok, %State{client: client, session_handle: session_handle}}
    rescue
      e in RuntimeError -> {:error, e}
    end
  end

  def connect() do
    connect(
      Application.get_env(:discovery_api, :thrive_username),
      Application.get_env(:discovery_api, :thrive_password)
    )
  end

  def disconnect(state) do
    %{status: status} =
      HiveClient."CloseSession"(
        state.client,
        %Models.TCloseSessionReq{sessionHandle: state.session_handle}
      )

    {:ok, status}
  end

  def execute_statement(state, query) do
    case HiveClient."ExecuteStatement"(
           state.client,
           %Models.TExecuteStatementReq{
             sessionHandle: state.session_handle,
             statement: query,
             confOverlay: :dict.new()
           }
         ) do
      %{status: %Models.TStatus{statusCode: 0}, operationHandle: operation_handle} ->
        {:ok, operation_handle}

      %{status: %Models.TStatus{sqlState: sql_state, errorCode: error_code}} ->
        {:error, "Error processing Hive query: #{sql_state} | #{error_code}"}
    end
  end

  def fetch_results(state, operation_handle, chunk_size \\ @max_int) do
    case HiveClient."FetchResults"(
           state.client,
           %Models.TFetchResultsReq{
             operationHandle: operation_handle,
             maxRows: chunk_size
           }
         ) do
      %{status: %Models.TStatus{statusCode: 0}, results: results} ->
        parsed_results = parse_results(results)
        {parsed_results, Enum.count(parsed_results) >= chunk_size}

      _ ->
        {["Connection Interrupted"], false}
    end
  end

  def stream_results(query, chunk_size) do
    with {:ok, state} <- connect(),
         {:ok, results} <- get_execution_results(state, query, chunk_size),
         do: {:ok, results}
  end

  defp get_execution_results(state, query, chunk_size) do
    with {:ok, operation_handle} <- execute_statement(state, query) do
      {:ok, build_output_stream(state, operation_handle, chunk_size)}
    else
      {:error, reason} ->
        disconnect(state)
        {:error, reason}
    end
  end

  defp build_output_stream(state, operation_handle, chunk_size) do
    Stream.resource(
      fn -> true end,
      fn more_data ->
        if more_data do
          fetch_results(state, operation_handle, chunk_size)
        else
          {:halt, more_data}
        end
      end,
      fn _ ->
        disconnect(state)
      end
    )
  end

  def parse_results(results) do
    results
    |> Map.get(:columns)
    |> Enum.map(fn column ->
      Map.from_struct(column)
      |> Map.values()
      |> Enum.filter(&filter_undefined/1)
      |> List.first()
      |> Map.get(:values)
    end)
    |> Enum.zip()
  end

  defp filter_undefined(result) do
    result != nil && result != :undefined
  end
end
