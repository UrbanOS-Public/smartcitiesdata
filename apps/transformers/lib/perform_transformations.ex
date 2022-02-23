defmodule Transformers do
  alias SmartCity.Ingestion.Transformation

  def performTransformations(opsList, initial_payload) do
    initial_payload
    # inital_payload -> starting accumulator (message received on the broadway handle_msg)
    # Enum.reduce(opsList, inital_payload, fn op, acc_payload ->
    #   case op.(acc_payload) do
    #     {:ok, result} ->
    #       result

    #     {:error, reason} ->
    #       stop reduce + elevate reason
    #   end
    # end)
  # end
end
