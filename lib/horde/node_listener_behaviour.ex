defmodule Horde.NodeListenerBehaviour do
  @moduledoc """
  A behaviour for cluster membership managers.

  Use this module to build a custom node listener with sensible defaults:

      defmodule MyNodeListener do
        use Horde.NodeListenerBehaviour

        @impl Horde.NodeListenerBehaviour
        def make_members(cluster),
          do: Enum.map(Node.list([:visible, :this]), &{cluster, &1})
      end

  The `use` macro injects default implementations of all callbacks. The only
  required callback to override is `make_members/1`. All others are overridable.
  """

  @doc "Returns the member list for the given cluster."
  @callback make_members(cluster :: atom()) :: [{atom(), node()}]

  @doc "Called when a node comes up."
  @callback handle_nodeup(node :: node(), cluster :: atom()) :: atom()

  @doc "Called when a node goes down."
  @callback handle_nodedown(node :: node(), cluster :: atom()) :: atom()

  @optional_callbacks handle_nodeup: 2, handle_nodedown: 2

  defmacro __using__(_opts) do
    quote do
      @behaviour Horde.NodeListenerBehaviour

      use GenServer

      # --- API ---

      @spec start_link(atom()) :: GenServer.on_start()
      def start_link(cluster),
        do: GenServer.start_link(__MODULE__, cluster, name: listener_name(cluster))

      # --- Behaviour defaults ---

      @impl GenServer
      def init(cluster) do
        :net_kernel.monitor_nodes(true, node_type: :visible)
        {:ok, cluster}
      end

      @impl Horde.NodeListenerBehaviour
      def handle_nodeup(_node, cluster) do
        set_members(cluster)
      end

      @impl Horde.NodeListenerBehaviour
      def handle_nodedown(_node, cluster) do
        set_members(cluster)
      end

      # --- GenServer callbacks ---

      @impl GenServer
      def handle_cast(:initial_set, cluster) do
        set_members(cluster)
        {:noreply, cluster}
      end

      @impl GenServer
      def handle_info({:nodeup, node, _node_type}, cluster) do
        handle_nodeup(node, cluster)
        {:noreply, cluster}
      end

      @impl GenServer
      def handle_info({:nodedown, node, _node_type}, cluster) do
        handle_nodedown(node, cluster)
        {:noreply, cluster}
      end

      @impl GenServer
      def handle_info(_, cluster), do: {:noreply, cluster}

      # --- Helpers ---

      defp listener_name(cluster), do: Module.concat(cluster, NodeListener)

      defp set_members(cluster),
        do: :ok = Horde.Cluster.set_members(cluster, make_members(cluster))

      defoverridable start_link: 1,
                     init: 1,
                     handle_nodeup: 2,
                     handle_nodedown: 2,
                     handle_cast: 2,
                     handle_info: 2
    end
  end
end
