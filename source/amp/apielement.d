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

enum ElementTypes{
    Group = "category",
    ResourceGroup = "resourceGroup",
    Resource = "resource",
    Action = "transition",
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

    /++
        Checks whether the item at the highest level of the json tree (jsonElement)
        equals the specified type
    +/
    bool isElementType(string type) const
    {
        return this.jsonElement["element"].str == type;
    }

    /++
        Returns the element at the end of the key sequence,
        if one of the keys does not exist, an empty string is returned

        Example: keys = ["a", "b"]
        returns json["a"]["b"] or ""
    +/
    string getElementOrEmptyString(string[] keys)
    {
        JSONValue content = this.jsonElement;

        foreach(string key; keys)
        {
            if(key in content)
                content = content[key];
            else
                return "";
        }

        try
        {
            return content.str;
        }
        catch(JSONException ex)
        {
            return "";
        }
    }

    /++
        Returns all child elements with the specified elementType as APIElement
    +/
    APIElement[] getChildrenByElementType(string elementType)
    {
        APIElement[] children;

        foreach(JSONValue json; jsonElement.array)
        {
            auto apiElement = new APIElement(json);

            if(apiElement.isElementType(ElementTypes.Resource))
            {
                children ~= apiElement;
            }
        }

        return children;
    }

}
