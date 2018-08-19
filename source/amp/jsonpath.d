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
module amp.jsonpath;


import std.stdio;
import std.json;
import std.conv : to;
import std.array;
import std.string;

class JSONPath
{
    JSONValue json;

    this(JSONValue json)
    {
        this.json = json;
    }

    public JSONValue parse(string path)
    {
        string[] propertyChain = path.split(".");

        JSONValue currentJsonValue = json;

        foreach(string property; propertyChain)
        {
            if(property[0] == '*')
            {
                property = property[1 .. property.length];
                JSONValue[] valuesWithPropertyName;
                foreach(JSONValue val; currentJsonValue.array)
                {
                    writeln(property);
                    writeln(val);
                    if(val.type == JSON_TYPE.STRING)
                    {
                        if(val.str == property)
                            valuesWithPropertyName ~= val;
                    }
                    else if(property in val)
                        valuesWithPropertyName ~= val[property];
                }
                return JSONValue(valuesWithPropertyName);
            }

            auto indexOfStartBracket = indexOf(property, '[');

            // condition
            if(property[indexOfStartBracket + 1] == '?')
            {
                string condition = property[indexOfStartBracket + 2 .. property.length-1];
                string[] conditionParts = condition.split('=');

                string smallProperty = property[0 .. indexOfStartBracket];

                JSONValue[] valuesWithPropertyName;

                foreach(JSONValue val; currentJsonValue[smallProperty].array)
                {
                    if(val[conditionParts[0]].str == conditionParts[1])
                        valuesWithPropertyName ~= val;
                }

                return JSONValue(valuesWithPropertyName);
            }
            else if(indexOfStartBracket> -1)
            {
                int propertyIndex = to!int(property[indexOfStartBracket + 1 .. property.length-1]);
                property = property[0 .. indexOfStartBracket];

                currentJsonValue = currentJsonValue[property][propertyIndex];
            }
            else
            {
                if(property in currentJsonValue)
                currentJsonValue = currentJsonValue[property];
                else
                return JSONValue();
            }

        }

        return currentJsonValue;
    }

    //TODO make generic
    string parseString(string path)
    {
        JSONValue json = parse(path);

        if(json.type == JSON_TYPE.STRING)
            return json.str;

        return "";
    }
}

interface Command
{
    JSONValue execute();
}

class ObjectQueryCommand : Command
{
    JSONValue json;
    string property;

    this(JSONValue json, string property)
    {
        this.json = json;
        this.property = property;
    }

    public JSONValue execute()
    {
        if(property in json)
            return json[property];
        else
            return JSONValue();
    }
}

class ArrayQueryCommand : Command
{
    JSONValue json;
    int index;

    this(JSONValue json, int index)
    {
        this.json = json;
        this.index = index;
    }

    public JSONValue execute()
    {
        if(json.type == JSON_TYPE.ARRAY)
        {
            return json[index];
        }
        else
            return JSONValue();
    }
}

class ConditionCommand(T) : Command
{
    JSONValue json;
    ConditionStrategy!T strategy;
    T comparisonPropertyName;
    T desiredValue;

    this(JSONValue json, ConditionStrategy!T strategy, T comparisonPropertyName, T desiredValue)
    {
        this.json = json;
        this.strategy = strategy;
        this.comparisonPropertyName = comparisonPropertyName;
        this.desiredValue = desiredValue;
    }

    public JSONValue execute()
    {
        JSONValue[] foundValues;

        if(json.type != JSON_TYPE.ARRAY)
            return JSONValue();

        foreach(JSONValue val; json.array)
        {
            if(strategy.evaluate(val[comparisonPropertyName].str), desiredValue)    // TODO remove .str with a more generic conversion method
                foundValues ~= val;
        }

        return JSONValue(foundValues);
    }
}

interface ConditionStrategy(T)
{
    bool evaluate(T actual, T expectation);
}

class EqualityStrategy(T) : ConditionStrategy!T
{
    public bool evaluate(T actual, T expectation)
    {
        return actual == expectation;
    }
}
