defmodule AnomaExplorer.Indexer.GraphQL.QueryBuilder do
  @moduledoc """
  Generic query builder for GraphQL where clauses.

  Provides reusable filter building functions to reduce duplication
  across different entity query modules.
  """

  alias AnomaExplorer.Utils.Formatting

  @doc """
  Builds a where clause string from a list of filter specifications.

  ## Filter Types

  Each filter spec is a tuple of `{key, filter_type, value}` where:
  - `key` is the GraphQL field name (atom or string)
  - `filter_type` is one of: `:eq`, `:ilike`, `:gte`, `:lte`, `:bool`, `:or`
  - `value` is the filter value

  ## Examples

      iex> build_where([{:chainId, :eq, 1}, {:txHash, :ilike, "0x123"}])
      "chainId: {_eq: 1}, txHash: {_ilike: \\"%0x123%\\"}"

      iex> build_where([{:blockNumber, :gte, 100}])
      "blockNumber: {_gte: 100}"
  """
  @spec build_where([{atom() | String.t(), atom(), term()}]) :: String.t()
  def build_where(filters) do
    filters
    |> Enum.map(&build_condition/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.join(", ")
  end

  @doc """
  Adds a chain_id filter if present in options.
  """
  @spec add_chain_id_filter(list(), keyword()) :: list()
  def add_chain_id_filter(conditions, opts) do
    case Keyword.get(opts, :chain_id) do
      nil -> conditions
      "" -> conditions
      id when is_integer(id) -> conditions ++ [{:chainId, :eq, id}]
      id -> conditions ++ [{:chainId, :eq, id}]
    end
  end

  @doc """
  Adds block range filters (block_min, block_max) if present in options.
  """
  @spec add_block_range_filters(list(), keyword()) :: list()
  def add_block_range_filters(conditions, opts) do
    conditions
    |> add_block_min_filter(opts)
    |> add_block_max_filter(opts)
  end

  defp add_block_min_filter(conditions, opts) do
    case Keyword.get(opts, :block_min) do
      nil -> conditions
      "" -> conditions
      min when is_integer(min) -> conditions ++ [{:blockNumber, :gte, min}]
      min -> conditions ++ [{:blockNumber, :gte, min}]
    end
  end

  defp add_block_max_filter(conditions, opts) do
    case Keyword.get(opts, :block_max) do
      nil -> conditions
      "" -> conditions
      max when is_integer(max) -> conditions ++ [{:blockNumber, :lte, max}]
      max -> conditions ++ [{:blockNumber, :lte, max}]
    end
  end

  @doc """
  Adds an ilike filter for a string field if present in options.
  """
  @spec add_ilike_filter(list(), keyword(), atom(), atom()) :: list()
  def add_ilike_filter(conditions, opts, opt_key, field_name) do
    case Keyword.get(opts, opt_key) do
      nil -> conditions
      "" -> conditions
      value -> conditions ++ [{field_name, :ilike, value}]
    end
  end

  @doc """
  Adds a boolean filter if present in options.
  """
  @spec add_bool_filter(list(), keyword(), atom(), atom()) :: list()
  def add_bool_filter(conditions, opts, opt_key, field_name) do
    case Keyword.get(opts, opt_key) do
      nil -> conditions
      true -> conditions ++ [{field_name, :bool, true}]
      false -> conditions ++ [{field_name, :bool, false}]
    end
  end

  @doc """
  Adds an equality filter for a string field if present in options.
  """
  @spec add_eq_filter(list(), keyword(), atom(), atom()) :: list()
  def add_eq_filter(conditions, opts, opt_key, field_name) do
    case Keyword.get(opts, opt_key) do
      nil -> conditions
      "" -> conditions
      value -> conditions ++ [{field_name, :eq_string, value}]
    end
  end

  @doc """
  Adds a nested ilike filter (for fields inside a relationship).
  Example: evmTransaction: {txHash: {_ilike: "%0x123%"}}
  """
  @spec add_nested_ilike_filter(list(), keyword(), atom(), atom(), atom()) :: list()
  def add_nested_ilike_filter(conditions, opts, opt_key, parent_field, field_name) do
    case Keyword.get(opts, opt_key) do
      nil -> conditions
      "" -> conditions
      value -> conditions ++ [{parent_field, :nested_ilike, {field_name, value}}]
    end
  end

  @doc """
  Adds a nested chain_id filter (for fields inside a relationship).
  """
  @spec add_nested_chain_id_filter(list(), keyword(), atom()) :: list()
  def add_nested_chain_id_filter(conditions, opts, parent_field) do
    case Keyword.get(opts, :chain_id) do
      nil -> conditions
      "" -> conditions
      id -> conditions ++ [{parent_field, :nested_eq, {:chainId, id}}]
    end
  end

  @doc """
  Adds nested block range filters (for fields inside a relationship).
  """
  @spec add_nested_block_range_filters(list(), keyword(), atom()) :: list()
  def add_nested_block_range_filters(conditions, opts, parent_field) do
    conditions
    |> add_nested_block_min_filter(opts, parent_field)
    |> add_nested_block_max_filter(opts, parent_field)
  end

  defp add_nested_block_min_filter(conditions, opts, parent_field) do
    case Keyword.get(opts, :block_min) do
      nil -> conditions
      "" -> conditions
      min -> conditions ++ [{parent_field, :nested_gte, {:blockNumber, min}}]
    end
  end

  defp add_nested_block_max_filter(conditions, opts, parent_field) do
    case Keyword.get(opts, :block_max) do
      nil -> conditions
      "" -> conditions
      max -> conditions ++ [{parent_field, :nested_lte, {:blockNumber, max}}]
    end
  end

  # Private: Build individual condition strings
  defp build_condition({field, :eq, value}) when is_integer(value) do
    "#{field}: {_eq: #{value}}"
  end

  defp build_condition({field, :eq, value}) do
    "#{field}: {_eq: #{value}}"
  end

  defp build_condition({field, :eq_string, value}) do
    "#{field}: {_eq: \"#{Formatting.escape_string(value)}\"}"
  end

  defp build_condition({field, :ilike, value}) do
    "#{field}: {_ilike: \"%#{Formatting.escape_string(value)}%\"}"
  end

  defp build_condition({field, :gte, value}) when is_integer(value) do
    "#{field}: {_gte: #{value}}"
  end

  defp build_condition({field, :gte, value}) do
    "#{field}: {_gte: #{value}}"
  end

  defp build_condition({field, :lte, value}) when is_integer(value) do
    "#{field}: {_lte: #{value}}"
  end

  defp build_condition({field, :lte, value}) do
    "#{field}: {_lte: #{value}}"
  end

  defp build_condition({field, :bool, true}) do
    "#{field}: {_eq: true}"
  end

  defp build_condition({field, :bool, false}) do
    "#{field}: {_eq: false}"
  end

  defp build_condition({:_or, :or, clauses}) when is_list(clauses) do
    or_parts = Enum.map(clauses, fn {field, op, value} ->
      build_condition({field, op, value})
    end)
    "_or: [#{Enum.map_join(or_parts, ", ", fn p -> "{#{p}}" end)}]"
  end

  # Nested filters for relationship fields (e.g., evmTransaction: {txHash: {_ilike: "%0x%"}})
  defp build_condition({parent, :nested_ilike, {field, value}}) do
    "#{parent}: {#{field}: {_ilike: \"%#{Formatting.escape_string(value)}%\"}}"
  end

  defp build_condition({parent, :nested_eq, {field, value}}) when is_integer(value) do
    "#{parent}: {#{field}: {_eq: #{value}}}"
  end

  defp build_condition({parent, :nested_eq, {field, value}}) do
    "#{parent}: {#{field}: {_eq: #{value}}}"
  end

  defp build_condition({parent, :nested_gte, {field, value}}) when is_integer(value) do
    "#{parent}: {#{field}: {_gte: #{value}}}"
  end

  defp build_condition({parent, :nested_gte, {field, value}}) do
    "#{parent}: {#{field}: {_gte: #{value}}}"
  end

  defp build_condition({parent, :nested_lte, {field, value}}) when is_integer(value) do
    "#{parent}: {#{field}: {_lte: #{value}}}"
  end

  defp build_condition({parent, :nested_lte, {field, value}}) do
    "#{parent}: {#{field}: {_lte: #{value}}}"
  end

  defp build_condition(_), do: nil
end
