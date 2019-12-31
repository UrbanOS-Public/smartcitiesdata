# defmodule DataWriter do
#   @moduledoc false

#   @callback init(args :: any()) :: :ok | {:error, term()}

#   @callback write(args :: any()) :: :ok | {:error, term()}
# end

# # defmodule Pipeline.Writer do
# #   @callback init(args :: any()) :: :ok | {:error, term()}
# # end

# # defmodule Pipeline.Reader do
# #   # init_args = [instance: any(), connection: any(), endpoints: any(), topic: any(), handler: any()]
# #   @callback init(args :: any()) :: :ok | {:error, term()}
# # end
# # init_args

# # defmodule Client do
# #   @callback start_link :: {:ok, client_id :: String.t}
# #   def start_link do
# #     client_id = "some_id"
# #     clean_session = true
# #   end
# # end
