----------------------------------------
-- Send a simple 404 response
----------------------------------------
core.register_service("send-404", "http", function(applet)
    response = [==[
<html><body><h1>404 Not Found</h1>
The requested URL was not found.
</body></html>
]==]
    applet:set_status(404, "Not Found")
    applet:add_header("Content-Length", "83")
    applet:add_header("Content-Type", "text/html")
    applet:add_header("Cache-Control", "no-cache")
    applet:start_response()
    applet:send(response)
end)
----------------------------------------
