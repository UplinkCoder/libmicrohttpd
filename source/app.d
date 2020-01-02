// import std.stdio;
import core.stdc.string;
import core.thread : sleep;

import core.stdc.stdio;

import microhttpd;
import libmicrohttpd.server;

int main(string[] args)
{
    static ServerCtx server;
	{
        server.add_route("/hello", transform_handler!handler);

        server.add_route("/exit", cast(PageCallback) (
                const HandlerData hData
            )
            {
                we_are_out = 1;
                return hData.connection.respond_with_text("<h1> exiting <h1>");
            }

        );

        server.add_route("/dani", cast(PageCallback) (
                const HandlerData hData
                )
            {
                return hData.connection.respond_with_text("<h1> Hello Dani <h1>");
            }
            
            );

		server.add_route("/help", cast(PageCallback)(
				const HandlerData hData
			)
			{
				enum page_text_header = 
					"<html><head><title>Help Page</title></head>";

				const(char)[] page_text_body = 
					"<body> <h2> avilable routes are: </h2>";

				foreach(route;server.route_callbacks.keys)
				{
					page_text_body ~= route ~ "<br/>";
				}
				auto page_text = page_text_header ~ page_text_body ~ "</body></html>";

				return hData.connection.respond_with_text(page_text);
					
			}
		);

            //server.add_route
	}


    auto mhd = server.fire(14321);
    if (!mhd)
    {
        printf("could not start server on port 14321\n");
        return 1;
    }

	while(!we_are_out && !server.terminate)
	{
		sleep(5);
	}

	server.stop();

	return 0;
}



extern (C) int handler (
	void *cls, MHD_Connection *connection,
	const (char) *url,
	const (char) *method, const (char) *version_,
	const (char) *upload_data,
	size_t *upload_data_size, void **con_cls
)
{

	string url_string = cast(string) url[0 .. strlen(url)];
    MHD_Response *response;

	auto have_seen = MHD_lookup_connection_value(connection,
		MHD_ValueKind.MHD_COOKIE_KIND,
		"HAVESEEN"
    );

	string have_seen_string = have_seen ? cast(string) have_seen[0 .. strlen(have_seen)] : "null";
    Header header = Header("Set-Cookie", "HAVESEEN=YES");
    Header[] headers = null;

    const (char)[] page  = "<html><body>Hello, browser!" ~
		"<br /> Url: " ~ url_string ~ 
		"<br /> HaveSeen: " ~ have_seen_string;


    if (have_seen_string != "YES")
    {
        printf("HaveSeen : '%s'\n", have_seen);
        page ~= "<br />Adding Header";
        headers = (&header)[0 .. 1];
    }

    page ~= "</body></html>";


    return connection.respond_with_text(page, headers);


}

