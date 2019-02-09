defmodule DynChan.Server do
  require Logger
  use GenServer

  alias Nostrum.Api, as: Discord
  alias DynChan.ServerRegistry
  alias DynChan.Server.{Create, Monitor}
  import DynChan.Server.Common

  defmodule State do
    @enforce_keys [:id, :name]
    defstruct(
      id: nil,
      name: nil,
      category_id: nil,
      channels: []
    )

    def log_name(state) do
      "#{inspect(state.name)} (#{inspect(state.id)})"
    end
  end

  def start_link(server_id) when is_integer(server_id) do
    name = {:via, Registry, {ServerRegistry, server_id}}
    GenServer.start_link(__MODULE__, server_id, name: name)
  end

  def poke(pid) when is_pid(pid) do
    GenServer.cast(pid, :poke)
  end

  def poke(server_id) when is_integer(server_id) do
    case ServerRegistry.whereis(server_id) do
      nil -> Logger.warn("Failed to poke server #{inspect(server_id)}: Not running.")
      pid when is_pid(pid) -> poke(pid)
    end
  end

  def create_channel(pid, name) do
    GenServer.call(pid, {:create, name})
  end

  @impl true
  def init(id) do
    Process.flag(:trap_exit, true)

    guild = Discord.get_guild!(id)

    state = %State{
      id: id,
      name: guild.name
    }

    {category_id, channels} = Monitor.init_dynamic_channels(id, state)
    state = %State{state | category_id: category_id, channels: channels}

    log(:info, state, "Now monitoring; ID: #{inspect(id)}")
    {:ok, state, {:continue, nil}}
  end

  @impl true
  def terminate(reason, state) do
    log(:info, state, "No longer monitoring; reason: #{inspect(reason)}")
  end

  @impl true
  def handle_call({:create, name}, _from, state) do
    {rval, state} = Create.create_channel(name, state)
    {:reply, rval, state, {:continue, nil}}
  end

  @impl true
  def handle_cast(:poke, state) do
    {:noreply, state, {:continue, nil}}
  end

  @impl true
  def handle_info(:timeout, state) do
    {:noreply, state, {:continue, nil}}
  end

  @impl true
  def handle_continue(_, state) do
    state = Monitor.update_channel_timeouts(state)
    {timeout, state} = Monitor.process_next_channel(state)
    {:noreply, state, timeout}
  end
end
