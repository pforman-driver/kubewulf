# Kubewulf

Gem to manage configuration in kubernetes, with a few heavy assumptions and/or opinions. The goal for this project is to simplify the generation of the related kubernetes objects/config and provide a manageable source of truth for this configuration.

Based on the data, the gem allows you to create the following objects:
namespace
config_maps
secrets
services

For the secrets I have included a hashicorp class to wrap calls, using hashicorp's vault gem.

This gem relies on the concept of a "site", which like all terms is tirelessly debatable. I use it to describe a group of services that can be designed with the following assumptions:
* all peer services will be acessible via dns shortname
* all services exposed publicly, will share a common subdomain
* a site exists in only one cluster and region/network at a time

In the case of kubernetes clusters, a site would not exist across federated clusters, but a single multi-az cluster would be ok. i
This is by design rather than limitation of tech. My reasoning is that a site should provide an abstraction from the infrastructure to a service developer while also providing a clean radius of failure. By federating a site across multiple clusters and regions, your service will be dependent on the underlying federation which, at some point will be much better, but for now is beyond the scope of this project.

## Features
Generates kubernetes config for services, config_maps, and secrets using a flat file data source.


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'kubewulf'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install kubewulf

## Usage
### Syncing a cluster
I've included a cluster sync script, providing an example of how you can implement the functionality in your cluster, for local development and testing on the gem. See my working example for the cluster-agent at github.com/rangedev/cluster-agent. This is basically the cluster-agent script running in a docker container with the necessary config to get you up and running in your cluster pretty quickly.

### Hashicorp vault secret backend
I am using hashicorps vault gem (https://github.com/hashicorp/vault-ruby), which will consume standard vault env variables. To configure a site to use hashicorp's vault, simply set the secret_backend to "hashicorp_vault" and ensure that the necessary env variables are set.
In this project I merely allow you to specify the key and field in a config line, and use the vault client, calling logical.read method.
Please see the documentation for vault ruby to ensure all necessary env variables are set.

For local testing with vault enabled you can do the following, assuming you have the vault binary in your path and the gem repo checked out:
```
$ docker run --cap-add=IPC_LOCK -e 'VAULT_DEV_ROOT_TOKEN_ID=myroot' -p 8200:8200 vault
$ vault write secret/prod/key-one value="this is a value in vault"
$ vault write secret/prod/key-file value="this is a file in vault\ndata\ndata"
$ bin/console
2.4.1 :001 > ds = Kubewulf::Datastore.new(:base_file_path => "spec/fixtures/files")
2.4.1 :002 > site = ds.load_sites[:'prod-b']
2.4.1 :003 > site.secrets
 => [#<Kubewulf::Secret:0x007f823b357540 @name="global-secrets", @site="prod-b", @data={:my_secret_key=>"this is a value in vault", :"my_secret.file"=>"this is a file in vault\ndata\ndata"}>]
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/rangedev/kubewulf.
