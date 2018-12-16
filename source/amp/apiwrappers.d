/++
    This file is part of AMP - API Markdown Processor.
    Copyright (c) 2018  R3Vid
    Copyright (c) 2018  0xEAB

    This Source Code Form is subject to the terms of the Mozilla Public
    License, v. 2.0. If a copy of the MPL was not distributed with this
    file, You can obtain one at http://mozilla.org/MPL/2.0/.
 +/
module amp.apiwrappers;

import std.array;
import std.conv : to;


enum HTTPMethod{
    GET,
    POST,
    PATCH,
    PUT,
    DELETE
}

struct Attribute
{
    int id;
    string name;
    string dataType;
    string description;
    string defaultValue;
}

struct GETParameter
{
    int id;
    string name;
    string dataType;
    string description;
    bool isRequired;
    string defaultValue;
}

struct DTO
{
    int id;
    string jsonExample;
    string description;
}

struct Request
{
    int id;
    string jsonExample;
    string description;

    Attribute[] attributes;

    string jsonSchema;
}

struct Response
{
    int id;
    string jsonExample;
    string description;
    int httpStatusCode;
    string jsonSchema;
    Attribute[] attributes;


}

/++
    TODO httpMethod might schould be moved to Request,
    since it is a part of the request in the JSON
    this would allow to define multiple requests / respones within an action
+/
struct Action
{
    int id;
    string title;
    string description;
    string httpMethod;
    string url;

    Request[] requests;
    Response[] responses;
    GETParameter[] getParameters;
    Attribute[] attributes;

    string toString()
    {
        auto app = appender!string;

        app ~= "#ACTION ";
        app ~= title ~ "\t\t" ~ httpMethod;
        app ~= "\n" ~ description;
        app ~= "\nREQUESTS:";

        foreach(Request request; requests)
        {
            app ~= "\n\t" ~ request.to!string;
        }

        app ~= "\nRESPONSES:";

        foreach(Response response; responses)
        {
            app ~= "\n\t" ~ response.to!string;
        }

        app ~= "\nPARAMS:";
        foreach(GETParameter param; getParameters)
        {
            app ~= "\n\t" ~ param.to!string;
        }

        app ~= "\nATTRIBUTES:";
        foreach(Attribute attribute; attributes)
        {
            app ~= "\n\t" ~ attribute.to!string;
        }

        return app.data;
    }
}

struct Resource
{
    int id;
    string title;
    string url;
    string description;

    Action[] actions;       // = HTTP Methods
    Attribute[] attributes;     // = data type definitions
    GETParameter[] getParameters;       //HREF params for all actions i.e. /users/{id}

    string toString()
    {
        auto app = appender!string;

        app ~= "#RESOURCE ";
        app ~= title ~ "\t\t" ~ url;
        app ~= "\n" ~ description ~ "\n";

        foreach(Attribute attribute; attributes)
        {
            app ~= "\n" ~ attribute.to!string;
        }

        app ~= "\n";

        foreach(Action action; actions)
        {
            app ~= "\n\n" ~ action.to!string;
        }

        return app.data;
    }
}

struct Group
{
    int id;
    string title;
    string description;

    Resource[] resources;

    string toString()
    {
        auto app = appender!string;

        app ~= "#GROUP ";
        app ~= title;
        app ~= "\n" ~ description;

        foreach(Resource resource; resources)
        {
            app ~= "\n\n\n" ~ resource.to!string;
        }

        return app.data;
    }
}

struct APIRoot
{
    int id;
    string title;
    string description;

    Group[] groups;

    void opOpAssign(string op : "~")(APIRoot a2)
    {
        assert(0, "Not implemented yet");
    }

    string toString()
    {
        auto app = appender!string;

        app ~= "#API ROOT ";
        app ~= title;
        app ~= "\n" ~ description;

        foreach(Group group; groups)
        {
            app ~= "\n\n\n" ~ group.to!string;
        }

        return app.data;
    }
}
