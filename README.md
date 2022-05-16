# Cert updater

## Functionality
 * checks certificates in a storage (currently a local/nfs file) for
   validity, renews / issues with letsencrypt if needed
 * checks certificates online (currently host port checks supported)
 * deploys certs if needed (currently AWS elb supported)



## Configuration

Create a file in /data/domains.json (best is to mount /data into your
container) containing sth like:

```

{
  deployments: [
    { "name": "some_name", 
      "test": { "host": "www.example.com", "port": "443"},
      "target": {
         "type": "aws-elb-classic|aws-elb-application",
         "balancer_name": "funny-elb-balancer-name"
      },
      "cert": "my_example"
    },
    ....more deployments
  ],
  certs: [
    {name: "my_example",
     domains: [
         { fqdn: "example.com" },
         { fqdn: "*.example.com" },
        ]
    },
    ..next cert
  ]
 }
```

Set the following evironment variables:
 * DNS_PROVIDER (default :none) see https://github.com/Neilpang/acme.sh/blob/master/dnsapi/README.md, you might have to set further environment variables
 * LOGGER_LEVEL (default 'error') one of debug, info, warn, error
 * DAYS (default 7) days a cert will be renewed before it expires
 * AWS_ACCESS_KEY_ID
 * AWS_SECRET_ACCESS_KEY



## Running it


```
bin/issue.rb
```

## TODO
 * more tests!
 * more issuers/renewers
 * more deployers
 * more checkers


