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

 module amp.output.htmlrenderer;

 import amp.apiwrappers;

 import mustache;
 import std.stdio;

 class HTMLRenderer
 {
     alias MustacheEngine!(string) Mustache;

     string htmlTemplatePath;
     APIRoot api;
     Mustache mustache;
     auto context = new Mustache.Context;

     public this(APIRoot api, string htmlTemplatePath)
     {
         this.api = api;
         this.htmlTemplatePath = htmlTemplatePath;
         this.createContext();
     }

     public void render(string templateName)
     {
         mustache.path  = this.htmlTemplatePath;
         mustache.level = Mustache.CacheLevel.no;
         stdout.rawWrite(mustache.render(templateName, context));
     }

     /++
     void addRecursiveContext(Mustache.Context cont, auto tuple)
     {
         foreach(i, ref part; tuple)
         {
             string partName = __traits(identifier, tuple[i]);

             // If the last letter of the name is a s -> plural -> list
             // NOTE this can lead to unexpected behaviour and should be changed to a secure method
             if(partName[$-1] == 's')
             {
                 auto subContext = cont.addSubContext(partName);
                 for (int j; j< part.length; j++) {
                     addRecursiveContext(subContext, part[j].tupleof);

                 }
             }
             else
             {
                 cont[partName] = part;
             }

         }
     }+/


     //TODO make this less disgusting (-.-)
     void createContext()
     {
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
                        paramContext["isRequired"] = param.isRequired;
                    }

                    foreach(Attribute attribute; action.attributes)
                    {
                        auto attributeContext = actionContext.addSubContext("attributes");
                        attributeContext["id"] = attribute.id;
                        attributeContext["name"] = attribute.name;
                        attributeContext["dataType"] = attribute.dataType;
                        attributeContext["description"] = attribute.description;
                    }
                }

                foreach(Attribute attribute; resource.attributes)
                {
                    auto attributeContext = resourceContext.addSubContext("attributes");
                    attributeContext["id"] = attribute.id;
                    attributeContext["name"] = attribute.name;
                    attributeContext["dataType"] = attribute.dataType;
                    attributeContext["description"] = attribute.description;
                }

                foreach(GETParameter param; resource.getParameters)
                {
                    auto paramContext = resourceContext.addSubContext("resourceGetParameters");
                    paramContext["id"] = param.id;
                    paramContext["name"] = param.name;
                    paramContext["dataType"] = param.dataType;
                    paramContext["description"] = param.description;
                    paramContext["isRequired"] = param.isRequired;
                }

            }
         }
     }
 }
