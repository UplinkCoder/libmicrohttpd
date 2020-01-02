module libmicrohttpd.server;
import microhttpd;

__gshared int we_are_out = 0;

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

struct Header
{
    const (char)* header;
    const (char)* content;
}

alias PageCallback = int function (const HandlerData data);

extern (C) struct ServerCtx
{
    import core.stdc.string : strlen;

    MHD_Daemon* mhd;
    bool terminate;
    //HandlerClosure handler_cls;

    void* handler_id = cast(void*) 32;
    

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

    MHD_Daemon* fire(ushort port)
    {
        return mhd = 
            MHD_start_daemon(MHD_FLAG.MHD_USE_EPOLL_INTERNALLY_LINUX_ONLY,
                port,
                null,
                null,
                &this.handler,
                &this,
                MHD_OPTION.MHD_OPTION_END
            );
    }

    void stop()
    {
        if (mhd)
        {
            MHD_stop_daemon(mhd);
        }
        mhd = null;
    }

    void add_route(string route_string, PageCallback page_callback)
    {
        if (page_callback)
        {
            assert(route_string !in route_callbacks);
            route_callbacks[route_string] = page_callback;
        }
    }

    void prefix_macthing_route(string prefix, PageCallback page_callack)
    {

    }

    static extern (C) int handler (
        void *cls, MHD_Connection *connection,
        const (char) *url,
        const (char) *method, const (char) *version_,
        const (char) *upload_data,
        size_t *upload_data_size, void **con_cls
        )
    {
        
        string url_string = cast(string) url[0 .. strlen(url)];
        
        const ServerCtx* server_ctx = cast(const ServerCtx*) cls;
        const HandlerData hData = HandlerData(cls, connection, url, method, version_, upload_data, upload_data_size, con_cls);
        
        int ret;
        
        if (auto route_handler = url_string in server_ctx.route_callbacks)
        {
            ret = (*route_handler)(hData);
        }
        else
        {
            ret = server_ctx.fallback_callback(hData);
        }
        
        return ret;
    }

}

template transform_handler(alias h)
{
    enum transform_handler = cast(PageCallback)
        (const HandlerData hData)
        { 
            return h(
                cast(void*)hData.cls,
                cast(MHD_Connection*)hData.connection,
                hData.url,
                hData.method,
                hData.version_,
                hData.upload_data,
                cast(size_t*)hData.upload_data_size,
                cast(void**)hData.con_cls
            );
    };
}

MHD_Response* prepare_response_with_text(const(char)[] page_text)
{
    return MHD_create_response_from_buffer (page_text.length,
        cast(void*) page_text.ptr, MHD_ResponseMemoryMode.MHD_RESPMEM_PERSISTENT);

}


int respond_with_text(const MHD_Connection* connection, const(char)[] page_text, Header[] headers = null)
{
    MHD_Response *response;
    int ret;

    response = MHD_create_response_from_buffer (page_text.length,
        cast(void*) page_text.ptr, MHD_ResponseMemoryMode.MHD_RESPMEM_PERSISTENT);

    foreach(header;headers)
    {
        MHD_add_response_header(response, header.header, header.content);
    }

    ret = MHD_queue_response (cast(MHD_Connection*)connection, MHD_HTTP_OK, response);
    MHD_destroy_response (response);
    
    return ret;
}