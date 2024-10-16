# Example Prefab Rails Application

NOTE: this has been updated in the latest commit to use the newest version of the Prefab Ruby SDK

This repo shows how to add [Prefab] to your Rails app to get access to features like

- Dynamic log levels
- Feature flags
- Live config

Follow along on YouTube

[![YouTube](https://img.youtube.com/vi/F1aaGwGAIUQ/0.jpg)](https://www.youtube.com/watch?v=F1aaGwGAIUQ)

## `rails new`

[Full diff](https://github.com/prefab-cloud/example-rails-app/compare/new-repo...rails-new)

We start with `rails new example-app --css tailwind`

We can run the app from the app root with `bin/dev` and see the default Rails content at http://localhost:3000

## Adding `prefab-cloud-ruby`

[Full diff](https://github.com/prefab-cloud/example-rails-app/compare/rails-new...add-prefab)

Adding Prefab to our new Rails app is easy.

Add `gem "prefab-cloud-ruby"` to your `Gemfile` and `bundle install`

In `config/application.rb`, we set up the client as a global for easy access throughout our app.

We also hook into the Rails loggers so we can use Prefab for [dynamic log levels].

```ruby
$prefab = Prefab::Client.new
$prefab.set_rails_loggers
```

Because Rails uses [Puma] out-of-the-box with process forking, we'll also need to do the same in our `on_worker_boot` in `config/puma.rb`[^1]

```ruby
on_worker_boot do
  $prefab = Prefab::Client.new
  $prefab.set_rails_loggers
end
```

The last part of adding Prefab to your Rails app is to get an API key from https://app.prefab.cloud and set it as the environment variable `PREFAB_API_KEY`. We'll restart our app to make sure it uses that env var.

That's all it takes to add Prefab to your app. Now let's take some of the features for a test drive.

## Dynamic log levels

[Full diff](https://github.com/prefab-cloud/example-rails-app/compare/add-prefab...dynamic-logging)

The first feature to demo is Dynamic log levels. To get a feel for this feature, we'll add a `HomeController` with a simple view and map the home controller to our root path.

In `app/controllers/home_controller.rb`, we add example logging at three different levels

```ruby
class HomeController < ApplicationController
  def index
    logger.debug '🔍 Hello from Rails.logger.debug'
    logger.info  'ℹ️ Hello from Rails.logger.info'
    logger.warn  '⚠️ Hello from Rails.logger.warn'
    logger.error '🚨 Hello from Rails.logger.error'
  end
end
```

By default, the Prefab client logs at the `warn` level. When we visit http://localhost:3000 we should see the `error` and `warn` output but not the debug or info output.

In the Prefab UI, let's set our "Root Log Level" to "INFO". Now reloading http://localhost:3000 shows the `error`, `warn`, and `info` output. Note that a number of items you're used to seeing in local Rails development are logged at the `info` level.

Prefab lets you change log levels on the fly. We can even set log levels for specific models, controllers, methods, and actions.

## Targeted log levels and Context

[Full diff](https://github.com/prefab-cloud/example-rails-app/compare/dynamic-logging...targeted-logging-and-context)

If you liked dynamic log levels, you'll love targeted log levels.

Let's imagine we get a report of a bug that only happens in mobile. Ugh. We don't want to turn on more verbose logging for every request and blow up our log retention SaaS bill.

No problem. Prefab makes it easy to add rules to log levels to get just the logging you need exactly where you need it.

Let's set the "Root Log Level" to error. Refreshing http://localhost:3000 shows only the `error` message.

Now let's expand our tree to zero-in on `app.controllers.home_controller.index` and select `Targeted`.

We'll set the "default value" to "Inherit" and click "Add Targeting Rule" -- this is where things get fun.

We'll set the level to `DEBUG` when "Property is one of" for the property `device.mobile` and set the value to `true`.

Wait, how does Prefab know if the request comes from a mobile device? It doesn't yet. This is where Prefab's context concept comes in.

We'll add three methods in `app/controllers/application_controller.rb`:

```ruby
around_action do |_, block|
  $prefab.with_context(prefab_context, &block)
end

def prefab_context
  {
    device: {
      mobile: mobile?
    }
  }
end

def mobile?
  request.user_agent&.match?(/(iPhone|iPod|iPad|Android)/)
end
```

We add an `around_action` to give Prefab some knowledge of our request. So far the only context is whether or not the request is from a mobile device. The `device.mobile` in our rule above maps to the context's `device` node's `mobile` attribute.

Reloading our desktop browser for http://localhost:3000 still only shows the `error` output. But loading the same URL from the iPhone simulator shows `debug` through `error` output.

If this were a real-world bug, we'd have all the detail we could possibly get.

## Feature flags and user targeting

[Full diff](https://github.com/prefab-cloud/example-rails-app/compare/targeted-logging-and-context...context-and-faux-users?w=1)

To the delight and terror of developers, most apps have users.

For this repo, we'll skip the boring user authentication and users bit and fake some example users. We'll use some avatars from https://userstock.io/ (except Jeff, our beloved CEO).

We'll add the `user` to our context in `app/controllers/application_controller.rb`

```ruby
def prefab_context
  {
    device: {
      mobile: mobile?
    },

    user: {
      id: current_user&.id,
      email: current_user&.email,
      country: current_user&.country,
    }
  }
end
```

Once you make Prefab aware of the current user for a request, you can target your log levels even further. Want to get debug-level logging for user with id 3 on their mobile device? Easy. For all users with an `@example.com` email? Cake.

We can also start using Prefab's feature flags.

Right now http://localhost:3000/ shows the GDPR cookie consent banner to everyone. I'm not a lawyer but let's imagine our lawyer says that we don't need to show this banner to people in the US. Awesome, let's declutter our UI.

We'll wrap our cookie consent UI with a feature flag check.

```erb
<% if $prefab.enabled?("gdpr.banner") %>
  ...
<% end %>
```

By default an `enabled?` check returns `false` so we can't just ship this to production without setting up the flag first in the Prefab UI.

We'll add a new flag with the key `gdpr-banner` of type `bool`. We want it to return `true` by default.

Next we click "Add Rule" and specify that we return `false` when "Property is one of" for `user.country` with value `US`.

Now we save and publish our changes.

Our UI has three users. Tony is from the UK so if we "Sign in as Tony" we'll see the GDPR banner. Joan is from France so if we "Sign in as Joan" we still see the GDPR banner. But Jeff? He lives in the US so if you sign in as him, we'll see the GDPR banner is gone. Beautiful.

## Live Config and Introspection

[Full diff](https://github.com/prefab-cloud/example-rails-app/compare/context-and-faux-users...config-and-introspection?w=1)

We're going to add one more feature to help us better understand how Prefab works in our app and to demonstrate Live Config.

First we add a new partial `app/views/home/_prefab_values.html.erb` to render out the resolved Prefab values for our application. Imagine this showing up in your admin dashboard.

```erb
<div id="prefab-values" class="mt-24 space-y-4">
  <p>Here's the resolved Prefab config for your application:</p>

  <table class="border-separate w-full">
    <thead class="bg-gray-50 text-left">
      <!-- snip -->
    </thead>

    <tbody class="<%= $prefab.get("admin.prefab-values.classes", "") %>">
      <% $prefab.resolver.presenter.each do |key, config| %>
        <tr class="odd:bg-blue-50">
          <td class="p-4 break-all"><%= key %></td>
          <td class="p-4"><%= config.value %></td>
          <td class="p-4"><%= $prefab.get(key) %></td>
          <td class="p-4"><%= config.value.class %></td>
          <td class="p-4"><%= config.source %></td>
        </tr>
      <% end %>
    </tbody>
  </table>
</div>
```

We reference this partial from the `app/views/home/index.html.erb` view.

```erb
<%= render partial: "prefab_values" %>
```

Live config, feature flags, and log levels can all have different kinds of rules applied to them, so it can be helpful to see the default values for this request. Additionally, because we have the context of the user, we can show the "Evaluated Value" for the current user.

When we sign in as "Jeff" you'll note that the `gdpr.banner` has a default value of `true` but an evaluated value of `false`.

When you change a value in Prefab, it pushes out the changes to your Rails app.[^2] We can use [Turbo] in Rails to see these updates in real-time.

First we'll register our turbo stream in `app/views/home/index.html.erb` right above our partial rendering.

```erb
<%= turbo_stream_from(:prefab_values) %>
<%= render partial: "prefab_values" %>
```

Next, we'll edit our `config/application.rb` to use this stream to push updates to our Prefab Values partial.

```ruby
$prefab.on_update do
  if defined?(Turbo::StreamsChannel)
    Turbo::StreamsChannel.broadcast_replace_to :prefab_values,
      target: 'prefab-values',
      partial: 'home/prefab_values'
  end
end
```

Since we made a change to `config/application.rb` we'll need to restart our server and refresh the page.

Now for some fun. You might have noticed that we included a live config evaluation, `$prefab.get("admin.prefab-values.classes", "")`, in our `_prefab_values.html.erb` partial. The first argument to `$prefab.get` is the config key and the second is the default.

Let's try it out! We'll add a config in the Prefab UI named `admin.prefab-values.classes`. For the value, set `font-mono`. Save and publish. Note that the table in our app updates immediately. Let's change the value to `font-mono bg-yellow-50` and save and publish. Now our zebra stripes on the table alternate blue and yellow.

## Add Prefab to your Rails app

You've seen how easy it is to add Prefab to a Rails app. With dynamic log levels, feature flags, and live config, you can take control of your app's behavior like never before. [Sign up] today!

[^1]: Why? Ruby uses a copy-on-write approach to forking. For Prefab, this means that a client initialized _before_ forking is frozen-in-time and doesn't get access to streaming config updates. Because the loggers are also copied during the fork, we need to re-wrap them to allow for dynamic log levels.
[^2]: Via server-sent events.

[dynamic log levels]: https://docs.prefab.cloud/docs/ruby-sdk/dynamic-log-levels
[Puma]: https://puma.io/
[Turbo]: https://turbo.hotwired.dev/
[Prefab]: https://prefab.cloud
[Sign up]: https://app.prefab.cloud/users/sign_up
