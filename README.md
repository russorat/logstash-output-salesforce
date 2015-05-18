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
