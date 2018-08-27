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
         "type": "aws-elb-classic",
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

## Running it

```
bin/issue.rb
```

## TODO
 * more tests!
 * more issuers/renewers
 * more deployers
 * more checkers


