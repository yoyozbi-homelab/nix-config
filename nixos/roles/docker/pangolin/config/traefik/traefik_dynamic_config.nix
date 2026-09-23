{
  config,
  pangolinDomain,
  baseDomain,
  email,
  ...
}:
{
  sops.templates."traefik_dynamic.yml".content = ''
    http:
      middlewares:
        badger:
          plugin:
            badger:
              disableForwardAuth: true
        redirect-to-https:
          redirectScheme:
            scheme: https
        # Applied to every router on the websecure entrypoint.
        # Traefik is the edge (no CDN in front), so forwarded headers are not
        # trusted: the client IP is always the TCP peer.
        # Fail-open when crowdsec is down, so a crowdsec outage doesn't take
        # every exposed service offline.
        crowdsec:
          plugin:
            crowdsec:
              enabled: true
              logLevel: INFO
              crowdsecMode: stream
              # Stream mode only pulls decision deltas; 15s was more LAPI
              # round-trips than a 1 OCPU box needs for an IP blocklist.
              updateIntervalSeconds: 60
              updateMaxFailure: -1
              httpTimeoutSeconds: 10
              crowdsecLapiScheme: http
              crowdsecLapiHost: crowdsec:8080
              crowdsecLapiKey: "${config.sops.placeholder.crowdsec-bouncer-key or ""}"
              crowdsecAppsecEnabled: true
              crowdsecAppsecHost: crowdsec:7422
              crowdsecAppsecFailureBlock: true
              crowdsecAppsecUnreachableBlock: false
              # Bodies are buffered in traefik before being shipped to appsec.
              # 10 MiB per in-flight request is not affordable on a 1 GB host;
              # 1 MiB still covers every form/API payload behind this proxy.
              crowdsecAppsecBodyLimit: 1048576
              clientTrustedIPs:
                - "10.0.0.0/8"
                - "172.16.0.0/12"
                - "192.168.0.0/16"

      routers:
        main-app-router-redirect:
          rule: "Host(`${pangolinDomain}`)"
          service: next-service
          entryPoints:
            - web
          middlewares:
            - redirect-to-https
            - badger

        next-router:
          rule: "Host(`${pangolinDomain}`) && !PathPrefix(`/api/v1`)"
          service: next-service
          entryPoints:
            - websecure
          middlewares:
            - badger
          tls:
            certResolver: letsencrypt

        api-router:
          rule: "Host(`${pangolinDomain}`) && PathPrefix(`/api/v1`)"
          service: api-service
          entryPoints:
            - websecure
          middlewares:
            - badger
          tls:
            certResolver: letsencrypt

        ws-router:
          rule: "Host(`${pangolinDomain}`)"
          service: api-service
          entryPoints:
            - websecure
          middlewares:
            - badger
          tls:
            certResolver: letsencrypt

      services:
        next-service:
          loadBalancer:
            servers:
              - url: "http://pangolin:3002"

        api-service:
          loadBalancer:
            servers:
              - url: "http://pangolin:3000"

    tcp:
      serversTransports:
        pp-transport-v1:
          proxyProtocol:
            version: 1
        pp-transport-v2:
          proxyProtocol:
            version: 2
  '';

  sops.templates."traefik_dynamic.yml".restartUnits = [ "arion-pangolin.service" ];
}
