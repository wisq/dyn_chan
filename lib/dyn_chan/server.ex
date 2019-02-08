defmodule DynChan.Server do
  require Logger
  use GenServer

  alias Nostrum.Api, as: Discord
  alias DynChan.{VoiceStates, ServerRegistry}

  # Discord channel types:
  @type_voice 2
  @type_category 4

  # If there's nothing to do, repeat the message every 5 minutes:
  @default_timeout 300_000

  defmodule Channel do
    @enforce_keys [:id, :name]
    defstruct(
      id: nil,
      name: nil,
      timeout: nil
    )

    def from_discord(%{id: id, name: name}) do
      %Channel{id: id, name: name}
    end

    def update(%Channel{id: id} = channel, active) do
      if id in active do
        set_active(channel)
      else
        set_inactive(channel)
      end
    end

    def set_active(%Channel{} = channel) do
      %Channel{channel | timeout: nil}
    end

    def set_inactive(%Channel{timeout: nil} = channel) do
      %Channel{channel | timeout: idle_timeout() |> in_future()}
    end

    def set_inactive(%Channel{timeout: %{zone_abbr: "UTC"}} = channel) do
      channel
    end

    defp idle_timeout, do: Application.get_env(:dyn_chan, :idle_timeout, 300)
    defp in_future(secs), do: DateTime.utc_now() |> DateTime.add(secs, :second)

    def earliest_timeout(channels) do
      channels
      |> Enum.filter(fn c -> !is_nil(c.timeout) end)
      |> min_sortable_timeout()
    end

    defp min_sortable_timeout([]), do: nil
    defp min_sortable_timeout(list), do: Enum.min_by(list, &sortable_timeout/1)

    defp sortable_timeout(%Channel{timeout: timeout}) do
      DateTime.to_unix(timeout, :native)
    end
  end

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

    {category_id, channels} = init_dynamic_channels(id, state)
    state = %State{state | category_id: category_id, channels: channels}

    log(:info, state, "Now monitoring; ID: #{inspect(id)}")
    {next, state} = process_channels(state)
    {:ok, state, next}
  end

  @impl true
  def terminate(reason, state) do
    log(:info, state, "No longer monitoring; reason: #{inspect(reason)}")
  end

  @impl true
  def handle_call({:create, name}, _from, state) do
    {rval, state} = handle_create_channel(name, state)
    {next, state} = process_channels(state)
    {:reply, rval, state, next}
  end

  defp handle_create_channel(name, %State{category_id: nil} = state) do
    result =
      Discord.create_guild_channel(state.id,
        name: dynamic_category_name(),
        type: @type_category
      )

    case result do
      {:ok, channel} ->
        state = %State{state | category_id: channel.id}
        handle_create_channel(name, state)

      {:error, _} = err ->
        {err, state}
    end
  end

  defp handle_create_channel(name, %State{category_id: cat_id} = state) when is_integer(cat_id) do
    result =
      Discord.create_guild_channel(state.id,
        name: name,
        type: @type_voice,
        parent_id: cat_id
      )

    case result do
      {:ok, channel} ->
        channels = [Channel.from_discord(channel) | state.channels]
        state = %State{state | channels: channels}
        {{:ok, channel}, state}

      {:error, _} = err ->
        {err, state}
    end
  end

  @impl true
  def handle_cast(:poke, state) do
    {next, state} = process_channels(state)
    {:noreply, state, next}
  end

  @impl true
  def handle_info(:timeout, state) do
    {next, state} = process_channels(state)
    {:noreply, state, next}
  end

  @impl true
  def handle_continue(channel_id, state) do
    state = delete_channel(state, channel_id)

    {next, state} = process_channels(state)
    {:noreply, state, next}
  end

  defp init_dynamic_channels(id, state) do
    channels = Discord.get_guild_channels!(id)

    case find_dynamic_category(channels) do
      nil ->
        log(:warn, state, "Can't find dynamic channel category.")
        {nil, []}

      cat ->
        {cat.id, list_dynamic_channels(cat.id, channels)}
    end
  end

  defp dynamic_category_name do
    Application.get_env(:dyn_chan, :category, "Dynamic Channels")
  end

  defp find_dynamic_category(channels) do
    name = dynamic_category_name()

    channels
    |> Enum.find(fn c -> c.type == @type_category && c.name == name end)
  end

  defp list_dynamic_channels(cat_id, channels) when is_integer(cat_id) do
    channels
    |> Enum.filter(fn c -> c.type == @type_voice && c.parent_id == cat_id end)
    |> Enum.map(&Channel.from_discord/1)
  end

  defp process_channels(state) do
    active =
      VoiceStates.get_active_channels(state.id)
      |> MapSet.new()

    channels = Enum.map(state.channels, &Channel.update(&1, active))
    state = %State{state | channels: channels}

    {calculate_next(state), state}
  end

  defp calculate_next(%State{channels: []} = state) do
    log(:info, state, "No dynamic channels.")
    @default_timeout
  end

  defp calculate_next(state) do
    Channel.earliest_timeout(state.channels)
    |> calculate_next(state)
  end

  defp calculate_next(nil, state) do
    count = Enum.count(state.channels)
    log(:info, state, "All #{count} dynamic channel(s) are active.")
    @default_timeout
  end

  defp calculate_next(channel, state) do
    now = DateTime.utc_now()
    delta = DateTime.diff(channel.timeout, now, :millisecond)

    if delta <= 0 do
      log(:info, state, "Channel #{inspect(channel.name)} needs cleaning up now.")
      {:continue, channel.id}
    else
      log(:info, state, "Next cleanup will be #{inspect(channel.name)} in #{delta} ms.")
      delta
    end
  end

  defp delete_channel(state, id) do
    channel = Enum.find(state.channels, &(&1.id == id))
    state = %State{state | channels: List.delete(state.channels, channel)}

    case Discord.delete_channel(id) do
      {:ok, %{id: ^id}} ->
        log(:info, state, "Deleted channel: #{inspect(channel.name)}")
        state

      error ->
        log(:error, state, "Failed to delete channel #{inspect(channel.name)}: #{inspect(error)}")
        # Add it back on, but mark it as active, so it gets
        # the timeout refreshed.  We'll try removing it again later.
        channels = [Channel.set_active(channel) | state.channels]
        %State{state | channels: channels}
    end
  end

  defp log(level, state, message) do
    Logger.log(level, ["#{inspect(state.name)}: ", message])
  end
end
