defmodule DynChan.Server do
  require Logger
  use GenServer

  alias Nostrum.Api, as: Discord
  alias DynChan.VoiceStates

  # Discord channel types:
  @type_voice 2
  @type_category 4

  # If there's nothing to do, repeat the message every 5 minutes:
  @default_timeout 10_000

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
    @enforce_keys [:id, :name, :category_id, :channels]
    defstruct(
      id: nil,
      name: nil,
      category_id: nil,
      channels: nil
    )

    def log_name(state) do
      "#{inspect(state.name)} (#{inspect(state.id)})"
    end
  end

  def start_link(server_id) when is_integer(server_id) do
    GenServer.start_link(__MODULE__, server_id)
  end

  def poke(pid) do
    GenServer.cast(pid, :poke)
  end

  @impl true
  def init(id) do
    Process.flag(:trap_exit, true)

    guild = Discord.get_guild!(id)
    {category_id, channels} = init_dynamic_channels(id, guild.name)

    state = %State{
      id: id,
      name: guild.name,
      category_id: category_id,
      channels: channels
    }

    Logger.info("#{inspect(state.name)}: Now monitoring; ID: #{inspect(id)}")
    {next, state} = process_channels(state)
    {:ok, state, next}
  end

  @impl true
  def terminate(reason, state) do
    Logger.info("#{inspect(state.name)}: No longer monitoring; reason: #{inspect(reason)}")
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

  defp init_dynamic_channels(id, name) do
    channels = Discord.get_guild_channels!(id)

    case find_dynamic_category(channels) do
      nil ->
        Logger.warn("#{inspect(name)}: Can't find dynamic channel category.")
        {nil, []}

      cat ->
        {cat.id, list_dynamic_channels(cat.id, channels)}
    end
  end

  defp find_dynamic_category(channels) do
    name = Application.get_env(:dyn_chan, :category, "Dynamic Channels")

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
    Logger.info("#{inspect(state.name)}: No dynamic channels.")
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
    log(:info, state, "Deleting channel: #{inspect(channel.name)}")

    %State{state | channels: List.delete(state.channels, channel)}
  end

  defp log(level, state, message) do
    Logger.log(level, ["#{inspect(state.name)}: ", message])
  end
end
