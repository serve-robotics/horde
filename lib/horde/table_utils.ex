defmodule Horde.TableUtils do
  @moduledoc false

  @spec new_table(atom()) :: :ets.tid()
  def new_table(name) do
    :ets.new(name, [:set, :protected])
  end

  @spec size_of(:ets.tid()) :: non_neg_integer()
  def size_of(table) do
    :ets.info(table, :size)
  end

  @spec get_item(:ets.tid(), term()) :: term() | nil
  def get_item(table, id) do
    case :ets.lookup(table, id) do
      [{_, item}] -> item
      [] -> nil
    end
  end

  @spec delete_item(:ets.tid(), term()) :: :ets.tid()
  def delete_item(table, id) do
    :ets.delete(table, id)
    table
  end

  @spec pop_item(:ets.tid(), term()) :: {term() | nil, :ets.tid()}
  def pop_item(table, id) do
    item = get_item(table, id)
    delete_item(table, id)
    {item, table}
  end

  @spec put_item(:ets.tid(), term(), term()) :: :ets.tid()
  def put_item(table, id, item) do
    :ets.insert(table, {id, item})
    table
  end

  @spec all_items_values(:ets.tid()) :: [term()]
  def all_items_values(table) do
    :ets.select(table, [{{:"$1", :"$2"}, [], [:"$2"]}])
  end

  @spec any_item(:ets.tid(), (term() -> boolean())) :: boolean()
  def any_item(table, predicate) do
    try do
      :ets.safe_fixtable(table, true)
      first_key = :ets.first(table)
      ets_any?(table, predicate, first_key)
    after
      :ets.safe_fixtable(table, false)
    end
  end

  @spec ets_any?(:ets.tid(), (term() -> boolean()), term()) :: boolean()
  def ets_any?(_table, _predicate, :"$end_of_table") do
    false
  end

  def ets_any?(table, predicate, key) do
    entry = get_item(table, key)

    if predicate.(entry) do
      true
    else
      ets_any?(table, predicate, :ets.next(table, key))
    end
  end
end
