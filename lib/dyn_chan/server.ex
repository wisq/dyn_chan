defmodule DynChan.Server do
  require Logger
  use GenServer
  alias DynChan.ServerRegistry

  defmodule State do
    @enforce_keys [:id]
    defstruct(id: nil)
  end

  def start_link(server_id) when is_integer(server_id) do
    name = {:via, Registry, {ServerRegistry, server_id}}
    GenServer.start_link(__MODULE__, server_id, name: name)
  end

  @impl true
  def init(id) do
    state = %State{id: id}
    {:ok, state}
  end
end
