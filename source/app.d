// import std.stdio;
import core.stdc.string;
import core.thread : sleep;

import core.stdc.stdio;

import microhttpd;
import libmicrohttpd.server;
import libmicrohttpd.cslice;

extern (C) int paramFiller (void* cls,
    MHD_ValueKind kind,
    const(char)* key,
    const(char)* value)
{
    c_slice* param_slice = cast(c_slice*) cls;

    GetParam param = GetParam(key, value);

    param_slice.append(&param);

    return 1;
}



int main(string[] args)
{
    import core.memory : GC;
    //GC.disable();

    ServerCtx server;
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

        server.add_route("/ben", cast(PageCallback) (
                const HandlerData hData
                )
            {
                return hData.connection.respond_with_text("<h1> Hello Ben <h1> <br /> <h2> Happy new Year </h2>");
            }
        );

        server.add_route("/don", cast(PageCallback) (
                const HandlerData hData
                )
            {
                return hData.connection.respond_with_text("<h1> Hello Don <h1>");
            }
        );

        server.add_route("/help", cast(PageCallback)(
				const HandlerData hData
			)
			{
                const server_ctx = (cast(ServerCtx*)hData.cls);
                static char[4096] page_text = '\0';
                char* page = page_text.ptr;

				page += sprintf(page, "<html><head><title>Help Page</title></head>" 
                    ~ "<h2> available routes are: </h2>");

                page += sprintf(page, "<h3> number of routes: %d </h3>", 
                    server_ctx.route_callbacks.length);
               
			    foreach(route;server_ctx.route_callbacks.keys)
				{
                 	page += sprintf(page, "%.*s <br/>", route.length, route.ptr);
				}

                return hData.connection.respond_with_text(page_text[0 .. page - page_text.ptr]);
			}
		);

        server.prefix_macthing_route("/complements", cast(PrefixMathcingCallback) (
                const HandlerData hData,
                const char[] afterPrefix
            )
            {
                c_slice getParams_c = c_slice(GetParam.sizeof);

                if (getParams_c.ptr == null)
                {
                    getParams_c.tupleof[1 .. $] = allocate(GetParam.sizeof).tupleof[1 .. $];
                }
                else
                {
                    (&getParams_c).reset();
                }

                char[2048] text = '\0';
                char* textp = &text[0];

                textp += sprintf(textp, "<html><head></head><body>"); 


                MHD_get_connection_values(
                    cast(MHD_Connection*)hData.connection,
                    MHD_ValueKind.MHD_GET_ARGUMENT_KIND,
                    cast(MHD_KeyValueIterator)&paramFiller,
                    cast(void*)&getParams_c
                );
                    

                textp += sprintf(textp, "<br /> url after prefix: %.*s\n", afterPrefix.length, afterPrefix.ptr);

                foreach(p;(cast(GetParam*)getParams_c.ptr)[0 .. getParams_c.length])
                {
                    textp += sprintf(textp, "<br /> %s = %s", p.key, p.value);
                }

                auto string_length = textp - &text[0];

                textp += sprintf(textp, "</body></html>");

                return hData.connection.respond_with_text(text.ptr[0 .. string_length]);
            }
        );
    }


    auto mhd = server.listen(14321);
    if (!mhd)
    {
        printf("could not start server on port 14321\n");
        return 1;
    }

	while(!we_are_out && !server.terminate)
	{
        import util : structToString;
        import std.stdio;
        sleep(1);
        GC.minimize();
        sleep(4);
        writeln(/*structToString(*/GC.stats()/*)*/);

        //GC.disable();
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

    char[4096] page_buffer = '\0';
    char* page = &page_buffer[0];

    page += sprintf(page, "<html><body>Hello, browser! <br /> Url: %s", url);
    page += sprintf(page, "<br /> Have seen: '%s'", have_seen);

    if (have_seen_string != "YES")
    {
        headers = (&header)[0 .. 1];
    }

    page += sprintf(page, "</body></html>");


    return connection.respond_with_text(page_buffer[0 .. page - page_buffer.ptr], headers);
}

