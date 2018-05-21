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
module amp.apielement;

import std.stdio;
import std.json;
import std.conv : to;

enum ElementType{
    Group = "category",
    ResourceGroup = "resourceGroup",
    Resource = "resource",
    Action = "transition",
    Description = "copy",
    Transaction = "httpTransaction",
    Request = "httpRequest",
    Response = "httpResponse",
    Member = "member",
    Asset = "asset",         // Part of a Request or Response containing the message body
    Attribute = "dataStructure"
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
        APIElement content()
        {
            return new APIElement(jsonElement["content"]);
        }

        /++
            Returns the content as string (if it is an integer or a string)
            If the content is not a string, an empty string is returned
        +/
        string contentstr()
        {
            if("element" in jsonElement)
            {
                if(jsonElement["element"].str == "number")
                    return jsonElement["content"].integer.to!string;
            }
            if("content" in jsonElement)
                return jsonElement["content"].str;
            else
                return "";
        }

        /++
            Location: meta -> title -> content
        +/
        string title()
        {
            return getContentOrEmptyString(["meta", "title"]);
        }

        /++
            Returns the description or an empty string
            Location: content -> element of type "copy" -> content
        +/
        string description()
        {
            auto descriptions = this.content.getChildrenByElementType(ElementType.Description);

            if(descriptions.length == 0)
                return "";
            else if(descriptions.length == 1)
                return descriptions[0].contentstr;
            else
            {
                writeln("WARNING: Multiple descriptions found for: ", this.jsonElement.toPrettyString());
                return descriptions[0].contentstr;      // NOTE only the first one is used
            }
        }

        APIElement attributes()
        {
            return this.getAPIElementOrNull(["attributes"]);
        }
    }

    /++
        Checks whether the item at the highest level of the json tree (jsonElement)
        equals the specified type
    +/
    bool isElementType(string type) const
    {
        return this.jsonElement["element"].str == type;
    }


    /++
        Returns the element at the end of the key sequence
        or null if a key does not exist

        Example: keys = ["a", "b"]
        returns json["a"]["b"] or null
    +/
    APIElement getAPIElementOrNull(string[] keys)
    {
        JSONValue content = this.jsonElement;

        foreach(string key; keys)
        {
            if(key in content)
                content = content[key];
            else
                return null;
        }

        return new APIElement(content);
    }

    /++
        Returns the content of the element at the end of the key sequence,
        if one of the keys or the content does not exist, an empty string is returned

        Example: keys = ["a", "b"]
        returns json["a"]["b"]["content"].str or ""
    +/
    string getContentOrEmptyString(string[] keys)
    {
        APIElement element = this.getAPIElementOrNull(keys);

        if(element)
            return element.contentstr;
        else
            return "";
    }

    /++
        Returns the frist element found of the specified type,
        returns null if the Element is not found
    +/
    APIElement findFirstElement(string elementType)
    {
        if(this.jsonElement.type != JSON_TYPE.ARRAY)
            throw new Exception("Find first element - JSONValue is not an array");

        foreach(JSONValue potentialElement; this.jsonElement.array)
        {
            auto apiElement = new APIElement(potentialElement);
            if(apiElement.isElementType(elementType))
                return apiElement;
        }

        return null;     // TODO
    }

    /++
        Returns all child elements with the specified elementType as APIElement
    +/
    APIElement[] getChildrenByElementType(string elementType)
    {
        APIElement[] children;

        foreach(JSONValue child; jsonElement.array)
        {
            auto apiElement = new APIElement(child);

            if(apiElement.isElementType(elementType))
            {
                children ~= apiElement;
            }
        }

        return children;
    }

}
