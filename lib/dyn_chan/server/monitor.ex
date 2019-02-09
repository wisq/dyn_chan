defmodule DynChan.Server.Monitor do
  require Logger
  use GenServer

  alias Nostrum.Api, as: Discord
  alias DynChan.{VoiceStates, Constants}
  alias DynChan.Server.{State, Channel}
  import DynChan.Server.Common

  # Discord channel types:
  @type_voice Constants.channel_type_voice()
  @type_category Constants.channel_type_category()

  # If there's nothing to do, repeat the message every 5 minutes:
  @default_timeout 300_000

  def init_dynamic_channels(id, state) do
    channels = Discord.get_guild_channels!(id)

    case find_dynamic_category(channels) do
      nil ->
        log(:warn, state, "Can't find category: #{inspect(dynamic_category_name())}")
        {nil, []}

      cat ->
        {cat.id, list_dynamic_channels(cat.id, channels)}
    end
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

  def update_channel_timeouts(state) do
    active =
      VoiceStates.get_active_channels(state.id)
      |> MapSet.new()

    channels = Enum.map(state.channels, &Channel.update(&1, active))
    %State{state | channels: channels}
  end

  def process_next_channel(%State{channels: []} = state) do
    log(:info, state, "No dynamic channels.")
    {@default_timeout, state}
  end

  def process_next_channel(state) do
    Channel.earliest_timeout(state.channels)
    |> process_channel(state)
  end

  defp process_channel(nil, state) do
    count = Enum.count(state.channels)
    log(:info, state, "All #{count} dynamic channel(s) are active.")
    {@default_timeout, state}
  end

  defp process_channel(channel, state) do
    now = DateTime.utc_now()
    delta = DateTime.diff(channel.timeout, now, :millisecond)

    if delta <= 0 do
      log(:info, state, "Channel #{inspect(channel.name)} needs cleaning up now.")
      state = delete_channel(channel, state)
      process_next_channel(state)
    else
      log(:info, state, "Next cleanup will be #{inspect(channel.name)} in #{delta} ms.")
      {delta, state}
    end
  end

  defp delete_channel(channel, state) do
    id = channel.id
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
end
