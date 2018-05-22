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
module amp.jsonprocessor;

import amp.parser;
import amp.apielement;
import amp.apiwrappers;

import std.stdio;
import std.json;
import std.conv : to;

int nextID = 0;

/++
    Input: List of members containing attributes
    Location: Resource -> content -> datastructure -> content
+/
Attribute[] getAttributes(APIElement api)
{
    Attribute[] attributes;

    /++
        If an Attribute is defined as
        + Attribute (User)
        only its name is stored in a dictionary, not an array
    +/
    if(api.jsonElement.type != JSON_TYPE.ARRAY)
    {
        if("element" in api.jsonElement)
            attributes ~= Attribute(nextID++, api.jsonElement["element"].str, api.jsonElement["element"].str);

        return attributes;
    }

    foreach(APIElement attribute; api.getChildrenByElementType(ElementType.Member))
    {
        string description = attribute.getContentOrEmptyString(["meta", "description"]);
        string name = attribute.getAPIElementOrNull(["content", "key"]).contentstr;
        string dataType = attribute.getAPIElementOrNull(["content", "value", "element"]).jsonElement.str;

        if(dataType == "array")
        {
            auto arrayContent = attribute.getAPIElementOrNull(["content", "value", "content"]);
            if(arrayContent)
            {
                auto arrayElement = arrayContent.jsonElement[0]["element"].str;
                dataType ~= "[" ~ arrayElement ~"]";
            }
        }

        string defaultValue = attribute.getContentOrEmptyString(["content", "value"]);

        attributes ~= Attribute(nextID++, name, dataType, description, defaultValue);
    }

    return attributes;
}


/++
    Returns all GET parameters that are found at the top json level
    Expects content of hrefVarialbes
+/
GETParameter[] getGETParameters(APIElement api)
{
    GETParameter[] params;

    foreach(APIElement param; api.getChildrenByElementType(ElementType.Member))
    {
        string name = param.getContentOrEmptyString(["content", "key"]);
        string dataType = param.title;
        string description = param.getContentOrEmptyString(["meta", "description"]);
        string constraint = "";

        APIElement constraintElements = param.getAPIElementOrNull(["attributes", "typeAttributes", "content"]);
        if(constraintElements)
            constraint = constraintElements.getChildrenByElementType("string")[0].contentstr;

        bool isRequired = constraint != "optional";

        string defaultValue = param.getContentOrEmptyString(["content", "value", "attributes", "default"]);

        params ~= GETParameter(nextID++, name, dataType, description, isRequired, defaultValue);
    }

    return params;
}

/++
    Returns all Responses on the current json level
    Expects the content of a transaction as input
+/
Response[] getResponses(APIElement api)
{
    Response[] responses;

    foreach(APIElement response; api.getChildrenByElementType(ElementType.Response))
    {
        string jsonExample = "";
        string description = "";

        auto responseContent = response.content;

        APIElement responseAsset = responseContent.findFirstElement(ElementType.Asset);
        if(responseAsset)
            jsonExample = responseAsset.content.jsonElement.str;


        APIElement responseDescription = responseContent.findFirstElement(ElementType.Description);
        if(responseDescription)
            description = responseDescription.contentstr;

        string statusCodeStr = response.getContentOrEmptyString(["attributes", "statusCode"]);
        int status = statusCodeStr == "" ? 0 : to!int(statusCodeStr);

        responses ~= Response(nextID++, jsonExample, description, status);
    }

    return responses;
}

/++
    Returns all Requests on the current json level
    Expects the content of a transaction as input
+/
Request[] getRequests(APIElement api)
{
    Request[] requests;

    foreach(APIElement request; api.getChildrenByElementType(ElementType.Request))
    {
        string jsonExample = "";
        string description = "";
        Attribute[] attributes;

        auto requestContent = request.content;      // contains description and assets


        // TODO add support for multiple assets
        APIElement requestAsset = requestContent.findFirstElement(ElementType.Asset);
        if(requestAsset)
            jsonExample = requestAsset.content.jsonElement.str;


        APIElement requestDescription = requestContent.findFirstElement(ElementType.Description);
        if(requestDescription)
            description = requestDescription.contentstr;

        APIElement attributeElement = requestContent.findFirstElement(ElementType.Attribute);
        if(attributeElement)
            attributes = getAttributes(attributeElement.content);


        requests ~= Request(nextID++, jsonExample, description, attributes);
    }

    return requests;
}

