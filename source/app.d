// import std.stdio;
import core.stdc.string;
import core.thread : sleep;

import microhttpd;

__gshared int we_are_out = 0;

static __gshared HandlerClosure handler_cls;

int main(string[] args)
{
	void* handler_id = cast(void*) 32;

	auto mhd = 
		MHD_start_daemon(MHD_FLAG.MHD_USE_EPOLL_INTERNALLY_LINUX_ONLY, 14321, null, null, &handle_with_closure, &handler_cls, MHD_OPTION.MHD_OPTION_END);

	if (!mhd) return 1;

	{
        handler_cls.add_route("/hello", transform_handler!handler);

        handler_cls.add_route("/exit", cast(PageCallback) (
                const HandlerData hData
            )
            {
                we_are_out = 1;
                return hData.connection.respond_with_text("<h1> exiting <h1>");
            }

        );

		handler_cls.add_route("/help", cast(PageCallback)(
				const HandlerData hData
			)
			{
				enum page_text_header = 
					"<html><head><title>Help Page</title></head>";

				const(char)[] page_text_body = 
					"<body> <h2> avilable routes are: </h2>";

				foreach(route;handler_cls.route_callbacks.keys)
				{
					page_text_body ~= route ~ "<br/>";
				}
				auto page_text = page_text_header ~ page_text_body ~ "</body></html>";

				return hData.connection.respond_with_text(page_text);
					
			}
		);
	}

	while(!we_are_out && !handler_cls.terminate)
	{
		sleep(5);
	}

	MHD_stop_daemon(mhd);

	return 0;
}

int respond_with_text(const MHD_Connection* connection, const(char)[] page_text)
{
	MHD_Response *response;
	int ret;

	response = MHD_create_response_from_buffer (page_text.length,
		cast(void*) page_text.ptr, MHD_ResponseMemoryMode.MHD_RESPMEM_PERSISTENT);

	ret = MHD_queue_response (cast(MHD_Connection*)connection, MHD_HTTP_OK, response);
	MHD_destroy_response (response);

	return ret;
}


struct HandlerData
{	
	void *cls;
	MHD_Connection *connection;
	const (char) *url;
	const (char) *method;
	const (char) *version_;
	const (char) *upload_data;
	size_t *upload_data_size; 
	void **con_cls;

}

alias PageCallback = int function (const HandlerData data);

struct HandlerClosure
{
	bool terminate = false;

	PageCallback[string] route_callbacks;
	PageCallback fallback_callback = (
		const HandlerData hData
	)
	{
		string url_string = cast(string) hData.url[0 .. strlen(hData.url)];

		char[] page  = 
			cast(char[]) "<html><body>404 This page could not be found." ~
				"<br /> Url: " ~ url_string;
				
		page ~= "</body></html>";
		
		return respond_with_text(hData.connection, page);
	};

	void add_route(string route_string, PageCallback page_callback)
	{
		if (page_callback)
		{
			assert(route_string !in route_callbacks);
			route_callbacks[route_string] = page_callback;
		}
	}
}

template transform_handler(alias h)
{
    enum transform_handler = cast(PageCallback)
        (const HandlerData hData) { return h(cast(void*)hData.cls,
        cast(MHD_Connection*)hData.connection,
        hData.url,
        hData.method,
        hData.version_,
        hData.upload_data,
        cast(size_t*)hData.upload_data_size,
        cast(void**)hData.con_cls);
    };
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

	const char[] page  = "<html><body>Hello, browser!" ~
		"<br /> Url: " ~ url_string ~ 
		"<br /> HaveSeen: " ~ have_seen_string ~ "</body></html>";

    response = MHD_create_response_from_buffer (page.length,
        cast(void*) page.ptr, MHD_ResponseMemoryMode.MHD_RESPMEM_PERSISTENT);

    if (have_seen != "YES")
    {
        MHD_add_response_header(response,
            MHD_HTTP_HEADER_SET_COOKIE,
            "HAVESEEN=YES"
        );
    }


	int ret;
	ret = MHD_queue_response (connection, MHD_HTTP_OK, response);
	MHD_destroy_response (response);
	
	return ret;
}

extern (C) int handle_with_closure (
	void *cls, MHD_Connection *connection,
	const (char) *url,
	const (char) *method, const (char) *version_,
	const (char) *upload_data,
	size_t *upload_data_size, void **con_cls
	)
{
	
	string url_string = cast(string) url[0 .. strlen(url)];

	const HandlerClosure* hand_cls = cast(const HandlerClosure*) cls;
	const HandlerData hData = HandlerData(cls, connection, url, method, version_, upload_data, upload_data_size, con_cls);

	int ret;

	if (auto route_handler = url_string in handler_cls.route_callbacks)
	{
		ret = (*route_handler)(hData);
	}
	else
	{
		ret = hand_cls.fallback_callback(hData);
	}

	return ret;
}
