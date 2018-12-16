/++
    This file is part of AMP - API Markdown Processor.
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
import amp.jsonpath;

import std.stdio;
import std.json;
import std.conv : to;

int nextID = 0;

const string TITLE_PATH = "meta.title.content";
const string DESCRIPTION_PATH = "content[?element=copy].[0].content"; // can only be used when the description is saved in a "copy" element

/++
    Input: List of members containing attributes
    Location: Resource -> content -> datastructure -> content
+/
Attribute[] getAttributes(JSONValue json)
{
    Attribute[] attributes;

    // avoid exceptions when the json is null
    if(json.type == JSON_TYPE.NULL)
        return attributes;

    auto inputPath = new JSONPath(json);

    /++
        If an Attribute is defined as
        + Attribute (User)
        only its name is stored in a dictionary, not an array
    +/
    if(json.type != JSON_TYPE.ARRAY)
    {
        if("element" in json)
            attributes ~= Attribute(nextID++, json["element"].str, json["element"].str);

        return attributes;
    }

    // parse the attributes
    foreach(JSONValue attribute; inputPath.parse("[?element=member]").array)
    {
        auto path = new JSONPath(attribute);
        string name = path.parseString("content.key.content");
        string description = path.parseString("meta.description.content");
        string defaultValue = path.parseString("content.value.content");
        string dataType = path.parseString("content.value.element");

        // if the datatype is an array, format the datatype like: [string]
        if(dataType == "array")
        {
            auto arrayDataType =  path.parseString("content.value.content[0].element");
            dataType ~= "[" ~ arrayDataType ~"]";
        }

        attributes ~= Attribute(nextID++, name, dataType, description, defaultValue);
    }

    return attributes;
}


/++
    Returns all GET parameters that are found at the top json level
    Expects content of hrefVarialbes
+/
GETParameter[] getGETParameters(JSONValue json)
{
    GETParameter[] params;

    if(json.type == JSON_TYPE.NULL)
        return params;

    auto inputPath = new JSONPath(json);

    foreach(JSONValue param; inputPath.parse("[?element=member]").array)
    {
        auto path = new JSONPath(param);

        string name = path.parseString("content.key.content");
        string dataType = path.parseString(TITLE_PATH);
        string description = path.parseString("meta.description.content");
        string constraint = path.parseString("attributes.typeAttributes.content[?element=string].[0].content");
        string defaultValue = path.parseString("content.value.attributes.default.content");

        bool isRequired = constraint != "optional";

        params ~= GETParameter(nextID++, name, dataType, description, isRequired, defaultValue);
    }

    return params;
}

/++
    Returns all Responses on the current json level
    Expects the content of a transaction as input
+/
Response[] getResponses(JSONValue json)
{
    Response[] responses;
    auto inputPath = new JSONPath(json);

    foreach(JSONValue responsej; inputPath.parse("[?element=httpResponse]").array)
    {
        auto path = new JSONPath(responsej);
        auto response = new APIElement(responsej);

        string jsonExample = path.parseString("content[?element=asset].[0].content");
        string description = path.parseString(DESCRIPTION_PATH);
        string jsonSchema = path.parseString("content[?element=asset].[1].content");
        string statusCodeStr = path.parseString("attributes.statusCode.content");

        int status = statusCodeStr == "" ? 0 : to!int(statusCodeStr);

        responses ~= Response(nextID++, jsonExample, description, status, jsonSchema);
    }

    return responses;
}

/++
    Returns all Requests on the current json level
    Expects the content of a transaction as input
+/
Request[] getRequests(JSONValue json)
{
    Request[] requests;

    auto inputPath = new JSONPath(json);

    foreach(JSONValue request; inputPath.parse("[?element=httpRequest]").array)
    {
        auto path = new JSONPath(request);

        string jsonExample = path.parseString("content[?element=asset].[0].content");
        string description = path.parseString(DESCRIPTION_PATH);
        string jsonSchema = path.parseString("content[?element=asset].[1].content");
        Attribute[] attributes = getAttributes(path.parse("content[?element=dataStructure].[0].content"));

        // TODO add support for multiple assets (json examples)

        requests ~= Request(nextID++, jsonExample, description, attributes, jsonSchema);
    }

    return requests;
}

