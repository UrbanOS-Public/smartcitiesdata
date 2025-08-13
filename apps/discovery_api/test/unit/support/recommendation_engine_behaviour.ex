defmodule RecommendationEngineBehaviour do
  @moduledoc """
  Behaviour for the RecommendationEngine module to enable mocking
  """
  
  @callback save(any()) :: any()
  @callback delete(any()) :: any()
  @callback get_recommendations(any()) :: any()
end