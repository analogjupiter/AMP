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
module amp.output.html;

import std.array : appender;
import std.path : buildPath;
import std.stdio : File;
import std.string;
import amp.apiwrappers;
import amp.parser;
import amp.output.generic;
import mustache;

enum TemplateFileName = "amp";
enum TemplateFileExt = Mustache.Option().ext;
enum TemplateFileNameFull = TemplateFileName ~ '.' ~ TemplateFileExt;

private
{
    alias Mustache = MustacheEngine!string;
}

/++
    Mustache template based HTML output
 +/
class HTMLAPIDocsOutput : APIDocsOutput
{
final @safe:

    private
    {
        Mustache _mustache;
    }

    public
    {
        @property
        {
            /++
                Mustache instance used by the HTML outputter
             +/
            Mustache mustache()
            {
                return this._mustache;
            }
        }

        @property
        {
            /++
                Template directory to use
             +/
            string templatePath()
            {
                return this._mustache.path;
            }

            /++ ditto +/
            void templatePath(string value)
            {
                this._mustache.ext = TemplateFileExt;
                this._mustache.path = value;
            }
        }
    }

    /++
        ctor
     +/
    public this(string templatePath)
    {
        this._mustache.level = Mustache.CacheLevel.no;
        this._mustache.path = templatePath;
    }

    public @system
    {
        /++
            Converts the API def to HTML
         +/
        void write(ParserResult pr, File target)
        {
            target.rawWrite(mustache.render(TemplateFileName, pr.api.createContext));
        }
    }
}

/++
    Creates a Mustache context for the passed API def

    TODO: make this less disgusting (-.-)
 +/
Mustache.Context createContext(APIRoot api)
{
    auto context = new Mustache.Context;

    context["id"] = api.id;
    context["title"] = api.title;
    context["description"] = api.description;

    foreach(Group group; api.groups)
    {
        auto groupContext = context.addSubContext("groups");
        groupContext["id"] = group.id;
        groupContext["title"] = group.title;
        groupContext["description"] = group.description;

        foreach(Resource resource; group.resources)
        {
            auto resourceContext = groupContext.addSubContext("resources");
            resourceContext["id"] = resource.id;
            resourceContext["title"] = resource.title;
            resourceContext["url"] = resource.url;
            resourceContext["description"] = resource.description;

            foreach(Action action; resource.actions)
            {
                auto actionContext = resourceContext.addSubContext("actions");
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
                {
                    auto requestContext = actionContext.addSubContext("requests");
                    requestContext["id"] = request.id;
                    requestContext["jsonExample"] = request.jsonExample;
                    requestContext["description"] = request.description;
                }

                foreach(Response response; action.responses)
                {
                    auto responseContext = actionContext.addSubContext("responses");
                    responseContext["id"] = response.id;
                    responseContext["jsonExample"] = response.jsonExample;
                    responseContext["description"] = response.description;
                    responseContext["httpStatusCode"] = response.httpStatusCode;
                }

                foreach(GETParameter param; action.getParameters)
                {
                    auto paramContext = actionContext.addSubContext("getParameters");
                    paramContext["id"] = param.id;
                    paramContext["name"] = param.name;
                    paramContext["dataType"] = param.dataType;
                    paramContext["description"] = param.description;
                    if(param.isRequired)
                        auto temp = paramContext.addSubContext("isRequired");
                    paramContext["defaultValue"] = param.defaultValue;
                }

                foreach(Attribute attribute; action.attributes)
                {
                    auto attributeContext = actionContext.addSubContext("attributes");
                    attributeContext["id"] = attribute.id;
                    attributeContext["name"] = attribute.name;
                    attributeContext["dataType"] = attribute.dataType;
                    attributeContext["description"] = attribute.description;
                    attributeContext["defaultValue"] = attribute.defaultValue;
                }
            }

            foreach(Attribute attribute; resource.attributes)
            {
                auto attributeContext = resourceContext.addSubContext("attributes");
                attributeContext["id"] = attribute.id;
                attributeContext["name"] = attribute.name;
                attributeContext["dataType"] = attribute.dataType;
                attributeContext["description"] = attribute.description;
                attributeContext["defaultValue"] = attribute.defaultValue;
            }

            foreach(GETParameter param; resource.getParameters)
            {
                auto paramContext = resourceContext.addSubContext("resourceGetParameters");
                paramContext["id"] = param.id;
                paramContext["name"] = param.name;
                paramContext["dataType"] = param.dataType;
                paramContext["description"] = param.description;
                if(param.isRequired)
                    auto temp = paramContext.addSubContext("isRequired");
                paramContext["defaultValue"] = param.defaultValue;
            }
        }
    }

    return context;
}