/++
    Returns all actions (HTTP methods) on the current json level;
    actions are sequences of requests and responses
    Expects the content of a Resource as input
+/
Action[] getActions(JSONValue json)
{
    Action[] actions;

    auto inputPath = new JSONPath(json);

    // parse all actions and append them
    foreach(JSONValue action; inputPath.parse("[?element=transition]").array)   // transition = "action"
    {
        auto path = new JSONPath(action);

        auto title = path.parseString(TITLE_PATH);
        auto description = path.parseString(DESCRIPTION_PATH);
        auto httpMethod = "";
        auto url = path.parseString("attributes.href.content");

        GETParameter[] getParameters = getGETParameters(path.parse("attributes.hrefVariables.content"));
        Attribute[] attributes = getAttributes(path.parse("attributes.data.content.content"));

        Request[] requests;
        Response[] responses;

        // request response pairs are "httpTransactions" - here they get parsed
        foreach(JSONValue transaction; path.parse("content[?element=httpTransaction]").array)
        {
            auto transactionPath = new JSONPath(transaction);

            // the http method is extracted here, it belongs to a request in the JSON but we need it in the action
            httpMethod = transactionPath.parseString("content[?element=httpRequest].[0].attributes.method.content");

            if(requests.length == 0)    // avoid parsing the same request multiple times
                requests = getRequests(transactionPath.parse("content"));

            // get all responses
            foreach(Response response; getResponses(transactionPath.parse("content")))
                responses ~= response;
        }

        actions ~= Action(nextID++, title, description, httpMethod, url, requests, responses, getParameters, attributes);
    }
    return actions;
}


/++
    Returns all Resources found within a Group
    Expects the content of a Group as input
+/
Resource[] getResources(JSONValue json)
{
    Resource[] resources;
    auto inputPath = new JSONPath(json);

    // parse each resource and append it to resources
    foreach(JSONValue resource; inputPath.parse("[?element=resource]").array)
    {
        auto path = new JSONPath(resource);

        auto title = path.parseString(TITLE_PATH);
        auto url = path.parseString("attributes.href.content");// resource.getContentOrEmptyString(["attributes", "href"]);
        auto description = path.parseString(DESCRIPTION_PATH);
        Attribute[] attributes = getAttributes(path.parse("content[?element=dataStructure].[0].content.content"));
        auto actions = getActions(path.parse("content"));

        GETParameter[] getParameters = getGETParameters(path.parse("attributes.hrefVariables.content"));

        resources ~= Resource(nextID++, title, url, description, actions, attributes, getParameters);
    }

    return resources;
}

/++
    Returns all groups found within the first level of the jsonTree
    Location in JSON: category -> content -> category with the class (->meta->classes->content->content) resourceGroup
    Input: The content of an APIRoot
+/
Group[] getGroups(JSONValue json)
{
    Group[] groups;

    auto inputPath = new JSONPath(json);

    foreach(JSONValue group; inputPath.parse("content[?element=category]").array)       // categories = groups
    {
        auto path = new JSONPath(group);
        if(path.parseString("meta.classes.content[0].content") == ElementType.ResourceGroup)        // verify that the object is valid
        {
            groups ~= Group(nextID++, path.parseString(TITLE_PATH),path.parseString(DESCRIPTION_PATH), getResources(path.parse("content")));
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

    auto path = new JSONPath(json);

    auto title = path.parseString(TITLE_PATH);
    auto description = path.parseString(DESCRIPTION_PATH);

    return APIRoot(nextID++, title, description, getGroups(json));
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
