defmodule AndiWeb.Helpers.TransformationHelpers do
  @moduledoc """
    Helper functions for common operations pertaining to transformation liveview forms
  """
  require Logger

  def move_element(list, index, new_index) do
    {extract_step_to_move, remaining_list} = List.pop_at(list, index)

    List.insert_at(remaining_list, new_index, extract_step_to_move)
  end

end
