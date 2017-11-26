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
### Domains
As part of a site's config, you can set the domain, which will be used with the assumption that a service will be called by ```<service_name>.<site.domain>```
This allows you manage DNS however you want. I use the site as a subdomain, so in a site named "range", by domain will be range.example.com, and a service named foo will be foo.range.example.com. 
This pattern works in production as well, lets say you want three production sites, in each of us-east, us-west, and us-central. Name your site however you want, just as long as it is unique, e.g.: prod-ue, prod-uw, prod-uc. Lets say you have a front end web service named webfe, deployed to all three sites creating: 
webfe.prod-uw.example.com
webfe.prod-uc.example.com
webfe.prod-ue.example.com

You most likely don't want to expose webfe.prod-*.example.com to your customers, but using DNS or an external load balancer you can point www.example.com to the three webfe instances. 

TODO: get more details on suggested load balancing and routing config. 

### Cluster Proxy
As part of the cluster agent, I have created a cluster-proxy service as well to help tie this all together. What I do is run haproxy in the cluster, exposing a single node_port, using the hostname to route requests to all the configured services. This allows you to have stronger controls over how traffic is routed to a service. There are things like turbine labs and istio that do a much better job of this, and for complex routing scenarios, you should look there. 
This is intended for a single instance of a service in a site to be routeable via ```<service_name>.<site.domain>```

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
