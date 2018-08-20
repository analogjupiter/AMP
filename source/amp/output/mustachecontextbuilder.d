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
module amp.output.mustachecontextbuilder;

import std.array : appender;
import std.path : buildPath;
import std.stdio : File;
import std.string;
import amp.apiwrappers;
import amp.parser;
import amp.output.generic;
import mustache;

private
{
    alias Mustache = MustacheEngine!string;
}


interface IMustacheContextBuilder
{
    Mustache.Context getContext(APIRoot api);
}

/++
    Build the mustache context for the api object
+/
class MustacheContextBuilder : IMustacheContextBuilder
{
    public:
        Mustache.Context getContext(APIRoot api)
        {
            auto context = new Mustache.Context;

            context["id"] = api.id;
            context["title"] = api.title;
            context["description"] = api.description;

            foreach(Group group; api.groups)
                addContext(group, context);

            return context;
    }
    void addContext(Group group, Mustache.Context context)
    {
        auto groupContext = context.addSubContext("groups");
        groupContext["id"] = group.id;
        groupContext["title"] = group.title;
        groupContext["description"] = group.description;

        foreach(Resource resource; group.resources)
            addContext(resource, groupContext);
    }
    void addContext(Resource resource, Mustache.Context context)
    {
        auto resourceContext = context.addSubContext("resources");
        resourceContext["id"] = resource.id;
        resourceContext["title"] = resource.title;
        resourceContext["url"] = resource.url;
        resourceContext["description"] = resource.description;

        foreach(Action action; resource.actions)
            addContext(action, resource, resourceContext);

        foreach(Attribute attribute; resource.attributes)
            addContext(attribute, resourceContext);

        foreach(GETParameter param; resource.getParameters)
            addContext(param, "resourceGetParameters", resourceContext);
    }
    void addContext(Action action, Resource resource, Mustache.Context context)
    {
        auto actionContext = context.addSubContext("actions");
        actionContext["id"] = action.id;
        actionContext["title"] = action.title;
        actionContext["description"] = action.description;
        actionContext["httpMethod"] = action.httpMethod;
        actionContext["httpMethodClass"] = action.httpMethod.toLower;   // used for css classes
        if(action.url.length > 0)
            actionContext["actionUrl"] = action.url;
        else
            actionContext["actionUrl"] = resource.url;


        // This is a workaround because the boolean values are not rendered as defined (they are always false)
        // Empty lists get renedered once.
        if(action.getParameters.length > 0 || resource.getParameters.length > 0)
            auto temp = actionContext.addSubContext("hasGETParameters");

        if(action.attributes.length > 0)
            auto temp = actionContext.addSubContext("hasAttributes");

        foreach(Request request; action.requests)
            addContext(request, actionContext);
        foreach(Response response; action.responses)
            addContext(response, actionContext);
        foreach(GETParameter param; action.getParameters)
            addContext(param, "getParameters", actionContext);
        foreach(Attribute attribute; action.attributes)
            addContext(attribute, actionContext);
    }
    void addContext(Request request, Mustache.Context context)
    {
        auto requestContext = context.addSubContext("requests");
        requestContext["id"] = request.id;
        requestContext["jsonExample"] = request.jsonExample;
        requestContext["description"] = request.description;
        requestContext["jsonSchema"] = request.jsonSchema;
    }
    void addContext(Response response, Mustache.Context context)
    {
        auto responseContext = context.addSubContext("responses");
        responseContext["id"] = response.id;
        responseContext["jsonExample"] = response.jsonExample;
        responseContext["description"] = response.description;
        responseContext["httpStatusCode"] = response.httpStatusCode;
        responseContext["jsonSchema"] = response.jsonSchema;
    }
    void addContext(Attribute attribute, Mustache.Context context)
    {
        auto attributeContext = context.addSubContext("attributes");
        attributeContext["id"] = attribute.id;
        attributeContext["name"] = attribute.name;
        attributeContext["dataType"] = attribute.dataType;
        attributeContext["description"] = attribute.description;
        attributeContext["defaultValue"] = attribute.defaultValue;
    }
    void addContext(GETParameter param, string name, Mustache.Context context)
    {
        auto paramContext = context.addSubContext(name);
        paramContext["id"] = param.id;
        paramContext["name"] = param.name;
        paramContext["dataType"] = param.dataType;
        paramContext["description"] = param.description;
        if(param.isRequired)
            auto temp = paramContext.addSubContext("isRequired");
        paramContext["defaultValue"] = param.defaultValue;
    }
}
