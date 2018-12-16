/++
    This file is part of AMP - API Markdown Processor.
    Copyright (c) 2018  R3Vid
    Copyright (c) 2018  0xEAB

    This Source Code Form is subject to the terms of the Mozilla Public
    License, v. 2.0. If a copy of the MPL was not distributed with this
    file, You can obtain one at http://mozilla.org/MPL/2.0/.
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
