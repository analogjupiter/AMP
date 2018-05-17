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
import std.stdio;
import std.json;
import amp.parser;

enum ElementTypes{
    Group = "category",
    ResourceGroup = "resourceGroup",
    Description = "description"
}

/++
    Abstraction of a JSONValue representing an Element from the parse result
+/
class APIElement
{
    JSONValue jsonElement;

    this(JSONValue jsonElement)
    {
        this.jsonElement = jsonElement;
    }

    public:

    /++
        Properties return the specified element, or an empty string if the element wasn't found.
    +/
    @property
    {
        /++
            Location: content
        +/
        JSONValue content()
        {
            return this.jsonElement["content"];
        }


        /++
            Location: meta -> title -> content
        +/
        string title()
        {
            try
            {
                return this.jsonElement["meta"]["title"]["content"].str;
            }
            catch(JSONException ex)
            {
                return "";
            }
        }

        /++
            Location: content -> element of type "copy" -> content
        +/
        string description()
        {
            try
            {
                /++ TODO search all elements instead of just taking the first one +/
                if(this.content[0]["element"].str != "copy")
                    writeln("The description could not be found!!");
                return this.content[0]["content"].str;
            }
            catch(JSONException ex)
            {
                return "";
            }
        }


    }

    bool isElementType(string type) const
    {
        return this.jsonElement["element"].str == type;
    }
}

APIRoot parse(JSONValue jsonTree)
{
    auto api = parseRoot(jsonTree["content"][0]);
    api.groups = getGroups(jsonTree["content"]["content"]);

    return api;
}

Group[] getGroups(JSONValue jsonTree)
{
    Group[] groups;
    /++
        Iterate over all potential Resource groups (= content of an API)
        parse and add all resource groups to the api root
    +/
    foreach(JSONValue val; jsonTree["content"]["content"].array)
    {
        auto apiElement = new APIElement(val);
        if(apiElement.isElementType(ElementTypes.Group) &&
            val["meta"]["classes"]["content"]["content"].str == ElementTypes.ResourceGroup)
        {
            groups ~= Group(apiElement.title, apiElement.description);
        }
    }

    return groups;
}


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
