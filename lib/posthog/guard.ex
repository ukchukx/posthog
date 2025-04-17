defmodule Posthog.Guard do
  @moduledoc """
  Custom guards for the Posthog library.

  This module contains guard expressions that can be used across the Posthog library
  for consistent pattern matching and type checking.
  """

  @doc """
  Guard that checks if a term is a keyword list.

  A keyword list is a list of 2-tuples where the first element of each tuple
  is an atom.

  ## Examples

      iex> import Posthog.Guard
      iex> match?({:ok, val} when is_keyword_list(val), {:ok, [foo: 1, bar: 2]})
      true
      iex> match?({:ok, val} when is_keyword_list(val), {:ok, [{:a, 1}, {:b, 2}]})
      true
      iex> match?({:ok, val} when is_keyword_list(val), {:ok, [{1, 2}, {3, 4}]})
      false
  """
  defguard is_keyword_list(term)
           when is_list(term) and length(term) > 0 and
                  elem(hd(term), 0) |> is_atom() and tuple_size(hd(term)) == 2
end
