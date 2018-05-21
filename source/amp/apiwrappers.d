/++
    This file is part of AMP - API Markup Processor.
    Copyright (c) 2018  R3Vid
    Copyright (c) 2018  0xEAB

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as
    published by the Free Software Foundation, either version 3 of the
    License, or (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.

    Linking this tool statically or dynamically with other modules is
    making a combined work based on this tool.  Thus, the terms and
    conditions of the GNU Affero General Public License cover the whole
    combination.

    As a special exception, the copyright holders of this tool give you
    permission to link this tool with independent modules to produce an
    executable, regardless of the license terms of these independent
    modules, and to copy and distribute the resulting executable under
    terms of your choice, provided that you also meet, for each linked
    independent module, the terms and conditions of the license of that
    module.  An independent module is a module which is not derived from
    or based on this tool.  If you modify this tool, you may extend
    this exception to your version of the tool, but you are not
    obligated to do so.  If you do not wish to do so, delete this
    exception statement from your version.
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
}

struct GETParameter
{
    int id;
    string name;
    string dataType;
    string description;
    bool isRequired;
}

struct Request
{
    int id;
    string jsonExample;
    string description;

    Attribute[] attributes;
}

struct Response
{
    int id;
    string jsonExample;
    string description;
    int httpStatusCode;

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
    int id;      // ids are strings for readability in the template
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
