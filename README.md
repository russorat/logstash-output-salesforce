# Logstash Plugin

This is a plugin for [Logstash](https://github.com/elasticsearch/logstash).

It is fully free and fully open source. The license is Apache 2.0, meaning you are pretty much free to use it however you want in whatever way.

## Documentation

logstash-output-salesforce
==========================

This logstash output provides an easy way to create and update Salesforce sObjects using the api.

A sample Logstash config might look something like this:

```
  salesforce {
    client_id => '<CLIENT ID HERE>'
    client_secret => '<CLIENT SECRET HERE>'
    username => 'you@example.com'
    password => 'secret-password'
    security_token => '<SECURITY TOKEN>'
    sfdc_object_name => 'Contact'
    event_to_sfdc_keys_mapping => {
      "[email]" => "Email"
    }
    event_to_sfdc_mapping => {
      "[first_name]" => "First_Name"
      "[last_name]" => "Last_Name"
    }
    raw_values_to_sfdc_mapping => {
      "1" => "Was_found__c"
    }
    increment_fields => [ "times_found" ]

    should_create_new_records => true
  }
```

## Need Help?

Need help? Try #logstash on freenode IRC or the logstash-users@googlegroups.com mailing list. Or file an issue.

## Developing

### 1. Plugin Developement and Testing

#### Code
- To get started, you'll need JRuby with the Bundler gem installed.

- Create a new plugin or clone and existing from the GitHub [logstash-plugins](https://github.com/logstash-plugins) organization. We also provide [example plugins](https://github.com/logstash-plugins?query=example).

- Install dependencies
```sh
bundle install
```

#### Test

- Update your dependencies

```sh
bundle install
```

- Run tests

```sh
bundle exec rspec
```

#### 2.2 Run in an installed Logstash

You can use the same **2.1** method to run your plugin in an installed Logstash by editing its `Gemfile` and pointing the `:path` to your local plugin development directory or you can build the gem and install it using:

- Build your plugin gem
```sh
gem build logstash-output-salesforce.gemspec
```
- Install the plugin from the Logstash home
```sh
bin/plugin install /your/local/plugin/logstash-output-salesforce.gem
```
- Start Logstash and proceed to test the plugin

## Contributing

All contributions are welcome: ideas, patches, documentation, bug reports, complaints, and even something you drew up on a napkin.

Programming is not a required skill. Whatever you've seen about open source and maintainers or community members  saying "send patches or die" - you will not see that here.

It is more important to the community that you are able to contribute.

For more information about contributing, see the [CONTRIBUTING](https://github.com/elasticsearch/logstash/blob/master/CONTRIBUTING.md) file.
