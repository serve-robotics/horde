defmodule Horde.ClusterTransport do
  @moduledoc """
  Behaviour for cluster communication primitives.

  Allows Horde to work with both standard Erlang distribution and
  alternative transports like Partisan.

  Configure per registry/supervisor via the `:transport` option:

      {Horde.Registry, name: MyRegistry, keys: :unique,
       transport: Horde.ClusterTransport.Partisan}
  """

  @doc "Returns all connected peer nodes."
  @callback members() :: [node()]

  @doc "Returns true if the given pid is alive on its node."
  @callback process_alive?(pid()) :: boolean()

  @doc "Call a function on a remote node."
  @callback call(node(), module(), atom(), [term()], timeout()) :: term()
end
