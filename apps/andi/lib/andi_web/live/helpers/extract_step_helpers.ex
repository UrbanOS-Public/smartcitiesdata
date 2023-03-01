defmodule AndiWeb.Helpers.ExtractStepHelpers do
  @moduledoc """
    Helper functions for common operations pertaining to extract step liveview forms
  """
  import Phoenix.LiveView
  require Logger

  def move_element(list, index, new_index) do
    {extract_step_to_move, remaining_list} = List.pop_at(list, index)

    List.insert_at(remaining_list, new_index, extract_step_to_move)
  end

  def map_to_dropdown_options(options) do
    Enum.map(options, fn {actual_value, description} -> [key: description, value: actual_value] end)
  end

  def update_validation_status(%{assigns: %{validation_status: validation_status, visibility: visibility}} = socket)
      when validation_status in ["valid", "invalid"] or visibility == "collapsed" do
    new_status = get_new_validation_status(socket.assigns.changeset)
    send(socket.parent_pid, {:validation_status, {socket.assigns.extract_step.id, new_status}})
    assign(socket, validation_status: new_status)
  end

  def update_validation_status(%{assigns: %{visibility: visibility}} = socket), do: assign(socket, validation_status: visibility)

  def get_new_validation_status(changeset) do
    case changeset.valid? do
      true -> "valid"
      false -> "invalid"
    end
  end

  def ends_with_http_or_s3_step?(steps) do
    last_step_type = List.last(steps) |> Map.get(:type)
    last_step_type in ["http", "s3"]
  end

  def remove_key_value(key_value_list, id) do
    Enum.reduce_while(key_value_list, key_value_list, fn key_value, acc ->
      case key_value.id == id do
        true -> {:halt, List.delete(key_value_list, key_value)}
        false -> {:cont, acc}
      end
    end)
  end
end
