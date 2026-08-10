{config, pangolinDomain, baseDomain, ...}:
{
  sops.templates."pangolin-config.yaml".content = ''
    # To see all available options, please visit the docs:
    # https://docs.pangolin.net/

    gerbil:
      start_port: 51820
      base_endpoint: "${pangolinDomain}"
    app:
      dashboard_url: "https://${pangolinDomain}"
      log_level: "info"
      telemetry:
        anonymous_usage: true

    domains:
      domain1:
        base_domain: "${baseDomain}"

    server:
      secret: "${config.sops.placeholder.pangolin-server-secret}"
      cors:
        origins: ["https://${pangolinDomain}"]
        methods: ["GET", "POST", "PUT", "DELETE", "PATCH"]
        allowed_headers: ["X-CSRF-Token", "Content-Type"]
        credentials: false

    flags:
      require_email_verification: false
      disable_signup_without_invite: true
      disable_user_create_org: false
      allow_raw_resources: true
  '';
}