/++
    Returns all actions (HTTP methods) on the current json level
    Expects the content of a Resource as input
+/
Action[] getActions(APIElement api)
{
    Action[] actions;

    foreach(APIElement action; api.getChildrenByElementType(ElementType.Action))
    {
        auto title = action.title;
        auto description = action.description;
        auto httpMethod = "";
        auto url = "";
        Request[] requests;
        Response[] responses;
        GETParameter[] getParameters;
        Attribute[] attributes;

        APIElement parameters = action.getAPIElementOrNull(["attributes", "hrefVariables", "content"]);
        if(parameters)
            getParameters = getGETParameters(parameters);

        APIElement href = action.getAPIElementOrNull(["attributes", "href"]);
        if(href)
            url = href.contentstr;

        APIElement attributeElements = action.getAPIElementOrNull(["attributes", "data", "content", "content"]);
        if(attributeElements)
            attributes = getAttributes(attributeElements);

        // NOTE multiple transactions and mmultiple requests / responses within a transaction will not work
        APIElement transaction = action.content;
        transaction = transaction.findFirstElement(ElementType.Transaction);

        if(transaction)
        {
            APIElement transactionItems = transaction.content;
            APIElement requestElement = transactionItems.findFirstElement(ElementType.Request);

            // NOTE this technically belongs to the Request, not to the Action
            if(requestElement)
                httpMethod = requestElement.getContentOrEmptyString(["attributes", "method"]);

            requests = getRequests(transaction.content);
            responses = getResponses(transaction.content);
        }

        actions ~= Action(nextID++, title, description, httpMethod, url, requests, responses, getParameters, attributes);
    }

    return actions;
}


/++
    Returns all Resources found within a Group
    Expects the content of a Group as input
+/
Resource[] getResources(APIElement api)
{
    Resource[] resources;

    foreach(APIElement resource; api.getChildrenByElementType(ElementType.Resource))
    {
        auto title = resource.title;
        auto url = resource.getContentOrEmptyString(["attributes", "href"]);
        auto description = resource.description;
        Attribute[] attributes;
        GETParameter[] getParameters;

        auto actions = getActions(resource.content);

        APIElement dataStructure = resource.content.findFirstElement(ElementType.Attribute);
        if(dataStructure)
        {
            auto attributeElements = dataStructure.getAPIElementOrNull(["content", "content"]);
            if(attributeElements)
                attributes = getAttributes(attributeElements);
        }

        APIElement hrefVariables = resource.getAPIElementOrNull(["attributes", "hrefVariables", "content"]);
        if(hrefVariables)
            getParameters = getGETParameters(hrefVariables);

        resources ~= Resource(nextID++, title, url, description, actions, attributes, getParameters);
    }

    return resources;
}

/++
    Returns all groups found within the first level of the jsonTree
    Location in JSON: category -> content -> category with the class (->meta->classes->content->content) resourceGroup
    Input: The content of an APIRoot
+/
Group[] getGroups(APIElement api)
{
    Group[] groups;

    foreach(APIElement group; api.getChildrenByElementType(ElementType.Group))
    {
        if(group.jsonElement["meta"]["classes"]["content"][0]["content"].str == ElementType.ResourceGroup)
        {
            groups ~= Group(nextID++, group.title, group.description, getResources(group.content));
        }
    }

    return groups;
}

/++
    Converts the first (root) Element into an APIRoot
    TODO implement functionality to handle mutliple "APIRoots"
+/
APIRoot getAPIRoot(JSONValue json)
{
    if(json["element"].str != "category")
        stderr.writeln("Root element not found!");

    APIElement api = new APIElement(json);

    auto title = api.title;
    auto description = api.description;

    return APIRoot(nextID++, title, description, getGroups(api.content));
}

/++
    Converts the provided JSON into an APIRoot object
    TODO resolve global Attribute references
+/
APIRoot process(JSONValue json)
{
    JSONValue firstElement = json["content"][0];

    auto api = getAPIRoot(firstElement);

    return api;
}
