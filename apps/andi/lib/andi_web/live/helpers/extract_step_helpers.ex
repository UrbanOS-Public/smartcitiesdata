defmodule AndiWeb.Helpers.ExtractStepHelpers do
  @moduledoc """
    Helper functions for common operations pertaining to extract step liveview forms
  """

  def move_element(list, index, new_index) do
    {extract_step_to_move, remaining_list} = List.pop_at(list, index)

    List.insert_at(remaining_list, new_index, extract_step_to_move)
  end
end
