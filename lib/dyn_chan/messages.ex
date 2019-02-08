defmodule DynChan.Messages do
  require Logger
  alias Nostrum.Api, as: Discord
  alias DynChan.{ServerSupervisor, Server}

  @help_text """
  Hello! :wave:  I'm a bot that creates dynamic voice channels.  Here's the commands I support:

  `!dc create <name>` — create a dynamic voice channel
  `!dc help` — this text right here :smile:

  If a channel I create hasn't been used in a while, I'll be sure to go clean it up.  Enjoy!
  """

  def message("!dc create " <> name, msg) do
    sane_channel_name(name)
    |> create_channel(msg)
  end

  def message("!dc help", msg) do
    reply(msg, @help_text)
  end

  def message("!dc " <> _, msg) do
    reply(msg, "I'm not sure what you're trying to do here.  Maybe try `!dc help` ?")
  end

  def message("!dc", msg) do
    reply(msg, "I'm not sure what you're trying to do here.  Maybe try `!dc help` ?")
  end

  def message(_text, _msg), do: :noop

  defp with_server(msg, fun) do
    case ServerSupervisor.whereis(msg.guild_id) do
      pid when is_pid(pid) ->
        fun.(pid)

      nil ->
        Logger.error("Not monitoring server #{inspect(msg.guild_id)}.")

        reply(
          msg,
          "Uh oh, I don't seem to be monitoring this server right now.  Maybe I crashed?"
        )
    end
  end

  defp reply(msg, text) do
    case Discord.create_message(msg.channel_id, text) do
      {:ok, _} ->
        :done

      {:error, _} ->
        dm(msg.author.id, text)
    end
  end

  defp dm(user_id, text) do
    with {:ok, %{id: dm_id}} <- Discord.create_dm(user_id),
         {:ok, _} <- Discord.create_message(dm_id, text) do
      :ok
    else
      {:error, err} -> Logger.error("Error DMing user #{inspect(user_id)}: #{inspect(err)}")
    end
  end

  defp sane_channel_name(name) do
    name
    |> String.replace(~r{[^A-Za-z0-9'."/-]+}, " ")
    |> String.trim()
    |> String.slice(0, 100)
  end

  defp create_channel("", msg) do
    reply(
      msg,
      "Ah, hey, I can't make heads or tails of that name.  Could we maybe stick to letters and numbers and basic punctuation, please?"
    )
  end

  defp create_channel(name, msg) do
    with_server(msg, fn pid ->
      case Server.create_channel(pid, name) do
        {:ok, channel} ->
          reply(msg, "Done!  I created `#{channel.name}`.")

        {:error, _} ->
          reply(
            msg,
            "Uh oh, something went wrong.  Maybe I don't have permission to create channels?"
          )
      end
    end)
  end
end
