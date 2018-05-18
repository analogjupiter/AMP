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


Attribute[] getAttributes(JSONValue jsonTree)
{
    Attribute[] a;
    return a;
}

/++
    Gets the
+/
Request getRequest(JSONValue json)
{
    return Request();
}
/++
    Returns all actions (HTTP methods) on the current json level
+/
Action[] getActions(JSONValue jsonTree)
{
    auto apiTree = new APIElement(jsonTree);
    Action[] actions;

    foreach(APIElement actionElement; apiTree.getChildrenByElementType(ElementTypes.Action))
    {
        auto title = actionElement.title;
        auto description = actionElement.description;

        APIElement transaction = new APIElement(actionElement.content);
        transaction = transaction.findFirstElement(ElementTypes.Transaction); //new APIElement(actionElement.content[0]);  // TODO implement support for multiple transactions within an Action / transition

        //TODO check element type
        if(transaction)
        {
            APIElement transactionItems = new APIElement(transaction.content);
            APIElement requestElement = transactionItems.findFirstElement(ElementTypes.Request);

            // NOTE this technically belongs to the Request, not to the Action

            auto httpMethod = requestElement.getElementOrEmptyString(["attributes", "method"]);
            writeln(httpMethod);
        }


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
