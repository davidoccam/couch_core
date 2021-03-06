-record(httpd,
    {mochi_req,
    peer,
    method,
    requested_path_parts,
    path_parts,
    db_url_handlers,
    user_ctx,
    req_body = undefined,
    design_url_handlers,
    auth,
    default_fun,
    url_handlers}).

-record(hstate, {
        socket :: inet:socket(),
        transport :: module(),
        loop :: {module(), any(), any()}}).
