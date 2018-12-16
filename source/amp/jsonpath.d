/++
    This file is part of AMP - API Markdown Processor.
    Copyright (c) 2018  R3Vid
    Copyright (c) 2018  0xEAB

    This Source Code Form is subject to the terms of the Mozilla Public
    License, v. 2.0. If a copy of the MPL was not distributed with this
    file, You can obtain one at http://mozilla.org/MPL/2.0/.
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

        Command[] commands;

        foreach(string property; propertyChain)
        {
            auto indexOfStartBracket = indexOf(property, '[');

            if(indexOfStartBracket == -1)
                currentJsonValue = new ObjectQueryCommand(currentJsonValue, property).execute();
            else if(property[indexOfStartBracket + 1] == '?')
            {
                string condition = property[indexOfStartBracket + 2 .. property.length-1];
                string[] conditionParts = condition.split('=');

                string propertyName = property[0 .. indexOfStartBracket];
                currentJsonValue = new ObjectQueryCommand(currentJsonValue, propertyName).execute();

                currentJsonValue = new ConditionCommand!string(currentJsonValue, new EqualityStrategy!string(), conditionParts[0], conditionParts[1]).execute();
            }
            else
            {
                int propertyIndex = to!int(property[indexOfStartBracket + 1 .. property.length-1]);
                property = property[0 .. indexOfStartBracket];

                currentJsonValue = new ObjectQueryCommand(currentJsonValue, property).execute();
                currentJsonValue = new ArrayQueryCommand(currentJsonValue, propertyIndex).execute();
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
        if(property == "")  // return the unchanged json, if the property is empty (enables support for .string[condition].[0])
            return json;
        if(json.type == JSON_TYPE.OBJECT && property in json)
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
        if(json.type == JSON_TYPE.ARRAY && json.array.length > index)
        {
            return json[index];
        }
        else if(index == 0)
            return json;    // heuristic that, if the index is 0 and the json is not an array, that the contents are wanted
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
            if(strategy.evaluate(val[comparisonPropertyName].str, desiredValue))    // TODO remove .str with a more generic conversion method
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
