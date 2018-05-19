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
 +/
module amp.jsontreeprocessor;

import amp.parser;
import amp.apielement;
import amp.apiwrappers;

import std.stdio;
import std.json;
import std.conv : to;

Attribute[] getAttributes(JSONValue jsonTree)
{
    Attribute[] a;
    return a;
}


/++
    Returns all GET parameters that are found at the top json level
    Expects content of hrefVarialbes
+/
GETParameter[] getGETParameters(JSONValue json)
{
    auto api = new APIElement(json);
    GETParameter[] params;

    foreach(APIElement paramElement; api.getChildrenByElementType(ElementTypes.Member))
    {
        string name = paramElement.getElementOrEmptyString(["content", "key"]);
        string dataType = paramElement.title;
        string description = paramElement.description;
        string constraint = "";

        writeln(paramElement.attributes.jsonElement["typeAttributes"]);
        if("typeAttributes" in paramElement.attributes.jsonElement)
        constraint = paramElement.attributes.jsonElement["typeAttributes"]["content"][0]["content"].str;

        bool isRequired = constraint != "optional";

        params ~= GETParameter(name, dataType, description, isRequired);
    }

    return params;
}

/++
    Returns all Responses on the current json level
    Expects the content of a transaction as input
+/
Response[] getResponses(JSONValue json)
{
    auto api = new APIElement(json);
    Response[] responses;

    foreach(APIElement responseElement; api.getChildrenByElementType(ElementTypes.Response))
    {
        string jsonExample = "";
        string description = "";

        auto foo = new APIElement(responseElement.content);

        APIElement responseAsset = foo.findFirstElement(ElementTypes.Asset);
        if(responseAsset)
            jsonExample = responseAsset.content.str;


        APIElement responseDescription = foo.findFirstElement(ElementTypes.Description);

        if(responseDescription)
            description = responseDescription.content.str;

        string statusCodeStr = responseElement.getElementOrEmptyString(["attributes", "statusCode", "content"]);
        int status = 0;
        if(statusCodeStr != "")
            status = to!int(statusCodeStr);

        Response response = Response(jsonExample, description, status);

        responses ~= response;
    }

    return responses;
}

/++
    Returns all Requests on the current json level
    Expects the content of a transaction as input
+/
Request[] getRequests(JSONValue json)
{
    auto api = new APIElement(json);
    Request[] requests;

    foreach(APIElement requestElement; api.getChildrenByElementType(ElementTypes.Request))
    {
        string jsonExample = "";
        string description = "";

        auto foo = new APIElement(requestElement.content);

        APIElement requestAsset = foo.findFirstElement(ElementTypes.Asset);
        if(requestAsset)
            jsonExample = requestAsset.content.str;


        APIElement requestDescription = foo.findFirstElement(ElementTypes.Description);

        if(requestDescription)
            description = requestDescription.content.str;

        Request request = Request(jsonExample, description);

        requests ~= request;
    }

    return requests;
}

/++
    Returns all actions (HTTP methods) on the current json level
    Expects the content of a Resource as input
+/
Action[] getActions(JSONValue jsonTree)
{
    auto apiTree = new APIElement(jsonTree);
    Action[] actions;

    foreach(APIElement actionElement; apiTree.getChildrenByElementType(ElementTypes.Action))
    {
        auto title = actionElement.title;
        auto description = actionElement.description;
        auto httpMethod = "";
        Request[] requests;
        Response[] responses;
        GETParameter[] getParameters;

        if("attributes" in actionElement.jsonElement)
        {
            APIElement hrefVariables = new APIElement(actionElement.jsonElement["attributes"]["hrefVariables"]);
            if("content" in hrefVariables.jsonElement)
                getParameters = getGETParameters(hrefVariables.content);
        }

        // NOTE multiple transactions and mmultiple requests / responses within a transaction may not work
        APIElement transaction = new APIElement(actionElement.content);
        transaction = transaction.findFirstElement(ElementTypes.Transaction);

        //TODO check element type
        if(transaction)
        {
            APIElement transactionItems = new APIElement(transaction.content);
            APIElement requestElement = transactionItems.findFirstElement(ElementTypes.Request);

            // NOTE this technically belongs to the Request, not to the Action
            if(requestElement)
                httpMethod = requestElement.getElementOrEmptyString(["attributes", "method"]);

            requests = getRequests(transaction.content);
            responses = getResponses(transaction.content);
        }

        auto action = Action(title, description, httpMethod, requests, responses);
        actions ~= action;
    }

    return actions;
}

Resource[] getResources(JSONValue jsonTree)
{
    Resource[] resources;

    foreach(JSONValue json; jsonTree.array)
    {
        auto apiElement = new APIElement(json);

        if(apiElement.isElementType(ElementTypes.Resource))
        {
            auto title = apiElement.title;
            auto url = json["attributes"]["href"]["content"].str;
            auto description = apiElement.description;

            auto resource = Resource(title, url, description);

            resource.attributes = getAttributes(apiElement.content);
            resource.actions = getActions(apiElement.content);

            resources ~= resource;
        }
    }

    return resources;
}

/++
    Returns all groups found within the first level of the jsonTree
+/
Group[] getGroups(JSONValue jsonTree)
{
    Group[] groups;

    /++
        Iterate over all potential Resource groups (= content of an API)
        parse and add all resource groups to the api root
    +/
    foreach(JSONValue json; jsonTree.array)
    {
        auto apiElement = new APIElement(json);

        if(apiElement.isElementType(ElementTypes.Group) &&
            json["meta"]["classes"]["content"][0]["content"].str == ElementTypes.ResourceGroup)
        {
            auto group = Group(apiElement.title, apiElement.description);
            group.resources = getResources(apiElement.content);

            groups ~= group;
        }
    }

    return groups;
}

/++
    Converts the first (root) Element into an APIRoot
    TODO implement functionality to handle mutliple "APIRoots"
+/
APIRoot parseRoot(JSONValue element)
{
    if(element["element"].str != "category")
        writeln("Root element not found!");

    auto title = element["meta"]["title"]["content"].str;
    auto description = "";
    foreach(JSONValue val; element["content"].array)
    {
        if(val["element"].str == "copy")
            description = val["content"].str;
    }

    writeln(title);
    writeln(description);

    return APIRoot(title,description);
}

/++
    Converts the provided JSON into an APIRoot object
+/
APIRoot parse(JSONValue jsonTree)
{
    JSONValue firstElement = jsonTree["content"][0];

    auto api = parseRoot(firstElement);

    api.groups = getGroups(firstElement["content"]);

    return api;
}
