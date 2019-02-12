# DynChan

DynChan is a Discord bot that dynamically creates voice channels on demand, then cleans them up when they sit unused for too long.

To see this in action, check out the [demo video](https://raw.githubusercontent.com/wisq/dyn_chan/master/demo.mp4).  (This uses a 5-second idle timeout, which is absurdly short.)

## Discord setup

To start, you'll need to create a Discord bot account:

1. Go to the [Discord Developer Portal](https://discordapp.com/developers/applications/).
2. Select "New Application" and pick a name.  (You can change this later.)
3. In your new app's settings, on the left hand side, select the "Bot" tab.
4. Under the "Build-A-Bot" section, select "Add Bot" (and confirm).
5. On the left hand side again, select the "OAuth2" tab.
6. Select the "bot" checkbox from the "Scopes" section.
7. Select the "Manage Channels" and "Send Messages" checkboxes from the "Bot Permissions" section (below).
8. Inbetween those two sections is a URL — something like `https://discordapp.com/api/oauth2/authorize?client_id=123456789&permissions=2064&scope=bot`.  Copy and paste that URL to a new tab.
9. Select your server from the dropdown and select "Authorize".
10. Verify you're not a robot, and you're done.

You should now have a bot logged in to your Discord server.  It'll be offline to start.

## Installation

To get your bot online, you need to get DynChan running:

1. [Install Elixir](https://elixir-lang.org/install.html).
2. Use git to clone this project somewhere.  (Change directory to that location.)
3. Copy `config/bot.exs.example` to `config/bot.exs` and edit it.
    * You'll need to paste your bot's token in the marked place.
    * Get this from the "Bot" tab of your application.
4. Run `mix deps.get`.
5. Run `mix compile`.

All set!  Now just run

```
mix run --no-halt
```

to start your bot.  If you've already added the bot to your server, you should see something like this:

```
02:28:17.599 [warn]  "Your server name": Can't find category: "Dynamic Channels"

02:28:17.600 [info]  "Your server name": Now monitoring; ID: 123456789012345678

02:28:17.600 [info]  "Your server name": No dynamic channels.
```

That means the bot is monitoring your server.  Don't worry about the warning; it'll automatically create the category when it creates the first channel.

## Usage

Go to your server and make sure your bot is online, then find a channel that your bot is in.  (It should be in all public channels by default, but you can add it to other channels, as long as it has the "Read messages" and "Send messages" permissions.)

Now, just say `!dc help` in the channel.  The bot should reply with a helpful description of itself and its commands.

## Troubleshooting

### My bot is DMing me instead of replying in the channel!

This happens when the bot doesn't have permission to speak in a channel.  Either the channel is private, or your server requires that members have a role to speak.

Make sure the bot (or its role by the same name) has the "Send Messages" permission — either server-wide, or in the channel it's in.

### My bot can't create channels!

Also a permissions problem.  Make sure the bot has the "Manage Channels" permission on the server.

### My bot is doing everything multiple times!

Is it possible you actually have the bot running multiple times in different windows?  Each one will operate independently.

If it's doing everything exactly **four** times, that probably means some code is crashing and it's retrying but failing each time.  Check the log output.

### Channels I create manually aren't being cleaned up!

During normal operation, the bot will only clean up channels it creates itself.  If you create a channel manually (as a Discord admin), it won't pay any attention to it.

However, if the bot is restarted, it will notice the new channels and clean them up as normal (eventually).

### Something else is broken!

If your problem is with the Discord side (setting up a bot or adjusting permissions), you can try asking on the [unofficial Discord API guild](https://discord.gg/2Bgn8nW).

If your problem is with getting Elixir installed or getting the DynChan app running, you could try asking on the [Elixir Slack community](https://elixir-slackin.herokuapp.com/).  (I'm `wisq` there.)

If none of that helps, you could try [filing an issue](../../issues).  However, keep in mind that I made this project mostly just as a fun exercise, and it's not even currently being used on any real Discord servers (as far as I know).  So while I'll do what I can to help, I can't dedicate a ton of time to this.

## Legal stuff

Copyright © 2019, Adrian Irving-Beer.

DynChan is released under the [Apache 2 License](../../blob/master/LICENSE) and is provided with **no warranty**.  In particular: I've done my best to keep things as simple and secure as possible, but it's still processing a lot of Discord messages from random users, so maybe don't go running this on your ultra-secure bank server or whatnot.
