# TODO

- [ ] HTTP proxy support for api calls: honor `HTTPS_PROXY`/`HTTP_PROXY`
      environment variables and/or an explicit `vim.g.adopure.proxy` setting
      when issuing plenary.curl requests to the Azure DevOps host.
- [ ] No-PAT auth mode: allow running without a PAT where authentication is
      injected upstream (e.g. a corporate proxy adding Kerberos/Windows auth
      to the request). Today the plugin always sends a PAT-derived basic
      Authorization header; with an unset PAT the request should simply omit
      the header instead of erroring.
