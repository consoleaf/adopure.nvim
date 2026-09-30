# TODO

- [x] HTTP proxy support for api calls: honor `HTTPS_PROXY`/`HTTP_PROXY`
      environment variables and/or an explicit `vim.g.adopure.proxy` setting
      when issuing plenary.curl requests to the Azure DevOps host.
      (env vars flow through curl automatically; `vim.g.adopure.proxy` is
      passed as `--proxy`)
- [x] No-PAT auth mode: allow running without a PAT where authentication is
      injected upstream (e.g. a corporate proxy adding Kerberos/Windows auth
      to the request). The Authorization header is omitted when no PAT is
      configured; health check downgrades to a warning.
