defmodule DynChan.VoiceStates do
  require Logger
  use GenServer

  defmodule Session do
    @enforce_keys [:id, :channel_id]
    defstruct(
      id: nil,
      channel_id: nil
    )

    def from_voice_state(%{session_id: sid, channel_id: cid})
        when is_binary(sid) and (is_integer(cid) or is_nil(cid)) do
      %__MODULE__{id: sid, channel_id: cid}
    end
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def add_server(server_id, voice_states) when is_integer(server_id) do
    sessions =
      Enum.map(voice_states, &Session.from_voice_state/1)
      |> Map.new(fn s -> {s.id, s} end)

    GenServer.cast(__MODULE__, {:replace, server_id, sessions})
  end

  def update_state(server_id, voice_state) when is_integer(server_id) do
    session = Session.from_voice_state(voice_state)
    GenServer.cast(__MODULE__, {:update, server_id, session})
  end

  def get_active_channels(server_id) do
    acc = %{}

    case GenServer.call(__MODULE__, {:get, server_id}) do
      {:ok, sessions} -> session_channels(sessions)
      :error -> acc
    end
  end

  defp session_channels(sessions) do
    sessions
    |> Enum.map(fn {_id, session} -> session.channel_id end)
    |> Enum.uniq()
    |> Enum.reject(&is_nil/1)
  end

  @impl true
  def init(nil) do
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:replace, server_id, sessions}, servers) do
    Logger.debug("VoiceStates replacing #{server_id} with #{inspect(sessions)}")
    {:noreply, Map.put(servers, server_id, sessions)}
  end

  @impl true
  def handle_cast({:update, server_id, session}, servers) do
    Logger.debug("VoiceStates updating #{server_id} with #{inspect(session)}")

    sessions =
      Map.get(servers, server_id, %{})
      |> Map.put(session.id, session)

    {:noreply, Map.put(servers, server_id, sessions)}
  end

  @impl true
  def handle_call({:get, server_id}, _from, servers) do
    {:reply, Map.fetch(servers, server_id), servers}
  end
end
